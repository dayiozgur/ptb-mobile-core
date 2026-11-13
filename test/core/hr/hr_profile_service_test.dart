import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../helpers/supabase_fakes.dart';

class MockTenantService extends Mock implements TenantService {}

void main() {
  late SupabaseHarness h;
  late HrProfileService service;

  setUp(() {
    h = SupabaseHarness();
    final tenant = MockTenantService();
    when(() => tenant.currentTenantId).thenReturn('tenant-1');
    final sl = GetIt.instance;
    if (sl.isRegistered<TenantService>()) sl.unregister<TenantService>();
    sl.registerSingleton<TenantService>(tenant);
    service = HrProfileService(supabase: h.client);

    h.stubCurrentUser(id: 'user-1');
    h.stubFrom('staffs', result: {
      'id': 'staff-1',
      'first_name': 'Ada',
      'last_name': 'Lovelace',
      'organization_id': null,
      'manager_id': null,
    });
    h.stubRpc('fn_staff_sensitive', result: <Map<String, dynamic>>[]);
  });

  tearDown(() => GetIt.instance.reset());

  group('fn_staff_personnel_get (sensitive block)', () {
    test('a readable block is returned, not denied', () async {
      h.stubRpc('fn_staff_personnel_get', result: <Map<String, dynamic>>[
        {'staff_id': 'staff-1', 'iban': 'TR00', 'gross_salary': 1000},
      ]);

      final p = await service.myStaffProfile();

      expect(p!.personnel, isNotNull);
      expect(p.personnel!.iban, 'TR00');
      expect(p.personnelDenied, isFalse);
      expect(h.capturedRpcParams('fn_staff_personnel_get'),
          {'p_staff_id': 'staff-1'});
    });

    test('42501 refusal → personnelDenied, profile still shown', () async {
      h.stubRpc('fn_staff_personnel_get',
          error: const PostgrestException(
              message: 'not authorized', code: '42501'));

      final p = await service.myStaffProfile();

      expect(p, isNotNull);
      expect(p!.displayName, 'Ada Lovelace');
      expect(p.personnel, isNull);
      expect(p.personnelDenied, isTrue);
    });

    test('any other failure degrades to "no block", not "denied"', () async {
      h.stubRpc('fn_staff_personnel_get',
          error: const PostgrestException(message: 'timeout', code: '57014'));

      final p = await service.myStaffProfile();

      expect(p!.personnel, isNull);
      expect(p.personnelDenied, isFalse);
    });
  });
}
