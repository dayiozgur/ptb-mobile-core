import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../helpers/supabase_fakes.dart';

class MockTenantService extends Mock implements TenantService {}

void main() {
  late SupabaseHarness h;
  late MockTenantService tenant;
  late HrEssService service;

  setUp(() {
    h = SupabaseHarness();
    tenant = MockTenantService();
    when(() => tenant.currentTenantId).thenReturn('tenant-1');
    // HrEssService resolves TenantService (and optionally Connectivity/
    // OfflineSync, left unregistered → online path) via the global locator.
    final sl = GetIt.instance;
    if (sl.isRegistered<TenantService>()) sl.unregister<TenantService>();
    sl.registerSingleton<TenantService>(tenant);
    service = HrEssService(supabase: h.client);
  });

  tearDown(() => GetIt.instance.reset());

  // Wires up a resolvable current staff id (auth user + staffs row).
  void stubStaff(String staffId) {
    h.stubCurrentUser(id: 'user-1');
    h.stubFrom('staffs', result: {'id': staffId});
  }

  group('myGoals (employee_goals read)', () {
    test('happy path: parses rows and scopes by staff_id', () async {
      stubStaff('staff-1');
      h.stubFrom('employee_goals', result: <Map<String, dynamic>>[
        {'id': 'g-1', 'title': 'Ship mobile', 'staff_id': 'staff-1'},
        {'id': 'g-2', 'title': 'Learn Dart', 'staff_id': 'staff-1'},
      ]);

      final goals = await service.myGoals();

      expect(goals.length, 2);
      expect(goals.first.id, 'g-1');
      final calls = h.queryByTable['employee_goals']!.calls;
      expect(calls.any((i) => i.memberName == #eq), isTrue);
    });

    test('returns [] when there is no staff row for the user', () async {
      h.stubCurrentUser(id: 'user-1');
      h.stubFrom('staffs', result: null); // maybeSingle → null

      expect(await service.myGoals(), isEmpty);
    });

    test('error is swallowed → [] (read never throws to UI)', () async {
      stubStaff('staff-1');
      h.stubFrom('employee_goals', error: Exception('db down'));

      expect(await service.myGoals(), isEmpty);
    });
  });

  group('myReviews (performance_reviews read)', () {
    test('happy path: parses rows', () async {
      stubStaff('staff-1');
      h.stubFrom('performance_reviews', result: <Map<String, dynamic>>[
        {'id': 'r-1', 'staff_id': 'staff-1', 'status': 'submitted'},
      ]);

      final reviews = await service.myReviews();
      expect(reviews.single.id, 'r-1');
    });

    test('error is swallowed → []', () async {
      stubStaff('staff-1');
      h.stubFrom('performance_reviews', error: Exception('boom'));

      expect(await service.myReviews(), isEmpty);
    });
  });

  group('completeOnboardingTask (fn_hr_onboarding_task_set_status rpc)', () {
    test('done=true sends p_status=done and returns instance_completed', () async {
      h.stubRpc('fn_hr_onboarding_task_set_status',
          result: {'instance_completed': true});

      final done = await service.completeOnboardingTask('task-1');

      expect(done, isTrue);
      final params = h.capturedRpcParams('fn_hr_onboarding_task_set_status')!;
      expect(params['p_task_id'], 'task-1');
      expect(params['p_status'], 'done');
      expect(params['p_notes'], isNull);
    });

    test('done=false sends p_status=pending (reopen)', () async {
      h.stubRpc('fn_hr_onboarding_task_set_status', result: {});

      final done = await service.completeOnboardingTask('task-1', done: false);

      expect(done, isFalse); // no instance_completed field
      final params = h.capturedRpcParams('fn_hr_onboarding_task_set_status')!;
      expect(params['p_status'], 'pending');
    });

    test('rethrows on rpc error', () async {
      h.stubRpc('fn_hr_onboarding_task_set_status', error: Exception('nope'));

      expect(
        () => service.completeOnboardingTask('task-1'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('decideLeave (leave_requests update)', () {
    test('approve writes status=approved (no decision_note when null)', () async {
      h.stubFrom('leave_requests', result: null);

      await service.decideLeave(leaveRequestId: 'lr-1', approve: true);

      final calls = h.queryByTable['leave_requests']!.calls;
      final update = calls.firstWhere((i) => i.memberName == #update);
      final patch = update.positionalArguments.first as Map;
      expect(patch['status'], 'approved');
      expect(patch.containsKey('decision_note'), isFalse);
      expect(calls.any((i) => i.memberName == #eq), isTrue);
    });

    test('reject writes status=rejected + decision_note', () async {
      h.stubFrom('leave_requests', result: null);

      await service.decideLeave(
        leaveRequestId: 'lr-1',
        approve: false,
        note: 'insufficient balance',
      );

      final update = h.queryByTable['leave_requests']!.calls
          .firstWhere((i) => i.memberName == #update);
      final patch = update.positionalArguments.first as Map;
      expect(patch['status'], 'rejected');
      expect(patch['decision_note'], 'insufficient balance');
    });

    test('rethrows on update error (trigger RAISE)', () async {
      h.stubFrom('leave_requests', error: Exception('not authorized'));

      expect(
        () => service.decideLeave(leaveRequestId: 'lr-1', approve: true),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('createLeaveRequest (leave_requests insert)', () {
    test('happy path: builds payload and returns the inserted row', () async {
      stubStaff('staff-1');
      h.stubFrom('leave_requests', result: {'id': 'lr-1', 'status': 'pending'});

      final row = await service.createLeaveRequest(
        leaveTypeId: 'lt-1',
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 3),
        note: 'holiday',
      );

      expect(row['id'], 'lr-1');
      final insert = h.queryByTable['leave_requests']!.calls
          .firstWhere((i) => i.memberName == #insert);
      final payload = insert.positionalArguments.first as Map;
      expect(payload['staff_id'], 'staff-1');
      expect(payload['tenant_id'], 'tenant-1');
      expect(payload['leave_type_id'], 'lt-1');
      expect(payload['start_date'], '2026-08-01');
      expect(payload['end_date'], '2026-08-03');
      expect(payload['status'], 'pending');
      expect(payload['created_by'], 'user-1');
    });

    test('throws when there is no staff row for the current user', () async {
      h.stubCurrentUser(id: 'user-1');
      h.stubFrom('staffs', result: null);

      expect(
        () => service.createLeaveRequest(
          leaveTypeId: 'lt-1',
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 3),
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('No staff row'),
        )),
      );
    });
  });
}
