import 'package:protoolbag_core/protoolbag_core.dart';

import '../../pem_common.dart';
import '../shared/pem_backend.dart';
import '../shared/pem_models.dart';

/// Pano dönemi: son 30 gün (günlük kova) ya da yıl başından beri (aylık kova —
/// web Enerji Kokpiti varsayılanı: YTD + `month`).
enum PemPeriod { last30Days, yearToDate }

extension PemPeriodX on PemPeriod {
  String get bucket => this == PemPeriod.last30Days ? 'day' : 'month';
}

/// Sorgu penceresi (UTC, web ile aynı: başlangıç 00:00:00.000Z, bitiş
/// 23:59:59.999Z).
class PemWindow {
  final DateTime from;
  final DateTime to;
  const PemWindow(this.from, this.to);

  String get fromIso => from.toIso8601String();
  String get toIso => to.toIso8601String();

  /// [now]'dan geriye [days] günlük pencere (bugün dahil).
  factory PemWindow.lastDays(DateTime now, int days) {
    final today = pemUtcDay(now.toUtc());
    return PemWindow(
      today.subtract(Duration(days: days - 1)),
      today.add(const Duration(
          hours: 23, minutes: 59, seconds: 59, milliseconds: 999)),
    );
  }

  /// Yıl başından bugüne.
  factory PemWindow.yearToDate(DateTime now) {
    final u = now.toUtc();
    final today = pemUtcDay(u);
    return PemWindow(
      DateTime.utc(u.year, 1, 1),
      today.add(const Duration(
          hours: 23, minutes: 59, seconds: 59, milliseconds: 999)),
    );
  }

  factory PemWindow.forPeriod(PemPeriod p, DateTime now) =>
      p == PemPeriod.last30Days
          ? PemWindow.lastDays(now, 30)
          : PemWindow.yearToDate(now);
}

/// Panonun dört manşet KPI'ı (web `CockpitKpis` paritesi).
class PemKpis {
  final double totalKwh;
  final double totalCost;
  final double peakDemandKw;
  final int activeAlarms;
  const PemKpis({
    this.totalKwh = 0,
    this.totalCost = 0,
    this.peakDemandKw = 0,
    this.activeAlarms = 0,
  });
}

/// Pano verisi.
class PemDashboardData {
  final PemPeriod period;
  final PemKpis kpis;

  /// Dönem başına toplam kWh (tüm utility'ler) — trend grafiği.
  final List<PeriodValue> series;

  /// Utility başına toplam kWh/maliyet + pay (trend satırlarından).
  final List<EnergyDimensionSlice> byUtility;

  /// En çok tüketen sahalar (`fn_pms_energy_by_dimension('site')`).
  final List<EnergyDimensionSlice> topSites;

  /// En yeni sayaç verisi (null = hiç veri yok / okunamadı).
  final String? latestReadingAt;

  const PemDashboardData({
    required this.period,
    required this.kpis,
    required this.series,
    required this.byUtility,
    required this.topSites,
    this.latestReadingAt,
  });

  /// Seçili dönemde tüketim verisi yok mu?
  bool get isEmpty => series.isEmpty;
}

/// Enerji panosu veri servisi — web `EnergyCockpitService` + kokpit bileşeninin
/// KPI/pivot mantığı. Tüm toplama SUNUCUDA (INVOKER RPC'ler, RLS kapsamı);
/// istemci yalnız önceden toplanmış satırları dönem/utility bazında katlar.
class PemDashboardService {
  PemDashboardService({PemBackend? backend, DateTime Function()? clock})
      : _backend = backend ?? SupabasePemBackend(),
        _clock = clock ?? DateTime.now;

  final PemBackend _backend;
  final DateTime Function() _clock;

