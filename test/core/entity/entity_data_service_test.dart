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

  group('reorderBacklog (form_submissions update)', () {
    test('persists equal-spaced ranks and updated_by per id', () async {
      service.setTenant('tenant-1');
      h.stubCurrentUser(id: 'user-9');
      h.stubFrom('form_submissions', result: null);

      await service.reorderBacklog(['a', 'b']);

      // queryByTable keeps the LAST from() call = second id, rank 2*1000.
      final calls = h.queryByTable['form_submissions']!.calls;
      final update = calls.firstWhere((i) => i.memberName == #update);
      final patch = update.positionalArguments.first as Map;
      expect(patch['backlog_rank'], 2000);
      expect(patch['updated_by'], 'user-9');
      // Scoped by id + tenant_id.
      expect(calls.where((i) => i.memberName == #eq).length, 2);
    });

    test('omits updated_by when there is no authenticated user', () async {
      service.setTenant('tenant-1');
      h.stubCurrentUser(id: null);
      h.stubFrom('form_submissions', result: null);

      await service.reorderBacklog(['a']);

      final calls = h.queryByTable['form_submissions']!.calls;
      final update = calls.firstWhere((i) => i.memberName == #update);
      final patch = update.positionalArguments.first as Map;
      expect(patch['backlog_rank'], 1000);
      expect(patch.containsKey('updated_by'), isFalse);
    });

    test('empty list short-circuits without touching the table', () async {
      service.setTenant('tenant-1');
      h.stubCurrentUser(id: 'user-9');

      await service.reorderBacklog([]);

      expect(h.queryByTable.containsKey('form_submissions'), isFalse);
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
