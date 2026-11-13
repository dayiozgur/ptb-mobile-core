/// Why a proxied Microsoft Graph call (through the `graph-proxy` Edge Function)
/// did not succeed — the small, stable set of states a screen must tell apart
/// instead of showing one generic error or an empty list.
///
/// Mobile parity of the web `IntegrationGraphProblemKind`
/// (`libs/core/services/src/integration-graph-problem.ts`) with one extra
/// state, [adminConsentRequired], split out of "missing consent" when Graph's
/// own wording says an administrator has to approve.
enum GraphProblemKind {
  /// No connection for this user (connect first).
  notConnected('not_connected'),

  /// The connection expired / was revoked, or Graph refused the token.
  reauth('reauth'),

  /// Connected, but the token lacks the permission (scope) for this call.
  missingConsent('missing_consent'),

  /// The organisation requires its Microsoft 365 administrator to approve.
  adminConsentRequired('admin_consent_required'),

  /// Permission is there, the account may not use the resource (licence,
  /// policy, ownership).
  forbidden('forbidden'),

  /// Microsoft is rate-limiting the account (429 / 503+Retry-After).
  throttled('throttled'),

  /// The item no longer exists.
  notFound('not_found'),

  /// Changed elsewhere since it was read (ETag) or already exists.
  conflict('conflict'),

  /// Refused before reaching Microsoft: request policy or subscription state.
  blocked('blocked'),

  /// Microsoft, the proxy or the network is temporarily unavailable.
  unavailable('unavailable'),

  /// Anything else.
  failed('failed');

  const GraphProblemKind(this.code);

  /// Snake-case code used in the keyword keys (`m365.problem.<code>.title`).
  final String code;
}

/// One failed proxied call, classified. Carries codes only — never a provider
/// message or a token.
class GraphProblem {
  final GraphProblemKind kind;

  /// Graph's HTTP status when Graph answered, else the proxy's own status;
  /// 0 = no response at all (network, timeout).
  final int status;

  /// Seconds to wait before retrying ([GraphProblemKind.throttled] only).
  final int? retryAfterSeconds;

  /// Stable proxy code (`ERR_REAUTH`, `ERR_GRAPH_THROTTLED`, …) when sent.
  final String? code;

  /// Graph's own `error.code` (e.g. `ErrorAccessDenied`).
  final String? graphCode;

  const GraphProblem({
    required this.kind,
    this.status = 0,
    this.retryAfterSeconds,
    this.code,
    this.graphCode,
  });

  /// Wait shown when Microsoft throttles without a Retry-After header.
  static const int defaultRetrySeconds = 30;
  static const int _retryMaxSeconds = 3600;

  /// Keyword key of the state's title / explanation / one-line toast.
  String get titleKey => 'm365.problem.${kind.code}.title';
  String get hintKey => 'm365.problem.${kind.code}.hint';
  String get toastKey => 'm365.problem.${kind.code}.toast';

  /// Fixed by (re)connecting the account.
  bool get needsConnect =>
      kind == GraphProblemKind.notConnected ||
      kind == GraphProblemKind.reauth ||
      kind == GraphProblemKind.missingConsent;

  /// Worth a user-triggered retry of the same call.
  bool get isRetryable =>
      kind == GraphProblemKind.throttled ||
      kind == GraphProblemKind.unavailable ||
      kind == GraphProblemKind.failed ||
      kind == GraphProblemKind.notFound ||
      kind == GraphProblemKind.conflict;

