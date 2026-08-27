import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../helpers/supabase_fakes.dart';

/// AdminPayrollAdjustmentService — PHR admin bordro ek/kesinti (avans/masraf)
/// yazma-akışları. Ctor-inject (sl gerekmez). Yazma hatası → `false`/`null`
/// (UI'a fırlatmaz). Payload sözleşmesi web `PayrollService` ile birebir.
void main() {
  late SupabaseHarness h;
  late AdminPayrollAdjustmentService service;

  setUp(() {
    h = SupabaseHarness();
    service = AdminPayrollAdjustmentService(supabase: h.client);
  });

  group('pushToPayroll', () {
    test('geçerli id → doğru payload ile RPC + dönen id string', () async {
      h.stubRpc('fn_hr_push_to_payroll', result: 'adj-99');

      final id = await service.pushToPayroll('sub-1');

      expect(id, 'adj-99');
      expect(h.capturedRpcParams('fn_hr_push_to_payroll'),
          {'p_submission_id': 'sub-1'});
    });

    test('null data → boş string (web String(data ?? "") aynası)', () async {
      h.stubRpc('fn_hr_push_to_payroll', result: null);
      expect(await service.pushToPayroll('sub-2'), '');
    });

    test('boş id → RPC çağrılmaz, null', () async {
      h.stubRpc('fn_hr_push_to_payroll', result: 'x');
      expect(await service.pushToPayroll('   '), isNull);
    });

    test('RPC hatası → null (fırlatmaz)', () async {
      h.stubRpc('fn_hr_push_to_payroll', error: Exception('boom'));
      expect(await service.pushToPayroll('sub-3'), isNull);
    });
  });

  group('applyAdjustments', () {
    test('geçerli runId → doğru payload + işlenen adet (int)', () async {
      h.stubRpc('fn_payroll_apply_adjustments', result: 4);

      final n = await service.applyAdjustments('run-1');

      expect(n, 4);
      expect(h.capturedRpcParams('fn_payroll_apply_adjustments'),
          {'p_run_id': 'run-1'});
    });

    test('num (double) sonuç → int (web Number(data) aynası)', () async {
      h.stubRpc('fn_payroll_apply_adjustments', result: 3.0);
      expect(await service.applyAdjustments('run-2'), 3);
    });

    test('null data → 0', () async {
      h.stubRpc('fn_payroll_apply_adjustments', result: null);
      expect(await service.applyAdjustments('run-3'), 0);
    });

    test('boş runId → RPC çağrılmaz, null', () async {
      h.stubRpc('fn_payroll_apply_adjustments', result: 5);
      expect(await service.applyAdjustments(''), isNull);
    });

    test('RPC hatası → null (fırlatmaz)', () async {
      h.stubRpc('fn_payroll_apply_adjustments', error: Exception('x'));
      expect(await service.applyAdjustments('run-4'), isNull);
    });
  });

  group('cancelAdjustment', () {
    test('geçerli id → update patch + id/status eq zinciri + true', () async {
      h.stubCurrentUser(id: 'u-1');
      h.stubFrom('payroll_adjustments', result: null);

      final ok = await service.cancelAdjustment('adj-1');

      expect(ok, isTrue);
      final calls = h.queryByTable['payroll_adjustments']!.calls;

      // update({status:'cancelled', updated_at, updated_by:'u-1'})
      final update = calls.firstWhere((c) => c.memberName == #update);
      final patch = update.positionalArguments.first as Map;
      expect(patch['status'], 'cancelled');
      expect(patch['updated_by'], 'u-1');
      expect(patch.containsKey('updated_at'), isTrue);

      // .eq('id','adj-1') ve .eq('status','pending')
      final eqs = calls.where((c) => c.memberName == #eq).toList();
      final eqMap = {
        for (final c in eqs)
          c.positionalArguments[0] as String: c.positionalArguments[1]
      };
      expect(eqMap['id'], 'adj-1');
      expect(eqMap['status'], 'pending');
    });

    test('oturum yoksa updated_by patch\'te YER ALMAZ', () async {
      h.stubCurrentUser(id: null);
      h.stubFrom('payroll_adjustments', result: null);

      final ok = await service.cancelAdjustment('adj-2');

      expect(ok, isTrue);
      final calls = h.queryByTable['payroll_adjustments']!.calls;
      final update = calls.firstWhere((c) => c.memberName == #update);
      final patch = update.positionalArguments.first as Map;
      expect(patch.containsKey('updated_by'), isFalse);
    });

    test('boş id → yazma yapılmaz, false', () async {
      h.stubFrom('payroll_adjustments', result: null);
      expect(await service.cancelAdjustment('  '), isFalse);
      expect(h.queryByTable.containsKey('payroll_adjustments'), isFalse);
    });

    test('update hatası → false (fırlatmaz)', () async {
      h.stubCurrentUser(id: 'u-1');
      h.stubFrom('payroll_adjustments', error: Exception('boom'));
      expect(await service.cancelAdjustment('adj-3'), isFalse);
    });
  });
}
