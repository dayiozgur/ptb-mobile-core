import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';

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
/// Function: the upstream HTTP [status] and the decoded [data] body.
class GraphResult {
  final int status;
  final dynamic data;
  const GraphResult(this.status, this.data);
  bool get ok => status >= 200 && status < 400;
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
/// Ctor-inject (no service-locator dependency). Read/query errors are logged
/// and surfaced as empty/false; the caller decides how to present them.
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

  /// Proxy one Microsoft Graph call. [method] e.g. 'GET'/'POST'; [path] a
  /// relative Graph path starting with '/'. [beta] swaps the Graph API version to
  /// /beta (endpoints not yet GA, e.g. Planner rosters). Returns null on transport error.
  Future<GraphResult?> graphCall(
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
        return GraphResult(env['status'] as int, env['data']);
      }
      // graph-proxy always returns {status,data}; anything else is an error envelope.
      Logger.error('[ms-integration] graph-proxy bad envelope', env);
      return null;
    } catch (e) {
      Logger.error('[ms-integration] graphCall failed ($method $path)', e);
      return null;
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

  /// Disconnect: remove the connection row (RLS-scoped to the user). Cascade
  /// clears its Graph subscriptions; a fresh connect re-creates everything.
  Future<bool> disconnect(String connectionId) async {
    try {
      await _supabase.from('integration_connections').delete().eq('id', connectionId);
      return true;
    } catch (e) {
      Logger.error('[ms-integration] disconnect failed', e);
      return false;
    }
  }
}
