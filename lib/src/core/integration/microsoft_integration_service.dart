import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';
import 'graph_problem.dart';

/// One row of `public.integration_connections` for the signed-in user, read
/// under the table's own RLS (read-own). Mirrors the web
/// `IntegrationConnection` shape.
class IntegrationConnection {
  final String id;
  final String provider;
  final String status; // 'connected' | 'revoked' | …
  final String? accountEmail;
  final bool syncEnabled;
  final List<String> scopes;

  const IntegrationConnection({
    required this.id,
    required this.provider,
    required this.status,
    required this.accountEmail,
    required this.syncEnabled,
    required this.scopes,
  });

  bool get isConnected => status == 'connected';

  factory IntegrationConnection.fromMap(Map<String, dynamic> m) => IntegrationConnection(
        id: m['id'] as String,
        provider: (m['provider'] ?? 'microsoft') as String,
        status: (m['status'] ?? '') as String,
        accountEmail: m['account_email'] as String?,
        syncEnabled: (m['sync_enabled'] ?? false) as bool,
        scopes: (m['scopes'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[],
      );
}

/// Result of one Microsoft Graph call proxied through the `graph-proxy` Edge
/// Function: the upstream HTTP [status] and the decoded [data] body, or — when
/// the call did not succeed — the classified [problem] (never a silent null).
class GraphResult {
  final int status;
  final dynamic data;

  /// Why the call failed; null on success.
  final GraphProblem? problem;

  const GraphResult(this.status, this.data, {this.problem});

  /// A failed call. [status] mirrors [GraphProblem.status] (Graph's own status
  /// when Graph answered — so callers can still branch on 404 / 412).
  GraphResult.failure(GraphProblem this.problem, {this.data})
      : status = problem.status;

  bool get ok => problem == null && status >= 200 && status < 400;
}

/// Outcome of reading the user's Microsoft connection, so a screen can tell
/// "not connected" from "could not be checked" and from "needs to be renewed".
class ConnectionLookup {
  /// The usable (`status = 'connected'`) connection, if any.
  final IntegrationConnection? connection;

  /// A connection row that exists but is not usable (expired / revoked /
  /// error) — the account has to be reconnected.
  final IntegrationConnection? stale;

  /// The read itself failed (network / server) — the state is UNKNOWN.
  final bool failed;

  const ConnectionLookup({this.connection, this.stale, this.failed = false});

  bool get isConnected => connection != null;
  bool get needsReconnect => connection == null && stale != null;
}

/// What came back from the browser leg of the Microsoft connect flow, for the
/// screens that started it. `DeepLinkService` writes here when the app is
/// reopened by `<scheme>://oauth-callback?...`; `MicrosoftIntegrationScreen`
/// and `MsMailboxScreen` listen.
class MicrosoftOAuthReturn {
  MicrosoftOAuthReturn._();

  /// The last non-success outcome (declined / admin consent required / failed
  /// / admin-consent granted or declined). A screen that showed it clears it.
  static final ValueNotifier<OAuthReturnNotice?> notice =
      ValueNotifier<OAuthReturnNotice?>(null);

  /// Bumped every time an `oauth_complete` hand-off finished (successfully or
  /// not) — listeners re-read the connection instead of guessing the timing.
  static final ValueNotifier<int> completions = ValueNotifier<int>(0);

  /// Record the result carried by an OAuth return deep link. Unknown
  /// parameters and unknown values are ignored.
  static OAuthReturnNotice? report(Uri uri) {
    final n = OAuthReturnNotice.fromQuery(uri.queryParameters);
    if (n != null) notice.value = n;
    return n;
  }

  /// The `oauth_complete` hand-off finished; [linked] false = the server
  /// refused it (expired / already used / started by another user).
  static void completed({required bool linked}) {
    if (!linked) notice.value = OAuthReturnNotice.failed;
    completions.value = completions.value + 1;
  }

  /// Test hook.
  @visibleForTesting
  static void reset() {
    notice.value = null;
    completions.value = 0;
  }
}

/// **Microsoft integration service (mobile)** — the client-side parity of the
/// web `IntegrationConnectionService`. It reuses the SAME, platform-neutral
/// Edge Functions as web (`oauth-start`, `graph-proxy`, `crm-mailbox-sync`,
/// `crm-calendar-sync`, `crm-contacts-import`); `functions.invoke` attaches the
/// user's JWT, so every call runs in the same tenant/RLS scope as web.
///
/// The connect flow returns to the app via a deep link: [startConnect] passes
/// the app's redirect URI to `oauth-start`; after the user authenticates in the
/// browser, `oauth-callback` upserts the connection and redirects to that URI,
/// reopening the app. Nothing here launches the browser — the caller opens the
/// returned `authUrl` (url_launcher) and refreshes on the deep-link return.
///
/// Ctor-inject (no service-locator dependency). Graph calls never return a
/// silent null: a failure carries a classified [GraphProblem] the screens turn
/// into an honest state. Connection reads have a throwing twin
/// ([lookupConnection]) for screens that must not show "not connected" when
/// the read itself failed.
class MicrosoftIntegrationService {
  final SupabaseClient _supabase;
  MicrosoftIntegrationService({required SupabaseClient supabase}) : _supabase = supabase;

  static const String provider = 'microsoft';

  /// All of the signed-in user's Microsoft connections (usually 0 or 1).
  Future<List<IntegrationConnection>> getConnections() async {
    try {
      final rows = await _supabase
          .from('integration_connections')
          .select('id,provider,status,account_email,sync_enabled,scopes')
          .eq('provider', provider);
      return (rows as List)
          .map((r) => IntegrationConnection.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      Logger.error('[ms-integration] getConnections failed', e);
      return const <IntegrationConnection>[];
    }
  }

  /// The user's single connected Microsoft account, or null.
  Future<IntegrationConnection?> getConnected() async {
    final conns = await getConnections();
    for (final c in conns) {
      if (c.isConnected) return c;
    }
    return null;
  }

  /// Like [getConnected], but tells the three "no usable connection" cases
  /// apart: never connected, connected-but-stale (reconnect), read failed.
  Future<ConnectionLookup> lookupConnection() async {
    try {
      final rows = await _supabase
          .from('integration_connections')
          .select('id,provider,status,account_email,sync_enabled,scopes')
          .eq('provider', provider);
      final conns = (rows as List)
          .map((r) => IntegrationConnection.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
      IntegrationConnection? stale;
      for (final c in conns) {
        if (c.isConnected) return ConnectionLookup(connection: c);
        stale ??= c;
      }
      return ConnectionLookup(stale: stale);
    } catch (e) {
      Logger.error('[ms-integration] lookupConnection failed', e);
      return const ConnectionLookup(failed: true);
    }
  }

  /// Start the OAuth connect flow: returns the Microsoft authorize URL to open
  /// in the device browser. [redirectAfter] is the app's deep-link URI that
  /// `oauth-callback` will bounce back to once the connection is written.
  Future<String?> startConnect({required String redirectAfter}) async {
    try {
      final res = await _supabase.functions.invoke('oauth-start', body: <String, dynamic>{
        'provider': provider,
        'redirect_after': redirectAfter,
      });
      final body = res.data;
      if (body is Map && body['auth_url'] is String) return body['auth_url'] as String;
      Logger.error('[ms-integration] oauth-start returned no auth_url', body);
      return null;
    } catch (e) {
      Logger.error('[ms-integration] startConnect failed', e);
      return null;
    }
  }

  /// Finish the connect flow (B-09, 2026-11-10): `oauth-callback` no longer writes the connection; it
  /// parks the code and returns to the app's deep link with `?oauth_complete=<nonce>`. This call — with
  /// the user's JWT — lets `oauth-start` exchange the code (PKCE) and write the connection only if this
  /// user started the flow. Returns true when the account was linked.
  Future<bool> completeConnect(String completion) async {
    try {
      final res = await _supabase.functions.invoke('oauth-start', body: <String, dynamic>{
        'action': 'complete',
        'completion': completion,
      });
      final body = res.data;
      final ok = res.status >= 200 && res.status < 300 && !(body is Map && body['error'] != null);
      if (!ok) Logger.error('[ms-integration] completeConnect rejected', body);
      return ok;
    } catch (e) {
      Logger.error('[ms-integration] completeConnect failed', e);
      return false;
    }
  }

  /// Proxy one Microsoft Graph call. [method] e.g. 'GET'/'POST'; [path] a
  /// relative Graph path starting with '/'. [beta] swaps the Graph API version to
  /// /beta (endpoints not yet GA, e.g. Planner rosters).
  ///
  /// Never throws and never returns null: a failed call is a [GraphResult]
  /// whose [GraphResult.problem] says why (not connected / reconnect / missing
  /// consent / throttled with retry-after / …). `graph-proxy` answers an
  /// upstream Graph failure with HTTP 502 and its own refusals with 401 / 403 /
  /// 409, all of which `functions.invoke` throws — the body is read from the
  /// exception and classified here.
  Future<GraphResult> graphCall(
    String method,
    String path, {
    Map<String, String>? query,
    dynamic body,
    bool beta = false,
  }) async {
    try {
      final res = await _supabase.functions.invoke('graph-proxy', body: <String, dynamic>{
        'provider': provider,
        'method': method,
        'path': path,
        if (query != null) 'query': query,
        if (body != null) 'body': body,
        if (beta) 'beta': true,
      });
      final env = res.data;
      if (env is Map && env['status'] is int) {
        final status = env['status'] as int;
        if (status >= 200 && status < 400) return GraphResult(status, env['data']);
        // Defensive: a 2xx envelope that reports an upstream failure.
        return GraphResult.failure(GraphProblem.classify(res.status, env), data: env['data']);
      }
      // graph-proxy always returns {status,data}; anything else is an error envelope.
      Logger.error('[ms-integration] graph-proxy bad envelope', env);
      return GraphResult.failure(GraphProblem.classify(res.status, env));
    } on FunctionException catch (e) {
      final problem = GraphProblem.classify(e.status, e.details);
      Logger.warning('[ms-integration] graphCall $method $path → $problem');
      final details = e.details;
      return GraphResult.failure(problem, data: details is Map ? details['data'] : null);
    } catch (e) {
      Logger.error('[ms-integration] graphCall failed ($method $path)', e);
      return GraphResult.failure(const GraphProblem(kind: GraphProblemKind.unavailable));
    }
  }

  /// Toggle background sync for a connection (the */10–*/15 crons honor this).
  Future<bool> setSyncEnabled(String connectionId, bool enabled) async {
    try {
      await _supabase
          .from('integration_connections')
          .update(<String, dynamic>{'sync_enabled': enabled})
          .eq('id', connectionId);
      return true;
    } catch (e) {
      Logger.error('[ms-integration] setSyncEnabled failed', e);
      return false;
    }
  }

  /// Trigger an immediate mailbox sync of the caller's own connection(s).
  Future<bool> syncMailbox() => _invokeAuthed('crm-mailbox-sync');

  /// Trigger an immediate 2-way calendar sync of the caller's own connection(s).
  Future<bool> syncCalendar() => _invokeAuthed('crm-calendar-sync');

  /// Import the caller's Outlook contacts into the CRM.
  Future<bool> importContacts() => _invokeAuthed('crm-contacts-import');

  Future<bool> _invokeAuthed(String fn) async {
    try {
      final res = await _supabase.functions.invoke(fn);
      final body = res.data;
      if (body is Map && body['error'] != null) {
        Logger.error('[ms-integration] $fn error', body['error']);
        return false;
      }
      return true;
    } catch (e) {
      Logger.error('[ms-integration] $fn failed', e);
      return false;
    }
  }

  /// Disconnect through the `integration-disconnect` Edge Function — the only
  /// supported path. It removes the Graph subscriptions at Microsoft, the
  /// refresh token in Vault and the connection row, and writes the audit
  /// record. (A direct client DELETE of the row skipped all of that; the RLS
  /// policy that allowed it is being removed server-side.)
  ///
  /// True only when the function reports `ok: true`. A partial teardown
  /// (HTTP 500 with `ok: false`) or a refusal (403 / 404) is false.
  Future<bool> disconnect(String connectionId) async {
    try {
      final res = await _supabase.functions.invoke(
        'integration-disconnect',
        body: <String, dynamic>{'connection_id': connectionId},
      );
      final body = res.data;
      final ok = res.status >= 200 && res.status < 300 && body is Map && body['ok'] == true;
      if (!ok) {
        Logger.error('[ms-integration] disconnect rejected', body);
      } else if (((body['subscriptions_failed'] as num?) ?? 0) > 0 || body['secret_removed'] == false) {
        Logger.warning('[ms-integration] disconnect: partial cleanup $body');
      }
      return ok;
    } on FunctionException catch (e) {
      Logger.error('[ms-integration] disconnect failed (HTTP ${e.status})', e.details);
      return false;
    } catch (e) {
      Logger.error('[ms-integration] disconnect failed', e);
      return false;
    }
  }
}
