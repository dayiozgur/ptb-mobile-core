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
      Logger.error('Failed to get active alarms', e, stackTrace);
      return [];
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
      Logger.error('Failed to get alarms by controllers', e, stackTrace);
      return [];
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
    } catch (e) {
      Logger.warning('Failed to get reset alarm count for site: $e');
      return 0;
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
    } catch (e) {
      Logger.warning('Failed to get reset alarm count for provider: $e');
      return 0;
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
      Logger.error('Failed to get alarm timeline', e, stackTrace);
      return [];
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
      Logger.error('Failed to get alarm distribution', e, stackTrace);
      return const AlarmDistribution(
        activeCount: 0,
        resetCount: 0,
        acknowledgedCount: 0,
      );
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
      Logger.error('Failed to get MTTR stats', e, stackTrace);
      return const AlarmMttrStats(overallMttr: Duration.zero);
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
      Logger.error('Failed to get alarm heatmap', e, stackTrace);
      return AlarmHeatmapData(
        matrix: List.generate(7, (_) => List.filled(24, 0)),
        maxCount: 0,
        weekStart: weekStartNormalized,
      );
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
