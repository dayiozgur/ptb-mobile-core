import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/supabase_fakes.dart';

class MockCacheManager extends Mock implements CacheManager {}

EntityTypeConfig _config({bool standalone = true}) => EntityTypeConfig(
      id: 'cfg-1',
      code: 'ppm_task',
      name: 'Task',
      isStandalone: standalone,
    );

void main() {
  late SupabaseHarness h;
  late MockCacheManager cache;
  late EntityDataService service;

  setUp(() {
    h = SupabaseHarness();
    cache = MockCacheManager();
    service = EntityDataService(supabase: h.client, cacheManager: cache);
  });

  group('updateStatus (status-transition Edge Function)', () {
    test('happy path: invokes with correct function name + body', () async {
      h.stubFunction('status-transition', data: {'success': true});

      await service.updateStatus(
        entityType: 'ppm_task',
        entityId: 'sub-1',
        toStatus: 'in_progress',
        comment: 'moving on',
      );

      final body = h.capturedFunctionBody('status-transition')!;
      expect(body['entityType'], 'ppm_task');
      expect(body['entityId'], 'sub-1');
      expect(body['toStatus'], 'in_progress');
      expect(body['comment'], 'moving on');
    });

    test('blank comment is omitted from the body', () async {
      h.stubFunction('status-transition', data: {'success': true});

      await service.updateStatus(
        entityType: 'ppm_task',
        entityId: 'sub-1',
        toStatus: 'done',
        comment: '   ',
      );

      final body = h.capturedFunctionBody('status-transition')!;
      expect(body.containsKey('comment'), isFalse);
    });

    test('error envelope {success:false} throws', () async {
      h.stubFunction('status-transition',
          data: {'success': false, 'error': 'not allowed'});

      expect(
        () => service.updateStatus(
          entityType: 'ppm_task',
          entityId: 'sub-1',
          toStatus: 'done',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('status-transition failed'),
        )),
      );
    });

    test('rethrows when the Edge Function throws', () async {
      h.stubFunction('status-transition',
          error: const FunctionException(status: 500));

      expect(
        () => service.updateStatus(
          entityType: 'ppm_task',
          entityId: 'sub-1',
          toStatus: 'done',
        ),
        throwsA(isA<FunctionException>()),
      );
    });
  });

  group('loadBacklog (form_submissions read)', () {
    test('happy path: parses rows into GenericEntity list', () async {
      service.setTenant('tenant-1');
      h.stubFrom('form_submissions', result: <Map<String, dynamic>>[
        {
          'id': 'sub-1',
          'entity_type': 'ppm_task',
          'subject': 'First',
          'status': 'todo',
          'backlog_rank': 1000,
          'form_templates': {'name': 'Task', 'code': 'ppm_task'},
        },
        {
          'id': 'sub-2',
          'entity_type': 'ppm_task',
          'subject': 'Second',
          'status': 'todo',
        },
      ]);

      final result = await service.loadBacklog(_config());

      expect(result.length, 2);
      expect(result.first.id, 'sub-1');
      expect(result.first.subject, 'First');
      expect(result.first.formTemplateName, 'Task');

      // Chain shape: filtered by the standalone/active/type/tenant predicates.
      final calls = h.queryByTable['form_submissions']!.calls;
      expect(calls.where((i) => i.memberName == #eq).length, greaterThanOrEqualTo(4));
      expect(calls.any((i) => i.memberName == #order), isTrue);
      expect(calls.any((i) => i.memberName == #limit), isTrue);
    });

    test('resolves assignee display names for rows with assigned_to', () async {
      service.setTenant('tenant-1');
      h.stubFrom('form_submissions', result: <Map<String, dynamic>>[
        {
          'id': 'sub-1',
          'entity_type': 'ppm_task',
          'subject': 'Assigned task',
          'assigned_to': 'user-7',
        },
      ]);
      h.stubFrom('profiles', result: <Map<String, dynamic>>[
        {'id': 'user-7', 'full_name': 'Ada Lovelace'},
      ]);

      final result = await service.loadBacklog(_config());

      expect(result.single.assignedTo, 'user-7');
      expect(result.single.assignedToName, 'Ada Lovelace');
    });

    test('throws when tenant context is not set', () async {
      expect(
        () => service.loadBacklog(_config()),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Tenant context is not set'),
        )),
      );
    });

    test('rethrows on query error', () async {
      service.setTenant('tenant-1');
      h.stubFrom('form_submissions', error: Exception('db down'));

      expect(() => service.loadBacklog(_config()), throwsA(isA<Exception>()));
    });
  });

  // reorderBacklog artık ATOMİK tek RPC (fn_reorder_backlog) — eski N-ayrı
  // form_submissions UPDATE kısmi-fail'de DB/UI drift bırakıyordu.
  group('reorderBacklog (fn_reorder_backlog RPC)', () {
    test('atomik RPC — sıralı id + eşit-aralıklı rank', () async {
      service.setTenant('tenant-1');
      h.stubRpc('fn_reorder_backlog', result: null);

      await service.reorderBacklog(['a', 'b']);

      final params = h.capturedRpcParams('fn_reorder_backlog');
      expect(params?['p_ids'], ['a', 'b']);
      expect(params?['p_ranks'], [1000, 2000]);
    });

    test('3 id → rank [1000, 2000, 3000]', () async {
      service.setTenant('tenant-1');
      h.stubRpc('fn_reorder_backlog', result: null);

      await service.reorderBacklog(['x', 'y', 'z']);

      expect(h.capturedRpcParams('fn_reorder_backlog')?['p_ranks'],
          [1000, 2000, 3000]);
    });

    test('boş liste → RPC çağrılmaz (kısa devre)', () async {
      service.setTenant('tenant-1');
      h.stubRpc('fn_reorder_backlog', result: null);

      await service.reorderBacklog([]);

      verifyNever(() => h.client.rpc<dynamic>('fn_reorder_backlog',
          params: any(named: 'params')));
    });

    test('throws when tenant context is not set', () async {
      expect(
        () => service.reorderBacklog(['a']),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Tenant context is not set'),
        )),
      );
    });
  });
}