  static const Map<String, GraphProblemKind> _byCode = {
    'ERR_NOT_CONNECTED': GraphProblemKind.notConnected,
    'ERR_REAUTH': GraphProblemKind.reauth,
    'ERR_GRAPH_UNAUTHORIZED': GraphProblemKind.reauth,
    'ERR_GRAPH_CONSENT': GraphProblemKind.missingConsent,
    'ERR_GRAPH_FORBIDDEN': GraphProblemKind.forbidden,
    'ERR_GRAPH_THROTTLED': GraphProblemKind.throttled,
    'ERR_GRAPH_NOT_FOUND': GraphProblemKind.notFound,
    'ERR_GRAPH_CONFLICT': GraphProblemKind.conflict,
    'ERR_GRAPH_UNAVAILABLE': GraphProblemKind.unavailable,
    'ERR_GRAPH_FAILED': GraphProblemKind.failed,
    'ERR_GRAPH_PATH_FORBIDDEN': GraphProblemKind.blocked,
    'ERR_GRAPH_METHOD_FORBIDDEN': GraphProblemKind.blocked,
    'ERR_ENTITLEMENT': GraphProblemKind.blocked,
    'ERR_TOO_LARGE': GraphProblemKind.failed,
  };

  // Same wording rule as the Edge Function (`_shared/graph-error.ts`) — used
  // when the deployed function is older and sent no classification.
  static final RegExp _consentRe = RegExp(
    r'insufficient privileges|missing scope|required scopes?|scp or roles|needs? admin|admin consent|has not consented|consent[_ ]required',
    caseSensitive: false,
  );

  // Graph wording that means "a user cannot grant this, an administrator has
  // to" (AADSTS90094 / 65001 family surfaces with this text on a 403).
  static final RegExp _adminConsentRe = RegExp(
    r'needs? admin|admin(istrator)? (consent|approval)|AADSTS(90094|900941|65001|90008)',
    caseSensitive: false,
  );

  static Map<String, dynamic>? _asMap(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : null;

  static int? _clampRetry(dynamic v) {
    num? n;
    if (v is num) {
      n = v;
    } else if (v is String && RegExp(r'^\d+$').hasMatch(v)) {
      n = int.tryParse(v);
    }
    if (n == null || n.isNaN || n.isInfinite) return null;
    final s = n.ceil();
    if (s < 1) return 1;
    return s > _retryMaxSeconds ? _retryMaxSeconds : s;
  }

  static GraphProblemKind _kindOfUpstream(
      int status, String graphCode, String graphMessage) {
    if (status == 429) return GraphProblemKind.throttled;
    if (status == 401) return GraphProblemKind.reauth;
    if (status == 403) {
      final consent = graphCode == 'Authorization_RequestDenied' ||
          _consentRe.hasMatch(graphMessage);
      return consent
          ? GraphProblemKind.missingConsent
          : GraphProblemKind.forbidden;
    }
    if (status == 404) return GraphProblemKind.notFound;
    if (status == 409 || status == 412) return GraphProblemKind.conflict;
    if (status >= 500) return GraphProblemKind.unavailable;
    return GraphProblemKind.failed;
  }

  /// Classify a failed Edge Function call from its HTTP status and decoded
  /// JSON body. `httpStatus` 0 / `body` null = no response (network, timeout).
  ///
  /// Works with both body generations: the classified one (`code`,
  /// `retry_after`, `graph_code`) and the older `{status, data}` of a 502,
  /// which is classified here from Graph's status and error.
  static GraphProblem classify(int httpStatus, dynamic body) {
    final b = _asMap(body);
    if (httpStatus == 0 && b == null) {
      return const GraphProblem(kind: GraphProblemKind.unavailable);
    }

    final code = b?['code'] is String ? b!['code'] as String : null;
    final upstream = b?['status'] is int ? b!['status'] as int : null;
    final graphErr = _asMap(_asMap(b?['data'])?['error']);
    final rawGraphCode = b?['graph_code'] is String
        ? b!['graph_code'] as String
        : (graphErr?['code'] is String ? graphErr!['code'] as String : null);
    final graphMessage =
        graphErr?['message'] is String ? graphErr!['message'] as String : '';
    final status = upstream ?? httpStatus;

    // ERR_REAUTH is only the proxy's own 401 ("reconnect this connection").
    // A bare 401 without it is the APP session (expired Supabase JWT) — not a
    // reason to reconnect Microsoft.
    GraphProblemKind? kind;
    if (code != null && !(code == 'ERR_REAUTH' && httpStatus != 401)) {
      kind = _byCode[code];
    }
    if (kind == null) {
      if (upstream != null) {
        kind = _kindOfUpstream(upstream, rawGraphCode ?? '', graphMessage);
      } else if (httpStatus == 402 || httpStatus == 403) {
        kind = GraphProblemKind.blocked;
      } else if (httpStatus == 409) {
        kind = GraphProblemKind.notConnected;
      } else if (httpStatus == 429) {
        kind = GraphProblemKind.throttled;
      } else if (httpStatus >= 500) {
        kind = GraphProblemKind.unavailable;
      } else {
        kind = GraphProblemKind.failed;
      }
    }
    if (kind == GraphProblemKind.missingConsent &&
        _adminConsentRe.hasMatch(graphMessage)) {
      kind = GraphProblemKind.adminConsentRequired;
    }

    final graphCode = rawGraphCode == null
        ? null
        : (rawGraphCode.length > 80
            ? rawGraphCode.substring(0, 80)
            : rawGraphCode);
    return GraphProblem(
      kind: kind,
      status: status,
      retryAfterSeconds: kind == GraphProblemKind.throttled
          ? (_clampRetry(b?['retry_after']) ?? defaultRetrySeconds)
          : null,
      code: code,
      graphCode: graphCode,
    );
  }

  @override
  String toString() =>
      'GraphProblem(${kind.code}, status: $status${code == null ? '' : ', code: $code'}'
      '${graphCode == null ? '' : ', graph: $graphCode'}'
      '${retryAfterSeconds == null ? '' : ', retryAfter: ${retryAfterSeconds}s'})';
}

/// What the provider callback handed back on the app's deep link when the
/// flow ended WITHOUT a connection (`oauth-callback` → `<scheme>://oauth-callback
/// ?oauth_error=…` / `?admin_consent=…`). Enumerated values only — anything
/// else is ignored.
enum OAuthReturnNotice {
  /// The user (or the organisation's policy) declined the permission screen.
  declined('declined', isError: true),

