import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// PEM ekranlarının veri kapısı (seam). Servis mantığı (eşleme, toplama,
/// hata→boş) bu arayüz üzerinden çalışır → birim testlerde sahte bir backend
/// ile Supabase'siz sınanır. Varsayılan gerçekleme [SupabasePemBackend].
///
/// Tüm okumalar web `@ptb/energy-management` servisleriyle BİREBİR aynı
/// tablo/RPC/kolonları kullanır (EnergyCockpitService, LoadProfileService,
/// MvSavingsService, EnergyAlarmService, ConsumptionService). v1 salt-okunur:
/// hiçbir yazma yolu yok.
abstract class PemBackend {
  /// Oturumun kiracısı (yoksa null).
  String? get tenantId;

  /// Seçili organizasyon (yoksa null = tüm kiracı portföyü).
  String? get organizationId;

  /// `fn_energy_consumption_rollup(p_from, p_to, p_bucket, p_organization_id)`
  /// → (bucket_start, utility_type, total_kwh, total_cost, avg_peak_kw,
  /// reading_count). SECURITY INVOKER; RLS kapsamı uygular.
  Future<List<Map<String, dynamic>>> consumptionRollup({
    required String from,
    required String to,
    required String bucket,
    String? organizationId,
  });

  /// `fn_pms_energy_by_dimension(p_dim, p_from, p_to, p_bucket,
  /// p_organization_id)` → (label, total_kwh, total_cost, pct).
  Future<List<Map<String, dynamic>>> energyByDimension({
    required String dim,
    required String from,
    required String to,
    required String bucket,
    String? organizationId,
  });

  /// Açık enerji alarmı sayısı: `alarms` HEAD count, `code LIKE 'ENERGY_%'`,
  /// `status <> 'closed'` (+ tenant/org).
  Future<int> activeEnergyAlarmCount({String? tenantId, String? organizationId});

  /// En yeni `energy_readings_rollup.bucket_start` (tenant/org) — veri tazeliği.
  Future<String?> latestReadingAt({String? tenantId, String? organizationId});

  /// `sites` (id, name, code, city) — ada göre sıralı (+ tenant).
  Future<List<Map<String, dynamic>>> sites({String? tenantId});

  /// `fn_energy_site_benchmark(p_from, p_to, p_driver)` → saha sıralaması.
  Future<List<Map<String, dynamic>>> siteBenchmark({
    required String from,
    required String to,
    required String driver,
  });

  /// Bir sahanın günlük rollup satırları (`energy_readings_rollup`,
  /// bucket='day', [from, to]).
  Future<List<Map<String, dynamic>>> siteDailyRollup({
    required String siteId,
    required String from,
    required String to,
    String? tenantId,
  });

  /// Aktif sayaçlar (`energy_meters`); [siteId] verilirse o sahanınkiler.
  Future<List<Map<String, dynamic>>> meters({String? siteId, String? tenantId});

  /// `fn_energy_load_profile(p_site_id, p_from, p_to)` → haftanın günü profili.
  Future<List<Map<String, dynamic>>> loadProfile({
    String? siteId,
    required String from,
    required String to,
  });

  /// `fn_energy_consumption_anomalies(...)` → gün başına model artıkları.
  Future<List<Map<String, dynamic>>> consumptionAnomalies({
    required String siteId,
    required String baselineFrom,
    required String baselineTo,
    required String detectFrom,
    required String detectTo,
    required String driver,
    required num sigma,
  });

  /// Tetiklenen enerji alarmları (`alarms`, `code LIKE 'ENERGY_%'`, en yeni
  /// önce, [limit]).
  Future<List<Map<String, dynamic>>> energyAlarms(
      {String? tenantId, int limit = 50});

  /// `priorities` (id, name, code, color, level) — active, level sıralı.
  Future<List<Map<String, dynamic>>> priorities();
}

/// [PemBackend]'in Supabase gerçeklemesi.
class SupabasePemBackend implements PemBackend {
  SupabasePemBackend({SupabaseClient? supabase}) : _client = supabase;

  final SupabaseClient? _client;
  SupabaseClient get _sb => _client ?? sl<SupabaseClient>();

