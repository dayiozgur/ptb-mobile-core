import '../dashboard/pem_dashboard_service.dart';
import 'pem_backend.dart';
import 'pem_models.dart';

/// Anomali çalıştırma sonucu (KPI'lar + gün listesi).
class PemAnomalyResult {
  final List<AnomalyPoint> days;
  const PemAnomalyResult(this.days);

  int get analysedDays => days.length;
  int get flaggedDays => days.where((d) => d.isAnomaly).length;

  /// En büyük mutlak sapma yüzdesi (yoksa null).
  double? get maxAbsDeviationPct {
    double? m;
    for (final d in days) {
      final v = d.deviationPct?.abs();
      if (v != null && (m == null || v > m)) m = v;
    }
    return m;
  }
}

/// Yük profili + tüketim anomalisi servisi — web `LoadProfileService` paritesi.
/// Her iki analiz de SUNUCUDA (SECURITY INVOKER RPC'ler, RLS kapsamı) çalışır.
class PemAnalyticsService {
  PemAnalyticsService({PemBackend? backend, DateTime Function()? clock})
      : _backend = backend ?? SupabasePemBackend(),
        _clock = clock ?? DateTime.now;

  final PemBackend _backend;
  final DateTime Function() _clock;

  /// Web anomali ekranı varsayılanları: sürücü `peak_demand_kw`, σ = 2,
  /// referans 120→30 gün önce, tespit son 30 gün.
  static const String anomalyDriver = 'peak_demand_kw';
  static const double anomalySigma = 2;
  static const int baselineStartDaysAgo = 120;
  static const int detectStartDaysAgo = 30;

  /// Seçilebilir sahalar (id, ad) — tenant + RLS.
  Future<List<PemSite>> sites() async {
    final rows = await _backend.sites(tenantId: _backend.tenantId);
    return [
      for (final r in rows)
        PemSite(
            id: r['id']?.toString() ?? '',
            name: (r['name'] as String?) ?? '—',
            code: r['code']?.toString(),
            city: r['city']?.toString()),
    ];
  }

  /// Haftanın günü yük profili; [siteId] null → tüm portföy. Son [days] gün.
  Future<List<LoadProfilePoint>> loadProfile(String? siteId,
      {int days = 90}) async {
    final w = PemWindow.lastDays(_clock(), days);
    final rows = await _backend.loadProfile(
        siteId: siteId, from: w.fromIso, to: w.toIso);
    return rows.map(LoadProfilePoint.fromRow).toList()
      ..sort((a, b) => a.dow.compareTo(b.dow));
  }

  /// Web varsayılan pencereleriyle salt-okunur anomali tespiti (alarm
  /// YÜKSELTMEZ — `fn_energy_evaluate_anomaly_alarms` çağrılmaz).
  Future<PemAnomalyResult> anomalies(String siteId) async {
    final today = _clock().toUtc();
    final d0 = DateTime.utc(today.year, today.month, today.day);
    DateTime ago(int n) => d0.subtract(Duration(days: n));
    String start(DateTime d) => d.toIso8601String();
    String end(DateTime d) => d
        .add(const Duration(hours: 23, minutes: 59, seconds: 59))
        .toIso8601String();

    final rows = await _backend.consumptionAnomalies(
      siteId: siteId,
      baselineFrom: start(ago(baselineStartDaysAgo)),
      baselineTo: end(ago(detectStartDaysAgo)),
      detectFrom: start(ago(detectStartDaysAgo)),
      detectTo: end(ago(0)),
      driver: anomalyDriver,
      sigma: anomalySigma,
    );
    final days = rows
        .map(AnomalyPoint.fromRow)
        .whereType<AnomalyPoint>()
        .toList()
      ..sort((a, b) => b.day.compareTo(a.day));
    return PemAnomalyResult(days);
  }
}