  /// The organisation requires its administrator to approve the app.
  adminConsentRequired('admin_consent_required', isError: true),

  /// Microsoft could not complete the flow.
  failed('failed', isError: true),

  /// Tenant-wide admin consent was granted.
  consentGranted('consent_granted', isError: false),

  /// Tenant-wide admin consent was declined.
  consentDeclined('consent_declined', isError: true);

  const OAuthReturnNotice(this.code, {required this.isError});

  final String code;
  final bool isError;

  String get titleKey => 'integrations.apps.oauth_result.$code.title';

  /// The web hints are reused, except for "administrator approval required":
  /// the web text points at "the setup wizard on this page", which the apps do
  /// not have — that one has its own mobile wording.
  String get hintKey => this == OAuthReturnNotice.adminConsentRequired
      ? 'integrations.ms.oauth_result.admin_consent_required.hint'
      : 'integrations.apps.oauth_result.$code.hint';

  /// Parse the query parameters of an OAuth return deep link. Returns null
  /// when the link carries no (known) result — e.g. a successful return, which
  /// carries `oauth_complete` instead.
  static OAuthReturnNotice? fromQuery(Map<String, String> q) {
    switch (q['oauth_error']) {
      case 'declined':
        return OAuthReturnNotice.declined;
      case 'admin_consent_required':
        return OAuthReturnNotice.adminConsentRequired;
      case 'failed':
        return OAuthReturnNotice.failed;
    }
    switch (q['admin_consent']) {
      case 'granted':
        return OAuthReturnNotice.consentGranted;
      case 'declined':
        return OAuthReturnNotice.consentDeclined;
    }
    return null;
  }
}