  static List<Map<String, dynamic>> _rows(dynamic res) =>
      ((res as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  @override
  String? get tenantId => sl.isRegistered<TenantService>()
      ? sl<TenantService>().currentTenantId
      : null;

  @override
  String? get organizationId => sl.isRegistered<OrganizationService>()
      ? sl<OrganizationService>().currentOrganizationId
      : null;

  @override
  Future<List<Map<String, dynamic>>> consumptionRollup({
    required String from,
    required String to,
    required String bucket,
    String? organizationId,
  }) async {
    final res = await _sb.rpc('fn_energy_consumption_rollup', params: {
      'p_from': from,
      'p_to': to,
      'p_bucket': bucket,
      'p_organization_id': organizationId,
    });
    return _rows(res);
  }

  @override
  Future<List<Map<String, dynamic>>> energyByDimension({
    required String dim,
    required String from,
    required String to,
    required String bucket,
    String? organizationId,
  }) async {
    final res = await _sb.rpc('fn_pms_energy_by_dimension', params: {
      'p_dim': dim,
      'p_from': from,
      'p_to': to,
      'p_bucket': bucket,
      'p_organization_id': organizationId,
    });
    return _rows(res);
  }

  @override
  Future<int> activeEnergyAlarmCount(
      {String? tenantId, String? organizationId}) async {
    var q = _sb
        .from('alarms')
        .select('id')
        .like('code', 'ENERGY_%')
        .neq('status', 'closed');
    if (tenantId != null) q = q.eq('tenant_id', tenantId);
    if (organizationId != null) q = q.eq('organization_id', organizationId);
    final res = await q.count(CountOption.exact);
    return res.count;
  }

  @override
  Future<String?> latestReadingAt(
      {String? tenantId, String? organizationId}) async {
    var q = _sb.from('energy_readings_rollup').select('bucket_start');
    if (tenantId != null) q = q.eq('tenant_id', tenantId);
    if (organizationId != null) q = q.eq('organization_id', organizationId);
    final res = await q.order('bucket_start', ascending: false).limit(1);
    final rows = _rows(res);
    return rows.isEmpty ? null : rows.first['bucket_start']?.toString();
  }

  @override
  Future<List<Map<String, dynamic>>> sites({String? tenantId}) async {
    var q = _sb.from('sites').select('id,name,code,city');
    if (tenantId != null) q = q.eq('tenant_id', tenantId);
    final res = await q.order('name', ascending: true);
    return _rows(res);
  }

  @override
  Future<List<Map<String, dynamic>>> siteBenchmark({
    required String from,
    required String to,
    required String driver,
  }) async {
    final res = await _sb.rpc('fn_energy_site_benchmark', params: {
      'p_from': from,
      'p_to': to,
      'p_driver': driver,
    });
    return _rows(res);
  }

  @override
  Future<List<Map<String, dynamic>>> siteDailyRollup({
    required String siteId,
    required String from,
    required String to,
    String? tenantId,
  }) async {
    var q = _sb
        .from('energy_readings_rollup')
        .select('meter_id,utility_type,bucket_start,consumption_kwh,'
            'peak_demand_kw,cost,reading_count')
        .eq('bucket', 'day')
        .eq('site_id', siteId)
        .gte('bucket_start', from)
        .lte('bucket_start', to);
    if (tenantId != null) q = q.eq('tenant_id', tenantId);
    final res = await q.order('bucket_start', ascending: true);
    return _rows(res);
  }

  @override
  Future<List<Map<String, dynamic>>> meters(
      {String? siteId, String? tenantId}) async {
    var q = _sb
        .from('energy_meters')
        .select('id,site_id,controller_id,utility_type,meter_role,unit,'
            'reading_kind,source,last_value,last_value_at,is_site_main')
        .eq('active', true);
    if (siteId != null) q = q.eq('site_id', siteId);
    if (tenantId != null) q = q.eq('tenant_id', tenantId);
    final res = await q.order('utility_type', ascending: true);
    return _rows(res);
  }

  @override
  Future<List<Map<String, dynamic>>> loadProfile({
    String? siteId,
    required String from,
    required String to,
  }) async {
    final res = await _sb.rpc('fn_energy_load_profile', params: {
      'p_site_id': siteId,
      'p_from': from,
      'p_to': to,
    });
    return _rows(res);
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
    final res = await _sb.rpc('fn_energy_consumption_anomalies', params: {
      'p_site_id': siteId,
      'p_baseline_from': baselineFrom,
      'p_baseline_to': baselineTo,
      'p_detect_from': detectFrom,
      'p_detect_to': detectTo,
      'p_driver': driver,
      'p_sigma': sigma,
    });
    return _rows(res);
  }

  @override
  Future<List<Map<String, dynamic>>> energyAlarms(
      {String? tenantId, int limit = 50}) async {
    var q = _sb
        .from('alarms')
        .select('id,name,code,description,category,status,start_time,'
            'priority_id,site_id')
        .like('code', 'ENERGY_%');
    if (tenantId != null) q = q.eq('tenant_id', tenantId);
    final res = await q.order('start_time', ascending: false).limit(limit);
    return _rows(res);
  }

  @override
  Future<List<Map<String, dynamic>>> priorities() async {
    final res = await _sb
        .from('priorities')
        .select('id,name,code,color,level')
        .eq('active', true)
        .order('level', ascending: true);
    return _rows(res);
  }
}
