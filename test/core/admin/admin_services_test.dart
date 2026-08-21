import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../helpers/supabase_fakes.dart';

void main() {
  late SupabaseHarness h;

  setUp(() => h = SupabaseHarness());

  group('AdminUserService.listUsers (profiles + fn_coarse_roles_of)', () {
    test('happy path: reads profiles then enriches coarse role via rpc', () async {
      h.stubFrom('profiles', result: <Map<String, dynamic>>[
        {'id': 'u-1', 'email': 'a@x.com', 'full_name': 'Ada'},
        {'id': 'u-2', 'email': 'b@x.com', 'full_name': 'Bob'},
      ]);
      h.stubRpc('fn_coarse_roles_of', result: <dynamic>[
        {'profile_id': 'u-1', 'role': 'ADMIN'},
        {'profile_id': 'u-2', 'role': 'USER'},
      ]);

      final service = AdminUserService(supabase: h.client);
      final users = await service.listUsers();

      expect(users.length, 2);
      expect(users.firstWhere((u) => u.id == 'u-1').coarseRole, 'ADMIN');
      expect(users.firstWhere((u) => u.id == 'u-2').coarseRole, 'USER');

      final params = h.capturedRpcParams('fn_coarse_roles_of')!;
      expect(params['p_ids'], containsAll(<String>['u-1', 'u-2']));
    });

    test('search term adds an or() filter over the profiles query', () async {
      h.stubFrom('profiles', result: <Map<String, dynamic>>[
        {'id': 'u-1', 'email': 'a@x.com'},
      ]);
      h.stubRpc('fn_coarse_roles_of', result: <dynamic>[]);

      final service = AdminUserService(supabase: h.client);
      await service.listUsers(search: 'ada');

      final calls = h.queryByTable['profiles']!.calls;
      expect(calls.any((i) => i.memberName == #or), isTrue);
    });

    test('coarse-role rpc failure falls back to existing role (no throw)', () async {
      h.stubFrom('profiles', result: <Map<String, dynamic>>[
        {'id': 'u-1', 'email': 'a@x.com'},
      ]);
      h.stubRpc('fn_coarse_roles_of', error: Exception('rpc down'));

      final service = AdminUserService(supabase: h.client);
      final users = await service.listUsers();

      expect(users.length, 1); // enrichment skipped, list still returned
    });

    test('listUsers rethrows when the profiles read fails', () async {
      h.stubFrom('profiles', error: Exception('rls denied'));

      final service = AdminUserService(supabase: h.client);
      expect(() => service.listUsers(), throwsA(isA<Exception>()));
    });
  });

  group('AdminStaffService.listStaff (staffs + organizations names)', () {
    test('happy path: parses staff rows and resolves org names', () async {
      h.stubFrom('staffs', result: <Map<String, dynamic>>[
        {'id': 's-1', 'name': 'Ada', 'organization_id': 'org-1'},
      ]);
      h.stubFrom('organizations', result: <Map<String, dynamic>>[
        {'id': 'org-1', 'name': 'Acme'},
      ]);

      final service = AdminStaffService(supabase: h.client);
      final staff = await service.listStaff();

      expect(staff.single.id, 's-1');
      expect(staff.single.organizationName, 'Acme');
    });

    test('rethrows when the staffs read fails', () async {
      h.stubFrom('staffs', error: Exception('db down'));

      final service = AdminStaffService(supabase: h.client);
      expect(() => service.listStaff(), throwsA(isA<Exception>()));
    });
  });

  group('AdminRbacService.listRoles (rbac_roles)', () {
    test('happy path: parses role rows', () async {
      h.stubFrom('rbac_roles', result: <Map<String, dynamic>>[
        {'id': 'r-1', 'code': 'admin', 'name': 'Administrator', 'level': 90},
        {'id': 'r-2', 'code': 'user', 'name': 'User', 'level': 10},
      ]);

      final service = AdminRbacService(supabase: h.client);
      final roles = await service.listRoles();

      expect(roles.length, 2);
      expect(roles.first.code, 'admin');
      expect(roles.first.level, 90);
    });

    test('tolerates rows with missing optional fields', () async {
      h.stubFrom('rbac_roles', result: <Map<String, dynamic>>[
        {'id': 'r-1'},
      ]);

      final service = AdminRbacService(supabase: h.client);
      final roles = await service.listRoles();

      expect(roles.single.code, '');
      expect(roles.single.level, 0);
    });

    test('rethrows on read error', () async {
      h.stubFrom('rbac_roles', error: Exception('boom'));

      final service = AdminRbacService(supabase: h.client);
      expect(() => service.listRoles(), throwsA(isA<Exception>()));
    });
  });

  group('AdminBugReportService.listBugReports (bug_reports)', () {
    test('happy path: parses rows + embedded reporter name', () async {
      h.stubFrom('bug_reports', result: <Map<String, dynamic>>[
        {
          'id': 'bug-1',
          'title': 'Crash on save',
          'status': 'open',
          'priority': 'high',
          'reporter': {'full_name': 'Ada Lovelace'},
        },
      ]);

      final service = AdminBugReportService(supabase: h.client);
      final reports = await service.listBugReports();

      expect(reports.single.id, 'bug-1');
      expect(reports.single.priority, 'high');
      expect(reports.single.reporterName, 'Ada Lovelace');
    });

    test('rethrows on read error', () async {
      h.stubFrom('bug_reports', error: Exception('rls denied'));

      final service = AdminBugReportService(supabase: h.client);
      expect(() => service.listBugReports(), throwsA(isA<Exception>()));
    });
  });
}
