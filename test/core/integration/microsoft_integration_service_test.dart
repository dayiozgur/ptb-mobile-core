import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/supabase_fakes.dart';

void main() {
  late SupabaseHarness h;
  late MicrosoftIntegrationService service;

  setUp(() {
    h = SupabaseHarness();
    service = MicrosoftIntegrationService(supabase: h.client);
  });

  group('disconnect → integration-disconnect Edge Function', () {
    test('invokes the function with the connection id; ok:true → true',
        () async {
      h.stubFunction('integration-disconnect', data: {
        'ok': true,
        'subscriptions_removed': 2,
        'subscriptions_failed': 0,
        'secret_removed': true,
      });

      expect(await service.disconnect('conn-1'), isTrue);

      expect(h.capturedFunctionBody('integration-disconnect'),
          {'connection_id': 'conn-1'});
    });

    test('never deletes the integration_connections row directly', () async {
      h.stubFunction('integration-disconnect', data: {'ok': true});
      h.stubFrom('integration_connections', result: <Map<String, dynamic>>[]);

      await service.disconnect('conn-1');

      verifyNever(() => h.client.from('integration_connections'));
    });

    test('ok:false body (partial teardown) → false', () async {
      h.stubFunction('integration-disconnect',
          data: {'ok': false, 'subscriptions_failed': 1});
      expect(await service.disconnect('conn-1'), isFalse);
    });

    test('403 / 404 / 500 from the function → false (no throw)', () async {
      for (final status in [403, 404, 500]) {
        h.stubFunction('integration-disconnect',
            error: FunctionException(
                status: status, details: {'error': 'x', 'code': 'ERR'}));
        expect(await service.disconnect('conn-1'), isFalse,
            reason: 'HTTP $status');
      }
    });

    test('transport failure → false', () async {
      h.stubFunction('integration-disconnect', error: Exception('offline'));
      expect(await service.disconnect('conn-1'), isFalse);
    });
  });

  group('graphCall — classified results, never null', () {
    test('success envelope → ok with data', () async {
      h.stubFunction('graph-proxy', data: {
        'status': 200,
        'data': {'value': []}
      });
      final res = await service.graphCall('GET', '/me/messages');
      expect(res.ok, isTrue);
      expect(res.problem, isNull);
      expect(res.data, {'value': []});
      final body = h.capturedFunctionBody('graph-proxy')!;
      expect(body['provider'], 'microsoft');
      expect(body['method'], 'GET');
      expect(body['path'], '/me/messages');
      expect(body.containsKey('beta'), isFalse);
    });

    test('409 ERR_NOT_CONNECTED → notConnected', () async {
      h.stubFunction('graph-proxy',
          error: const FunctionException(
              status: 409, details: {'code': 'ERR_NOT_CONNECTED'}));
      final res = await service.graphCall('GET', '/me/messages');
      expect(res.ok, isFalse);
      expect(res.problem!.kind, GraphProblemKind.notConnected);
    });

    test('502 with a throttled body → throttled + retry-after + Graph status',
        () async {
      h.stubFunction('graph-proxy',
          error: const FunctionException(status: 502, details: {
            'status': 429,
            'data': {
              'error': {'code': 'TooManyRequests'}
            },
            'code': 'ERR_GRAPH_THROTTLED',
            'retry_after': 12,
          }));
      final res = await service.graphCall('GET', '/me/drive/recent');
      expect(res.ok, isFalse);
      expect(res.status, 429, reason: "Graph's own status, not the proxy 502");
      expect(res.problem!.kind, GraphProblemKind.throttled);
      expect(res.problem!.retryAfterSeconds, 12);
    });

    test('502 with a Graph 404 keeps status 404 for callers that branch on it',
        () async {
      h.stubFunction('graph-proxy',
          error: const FunctionException(
              status: 502,
              details: {'status': 404, 'data': {}, 'code': 'ERR_GRAPH_NOT_FOUND'}));
      final res = await service.graphCall('GET', '/users/x');
      expect(res.status, 404);
      expect(res.problem!.kind, GraphProblemKind.notFound);
    });

    test('502 missing consent → missingConsent', () async {
      h.stubFunction('graph-proxy',
          error: const FunctionException(status: 502, details: {
            'status': 403,
            'data': {
              'error': {
                'code': 'Forbidden',
                'message': 'Missing scope permissions on the request.'
              }
            },
            'code': 'ERR_GRAPH_CONSENT',
          }));
      final res = await service.graphCall('POST', '/chats', body: {});
      expect(res.problem!.kind, GraphProblemKind.missingConsent);
    });

    test('transport failure → unavailable (not a throw, not null)', () async {
      h.stubFunction('graph-proxy', error: Exception('socket closed'));
      final res = await service.graphCall('GET', '/me');
      expect(res.ok, isFalse);
      expect(res.problem!.kind, GraphProblemKind.unavailable);
    });

    test('beta flag is forwarded', () async {
      h.stubFunction('graph-proxy', data: {
        'status': 201,
        'data': {'id': 'r1'}
      });
      await service.graphCall('POST', '/planner/rosters',
          body: {'a': 1}, beta: true);
      expect(h.capturedFunctionBody('graph-proxy')!['beta'], true);
    });
  });

  group('lookupConnection', () {
    test('connected row → isConnected', () async {
      h.stubFrom('integration_connections', result: [
        {
          'id': 'c1',
          'provider': 'microsoft',
          'status': 'connected',
          'account_email': 'a@b.c',
          'sync_enabled': true,
          'scopes': ['Mail.Read'],
        }
      ]);
      final l = await service.lookupConnection();
      expect(l.isConnected, isTrue);
      expect(l.failed, isFalse);
      expect(l.connection!.id, 'c1');
    });

    test('expired row → needsReconnect (not "never connected")', () async {
      h.stubFrom('integration_connections', result: [
        {'id': 'c1', 'provider': 'microsoft', 'status': 'expired'}
      ]);
      final l = await service.lookupConnection();
      expect(l.isConnected, isFalse);
      expect(l.needsReconnect, isTrue);
      expect(l.stale!.id, 'c1');
    });

    test('no row → not connected, not failed', () async {
      h.stubFrom('integration_connections', result: <Map<String, dynamic>>[]);
      final l = await service.lookupConnection();
      expect(l.isConnected, isFalse);
      expect(l.needsReconnect, isFalse);
      expect(l.failed, isFalse);
    });

    test('read error → failed (state unknown, not "not connected")', () async {
      h.stubFrom('integration_connections',
          error: const PostgrestException(message: 'timeout', code: '57014'));
      final l = await service.lookupConnection();
      expect(l.failed, isTrue);
      expect(l.isConnected, isFalse);
    });
  });
}
