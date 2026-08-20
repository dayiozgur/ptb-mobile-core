import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/iot_config.dart';
import '../storage/cache_manager.dart';
import '../utils/logger.dart';
import 'alarm_model.dart';
import 'alarm_history_model.dart';
import 'alarm_stats_model.dart';

/// Alarm Service
///
/// Aktif alarm ve resetlenmiş alarm verilerini yönetir.
/// DB tabloları:
///   - alarms: Sadece AKTİF alarmlar (tenant_id, organization_id, site_id, provider_id VAR)
///   - alarm_histories: Sadece RESETLENMİŞ alarmlar (tenant_id, organization_id, site_id, provider_id VAR)
///
/// Backend tarafından yönetilen senkronizasyon:
///   - Alarm aktif olduğunda → alarms tablosunda
///   - Alarm resetlendiğinde → alarm_histories tablosuna taşınır
///
/// Multi-Tenant İzolasyon:
///   - tenant_id: Zorunlu - tenant bazlı izolasyon
///   - organization_id: Opsiyonel - organization bazlı filtreleme
///   - site_id: Opsiyonel - site bazlı filtreleme
///   - provider_id: Opsiyonel - provider bazlı filtreleme
///
/// Description Kaynağı:
///   - alarms.description / alarm_histories.description: Doğrudan tabloda saklanır
///   - variable_id → variables.description: Variable ile ilişkili açıklama
///   Supabase JOIN ile variable description'ı da çekilebilir.
class AlarmService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  // Multi-Tenant İzolasyon Context
  String? _currentTenantId;
  String? _currentOrganizationId;
  String? _currentSiteId;

  final _alarmsController = StreamController<List<Alarm>>.broadcast();
  final _historyController = StreamController<List<AlarmHistory>>.broadcast();

  AlarmService({
    required SupabaseClient supabase,
    required CacheManager cacheManager,
  })  : _supabase = supabase,
        _cacheManager = cacheManager;

  // ============================================
  // GETTERS
  // ============================================

  Stream<List<Alarm>> get alarmsStream => _alarmsController.stream;
  Stream<List<AlarmHistory>> get historyStream => _historyController.stream;

  // ============================================
  // MULTI-TENANT ISOLATION CONTEXT
  // ============================================

  /// Tenant context ayarla - zorunlu izolasyon katmanı
  void setTenant(String tenantId) {
    _currentTenantId = tenantId;
  }

  /// Tenant context temizle
  void clearTenant() {
    _currentTenantId = null;
  }

  /// Organization context ayarla - opsiyonel izolasyon katmanı
  void setOrganization(String organizationId) {
    _currentOrganizationId = organizationId;
  }

  /// Organization context temizle
  void clearOrganization() {
    _currentOrganizationId = null;
  }

  /// Site context ayarla - opsiyonel izolasyon katmanı
  void setSite(String siteId) {
    _currentSiteId = siteId;
  }

  /// Site context temizle
  void clearSite() {
    _currentSiteId = null;
  }

  /// Tüm izolasyon context'lerini temizle
  void clearAllContexts() {
    _currentTenantId = null;
    _currentOrganizationId = null;
    _currentSiteId = null;
  }

  /// Mevcut tenant ID
  String? get currentTenantId => _currentTenantId;

  /// Mevcut organization ID
  String? get currentOrganizationId => _currentOrganizationId;

  /// Mevcut site ID
  String? get currentSiteId => _currentSiteId;

  // ============================================
  // SERVER-SIDE KPI / AGGREGATION HELPERS
  // ============================================

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  /// Zaman aralığı yardımcıları (RPC p_from/p_to için ISO string)
  String _rangeFrom(int days) =>
      DateTime.now().subtract(Duration(days: days)).toIso8601String();
  String _rangeTo() => DateTime.now().toIso8601String();

  /// RPC agregasyon yolunu kullanmak güvenli mi?
  ///
  /// Sunucu RPC'leri tenant (+opsiyonel organization) kapsamlıdır; site/
  /// controller/provider daraltması YAPAMAZ. Bu daraltmalar aktifken RPC
  /// yanlış (tenant-geneli) sonuç verir → bu durumda client-side yola düşülür.
  bool _canUseTenantRpc({
    String? controllerId,
    String? siteId,
    String? providerId,
  }) {
    return _currentTenantId != null &&
        controllerId == null &&
        siteId == null &&
        providerId == null &&
        _currentSiteId == null;
  }

  /// Server-side KPI özeti (fn_pms_kpi_summary)
  ///
  /// Tüm sayımlar/MTTR sunucuda hesaplanır. İmza sürüklenmesinde RPC hata
  /// fırlatır (sessiz 0 yerine). tenant_id yoksa boş özet döner.
  Future<AlarmKpiSummary> getKpiSummary({
    int days = IoTConfig.defaultAlarmTimelineDays,
  }) async {
    if (_currentTenantId == null) return AlarmKpiSummary.empty;

    final effectiveDays = IoTConfig.clampDaysRange(days);
    final response = await _supabase.rpc('fn_pms_kpi_summary', params: {
      'p_tenant_id': _currentTenantId,
      'p_from': _rangeFrom(effectiveDays),
      'p_to': _rangeTo(),
    });

    final rows = response as List;
    if (rows.isEmpty) return AlarmKpiSummary.empty;
    return AlarmKpiSummary.fromRow(
        Map<String, dynamic>.from(rows.first as Map));
  }

  /// Server-side controller uptime / kullanılabilirlik (fn_pms_controller_uptime)
  ///
  /// Tenant kapsamlı; agregasyon sunucuda yapılır. İmza sürüklenmesinde RPC
  /// hata fırlatır (sessiz boş yerine). tenant_id yoksa boş liste döner.
  Future<List<ControllerUptime>> getControllerUptime({
    int days = IoTConfig.defaultAlarmTimelineDays,
  }) async {
    if (_currentTenantId == null) return const [];

    final effectiveDays = IoTConfig.clampDaysRange(days);
    final response =
        await _supabase.rpc('fn_pms_controller_uptime', params: {
      'p_tenant_id': _currentTenantId,
      'p_from': _rangeFrom(effectiveDays),
      'p_to': _rangeTo(),
    });

    return (response as List)
        .map((e) =>
            ControllerUptime.fromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Server-side provider sağlık skorları (fn_pms_provider_health)
  ///
  /// Tenant kapsamlı; agregasyon sunucuda yapılır. İmza sürüklenmesinde RPC
  /// hata fırlatır (sessiz boş yerine). tenant_id yoksa boş liste döner.
  Future<List<ProviderHealth>> getProviderHealth({
    int days = IoTConfig.defaultAlarmTimelineDays,
  }) async {
    if (_currentTenantId == null) return const [];

    final effectiveDays = IoTConfig.clampDaysRange(days);
    final response = await _supabase.rpc('fn_pms_provider_health', params: {
      'p_tenant_id': _currentTenantId,
      'p_from': _rangeFrom(effectiveDays),
      'p_to': _rangeTo(),
    });

    return (response as List)
        .map((e) =>
            ProviderHealth.fromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ============================================
  // ALARM ACTIONS (server RPC - RLS/yetki sunucuda)
  // ============================================

  /// Alarmı onayla (acknowledge) - fn_pms_alarm_acknowledge
  ///
  /// Yetki/tenant kontrolü sunucuda yapılır. Ağ/imza hatası fırlatır;
  /// iş kuralı reddi (already_acknowledged_or_closed vb.) `false` döner.
  Future<bool> acknowledgeAlarm(String alarmId) async {
    final result = await _supabase
        .rpc('fn_pms_alarm_acknowledge', params: {'p_alarm_id': alarmId});
    return _actionSucceeded(result);
  }

  /// Alarmı resetle (kapat) - fn_pms_alarm_reset
  Future<bool> resetAlarm(String alarmId) async {
    final result = await _supabase
        .rpc('fn_pms_alarm_reset', params: {'p_alarm_id': alarmId});
    return _actionSucceeded(result);
  }

  /// Alarmı inhibit et / kaldır - fn_pms_alarm_inhibit
  Future<bool> inhibitAlarm(String alarmId, {bool inhibit = true}) async {
    final result = await _supabase.rpc('fn_pms_alarm_inhibit',
        params: {'p_alarm_id': alarmId, 'p_inhibit': inhibit});
    return _actionSucceeded(result);
  }

  bool _actionSucceeded(dynamic rpcResult) {
    if (rpcResult is Map) {
      return rpcResult['success'] == true;
    }
    // fn_alarm_acknowledge gibi boolean dönen varyantlar için
    if (rpcResult is bool) return rpcResult;
    return false;
  }

  // ============================================
  // ACTIVE ALARMS
  // ============================================

  /// Aktif alarmları getir
  ///
  /// alarms tablosu üzerinden çalışır (sadece aktif alarmlar burada).
  /// Multi-tenant izolasyon: tenant_id, organization_id, site_id ile filtrelenir.
  /// Backend, alarm resetlendiğinde alarms → alarm_histories taşımasını yapar.
  ///
  /// [includeVariable]: true ise variable bilgisini JOIN ile çeker (description için)
  Future<List<Alarm>> getActiveAlarms({
    String? controllerId,
    String? variableId,
    bool includeVariable = false,
  }) async {
    try {
      // Variable JOIN opsiyonel: variable description'ı çekmek için
      final selectClause = includeVariable
          ? '*, variable:variables(id, name, description, unit)'
          : '*';

      // alarms tablosu zaten sadece aktif alarmları içerir (backend tarafından yönetilen)
      var query = _supabase
          .from('alarms')
          .select(selectClause);

      // Multi-Tenant İzolasyon Filtreleri
      // NOT: alarms tablosunda tenant_id NULL olabilir, bu yüzden
      // tenant_id varsa filtrele, yoksa tüm kayıtları getir
      if (_currentTenantId != null) {
        query = query.or('tenant_id.eq.$_currentTenantId,tenant_id.is.null');
      }

      if (_currentSiteId != null) {
        query = query.eq('site_id', _currentSiteId!);
      }

      // Ek filtreler
      if (controllerId != null) {
        query = query.eq('controller_id', controllerId);
      }

      if (variableId != null) {
        query = query.eq('variable_id', variableId);
      }

      final response = await query.order('start_time', ascending: false);
      final alarms = <Alarm>[];
      for (final e in (response as List)) {
        try {
          alarms.add(Alarm.fromJson(e as Map<String, dynamic>));
        } catch (parseError) {
          Logger.warning('Failed to parse alarm: $parseError');
        }
      }

      _alarmsController.add(alarms);
      return alarms;
    } catch (e, stackTrace) {
      // Bir monitoring uygulamasında başarısız yükleme "alarm yok" gibi
      // gösterilmemeli — sessiz boş-liste yerine hatayı yukarı ilet; tüm
      // çağıranlar try/catch ile hata-durumu/graceful-degrade uyguluyor.
      Logger.error('Failed to get active alarms', e, stackTrace);
      rethrow;
    }
  }

  /// Aktif alarmları variable description ile birlikte getir
  Future<List<Alarm>> getActiveAlarmsWithVariable({
    String? controllerId,
    String? variableId,
  }) async {
    return getActiveAlarms(
      controllerId: controllerId,
      variableId: variableId,
      includeVariable: true,
    );
  }

  /// Controller ID listesi ile aktif alarmları getir
  Future<List<Alarm>> getActiveAlarmsByControllers(
      List<String> controllerIds) async {
    if (controllerIds.isEmpty) return [];

    try {
      // alarms tablosu zaten sadece aktif alarmları içerir
      // Variable JOIN: description bilgisini çekmek için
      var query = _supabase
          .from('alarms')
          .select('*, variable:variables(id, name, description, unit)')
          .inFilter('controller_id', controllerIds);

      // Multi-Tenant İzolasyon: tenant_id NULL olabilir
      if (_currentTenantId != null) {
        query = query.or('tenant_id.eq.$_currentTenantId,tenant_id.is.null');
      }

      if (_currentSiteId != null) {
        query = query.eq('site_id', _currentSiteId!);
      }

      final response = await query.order('start_time', ascending: false);

      final alarms = <Alarm>[];
      for (final e in (response as List)) {
        try {
          alarms.add(Alarm.fromJson(e as Map<String, dynamic>));
        } catch (parseError) {
          Logger.warning('Failed to parse alarm: $parseError');
        }
      }

      return alarms;
    } catch (e, stackTrace) {
      // Hatayı gizleme — çağıran (provider/site landing) kendi try/catch'iyle
      // graceful-degrade uyguluyor; false-empty monitoring için yanıltıcı.
      Logger.error('Failed to get alarms by controllers', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // ALARM HISTORY
  // ============================================

  /// Resetlenmiş alarm geçmişini getir (alarm_histories tablosu)
  ///
  /// alarm_histories tablosu sadece resetlenmiş alarmları içerir.
  /// tenant_id, site_id, provider_id ile filtreleme yapılabilir.
  ///
  /// [includeVariable]: true ise variable bilgisini JOIN ile çeker (description için)
  Future<List<AlarmHistory>> getHistory({
    String? siteId,
    String? providerId,
    String? controllerId,
    String? variableId,
    int limit = 50,
    bool forceRefresh = false,
    bool includeVariable = false,
  }) async {
    final filterKey = siteId ?? providerId ?? controllerId ?? 'all';
    final cacheKey = 'alarm_history_${_currentTenantId}_${filterKey}_v${includeVariable ? 1 : 0}';

    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        final history = cached
            .map((e) => AlarmHistory.fromJson(e as Map<String, dynamic>))
            .toList();
        _historyController.add(history);
        return history;
      }
    }

    try {
      // Variable JOIN opsiyonel: variable description'ı çekmek için
      final selectClause = includeVariable
          ? '*, variable:variables(id, name, description, unit)'
          : '*';

      var query = _supabase
          .from('alarm_histories')
          .select(selectClause);

      // Multi-Tenant İzolasyon: tenant_id veya NULL
      if (_currentTenantId != null) {
        query = query.or('tenant_id.eq.$_currentTenantId,tenant_id.is.null');
      }

      if (_currentSiteId != null) {
        query = query.eq('site_id', _currentSiteId!);
      }

      // Ek filtreler (parametre olarak geçilenler)
      if (siteId != null) {
        query = query.eq('site_id', siteId);
      }

      if (providerId != null) {
        query = query.eq('provider_id', providerId);
      }

      if (controllerId != null) {
        query = query.eq('controller_id', controllerId);
      }

      if (variableId != null) {
        query = query.eq('variable_id', variableId);
      }

      // start_time ile sırala (created_at NULL olabilir DB'de)
      final response = await query
          .order('start_time', ascending: false)
          .limit(limit);

      final history = <AlarmHistory>[];
      for (final e in (response as List)) {
        try {
          history.add(AlarmHistory.fromJson(e as Map<String, dynamic>));
        } catch (parseError) {
          Logger.warning('Failed to parse alarm history: $parseError');
        }
      }

      await _cacheManager.set(
        cacheKey,
        history.map((e) => e.toJson()).toList(),
        ttl: const Duration(minutes: 5),
      );

      _historyController.add(history);
      return history;
    } catch (e, stackTrace) {
      Logger.error('Failed to get alarm history', e, stackTrace);
      return [];
    }
  }

  /// Alarm geçmişini variable description ile birlikte getir
  Future<List<AlarmHistory>> getHistoryWithVariable({
    String? siteId,
    String? providerId,
    String? controllerId,
    String? variableId,
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    return getHistory(
      siteId: siteId,
      providerId: providerId,
      controllerId: controllerId,
      variableId: variableId,
      limit: limit,
      forceRefresh: forceRefresh,
      includeVariable: true,
    );
  }

  /// Site bazlı resetlenmiş alarm sayısı (alarm_histories tablosu)
  ///
  /// NOT: Aktif alarmlar için alarms tablosu kullanılır ve orada site_id yok.
  /// Bu metod sadece resetlenmiş alarm geçmişi için kullanılabilir.
  /// getHistory() metodu ile tutarlı filtreler kullanır (tenant_id dahil).
  Future<int> getResetAlarmCountBySite(String siteId) async {
    try {
      var query = _supabase
          .from('alarm_histories')
          .select('id')
          .eq('site_id', siteId);

      // tenant_id filtresi - getHistory() ile tutarlı
      if (_currentTenantId != null) {
        query = query.eq('tenant_id', _currentTenantId!);
      }

      final response = await query;
      return (response as List).length;
    } catch (e, stackTrace) {
      // Drift-loud: sessizce 0 döndürme. Gerçek hata (imza/RLS/ağ) yüzeye
      // çıksın; çağıran (site listesi/harita) kendi try/catch'inde ele alır.
      Logger.error('Failed to get reset alarm count for site', e, stackTrace);
      rethrow;
    }
  }

  /// Provider bazlı resetlenmiş alarm sayısı (alarm_histories tablosu)
  ///
  /// NOT: Aktif alarmlar için alarms tablosu kullanılır ve orada provider_id yok.
  /// Bu metod sadece resetlenmiş alarm geçmişi için kullanılabilir.
  /// getHistory() metodu ile tutarlı filtreler kullanır (tenant_id dahil).
  Future<int> getResetAlarmCountByProvider(String providerId) async {
    try {
      var query = _supabase
          .from('alarm_histories')
          .select('id')
          .eq('provider_id', providerId);

      // tenant_id filtresi - getHistory() ile tutarlı
      if (_currentTenantId != null) {
        query = query.eq('tenant_id', _currentTenantId!);
      }

      final response = await query;
      return (response as List).length;
    } catch (e, stackTrace) {
      // Drift-loud: sessizce 0 döndürme. Gerçek hata yüzeye çıksın.
      Logger.error(
          'Failed to get reset alarm count for provider', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // RESET ALARMS (alarm_histories tablosu)
  // ============================================

  /// Resetlenmiş alarmları getir (alarm_histories tablosu)
  ///
  /// alarm_histories tablosu sadece resetlenmiş alarmları içerir.
  /// Backend, alarm resetlendiğinde alarms → alarm_histories taşıması yapar.
  ///
  /// Son [days] gün içindeki resetlenmiş alarmları döner (max [IoTConfig.maxDaysRange] gün).
  /// created_at üzerinden zaman filtresi (start_time NULL olabilir).
  /// Sıralama: created_at DESC
  Future<List<AlarmHistory>> getResetAlarms({
    String? controllerId,
    String? siteId,
    String? providerId,
    int days = IoTConfig.defaultResetAlarmDays,
    int limit = IoTConfig.defaultListLimit,
    bool forceRefresh = false,
  }) async {
    final effectiveDays = IoTConfig.clampDaysRange(days);
    final filterKey = controllerId ?? siteId ?? providerId ?? 'all';
    final cacheKey =
        'reset_alarms_${_currentTenantId}_${filterKey}_${effectiveDays}d';

    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        return cached
            .map((e) => AlarmHistory.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }

    try {
      final since = DateTime.now()
          .subtract(Duration(days: effectiveDays))
          .toIso8601String();

      // alarm_histories tablosu zaten sadece resetlenmiş alarmları içerir
      // DB'de created_at NULL, start_time dolu - start_time üzerinden filtrele
      // Variable JOIN: description bilgisini çekmek için
      var query = _supabase
          .from('alarm_histories')
          .select('*, variable:variables(id, name, description, unit)')
          .gte('start_time', since);

      // Multi-Tenant İzolasyon: tenant_id veya NULL
      if (_currentTenantId != null) {
        query = query.or('tenant_id.eq.$_currentTenantId,tenant_id.is.null');
      }
      if (controllerId != null) {
        query = query.eq('controller_id', controllerId);
      }
      if (siteId != null) {
        query = query.eq('site_id', siteId);
      }
      if (providerId != null) {
        query = query.eq('provider_id', providerId);
      }

      final response = await query
          .order('start_time', ascending: false)
          .limit(limit);

      final results = <AlarmHistory>[];
      for (final e in (response as List)) {
        try {
          results.add(AlarmHistory.fromJson(e as Map<String, dynamic>));
        } catch (parseError) {
          Logger.warning('Failed to parse reset alarm: $parseError');
        }
      }

      await _cacheManager.set(
        cacheKey,
        results.map((e) => e.toJson()).toList(),
        ttl: const Duration(minutes: 5),
      );

      return results;
    } catch (e, stackTrace) {
      Logger.error('Failed to get reset alarms', e, stackTrace);
      return [];
    }
  }

  // ============================================
  // ALARM TIMELINE (alarm_histories tablosu)
  // ============================================

  /// Resetlenmiş alarm zaman çizelgesi - günlük gruplandırılmış alarm sayıları
  ///
  /// alarm_histories tablosundan son [days] gün (max [IoTConfig.maxDaysRange]) verileri çeker.
  /// alarm_histories sadece resetlenmiş alarmları içerir.
  /// client-side günlük gruplandırma yapar.
  /// Her gün için priority bazlı ayrıntı içerir.
  /// created_at üzerinden filtrele (start_time NULL olabilir).
  Future<List<AlarmTimelineEntry>> getAlarmTimeline({
    String? controllerId,
    String? siteId,
    String? providerId,
    int days = IoTConfig.defaultAlarmTimelineDays,
    bool forceRefresh = false,
  }) async {
    final effectiveDays = IoTConfig.clampDaysRange(days);
    final filterKey = controllerId ?? siteId ?? providerId ?? 'all';
    final cacheKey =
        'alarm_timeline_${_currentTenantId}_${filterKey}_${effectiveDays}d';

    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        return cached.map((e) {
          final map = e as Map<String, dynamic>;
          return AlarmTimelineEntry(
            date: DateTime.parse(map['date'] as String),
            totalCount: map['totalCount'] as int,
            countByPriority:
                (map['countByPriority'] as Map<String, dynamic>?)
                    ?.map((k, v) => MapEntry(k, v as int)) ??
                {},
          );
        }).toList();
      }
    }

    // Server-side yol: daraltma yoksa fn_pms_alarm_trend günlük gruplamayı
    // sunucuda yapar (client-side satır gruplaması yerine).
    if (_canUseTenantRpc(
        controllerId: controllerId, siteId: siteId, providerId: providerId)) {
      final response = await _supabase.rpc('fn_pms_alarm_trend', params: {
        'p_tenant_id': _currentTenantId,
        'p_bucket': 'day',
        'p_from': _rangeFrom(effectiveDays),
        'p_to': _rangeTo(),
      });

      // period (YYYY-MM-DD) -> cnt
      final totalByDate = <String, int>{};
      for (final r in (response as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        final period = m['period'] as String?;
        if (period != null) totalByDate[period] = _asInt(m['cnt']);
      }

      // Boş günleri de dahil et (mevcut davranışla aynı)
      final entries = <AlarmTimelineEntry>[];
      final now = DateTime.now();
      for (var i = effectiveDays - 1; i >= 0; i--) {
        final day =
            DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
        final dateKey =
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        entries.add(AlarmTimelineEntry(
          date: day,
          totalCount: totalByDate[dateKey] ?? 0,
          countByPriority: const {},
        ));
      }

      await _cacheManager.set(
        cacheKey,
        entries
            .map((e) => {
                  'date': e.date.toIso8601String(),
                  'totalCount': e.totalCount,
                  'countByPriority': e.countByPriority,
                })
            .toList(),
        ttl: const Duration(minutes: 5),
      );

      return entries;
    }

    try {
      final since = DateTime.now()
          .subtract(Duration(days: effectiveDays))
          .toIso8601String();

      // DB'de created_at NULL - start_time üzerinden filtrele
      var query = _supabase
          .from('alarm_histories')
          .select('id,start_time,priority_id')
          .gte('start_time', since);

      // Multi-Tenant İzolasyon: tenant_id veya NULL
      if (_currentTenantId != null) {
        query = query.or('tenant_id.eq.$_currentTenantId,tenant_id.is.null');
      }
      if (controllerId != null) {
        query = query.eq('controller_id', controllerId);
      }
      if (siteId != null) {
        query = query.eq('site_id', siteId);
      }
      if (providerId != null) {
        query = query.eq('provider_id', providerId);
      }

      final response =
          await query.order('start_time', ascending: true);

      // Client-side günlük gruplandırma
      final dailyMap = <String, Map<String, int>>{};
      final dailyTotal = <String, int>{};

      for (final e in (response as List)) {
        final row = e as Map<String, dynamic>;
        final timeStr = row['start_time'] as String?;
        if (timeStr == null) continue;

        final date = DateTime.tryParse(timeStr);
        if (date == null) continue;

        final dateKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final priorityId = row['priority_id'] as String? ?? 'unknown';

        dailyTotal[dateKey] = (dailyTotal[dateKey] ?? 0) + 1;
        dailyMap[dateKey] ??= {};
        dailyMap[dateKey]![priorityId] =
            (dailyMap[dateKey]![priorityId] ?? 0) + 1;
      }

      // Boş günleri de dahil et
      final entries = <AlarmTimelineEntry>[];
      final now = DateTime.now();
      for (var i = effectiveDays - 1; i >= 0; i--) {
        final day = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: i));
        final dateKey =
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

        entries.add(AlarmTimelineEntry(
          date: day,
          totalCount: dailyTotal[dateKey] ?? 0,
          countByPriority: dailyMap[dateKey] ?? {},
        ));
      }

      await _cacheManager.set(
        cacheKey,
        entries
            .map((e) => {
                  'date': e.date.toIso8601String(),
                  'totalCount': e.totalCount,
                  'countByPriority': e.countByPriority,
                })
            .toList(),
        ttl: const Duration(minutes: 5),
      );

      return entries;
    } catch (e, stackTrace) {
      // Drift-loud: sessiz boş liste yerine hata yüzeye çıksın.
      Logger.error('Failed to get alarm timeline', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // ALARM DISTRIBUTION (alarm_histories tablosu)
  // ============================================

  /// Alarm dağılımı - aktif vs reset
  ///
  /// Aktif alarmlar: alarms tablosundan (sadece aktif alarmlar bu tabloda)
  /// Resetlenmiş alarmlar: alarm_histories tablosundan (sadece resetli alarmlar)
  ///
  /// activeCount: alarms tablosu (tüm kayıtlar aktif)
  /// resetCount: alarm_histories (reset_time NOT NULL, son N gün)
  /// acknowledgedCount: alarms tablosundan (local_acknowledge_time NOT NULL)
  ///
  /// NOT: alarms tablosunda tenant_id yok, controller_id ile filtrelenir.
  Future<AlarmDistribution> getAlarmDistribution({
    String? controllerId,
    String? siteId,
    int days = IoTConfig.defaultAlarmDistributionDays,
    bool forceRefresh = false,
  }) async {
    final effectiveDays = IoTConfig.clampDaysRange(days);
    final filterKey = controllerId ?? siteId ?? 'all';
    final cacheKey =
        'alarm_dist_${_currentTenantId}_${filterKey}_${effectiveDays}d';

    if (!forceRefresh) {
      final cached = await _cacheManager.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        return AlarmDistribution(
          activeCount: cached['activeCount'] as int,
          resetCount: cached['resetCount'] as int,
          acknowledgedCount: cached['acknowledgedCount'] as int? ?? 0,
          activeByPriority: (cached['activeByPriority'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as int)) ?? {},
          resetByPriority: (cached['resetByPriority'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as int)) ?? {},
        );
      }
    }

    // Server-side agregasyon yolu: site/controller daraltması yoksa ve tenant
    // biliniyorsa fn_pms_kpi_summary + fn_pms_alarm_priority_breakdown kullan.
    if (_canUseTenantRpc(controllerId: controllerId, siteId: siteId)) {
      final since = _rangeFrom(effectiveDays);
      final until = _rangeTo();

      final kpiResp = await _supabase.rpc('fn_pms_kpi_summary', params: {
        'p_tenant_id': _currentTenantId,
        'p_from': since,
        'p_to': until,
      });
      final kpiRows = kpiResp as List;
      final kpi = kpiRows.isNotEmpty
          ? AlarmKpiSummary.fromRow(Map<String, dynamic>.from(kpiRows.first as Map))
          : AlarmKpiSummary.empty;

      // Reset alarm priority dağılımı (alarm_histories)
      final prioResp =
          await _supabase.rpc('fn_pms_alarm_priority_breakdown', params: {
        'p_tenant_id': _currentTenantId,
        'p_from': since,
        'p_to': until,
        'p_organization_id': _currentOrganizationId,
      });
      final resetByPriority = <String, int>{};
      for (final r in (prioResp as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        final pid = m['priority_id'] as String?;
        if (pid != null) resetByPriority[pid] = _asInt(m['cnt']);
      }

      // Onaylı aktif alarm sayısı (küçük, filtreli sorgu - RPC'de yok)
      final ackResp = await _supabase
          .from('alarms')
          .select('id')
          .not('local_acknowledge_time', 'is', null)
          .or('tenant_id.eq.$_currentTenantId,tenant_id.is.null');
      final acknowledgedCount = (ackResp as List).length;

      final distribution = AlarmDistribution(
        activeCount: kpi.activeAlarms,
        resetCount: kpi.resolvedAlarms,
        acknowledgedCount: acknowledgedCount,
        activeByPriority: const {},
        resetByPriority: resetByPriority,
      );

      await _cacheManager.set(
        cacheKey,
        {
          'activeCount': distribution.activeCount,
          'resetCount': distribution.resetCount,
          'acknowledgedCount': distribution.acknowledgedCount,
          'activeByPriority': distribution.activeByPriority,
          'resetByPriority': distribution.resetByPriority,
        },
        ttl: const Duration(minutes: 5),
      );

      return distribution;
    }

    try {
      final since = DateTime.now()
          .subtract(Duration(days: effectiveDays))
          .toIso8601String();

      // --- Aktif alarm sayısı ve priority dağılımı (alarms tablosu) ---
      var activeQuery = _supabase
          .from('alarms')
          .select('id,priority_id');

      // Multi-Tenant İzolasyon: tenant_id veya NULL
      if (_currentTenantId != null) {
        activeQuery = activeQuery.or('tenant_id.eq.$_currentTenantId,tenant_id.is.null');
      }

      if (_currentSiteId != null) {
        activeQuery = activeQuery.eq('site_id', _currentSiteId!);
      }

      if (controllerId != null) {
        activeQuery = activeQuery.eq('controller_id', controllerId);
      }

      if (siteId != null) {
        activeQuery = activeQuery.eq('site_id', siteId);
      }

      final activeResponse = await activeQuery;
      final activeList = activeResponse as List;
      final activeCount = activeList.length;

      // Priority bazlı aktif alarm dağılımı
      final activeByPriority = <String, int>{};
      for (final row in activeList) {
        final priorityId = (row as Map<String, dynamic>)['priority_id'] as String?;
        if (priorityId != null) {
          activeByPriority[priorityId] = (activeByPriority[priorityId] ?? 0) + 1;
        }
      }

      // --- Onaylı aktif alarm sayısı (alarms tablosu) ---
      var ackQuery = _supabase
          .from('alarms')
          .select('id')
          .not('local_acknowledge_time', 'is', null);

      if (_currentTenantId != null) {
        ackQuery = ackQuery.or('tenant_id.eq.$_currentTenantId,tenant_id.is.null');
      }

      if (_currentSiteId != null) {
        ackQuery = ackQuery.eq('site_id', _currentSiteId!);
      }

      if (controllerId != null) {
        ackQuery = ackQuery.eq('controller_id', controllerId);
      }

      if (siteId != null) {
        ackQuery = ackQuery.eq('site_id', siteId);
      }

      final ackResponse = await ackQuery;
      final acknowledgedCount = (ackResponse as List).length;

      // --- Resetli alarm sayısı ve priority dağılımı (alarm_histories tablosu: son N gün) ---
      // DB'de created_at NULL - start_time üzerinden filtrele
      var resetQuery = _supabase
          .from('alarm_histories')
          .select('id,priority_id')
          .gte('start_time', since);

      if (_currentTenantId != null) {
        resetQuery = resetQuery.or('tenant_id.eq.$_currentTenantId,tenant_id.is.null');
      }

      if (_currentSiteId != null) {
        resetQuery = resetQuery.eq('site_id', _currentSiteId!);
      }

      if (controllerId != null) {
        resetQuery = resetQuery.eq('controller_id', controllerId);
      }

      if (siteId != null) {
        resetQuery = resetQuery.eq('site_id', siteId);
      }

      final resetResponse = await resetQuery;
      final resetList = resetResponse as List;
      final resetCount = resetList.length;

      // Priority bazlı reset alarm dağılımı
      final resetByPriority = <String, int>{};
      for (final row in resetList) {
        final priorityId = (row as Map<String, dynamic>)['priority_id'] as String?;
        if (priorityId != null) {
          resetByPriority[priorityId] = (resetByPriority[priorityId] ?? 0) + 1;
        }
      }

      final distribution = AlarmDistribution(
        activeCount: activeCount,
        resetCount: resetCount,
        acknowledgedCount: acknowledgedCount,
        activeByPriority: activeByPriority,
        resetByPriority: resetByPriority,
      );

      await _cacheManager.set(
        cacheKey,
        {
          'activeCount': activeCount,
          'resetCount': resetCount,
          'acknowledgedCount': acknowledgedCount,
          'activeByPriority': activeByPriority,
          'resetByPriority': resetByPriority,
        },
        ttl: const Duration(minutes: 5),
      );

      return distribution;
    } catch (e, stackTrace) {
      // Drift-loud: sessiz sıfır dashboard yerine hata yüzeye çıksın.
      Logger.error('Failed to get alarm distribution', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // ALARM KPI STATS
  // ============================================

  /// MTTR (Mean Time To Resolve) istatistikleri
  ///
  /// alarm_histories tablosundan end_time NOT NULL kayıtlar üzerinden hesaplanır.
  /// end_time - start_time ortalaması genel + priority bazlı + haftalık trend.
  Future<AlarmMttrStats> getMttrStats({
    int days = IoTConfig.defaultAlarmTimelineDays,
    String? controllerId,
    String? siteId,
    String? providerId,
    bool forceRefresh = false,
  }) async {
    final effectiveDays = IoTConfig.clampDaysRange(days);
    final filterKey = controllerId ?? siteId ?? providerId ?? 'all';
    final cacheKey =
        'alarm_mttr_${_currentTenantId}_${filterKey}_${effectiveDays}d';

    if (!forceRefresh) {
      final cached = await _cacheManager.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        return _parseMttrStatsFromCache(cached);
      }
    }

    // Server-side yol: daraltma yoksa fn_pms_kpi_summary genel MTTR'ı sunucuda
    // hesaplar (avg_resolution_hours). Priority-bazlı/haftalık trend tüketilmiyor.
    if (_canUseTenantRpc(
        controllerId: controllerId, siteId: siteId, providerId: providerId)) {
      final response = await _supabase.rpc('fn_pms_kpi_summary', params: {
        'p_tenant_id': _currentTenantId,
        'p_from': _rangeFrom(effectiveDays),
        'p_to': _rangeTo(),
      });
      final rows = response as List;
      final kpi = rows.isNotEmpty
          ? AlarmKpiSummary.fromRow(Map<String, dynamic>.from(rows.first as Map))
          : AlarmKpiSummary.empty;

      final overallMttr = Duration(
          milliseconds: (kpi.avgResolutionHours * 3600 * 1000).round());
      final stats = AlarmMttrStats(
        overallMttr: overallMttr,
        totalAlarmCount: kpi.resolvedAlarms,
      );

      await _cacheManager.set(
        cacheKey,
        {
          'overallMttrMs': overallMttr.inMilliseconds,
          'totalAlarmCount': kpi.resolvedAlarms,
          'mttrByPriority': const <String, int>{},
          'trend': const <dynamic>[],
        },
        ttl: const Duration(minutes: 5),
      );

      return stats;
    }

    try {
      final since = DateTime.now()
          .subtract(Duration(days: effectiveDays))
          .toIso8601String();

      var query = _supabase
          .from('alarm_histories')
          .select('start_time,end_time,priority_id')
          .not('end_time', 'is', null)
          .gte('start_time', since);

      if (_currentTenantId != null) {
        query = query.or('tenant_id.eq.$_currentTenantId,tenant_id.is.null');
      }
      if (controllerId != null) {
        query = query.eq('controller_id', controllerId);
      }
      if (siteId != null) {
        query = query.eq('site_id', siteId);
      }
      if (providerId != null) {
        query = query.eq('provider_id', providerId);
      }

      final response = await query.order('start_time', ascending: true);
      final rows = response as List;

      // Genel MTTR hesaplama
      int totalDurationMs = 0;
      int totalCount = 0;
      final priorityDurations = <String, List<int>>{};
      final weeklyData = <String, List<int>>{}; // weekKey → durations list

      for (final row in rows) {
        final r = row as Map<String, dynamic>;
        final startStr = r['start_time'] as String?;
        final endStr = r['end_time'] as String?;
        if (startStr == null || endStr == null) continue;

        final start = DateTime.tryParse(startStr);
        final end = DateTime.tryParse(endStr);
        if (start == null || end == null) continue;

        final durationMs = end.difference(start).inMilliseconds;
        if (durationMs < 0) continue;

        totalDurationMs += durationMs;
        totalCount++;

        final priorityId = r['priority_id'] as String? ?? 'unknown';
        priorityDurations.putIfAbsent(priorityId, () => []).add(durationMs);

        // Haftalık gruplama
        final weekStart = start.subtract(Duration(days: start.weekday - 1));
        final weekKey =
            '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
        weeklyData.putIfAbsent(weekKey, () => []).add(durationMs);
      }

      final overallMttr = totalCount > 0
          ? Duration(milliseconds: totalDurationMs ~/ totalCount)
          : Duration.zero;

      final mttrByPriority = <String, Duration>{};
      for (final entry in priorityDurations.entries) {
        final avg = entry.value.reduce((a, b) => a + b) ~/ entry.value.length;
        mttrByPriority[entry.key] = Duration(milliseconds: avg);
      }

      // Haftalık trend
      final sortedWeeks = weeklyData.keys.toList()..sort();
      final trend = sortedWeeks.map((weekKey) {
        final durations = weeklyData[weekKey]!;
        final avg = durations.reduce((a, b) => a + b) ~/ durations.length;
        return MttrTrendEntry(
          date: DateTime.parse(weekKey),
          avgMttr: Duration(milliseconds: avg),
          alarmCount: durations.length,
        );
      }).toList();

      final stats = AlarmMttrStats(
        overallMttr: overallMttr,
        mttrByPriority: mttrByPriority,
        trend: trend,
        totalAlarmCount: totalCount,
      );

      await _cacheManager.set(
        cacheKey,
        {
          'overallMttrMs': overallMttr.inMilliseconds,
          'totalAlarmCount': totalCount,
          'mttrByPriority': mttrByPriority
              .map((k, v) => MapEntry(k, v.inMilliseconds)),
          'trend': trend
              .map((e) => {
                    'date': e.date.toIso8601String(),
                    'avgMttrMs': e.avgMttr.inMilliseconds,
                    'alarmCount': e.alarmCount,
                  })
              .toList(),
        },
        ttl: const Duration(minutes: 5),
      );

      return stats;
    } catch (e, stackTrace) {
      // Drift-loud: sessiz sıfır yerine hata yüzeye çıksın.
      Logger.error('Failed to get MTTR stats', e, stackTrace);
      rethrow;
    }
  }

  AlarmMttrStats _parseMttrStatsFromCache(Map<String, dynamic> cached) {
    return AlarmMttrStats(
      overallMttr: Duration(milliseconds: cached['overallMttrMs'] as int? ?? 0),
      totalAlarmCount: cached['totalAlarmCount'] as int? ?? 0,
      mttrByPriority: (cached['mttrByPriority'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, Duration(milliseconds: v as int))) ??
          {},
      trend: (cached['trend'] as List<dynamic>?)
              ?.map((e) {
                final m = e as Map<String, dynamic>;
                return MttrTrendEntry(
                  date: DateTime.parse(m['date'] as String),
                  avgMttr: Duration(milliseconds: m['avgMttrMs'] as int),
                  alarmCount: m['alarmCount'] as int,
                );
              })
              .toList() ??
          [],
    );
  }

  /// En sık tekrarlayan alarmlar (Top N)
  ///
  /// alarm_histories tablosundan variable_id bazlı gruplama yapılır.
  Future<List<AlarmFrequency>> getTopAlarms({
    int days = IoTConfig.defaultAlarmTimelineDays,
    int limit = 10,
    String? controllerId,
    String? siteId,
    String? providerId,
    bool forceRefresh = false,
  }) async {
    final effectiveDays = IoTConfig.clampDaysRange(days);
    final filterKey = controllerId ?? siteId ?? providerId ?? 'all';
    final cacheKey =
        'alarm_top_${_currentTenantId}_${filterKey}_${effectiveDays}d_$limit';

    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        return cached.map((e) {
          final m = e as Map<String, dynamic>;
          return AlarmFrequency(
            variableId: m['variableId'] as String,
            alarmName: m['alarmName'] as String,
            alarmCode: m['alarmCode'] as String?,
            priorityId: m['priorityId'] as String?,
            count: m['count'] as int,
            lastOccurrence: DateTime.parse(m['lastOccurrence'] as String),
          );
        }).toList();
      }
    }

    try {
      final since = DateTime.now()
          .subtract(Duration(days: effectiveDays))
          .toIso8601String();

      var query = _supabase
          .from('alarm_histories')
          .select('variable_id,name,code,priority_id,start_time')
          .gte('start_time', since);

      if (_currentTenantId != null) {
        query = query.or('tenant_id.eq.$_currentTenantId,tenant_id.is.null');
      }
      if (controllerId != null) {
        query = query.eq('controller_id', controllerId);
      }
      if (siteId != null) {
        query = query.eq('site_id', siteId);
      }
      if (providerId != null) {
        query = query.eq('provider_id', providerId);
      }

      final response = await query;
      final rows = response as List;

      // variable_id bazlı gruplama
      final groups = <String, _AlarmGroup>{};
      for (final row in rows) {
        final r = row as Map<String, dynamic>;
        final variableId = r['variable_id'] as String? ?? 'unknown';
        final name = r['name'] as String? ?? 'Bilinmeyen';
        final code = r['code'] as String?;
        final priorityId = r['priority_id'] as String?;
        final startTimeStr = r['start_time'] as String?;

        final group = groups.putIfAbsent(
          variableId,
          () => _AlarmGroup(
            variableId: variableId,
            name: name,
            code: code,
            priorityId: priorityId,
          ),
        );
        group.count++;
        if (startTimeStr != null) {
          final st = DateTime.tryParse(startTimeStr);
          if (st != null && st.isAfter(group.lastOccurrence)) {
            group.lastOccurrence = st;
          }
        }
      }

      final sorted = groups.values.toList()
        ..sort((a, b) => b.count.compareTo(a.count));
      final topN = sorted.take(limit).toList();

      final results = topN
          .map((g) => AlarmFrequency(
                variableId: g.variableId,
                alarmName: g.name,
                alarmCode: g.code,
                priorityId: g.priorityId,
                count: g.count,
                lastOccurrence: g.lastOccurrence,
              ))
          .toList();

      await _cacheManager.set(
        cacheKey,
        results
            .map((e) => {
                  'variableId': e.variableId,
                  'alarmName': e.alarmName,
                  'alarmCode': e.alarmCode,
                  'priorityId': e.priorityId,
                  'count': e.count,
                  'lastOccurrence': e.lastOccurrence.toIso8601String(),
                })
            .toList(),
        ttl: const Duration(minutes: 5),
      );

      return results;
    } catch (e, stackTrace) {
      Logger.error('Failed to get top alarms', e, stackTrace);
      return [];
    }
  }

  /// Site bazlı alarm sayıları (ranking chart verisi)
  ///
  /// alarm_histories tablosundan site_id bazlı gruplama yapılır (resetCount).
  /// Aktif alarmlar alarms tablosundan site_id bazlı sayılır (activeCount).
  /// Site adları siteNames parametresi ile eşleştirilir.
  Future<List<SiteAlarmCount>> getAlarmCountsBySite({
    required Map<String, String> siteNames,
    int days = IoTConfig.defaultAlarmTimelineDays,
    int limit = 10,
    bool forceRefresh = false,
  }) async {
    final effectiveDays = IoTConfig.clampDaysRange(days);
    final cacheKey =
        'alarm_site_ranking_${_currentTenantId}_${effectiveDays}d_$limit';

    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        return cached.map((e) {
          final m = e as Map<String, dynamic>;
          return SiteAlarmCount(
            siteId: m['siteId'] as String,
            siteName: m['siteName'] as String,
            resetCount: m['resetCount'] as int,
            activeCount: m['activeCount'] as int,
          );
        }).toList();
      }
    }

    try {
      final since = _rangeFrom(effectiveDays);

      final resetBySite = <String, int>{};
      final rpcSiteNames = <String, String>{};

      if (_currentTenantId != null) {
        // Server-side: site bazlı reset alarm sayıları sunucuda gruplanır
        // (fn_pms_alarm_site_controller). Client-side "tüm satırları çek + say"
        // yerine indexli agregasyon.
        final scResp =
            await _supabase.rpc('fn_pms_alarm_site_controller', params: {
          'p_tenant_id': _currentTenantId,
          'p_from': since,
          'p_to': _rangeTo(),
          'p_organization_id': _currentOrganizationId,
        });
        for (final r in (scResp as List)) {
          final m = Map<String, dynamic>.from(r as Map);
          final sid = m['site_id'] as String?;
          if (sid == null) continue;
          resetBySite[sid] = (resetBySite[sid] ?? 0) + _asInt(m['cnt']);
          final sname = m['site_name'] as String?;
          if (sname != null) rpcSiteNames[sid] = sname;
        }
      } else {
        // tenant yok: client-side fallback (RPC tenant zorunlu)
        final resetResponse = await _supabase
            .from('alarm_histories')
            .select('site_id')
            .gte('start_time', since);
        for (final row in (resetResponse as List)) {
          final siteId = (row as Map<String, dynamic>)['site_id'] as String?;
          if (siteId != null) {
            resetBySite[siteId] = (resetBySite[siteId] ?? 0) + 1;
          }
        }
      }

      // Aktif alarm sayıları (alarms)
      var activeQuery = _supabase.from('alarms').select('site_id');

      if (_currentTenantId != null) {
        activeQuery =
            activeQuery.or('tenant_id.eq.$_currentTenantId,tenant_id.is.null');
      }

      final activeResponse = await activeQuery;
      final activeRows = activeResponse as List;

      final activeBySite = <String, int>{};
      for (final row in activeRows) {
        final siteId = (row as Map<String, dynamic>)['site_id'] as String?;
        if (siteId != null) {
          activeBySite[siteId] = (activeBySite[siteId] ?? 0) + 1;
        }
      }

      // Birleştir
      final allSiteIds = <String>{...resetBySite.keys, ...activeBySite.keys};
      final results = allSiteIds.map((siteId) {
        return SiteAlarmCount(
          siteId: siteId,
          siteName: siteNames[siteId] ?? rpcSiteNames[siteId] ?? siteId,
          resetCount: resetBySite[siteId] ?? 0,
          activeCount: activeBySite[siteId] ?? 0,
        );
      }).toList();

      // totalCount'a göre sırala
      results.sort((a, b) => b.totalCount.compareTo(a.totalCount));
      final topN = results.take(limit).toList();

      await _cacheManager.set(
        cacheKey,
        topN
            .map((e) => {
                  'siteId': e.siteId,
                  'siteName': e.siteName,
                  'resetCount': e.resetCount,
                  'activeCount': e.activeCount,
                })
            .toList(),
        ttl: const Duration(minutes: 5),
      );

      return topN;
    } catch (e, stackTrace) {
      // Drift-loud: sessiz boş liste yerine hata yüzeye çıksın.
      Logger.error('Failed to get alarm counts by site', e, stackTrace);
      rethrow;
    }
  }

  /// Alarm heatmap verisi (7 gün x 24 saat)
  ///
  /// alarm_histories tablosundan 1 haftalık pencerede start_time bazlı dağılım.
  Future<AlarmHeatmapData> getAlarmHeatmap({
    DateTime? weekStart,
    String? controllerId,
    String? siteId,
    String? providerId,
    bool forceRefresh = false,
  }) async {
    final effectiveWeekStart = weekStart ??
        DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
    final weekStartNormalized = DateTime(
      effectiveWeekStart.year,
      effectiveWeekStart.month,
      effectiveWeekStart.day,
    );
    final weekEnd = weekStartNormalized.add(const Duration(days: 7));

    final filterKey = controllerId ?? siteId ?? providerId ?? 'all';
    final cacheKey =
        'alarm_heatmap_${_currentTenantId}_${filterKey}_${weekStartNormalized.toIso8601String()}';

    if (!forceRefresh) {
      final cached = await _cacheManager.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        return _parseHeatmapFromCache(cached);
      }
    }

    try {
      var query = _supabase
          .from('alarm_histories')
          .select('start_time')
          .gte('start_time', weekStartNormalized.toIso8601String())
          .lt('start_time', weekEnd.toIso8601String());

      if (_currentTenantId != null) {
        query = query.or('tenant_id.eq.$_currentTenantId,tenant_id.is.null');
      }
      if (controllerId != null) {
        query = query.eq('controller_id', controllerId);
      }
      if (siteId != null) {
        query = query.eq('site_id', siteId);
      }
      if (providerId != null) {
        query = query.eq('provider_id', providerId);
      }

      final response = await query;
      final rows = response as List;

      // 7x24 matris oluştur
      final matrix = List.generate(7, (_) => List.filled(24, 0));
      int maxCount = 0;

      for (final row in rows) {
        final r = row as Map<String, dynamic>;
        final startTimeStr = r['start_time'] as String?;
        if (startTimeStr == null) continue;

        final dt = DateTime.tryParse(startTimeStr);
        if (dt == null) continue;

        final dayIndex = (dt.weekday - 1).clamp(0, 6); // 0=Mon, 6=Sun
        final hourIndex = dt.hour;

        matrix[dayIndex][hourIndex]++;
        if (matrix[dayIndex][hourIndex] > maxCount) {
          maxCount = matrix[dayIndex][hourIndex];
        }
      }

      final data = AlarmHeatmapData(
        matrix: matrix,
        maxCount: maxCount,
        weekStart: weekStartNormalized,
      );

      await _cacheManager.set(
        cacheKey,
        {
          'matrix': matrix,
          'maxCount': maxCount,
          'weekStart': weekStartNormalized.toIso8601String(),
        },
        ttl: const Duration(minutes: 5),
      );

      return data;
    } catch (e, stackTrace) {
      // Sıfır-dolu matris "sakin/sağlıklı hafta" gibi görünür — yükleme
      // hatasını böyle maskeleme; çağıran ekranlar hata-durumu gösteriyor.
      Logger.error('Failed to get alarm heatmap', e, stackTrace);
      rethrow;
    }
  }

  AlarmHeatmapData _parseHeatmapFromCache(Map<String, dynamic> cached) {
    final rawMatrix = cached['matrix'] as List<dynamic>;
    final matrix = rawMatrix
        .map((row) => (row as List<dynamic>).map((e) => e as int).toList())
        .toList();
    return AlarmHeatmapData(
      matrix: matrix,
      maxCount: cached['maxCount'] as int? ?? 0,
      weekStart: DateTime.parse(cached['weekStart'] as String),
    );
  }

  void dispose() {
    _alarmsController.close();
    _historyController.close();
  }
}

class _AlarmGroup {
  final String variableId;
  final String name;
  final String? code;
  final String? priorityId;
  int count = 0;
  DateTime lastOccurrence = DateTime(2000);

  _AlarmGroup({
    required this.variableId,
    required this.name,
    this.code,
    this.priorityId,
  });
}
