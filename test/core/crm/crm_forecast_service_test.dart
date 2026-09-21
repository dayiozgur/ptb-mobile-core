import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../helpers/supabase_fakes.dart';

/// CrmForecastService — web ForecastBoardComponent (CRM-07) mobil paritesi:
///   • getRollup      → `fn_crm_forecast_submit_rollup` (per-temsilci rollup)
///   • submitForecast → `fn_crm_submit_forecast` (kendi tahminini dondur)
/// Hata → [] / false (UI'a fırlatmaz). RPC imzaları canlı-DB'den doğrulandı.
void main() {
  late SupabaseHarness h;
  late CrmForecastService service;

  setUp(() {
    h = SupabaseHarness();
    service = CrmForecastService(supabase: h.client);
  });

  group('getRollup', () {
    test('satırları ForecastRow listesine parse eder', () async {
      h.stubRpc('fn_crm_forecast_submit_rollup', result: <Map<String, dynamic>>[
        {
          'owner_id': 'u1', 'owner_name': 'Ada Rep', 'quota_amount': 100000,
          'commit_amount': 60000, 'best_case_amount': 80000, 'pipeline_amount': 120000,
          'won_amount': 45000, 'weighted_amount': 70000, 'open_count': 7,
          'gap_to_quota': 40000, 'attainment_pct': 45, 'submitted_commit': 60000,
          'submitted_at': '2026-09-20T10:00:00Z',
        },
        {'owner_id': 'u2', 'owner_name': 'Boran Rep', 'quota_amount': 50000, 'attainment_pct': 0},
      ]);

      final rows = await service.getRollup('month', DateTime(2026, 9, 1));

      expect(rows, hasLength(2));
      expect(rows[0].ownerName, 'Ada Rep');
      expect(rows[0].commit, 60000);
      expect(rows[0].attainmentPct, 45);
      expect(rows[0].isSubmitted, isTrue);
      expect(rows[1].isSubmitted, isFalse);
    });

    test('doğru period param gönderir', () async {
      h.stubRpc('fn_crm_forecast_submit_rollup', result: <Map<String, dynamic>>[]);
      await service.getRollup('quarter', DateTime(2026, 7, 1));
      final p = h.capturedRpcParams('fn_crm_forecast_submit_rollup');
      expect(p?['p_period_type'], 'quarter');
      expect(p?['p_period_start'], '2026-07-01');
    });

    test('hata → boş liste (fırlatmaz)', () async {
      h.stubRpc('fn_crm_forecast_submit_rollup', error: Exception('db down'));
      expect(await service.getRollup('month', DateTime(2026, 9, 1)), isEmpty);
    });
  });

  group('submitForecast', () {
    test('başarılı → true + doğru param', () async {
      h.stubRpc('fn_crm_submit_forecast', result: <String, dynamic>{'id': 'snap1'});
      final ok = await service.submitForecast('month', DateTime(2026, 9, 1));
      expect(ok, isTrue);
      final p = h.capturedRpcParams('fn_crm_submit_forecast');
      expect(p?['p_period_type'], 'month');
      expect(p?['p_period_start'], '2026-09-01');
      expect(p?.containsKey('p_note'), isFalse); // note boş → gönderilmez
    });

    test('note verilince p_note ekler', () async {
      h.stubRpc('fn_crm_submit_forecast', result: <String, dynamic>{'id': 'snap2'});
      await service.submitForecast('month', DateTime(2026, 9, 1), note: 'Q3 güçlü');
      final p = h.capturedRpcParams('fn_crm_submit_forecast');
      expect(p?['p_note'], 'Q3 güçlü');
    });

    test('hata → false (fırlatmaz)', () async {
      h.stubRpc('fn_crm_submit_forecast', error: Exception('rls'));
      expect(await service.submitForecast('month', DateTime(2026, 9, 1)), isFalse);
    });
  });
}
