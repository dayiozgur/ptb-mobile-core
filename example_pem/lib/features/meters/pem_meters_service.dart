import 'package:protoolbag_core/protoolbag_core.dart';

import '../shared/pem_backend.dart';
import '../shared/pem_models.dart';

/// Saha başlığı altında sayaç grubu.
class PemMeterGroup {
  final String siteId;
  final String siteName;
  final List<PemMeter> meters;
  const PemMeterGroup(
      {required this.siteId, required this.siteName, required this.meters});
}

/// Sayaç listesi servisi — web `ConsumptionService.listMeters` /
/// meter-management okuma yolu (aktif `energy_meters`, tenant + RLS), saha
/// adına göre gruplanır. Salt-okunur.
class PemMetersService {
  PemMetersService({PemBackend? backend})
      : _backend = backend ?? SupabasePemBackend();

  final PemBackend _backend;

  Future<List<PemMeterGroup>> grouped() async {
    final tenantId = _backend.tenantId;
    final meters = (await _backend.meters(tenantId: tenantId))
        .map(PemMeter.fromRow)
        .toList();
    var siteNames = <String, String>{};
    try {
      final sites = await _backend.sites(tenantId: tenantId);
      siteNames = {
        for (final s in sites)
          if (s['id'] != null) s['id'].toString(): (s['name'] as String?) ?? '—',
      };
    } catch (e) {
      Logger.warning('PEM meter site names failed: $e');
    }
    return group(meters, siteNames);
  }

  /// Sayaçları sahaya göre grupla; gruplar saha adına göre, ana sayaç önce.
  static List<PemMeterGroup> group(
      List<PemMeter> meters, Map<String, String> siteNames) {
    final bySite = <String, List<PemMeter>>{};
    for (final m in meters) {
      bySite.putIfAbsent(m.siteId ?? '', () => []).add(m);
    }
    final groups = [
      for (final e in bySite.entries)
        PemMeterGroup(
          siteId: e.key,
          siteName: siteNames[e.key] ?? '—',
          meters: e.value
            ..sort((a, b) {
              if (a.isSiteMain != b.isSiteMain) return a.isSiteMain ? -1 : 1;
              return (a.utilityType ?? '').compareTo(b.utilityType ?? '');
            }),
        ),
    ]..sort((a, b) => a.siteName.toLowerCase().compareTo(b.siteName.toLowerCase()));
    return groups;
  }
}
