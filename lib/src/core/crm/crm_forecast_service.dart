import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';

/// Bir satış-temsilcisinin dönem-tahmini satırı — web `ForecastBoardComponent`
/// (CRM-07) `fn_crm_forecast_submit_rollup` çıktısının mobil karşılığı.
class ForecastRow {
  final String? ownerId;
  final String ownerName;
  final double quota;
  final double commit;
  final double bestCase;
  final double pipeline;
  final double won;
  final double weighted;
  final int openCount;
  final double gapToQuota;
  final double attainmentPct;
  final double? submittedCommit;
  final DateTime? submittedAt;

  const ForecastRow({
    this.ownerId,
    required this.ownerName,
    this.quota = 0,
    this.commit = 0,
    this.bestCase = 0,
    this.pipeline = 0,
    this.won = 0,
    this.weighted = 0,
    this.openCount = 0,
    this.gapToQuota = 0,
    this.attainmentPct = 0,
    this.submittedCommit,
    this.submittedAt,
  });

  bool get isSubmitted => submittedAt != null;

  static double _d(Object? v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
  static int _i(Object? v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

  factory ForecastRow.fromJson(Map<String, dynamic> j) => ForecastRow(
        ownerId: j['owner_id'] as String?,
        ownerName: (j['owner_name'] as String?)?.trim().isNotEmpty == true
            ? (j['owner_name'] as String)
            : '—',
        quota: _d(j['quota_amount']),
        commit: _d(j['commit_amount']),
        bestCase: _d(j['best_case_amount']),
        pipeline: _d(j['pipeline_amount']),
        won: _d(j['won_amount']),
        weighted: _d(j['weighted_amount']),
        openCount: _i(j['open_count']),
        gapToQuota: _d(j['gap_to_quota']),
        attainmentPct: _d(j['attainment_pct']),
        submittedCommit: j['submitted_commit'] == null ? null : _d(j['submitted_commit']),
        submittedAt: DateTime.tryParse((j['submitted_at'] as String?) ?? ''),
      );
}

/// **CRM Satış-Tahmini servisi** — web `QuotaService.submitForecast` +
/// forecast-board rollup paritesi. Dönem-bazlı per-temsilci rollup okur ve
/// çağıranın kendi tahminini `crm_forecast_snapshots`'a dondurur.
///
/// Yazma sözleşmesi: hata → `false` / boş-liste (UI'a ASLA fırlatmaz); tenant
/// RLS'e bırakılır (diğer mobil CRM servisleriyle aynı).
class CrmForecastService {
  final SupabaseClient _supabase;

  CrmForecastService({required SupabaseClient supabase}) : _supabase = supabase;

  /// Dönem için per-temsilci forecast-vs-quota rollup'ı. Hata → [].
  Future<List<ForecastRow>> getRollup(String periodType, DateTime periodStart) async {
    try {
      final res = await _supabase.rpc('fn_crm_forecast_submit_rollup', params: {
        'p_period_type': periodType,
        'p_period_start': _dateOnly(periodStart),
      });
      return (res as List)
          .map((r) => ForecastRow.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      Logger.error('crm getRollup hata', e);
      return const [];
    }
  }

  /// Çağıranın kendi tahminini dönem için dondur (`fn_crm_submit_forecast`). Hata → false.
  Future<bool> submitForecast(String periodType, DateTime periodStart, {String? note}) async {
    try {
      await _supabase.rpc('fn_crm_submit_forecast', params: {
        'p_period_type': periodType,
        'p_period_start': _dateOnly(periodStart),
        if (note != null && note.trim().isNotEmpty) 'p_note': note.trim(),
      });
      return true;
    } catch (e) {
      Logger.error('crm submitForecast hata', e);
      return false;
    }
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
