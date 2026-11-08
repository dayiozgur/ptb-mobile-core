import 'package:protoolbag_core/protoolbag_core.dart';

import '../dashboard/pem_dashboard_service.dart';
import '../shared/pem_backend.dart';
import '../shared/pem_models.dart';

/// Saha enerji detayı verisi.
class PemSiteDetail {
  /// Son 30 günün günlük toplamları (veri olan günler, kronolojik).
  final List<DailyConsumption> daily;

  /// Sahadaki aktif sayaçlar.
  final List<PemMeter> meters;

  /// Son 90 günün haftanın günü profili.
  final List<LoadProfilePoint> loadProfile;

  const PemSiteDetail({
    required this.daily,
    required this.meters,
    required this.loadProfile,
  });

  double get totalKwh => daily.fold(0.0, (s, d) => s + d.kwh);
  double get totalCost => daily.fold(0.0, (s, d) => s + d.cost);
  double get peakKw => daily.fold(
      0.0, (s, d) => (d.peakKw != null && d.peakKw! > s) ? d.peakKw! : s);
  bool get hasConsumption => daily.isNotEmpty;
}

/// Saha listesi + saha enerji detayı servisi.
///
/// Liste: `sites` (web LoadProfileService/ConsumptionService.listSites ile
/// aynı: id,name + kod/şehir; tenant + RLS) ve `fn_energy_site_benchmark`
/// (web Saha Kıyaslama varsayılanı: son 12 ay, `hdd`) sıralaması saha id'si
/// ile birleştirilir. Kıyaslama okunamazsa liste YİNE gösterilir.
///
/// Detay: `energy_readings_rollup` (bucket='day', son 30 gün) gün başına
/// toplanır; sayaçlar `energy_meters`; profil `fn_energy_load_profile`.
class PemSitesService {
  PemSitesService({PemBackend? backend, DateTime Function()? clock})
      : _backend = backend ?? SupabasePemBackend(),
        _clock = clock ?? DateTime.now;

  final PemBackend _backend;
  final DateTime Function() _clock;

  /// Kıyaslama sürücüsü (web varsayılanı).
  static const String benchmarkDriver = 'hdd';

  Future<List<PemSite>> listSites() async {
    final rows = await _backend.sites(tenantId: _backend.tenantId);
    final byId = <String, Map<String, dynamic>>{};
    try {
      final w = PemWindow.lastDays(_clock(), 365);
      final bench = await _backend.siteBenchmark(
          from: w.fromIso, to: w.toIso, driver: benchmarkDriver);
      for (final b in bench) {
        final id = b['site_id']?.toString();
        if (id != null) byId[id] = b;
      }
    } catch (e) {
      Logger.warning('PEM site benchmark failed: $e');
    }
    return [
      for (final r in rows)
        PemSite(
          id: r['id']?.toString() ?? '',
          name: (r['name'] as String?)?.trim().isNotEmpty == true
              ? (r['name'] as String).trim()
              : '—',
          code: r['code']?.toString(),
          city: r['city']?.toString(),
        ).withBenchmark(byId[r['id']?.toString()]),
    ];
  }

  /// Arama süzgeci (ad / kod / şehir, büyük-küçük harf duyarsız).
  static List<PemSite> filter(List<PemSite> all, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((s) => [s.name, s.code ?? '', s.city ?? '']
            .any((v) => v.toLowerCase().contains(q)))
        .toList();
  }

  /// Saha detayı. Günlük rollup hatası YUKARI fırlatılır (ana veri); sayaç ve
  /// profil okumaları hata durumunda boşa düşer.
  Future<PemSiteDetail> siteDetail(String siteId) async {
    final now = _clock();
    final w30 = PemWindow.lastDays(now, 30);
    final w90 = PemWindow.lastDays(now, 90);
    final tenantId = _backend.tenantId;

    final results = await Future.wait<Object?>([
      _backend.siteDailyRollup(
          siteId: siteId, from: w30.fromIso, to: w30.toIso, tenantId: tenantId),
      _safe(() => _backend.meters(siteId: siteId, tenantId: tenantId),
          'meters'),
      _safe(
          () => _backend.loadProfile(
              siteId: siteId, from: w90.fromIso, to: w90.toIso),
          'load profile'),
    ]);

    return PemSiteDetail(
      daily: aggregateDaily(results[0] as List<Map<String, dynamic>>),
      meters: (results[1] as List<Map<String, dynamic>>)
          .map(PemMeter.fromRow)
          .toList(),
      loadProfile: (results[2] as List<Map<String, dynamic>>)
          .map(LoadProfilePoint.fromRow)
          .toList()
        ..sort((a, b) => a.dow.compareTo(b.dow)),
    );
  }

  Future<List<Map<String, dynamic>>> _safe(
      Future<List<Map<String, dynamic>>> Function() f, String what) async {
    try {
      return await f();
    } catch (e) {
      Logger.warning('PEM site $what failed: $e');
      return const [];
    }
  }

  /// Sayaç/utility başına günlük rollup satırlarını gün başına topla
  /// (kWh + maliyet toplamı; tepe = günün en yüksek sayaç tepesi).
  static List<DailyConsumption> aggregateDaily(
      List<Map<String, dynamic>> rows) {
    final kwh = <DateTime, double>{};
    final cost = <DateTime, double>{};
    final peak = <DateTime, double>{};
    for (final r in rows) {
      final at = DateTime.tryParse(r['bucket_start']?.toString() ?? '');
      if (at == null) continue;
      final u = at.toUtc();
      final d = DateTime.utc(u.year, u.month, u.day);
      kwh[d] = (kwh[d] ?? 0) + (_n(r['consumption_kwh']) ?? 0);
      cost[d] = (cost[d] ?? 0) + (_n(r['cost']) ?? 0);
      final pk = _n(r['peak_demand_kw']);
      if (pk != null && pk > (peak[d] ?? double.negativeInfinity)) peak[d] = pk;
    }
    final days = kwh.keys.toList()..sort();
    return [
      for (final d in days)
        DailyConsumption(day: d, kwh: kwh[d]!, cost: cost[d] ?? 0, peakKw: peak[d]),
    ];
  }

  static double? _n(Object? v) =>
      v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
}