  /// Panoyu yükle. Trend + saha dağılımı hataları YUKARI fırlatılır (ekran
  /// hata ile boş veriyi ayırt eder — web paritesi); alarm sayısı ve veri
  /// tazeliği hata durumunda 0 / null'a düşer.
  Future<PemDashboardData> load(PemPeriod period) async {
    final w = PemWindow.forPeriod(period, _clock());
    final orgId = _backend.organizationId;
    final tenantId = _backend.tenantId;

    final results = await Future.wait<Object?>([
      _backend.consumptionRollup(
          from: w.fromIso,
          to: w.toIso,
          bucket: period.bucket,
          organizationId: orgId),
      _backend.energyByDimension(
          dim: 'site',
          from: w.fromIso,
          to: w.toIso,
          bucket: period.bucket,
          organizationId: orgId),
      _safeAlarmCount(tenantId, orgId),
      _safeLatest(tenantId, orgId),
    ]);

    final trend = (results[0] as List<Map<String, dynamic>>)
        .map(ConsumptionTrendPoint.fromRow)
        .whereType<ConsumptionTrendPoint>()
        .toList();
    final sites = (results[1] as List<Map<String, dynamic>>)
        .map(EnergyDimensionSlice.fromRow)
        .toList()
      ..sort((a, b) => b.totalKwh.compareTo(a.totalKwh));

    return PemDashboardData(
      period: period,
      kpis: computeKpis(trend, results[2] as int),
      series: pivotByPeriod(trend),
      byUtility: byUtility(trend),
      topSites: sites,
      latestReadingAt: results[3] as String?,
    );
  }

  Future<int> _safeAlarmCount(String? tenantId, String? orgId) async {
    try {
      return await _backend.activeEnergyAlarmCount(
          tenantId: tenantId, organizationId: orgId);
    } catch (e) {
      Logger.warning('PEM active alarm count failed: $e');
      return 0;
    }
  }

  Future<String?> _safeLatest(String? tenantId, String? orgId) async {
    try {
      return await _backend.latestReadingAt(
          tenantId: tenantId, organizationId: orgId);
    } catch (e) {
      Logger.warning('PEM latest reading failed: $e');
      return null;
    }
  }

  /// Trend satırlarından manşet KPI'lar (web `computeKpis` ile aynı: Σ kWh,
  /// Σ maliyet, en yüksek avg-peak).
  static PemKpis computeKpis(List<ConsumptionTrendPoint> trend, int alarms) {
    var kwh = 0.0, cost = 0.0, peak = 0.0;
    for (final p in trend) {
      kwh += p.totalKwh;
      cost += p.totalCost;
      final pk = p.avgPeakKw;
      if (pk != null && pk > peak) peak = pk;
    }
    return PemKpis(
        totalKwh: kwh, totalCost: cost, peakDemandKw: peak, activeAlarms: alarms);
  }

  /// (bucket, utility) satırlarını dönem başına tek toplam kWh noktasına katla
  /// (web `rebuildChart` paritesi), kronolojik sıralı.
  static List<PeriodValue> pivotByPeriod(List<ConsumptionTrendPoint> trend) {
    final byPeriod = <DateTime, double>{};
    for (final p in trend) {
      byPeriod[p.bucketStart] = (byPeriod[p.bucketStart] ?? 0) + p.totalKwh;
    }
    final keys = byPeriod.keys.toList()..sort();
    return [for (final k in keys) PeriodValue(k, byPeriod[k]!)];
  }

  /// Utility başına Σ kWh / Σ maliyet + kWh payı (%), büyükten küçüğe.
  static List<EnergyDimensionSlice> byUtility(
      List<ConsumptionTrendPoint> trend) {
    final kwh = <String, double>{};
    final cost = <String, double>{};
    var total = 0.0;
    for (final p in trend) {
      kwh[p.utilityType] = (kwh[p.utilityType] ?? 0) + p.totalKwh;
      cost[p.utilityType] = (cost[p.utilityType] ?? 0) + p.totalCost;
      total += p.totalKwh;
    }
    final out = [
      for (final u in kwh.keys)
        EnergyDimensionSlice(
          label: u,
          totalKwh: kwh[u]!,
          totalCost: cost[u] ?? 0,
          pct: total > 0 ? kwh[u]! / total * 100 : 0,
        ),
    ]..sort((a, b) => b.totalKwh.compareTo(a.totalKwh));
    return out;
  }
}
