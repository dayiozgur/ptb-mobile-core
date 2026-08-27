import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../helpers/supabase_fakes.dart';

class MockTenantService extends Mock implements TenantService {}

/// AdminPayrollService.getPushableSubmissions — bordroya itilebilir (onaylı)
/// avans/masraf başvuruları. Web `PayrollService.getPushableSubmissions`
/// 3-sorgu istemci-okumasının aynası: itilmiş (source_ref) başvurular elenir,
/// submitterName staffs'tan, amount = metadata.amount. Hata → [] (sessiz-boş).
void main() {
  late SupabaseHarness h;
  late MockTenantService tenant;
  late AdminPayrollService service;

  setUp(() {
    h = SupabaseHarness();
    tenant = MockTenantService();
    when(() => tenant.currentTenantId).thenReturn('tenant-1');
    final sl = GetIt.instance;
    if (sl.isRegistered<TenantService>()) sl.unregister<TenantService>();
    sl.registerSingleton<TenantService>(tenant);
    service = AdminPayrollService(supabase: h.client);
  });

  tearDown(() => GetIt.instance.reset());

  group('getPushableSubmissions (3-sorgu)', () {
    test('taken (source_ref) başvuruları eler; kalanı map\'ler', () async {
      h.stubFrom('form_submissions', result: <Map<String, dynamic>>[
        {
          'id': 'sub-1',
          'entity_type': 'hr_advance',
          'status': 'approved',
          'code': 'ADV-1',
          'subject': 'Avans 1',
          'metadata': {'amount': 1500},
          'submitted_by': 'prof-1',
          'active': true,
        },
        {
          'id': 'sub-2',
          'entity_type': 'hr_expense',
          'status': 'approved',
          'code': 'EXP-2',
          'subject': 'Masraf 2',
          'metadata': {'amount': 250.5},
          'submitted_by': 'prof-2',
          'active': true,
        },
      ]);
      // sub-1 zaten itilmiş (iptal edilmemiş adjustment) → elenmeli.
      h.stubFrom('payroll_adjustments', result: <Map<String, dynamic>>[
        {'source_ref': 'sub-1', 'status': 'pending'},
      ]);
      h.stubFrom('staffs', result: <Map<String, dynamic>>[
        {
          'profile_id': 'prof-2',
          'name': null,
          'first_name': 'Ada',
          'last_name': 'Lovelace',
        },
      ]);

      final rows = await service.getPushableSubmissions();

      expect(rows.length, 1);
      final r = rows.single;
      expect(r.id, 'sub-2');
      expect(r.entityType, 'hr_expense');
      expect(r.status, 'approved');
      expect(r.code, 'EXP-2');
      expect(r.amount, 250.5); // metadata.amount parse
      expect(r.submitterName, 'Ada Lovelace'); // first+last fallback
    });

    test('iptal edilmiş adjustment source_ref\'i ELEMEZ (neq status filtresi)',
        () async {
      // Sorgu zaten status<>cancelled ile filtrelendiği için mock yalnız
      // canlı (pending/applied) satırları döndürür; boş → hiçbir eleme.
      h.stubFrom('form_submissions', result: <Map<String, dynamic>>[
        {
          'id': 'sub-9',
          'entity_type': 'hr_advance',
          'status': 'approved',
          'metadata': {'amount': 100},
          'submitted_by': 'prof-9',
          'active': true,
        },
      ]);
      h.stubFrom('payroll_adjustments', result: <Map<String, dynamic>>[]);
      h.stubFrom('staffs', result: <Map<String, dynamic>>[
        {'profile_id': 'prof-9', 'name': 'Grace Hopper'},
      ]);

      final rows = await service.getPushableSubmissions();

      expect(rows.length, 1);
      expect(rows.single.id, 'sub-9');
      expect(rows.single.submitterName, 'Grace Hopper'); // name önceliği

      // neq('status','cancelled') zinciri kuruldu mu?
      final adjCalls = h.queryByTable['payroll_adjustments']!.calls;
      expect(adjCalls.any((c) => c.memberName == #neq), isTrue);
    });

    test('metadata yoksa amount = 0; isim eşleşmezse submitterName null',
        () async {
      h.stubFrom('form_submissions', result: <Map<String, dynamic>>[
        {
          'id': 'sub-3',
          'entity_type': 'hr_advance',
          'status': 'pending',
          'submitted_by': 'prof-x',
          'active': true,
        },
      ]);
      h.stubFrom('payroll_adjustments', result: <Map<String, dynamic>>[]);
      h.stubFrom('staffs', result: <Map<String, dynamic>>[]);

      final rows = await service.getPushableSubmissions();

      expect(rows.single.amount, 0);
      expect(rows.single.submitterName, isNull);
    });

    test('form_submissions boş → []', () async {
      h.stubFrom('form_submissions', result: <Map<String, dynamic>>[]);
      h.stubFrom('payroll_adjustments', result: <Map<String, dynamic>>[]);

      expect(await service.getPushableSubmissions(), isEmpty);
    });

    test('hata → [] (fırlatmaz; inbox\'ı çökertmez)', () async {
      h.stubFrom('form_submissions', error: Exception('db down'));

      expect(await service.getPushableSubmissions(), isEmpty);
    });

    test('doğru kolonlar + entity_type/active filtreleri kuruldu', () async {
      h.stubFrom('form_submissions', result: <Map<String, dynamic>>[]);
      h.stubFrom('payroll_adjustments', result: <Map<String, dynamic>>[]);

      await service.getPushableSubmissions();

      final calls = h.queryByTable['form_submissions']!.calls;
      final select = calls.firstWhere((c) => c.memberName == #select);
      final cols = select.positionalArguments.first as String;
      expect(cols.contains('metadata'), isTrue);
      expect(cols.contains('submitted_by'), isTrue);
      // inFilter(entity_type,[...]) + eq(active,true)
      expect(calls.any((c) => c.memberName == #inFilter), isTrue);
      final eqs = calls.where((c) => c.memberName == #eq).toList();
      final eqMap = {
        for (final c in eqs)
          c.positionalArguments[0] as String: c.positionalArguments[1]
      };
      expect(eqMap['active'], true);
      expect(eqMap['tenant_id'], 'tenant-1');
    });
  });

  group('mapPushableSubmissions (saf mapper)', () {
    test('name önceliği: name varsa first/last yok sayılır', () {
      final rows = AdminPayrollService.mapPushableSubmissions(
        submissions: [
          {
            'id': 's1',
            'entity_type': 'hr_advance',
            'submitted_by': 'p1',
            'metadata': {'amount': 10},
          },
        ],
        adjustments: const [],
        staffs: [
          {
            'profile_id': 'p1',
            'name': 'Öncelikli Ad',
            'first_name': 'Yok',
            'last_name': 'Sayılır',
          },
        ],
      );
      expect(rows.single.submitterName, 'Öncelikli Ad');
    });

    test('taken source_ref eler; sıra korunur', () {
      final rows = AdminPayrollService.mapPushableSubmissions(
        submissions: [
          {'id': 'a', 'submitted_by': 'p', 'metadata': {'amount': 1}},
          {'id': 'b', 'submitted_by': 'p', 'metadata': {'amount': 2}},
          {'id': 'c', 'submitted_by': 'p', 'metadata': {'amount': 3}},
        ],
        adjustments: const [
          {'source_ref': 'b', 'status': 'applied'},
        ],
        staffs: const [],
      );
      expect(rows.map((e) => e.id).toList(), ['a', 'c']);
    });

    test('metadata string/num karışık → payrollNum parse', () {
      final rows = AdminPayrollService.mapPushableSubmissions(
        submissions: [
          {'id': 'a', 'metadata': {'amount': '1234.50'}},
          {'id': 'b', 'metadata': null},
        ],
        adjustments: const [],
        staffs: const [],
      );
      expect(rows[0].amount, 1234.50);
      expect(rows[1].amount, 0);
    });
  });
}
