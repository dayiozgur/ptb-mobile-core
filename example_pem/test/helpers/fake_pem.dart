import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:protoolbag_pem/features/shared/pem_backend.dart';

/// Kayıtlı çağrı (işlem adı + parametreler).
class PemCall {
  final String name;
  final Map<String, dynamic> params;
  const PemCall(this.name, this.params);
  @override
  String toString() => 'PemCall($name, $params)';
}

/// Supabase'siz [PemBackend] — yanıtlar önceden verilir, çağrılar kaydedilir.
/// [errors] içindeki işlem adı için çağrı o hatayı fırlatır.
class FakePemBackend implements PemBackend {
  FakePemBackend({
    this.tenant = 'tenant-1',
    this.org = 'org-1',
    this.rollup = const [],
    this.dimension = const {},
    this.alarmCount = 0,
    this.latest,
    this.siteRows = const [],
    this.benchmark = const [],
    this.daily = const [],
    this.meterRows = const [],
    this.profile = const [],
    this.anomalyRows = const [],
    this.alarmRows = const [],
    this.priorityRows = const [],
    this.errors = const {},
  });

  final String? tenant;
  final String? org;
  final List<Map<String, dynamic>> rollup;
  final Map<String, List<Map<String, dynamic>>> dimension;
  final int alarmCount;
  final String? latest;
  final List<Map<String, dynamic>> siteRows;
  final List<Map<String, dynamic>> benchmark;
  final List<Map<String, dynamic>> daily;
  final List<Map<String, dynamic>> meterRows;
  final List<Map<String, dynamic>> profile;
  final List<Map<String, dynamic>> anomalyRows;
  final List<Map<String, dynamic>> alarmRows;
  final List<Map<String, dynamic>> priorityRows;
  final Map<String, Object> errors;

  final List<PemCall> calls = [];

  PemCall? last(String name) {
    for (final c in calls.reversed) {
      if (c.name == name) return c;
    }
    return null;
  }

  void _record(String name, Map<String, dynamic> params) {
    calls.add(PemCall(name, params));
    final e = errors[name];
    if (e != null) throw e;
  }

  @override
  String? get tenantId => tenant;

  @override
  String? get organizationId => org;

  @override
  Future<List<Map<String, dynamic>>> consumptionRollup({
    required String from,
    required String to,
    required String bucket,
    String? organizationId,
  }) async {
    _record('fn_energy_consumption_rollup', {
      'p_from': from,
      'p_to': to,
      'p_bucket': bucket,
      'p_organization_id': organizationId,
    });
    return rollup;
  }

  @override
  Future<List<Map<String, dynamic>>> energyByDimension({
    required String dim,
    required String from,
    required String to,
    required String bucket,
    String? organizationId,
  }) async {
    _record('fn_pms_energy_by_dimension', {
      'p_dim': dim,
      'p_from': from,
      'p_to': to,
      'p_bucket': bucket,
      'p_organization_id': organizationId,
    });
    return dimension[dim] ?? const [];
  }

  @override
  Future<int> activeEnergyAlarmCount(
      {String? tenantId, String? organizationId}) async {
    _record('alarms.count',
        {'tenant_id': tenantId, 'organization_id': organizationId});
    return alarmCount;
  }

  @override
  Future<String?> latestReadingAt(
      {String? tenantId, String? organizationId}) async {
    _record('energy_readings_rollup.latest',
        {'tenant_id': tenantId, 'organization_id': organizationId});
    return latest;
  }

  @override
  Future<List<Map<String, dynamic>>> sites({String? tenantId}) async {
    _record('sites', {'tenant_id': tenantId});
    return siteRows;
  }

  @override
  Future<List<Map<String, dynamic>>> siteBenchmark({
    required String from,
    required String to,
    required String driver,
  }) async {
    _record('fn_energy_site_benchmark',
        {'p_from': from, 'p_to': to, 'p_driver': driver});
    return benchmark;
  }

  @override
  Future<List<Map<String, dynamic>>> siteDailyRollup({
    required String siteId,
    required String from,
    required String to,
    String? tenantId,
  }) async {
    _record('energy_readings_rollup.daily',
        {'site_id': siteId, 'from': from, 'to': to, 'tenant_id': tenantId});
    return daily;
  }

  @override
  Future<List<Map<String, dynamic>>> meters(
      {String? siteId, String? tenantId}) async {
    _record('energy_meters', {'site_id': siteId, 'tenant_id': tenantId});
    return siteId == null
        ? meterRows
        : meterRows.where((m) => m['site_id'] == siteId).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> loadProfile({
    String? siteId,
    required String from,
    required String to,
  }) async {
    _record('fn_energy_load_profile',
        {'p_site_id': siteId, 'p_from': from, 'p_to': to});
    return profile;
  }

  @override
  Future<List<Map<String, dynamic>>> consumptionAnomalies({
    required String siteId,
    required String baselineFrom,
    required String baselineTo,
    required String detectFrom,
    required String detectTo,
    required String driver,
    required num sigma,
  }) async {
    _record('fn_energy_consumption_anomalies', {
      'p_site_id': siteId,
      'p_baseline_from': baselineFrom,
      'p_baseline_to': baselineTo,
      'p_detect_from': detectFrom,
      'p_detect_to': detectTo,
      'p_driver': driver,
      'p_sigma': sigma,
    });
    return anomalyRows;
  }

  @override
  Future<List<Map<String, dynamic>>> energyAlarms(
      {String? tenantId, int limit = 50}) async {
    _record('alarms', {'tenant_id': tenantId, 'limit': limit});
    return alarmRows;
  }

  @override
  Future<List<Map<String, dynamic>>> priorities() async {
    _record('priorities', const {});
    return priorityRows;
  }
}

/// Anahtarı (ya da verilen tabloyu) döndüren sahte [LocalizationService] —
/// `pemT` anahtar bulunamayınca Türkçe yedeğe düşer.
class FakeLocalization implements LocalizationService {
  FakeLocalization([this.table = const {}]);
  final Map<String, String> table;

  @override
  String translate(String key, {Map<String, dynamic>? params}) =>
      table[key] ?? key;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// [FakeLocalization]'ı service locator'a kaydet (öncekini değiştirerek).
void registerFakeLocalization([Map<String, String> table = const {}]) {
  if (sl.isRegistered<LocalizationService>()) {
    sl.unregister<LocalizationService>();
  }
  sl.registerSingleton<LocalizationService>(FakeLocalization(table));
}

/// Sabit saat: 2026-11-08 10:00 UTC.
DateTime fixedNow() => DateTime.utc(2026, 11, 8, 10);
