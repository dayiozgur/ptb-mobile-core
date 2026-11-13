import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Contract tests for the classification of `graph-proxy` failures — the
/// bodies are the ones the Edge Function sends
/// (`supabase/functions/graph-proxy/index.ts`, `_shared/graph-error.ts`).
void main() {
  group('GraphProblem.classify — proxy refusals', () {
    test('409 ERR_NOT_CONNECTED → notConnected', () {
      final p = GraphProblem.classify(409, {
        'error': 'no connection for this user/provider',
        'code': 'ERR_NOT_CONNECTED',
      });
      expect(p.kind, GraphProblemKind.notConnected);
      expect(p.needsConnect, isTrue);
      expect(p.titleKey, 'm365.problem.not_connected.title');
    });

    test('401 ERR_REAUTH → reauth (reconnect)', () {
      final p = GraphProblem.classify(401, {
        'error': 'connection expired — reconnect required',
        'code': 'ERR_REAUTH',
        'connection_status': 'expired',
      });
      expect(p.kind, GraphProblemKind.reauth);
      expect(p.needsConnect, isTrue);
    });

    test('bare 401 (expired app session) is NOT a Microsoft reconnect', () {
      final p = GraphProblem.classify(401, {'error': 'no tenant context'});
      expect(p.kind, GraphProblemKind.failed);
      expect(p.needsConnect, isFalse);
    });

    test('403 policy reject → blocked', () {
      final p = GraphProblem.classify(403, {
        'error': 'request not allowed by graph-proxy policy',
        'code': 'ERR_GRAPH_PATH_FORBIDDEN',
      });
      expect(p.kind, GraphProblemKind.blocked);
      expect(p.isRetryable, isFalse);
    });

    test('402 entitlement block → blocked', () {
      expect(GraphProblem.classify(402, {'code': 'ERR_ENTITLEMENT'}).kind,
          GraphProblemKind.blocked);
      expect(GraphProblem.classify(402, {'error': 'x'}).kind,
          GraphProblemKind.blocked);
    });

    test('no response at all → unavailable (status 0)', () {
      final p = GraphProblem.classify(0, null);
      expect(p.kind, GraphProblemKind.unavailable);
      expect(p.status, 0);
      // FunctionsFetchException carries a non-map `details`
      expect(GraphProblem.classify(0, 'SocketException').kind,
          GraphProblemKind.unavailable);
    });

    test('500 from the proxy itself → unavailable', () {
      expect(GraphProblem.classify(500, {'error': 'graph-proxy failed'}).kind,
          GraphProblemKind.unavailable);
    });
  });

  group('GraphProblem.classify — upstream Graph failure (HTTP 502)', () {
    test('throttled with retry_after', () {
      final p = GraphProblem.classify(502, {
        'status': 429,
        'data': {
          'error': {'code': 'TooManyRequests', 'message': 'slow down'}
        },
        'code': 'ERR_GRAPH_THROTTLED',
        'retry_after': 17,
        'graph_code': 'TooManyRequests',
      });
      expect(p.kind, GraphProblemKind.throttled);
      expect(p.status, 429);
      expect(p.retryAfterSeconds, 17);
      expect(p.graphCode, 'TooManyRequests');
      expect(p.isRetryable, isTrue);
    });

    test('throttled without retry_after → default wait', () {
      final p = GraphProblem.classify(
          502, {'status': 429, 'data': null, 'code': 'ERR_GRAPH_THROTTLED'});
      expect(p.retryAfterSeconds, GraphProblem.defaultRetrySeconds);
    });

    test('retry_after is clamped to 1…3600', () {
      expect(
          GraphProblem.classify(502, {
            'status': 429,
            'code': 'ERR_GRAPH_THROTTLED',
            'retry_after': 999999
          }).retryAfterSeconds,
          3600);
      expect(
          GraphProblem.classify(502, {
            'status': 429,
            'code': 'ERR_GRAPH_THROTTLED',
            'retry_after': 0
          }).retryAfterSeconds,
          1);
    });

    test('missing consent for this scope', () {
      final p = GraphProblem.classify(502, {
        'status': 403,
        'data': {
          'error': {
            'code': 'Forbidden',
            'message':
                "Missing scope permissions on the request. API requires one of 'Chat.ReadWrite'"
          }
        },
        'code': 'ERR_GRAPH_CONSENT',
        'graph_code': 'Forbidden',
      });
      expect(p.kind, GraphProblemKind.missingConsent);
      expect(p.needsConnect, isTrue);
    });

    test('admin consent required is split out of missing consent', () {
      final p = GraphProblem.classify(502, {
        'status': 403,
        'data': {
          'error': {
            'code': 'Authorization_RequestDenied',
            'message': 'Need admin approval: admin consent is required'
          }
        },
        'code': 'ERR_GRAPH_CONSENT',
      });
      expect(p.kind, GraphProblemKind.adminConsentRequired);
      expect(p.needsConnect, isFalse,
          reason: 'reconnecting does not help; an administrator must approve');
      expect(p.titleKey, 'm365.problem.admin_consent_required.title');
    });

    test('forbidden (licence / policy) is not a consent problem', () {
      final p = GraphProblem.classify(502, {
        'status': 403,
        'data': {
          'error': {'code': 'ErrorAccessDenied', 'message': 'Access is denied.'}
        },
        'code': 'ERR_GRAPH_FORBIDDEN',
      });
      expect(p.kind, GraphProblemKind.forbidden);
      expect(p.needsConnect, isFalse);
    });

    test('Graph 401 → reconnect', () {
      final p = GraphProblem.classify(
          502, {'status': 401, 'data': {}, 'code': 'ERR_GRAPH_UNAUTHORIZED'});
      expect(p.kind, GraphProblemKind.reauth);
    });

    test('404 / 412 / 5xx', () {
      expect(
          GraphProblem.classify(
              502, {'status': 404, 'code': 'ERR_GRAPH_NOT_FOUND'}).kind,
          GraphProblemKind.notFound);
      expect(
          GraphProblem.classify(
              502, {'status': 412, 'code': 'ERR_GRAPH_CONFLICT'}).kind,
          GraphProblemKind.conflict);
      expect(
          GraphProblem.classify(
              502, {'status': 503, 'code': 'ERR_GRAPH_UNAVAILABLE'}).kind,
          GraphProblemKind.unavailable);
    });
  });

  group('GraphProblem.classify — older function body (no code)', () {
    test('{status, data} of a 502 is classified from Graph status + error', () {
      expect(GraphProblem.classify(502, {'status': 429, 'data': {}}).kind,
          GraphProblemKind.throttled);
      expect(GraphProblem.classify(502, {'status': 401, 'data': {}}).kind,
          GraphProblemKind.reauth);
      expect(
          GraphProblem.classify(502, {
            'status': 403,
            'data': {
              'error': {
                'code': 'Authorization_RequestDenied',
                'message': 'Insufficient privileges to complete the operation.'
              }
            }
          }).kind,
          GraphProblemKind.missingConsent);
      expect(
          GraphProblem.classify(502, {
            'status': 403,
            'data': {
              'error': {'code': 'accessDenied', 'message': 'Access denied'}
            }
          }).kind,
          GraphProblemKind.forbidden);
      expect(GraphProblem.classify(502, {'status': 404, 'data': {}}).kind,
          GraphProblemKind.notFound);
    });

    test('409 without a code → not connected', () {
      expect(GraphProblem.classify(409, {'error': 'no connection'}).kind,
          GraphProblemKind.notConnected);
    });
  });

  group('OAuthReturnNotice.fromQuery', () {
    test('each enumerated oauth_error value', () {
      expect(OAuthReturnNotice.fromQuery({'oauth_error': 'declined'}),
          OAuthReturnNotice.declined);
      expect(
          OAuthReturnNotice.fromQuery(
              {'oauth_error': 'admin_consent_required'}),
          OAuthReturnNotice.adminConsentRequired);
      expect(OAuthReturnNotice.fromQuery({'oauth_error': 'failed'}),
          OAuthReturnNotice.failed);
    });

    test('admin_consent granted / declined', () {
      expect(OAuthReturnNotice.fromQuery({'admin_consent': 'granted'}),
          OAuthReturnNotice.consentGranted);
      expect(OAuthReturnNotice.fromQuery({'admin_consent': 'declined'}),
          OAuthReturnNotice.consentDeclined);
    });

    test('unknown values / parameters are ignored (nothing is reflected)', () {
      expect(OAuthReturnNotice.fromQuery({'oauth_error': '<script>'}), isNull);
      expect(OAuthReturnNotice.fromQuery({'admin_consent': 'true'}), isNull);
      expect(OAuthReturnNotice.fromQuery({'oauth_complete': 'abc'}), isNull);
      expect(OAuthReturnNotice.fromQuery(const {}), isNull);
    });

    test('every value has its own translated title and hint (tr + en)', () {
      final tr = AppLocalizations.getTranslations(AppLocale.turkish);
      final en = AppLocalizations.getTranslations(AppLocale.english);
      final titles = <String>{};
      for (final n in OAuthReturnNotice.values) {
        for (final map in [tr, en]) {
          expect(map.containsKey(n.titleKey), isTrue, reason: n.titleKey);
          expect(map.containsKey(n.hintKey), isTrue, reason: n.hintKey);
        }
        titles.add(tr[n.titleKey]!);
      }
      expect(titles.length, OAuthReturnNotice.values.length,
          reason: 'one distinct message per value');
      expect(OAuthReturnNotice.declined.isError, isTrue);
      expect(OAuthReturnNotice.consentGranted.isError, isFalse);
    });
  });

  test('every problem kind has title / hint / toast in the tr + en + de maps',
      () {
    for (final locale in [AppLocale.turkish, AppLocale.english, AppLocale.german]) {
      final map = AppLocalizations.getTranslations(locale);
      for (final k in GraphProblemKind.values) {
        final p = GraphProblem(kind: k);
        for (final key in [p.titleKey, p.hintKey, p.toastKey]) {
          expect(map[key], isNotNull, reason: '$key ($locale)');
          expect(map[key], isNot(key));
        }
      }
      for (final key in [
        'm365.connect.action',
        'm365.connect.reconnect',
        'm365.problem.retry',
        'm365.problem.retry_in',
        'm365.problem.open_hub',
        'integrations.ms.connect_on_web',
      ]) {
        expect(map[key], isNotNull, reason: '$key ($locale)');
      }
    }
  });
}
