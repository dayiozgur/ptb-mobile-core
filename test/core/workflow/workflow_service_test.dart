import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../helpers/supabase_fakes.dart';

class MockCacheManager extends Mock implements CacheManager {}

void main() {
  late SupabaseHarness h;
  late WorkflowService service;

  setUp(() {
    h = SupabaseHarness();
    service = WorkflowService(supabase: h.client, cacheManager: MockCacheManager());
  });

  tearDown(() => service.dispose());

  group('pendingApprovals (fn_workflow_my_approvals rpc)', () {
    test('happy path: maps rows to WorkflowApproval', () async {
      h.stubRpc('fn_workflow_my_approvals', result: <dynamic>[
        {
          'id': 'appr-1',
          'workflow_id': 'wf-1',
          'title': 'Leave for Ada',
          'entity_type': 'leave_request',
          'entity_id': 'lr-9',
        },
        {'id': 'appr-2'},
      ]);

      final result = await service.pendingApprovals();

      expect(result.length, 2);
      expect(result.first.id, 'appr-1');
      expect(result.first.title, 'Leave for Ada');
      expect(result.first.entityType, 'leave_request');
    });

    test('non-list response yields empty list', () async {
      h.stubRpc('fn_workflow_my_approvals', result: {'unexpected': true});

      expect(await service.pendingApprovals(), isEmpty);
    });

    test('error is swallowed → empty list (never throws to UI)', () async {
      h.stubRpc('fn_workflow_my_approvals', error: Exception('rpc failed'));

      expect(await service.pendingApprovals(), isEmpty);
    });

    test('tolerates rows missing optional fields', () async {
      h.stubRpc('fn_workflow_my_approvals', result: <dynamic>[
        {'id': 'appr-3'},
      ]);

      final result = await service.pendingApprovals();
      expect(result.single.id, 'appr-3');
      expect(result.single.title, isNull);
    });
  });

  group('decideApproval (fn_workflow_approval_decide rpc)', () {
    test('approve sends p_decision=approved with trimmed note', () async {
      h.stubRpc('fn_workflow_approval_decide', result: {'ok': true});

      await service.decideApproval(
        approvalId: 'appr-1',
        approve: true,
        note: '  looks good  ',
      );

      final params = h.capturedRpcParams('fn_workflow_approval_decide')!;
      expect(params['p_id'], 'appr-1');
      expect(params['p_decision'], 'approved');
      expect(params['p_comment'], 'looks good');
    });

    test('reject sends p_decision=rejected and null comment when blank', () async {
      h.stubRpc('fn_workflow_approval_decide', result: {'ok': true});

      await service.decideApproval(
        approvalId: 'appr-2',
        approve: false,
        note: '   ',
      );

      final params = h.capturedRpcParams('fn_workflow_approval_decide')!;
      expect(params['p_decision'], 'rejected');
      expect(params['p_comment'], isNull);
    });

    test('rethrows on rpc error (authorization/state failure)', () async {
      h.stubRpc('fn_workflow_approval_decide', error: Exception('not authorized'));

      expect(
        () => service.decideApproval(approvalId: 'appr-1', approve: true),
        throwsA(isA<Exception>()),
      );
    });
  });
}
