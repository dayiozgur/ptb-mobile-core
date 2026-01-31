import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../utils/logger.dart';
import 'alarm_model.dart';
import 'alarm_history_model.dart';
import 'alarm_stats_model.dart';

/// Alarm Service
///
/// Aktif alarm ve resetlenmiş alarm verilerini yönetir.
/// DB tabloları:
///   - alarms: Sadece AKTİF alarmlar (tenant_id, site_id, provider_id YOK!)
///   - alarm_histories: Sadece RESETLENMİŞ alarmlar (tenant_id, site_id, provider_id VAR)
///
/// Backend tarafından yönetilen senkronizasyon:
///   - Alarm aktif olduğunda → alarms tablosunda
///   - Alarm resetlendiğinde → alarm_histories tablosuna taşınır
///
/// NOT: alarms tablosunda tenant_id kolonu bulunmaz.
/// Aktif alarm sayısı için alarms tablosu kullanılır.
/// Resetlenmiş alarm geçmişi için alarm_histories tablosu kullanılır.
///
/// Description Kaynağı:
///   - alarms.description / alarm_histories.description: Doğrudan tabloda saklanır
///   - variable_id → variables.description: Variable ile ilişkili açıklama
///   Supabase JOIN ile variable description'ı da çekilebilir.
class AlarmService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  String? _currentTenantId;

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
  // TENANT CONTEXT
  // ============================================

  void setTenant(String tenantId) {
    _currentTenantId = tenantId;
  }

  void clearTenant() {
    _currentTenantId = null;
  }

  // ============================================
  // ACTIVE ALARMS
  // ============================================

  /// Aktif alarmları getir (controller bazlı)
  ///
  /// alarms tablosu üzerinden çalışır (sadece aktif alarmlar burada).
  /// NOT: alarms tablosunda tenant_id yok, sadece controller_id ile filtrelenir.
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

      var query = _supabase
          .from('alarms')
          .select(selectClause)
          .eq('active', true);

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
      final response = await _supabase
          .from('alarms')
          .select()
          .eq('active', true)
          .inFilter('controller_id', controllerIds)
          .order('start_time', ascending: false);

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

      if (_currentTenantId != null) {
        query = query.eq('tenant_id', _currentTenantId!);
      }

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

      // created_at fallback sıralama: start_time NULL olabilir
      final response = await query
          .order('created_at', ascending: false)
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
  Future<int> getResetAlarmCountBySite(String siteId) async {
    try {
      final response = await _supabase
          .from('alarm_histories')
          .select('id')
          .eq('site_id', siteId);

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
  Future<int> getResetAlarmCountByProvider(String providerId) async {
    try {
      final response = await _supabase
          .from('alarm_histories')
          .select('id')
          .eq('provider_id', providerId);

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
  /// Son [days] gün içindeki resetlenmiş alarmları döner (max 90 gün).
  /// created_at üzerinden zaman filtresi (start_time NULL olabilir).
  /// Sıralama: created_at DESC
  Future<List<AlarmHistory>> getResetAlarms({
    String? controllerId,
    String? siteId,
    String? providerId,
    int days = 90,
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    final effectiveDays = days.clamp(1, 90);
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

      // reset_time NOT NULL → resetlenmiş alarmlar
      // created_at üzerinden filtrele (start_time NULL olabilir)
      var query = _supabase
          .from('alarm_histories')
          .select()
          .not('reset_time', 'is', null)
          .gte('created_at', since);

      if (_currentTenantId != null) {
        query = query.eq('tenant_id', _currentTenantId!);
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
          .order('created_at', ascending: false)
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
  /// alarm_histories tablosundan son [days] gün (max 90) verileri çeker.
  /// alarm_histories sadece resetlenmiş alarmları içerir.
  /// client-side günlük gruplandırma yapar.
  /// Her gün için priority bazlı ayrıntı içerir.
  /// created_at üzerinden filtrele (start_time NULL olabilir).
  Future<List<AlarmTimelineEntry>> getAlarmTimeline({
    String? controllerId,
    String? siteId,
    String? providerId,
    int days = 30,
    bool forceRefresh = false,
  }) async {
    final effectiveDays = days.clamp(1, 90);
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

      // created_at üzerinden filtrele (start_time NULL olabilir)
      var query = _supabase
          .from('alarm_histories')
          .select('id,start_time,created_at,priority_id')
          .gte('created_at', since);

      if (_currentTenantId != null) {
        query = query.eq('tenant_id', _currentTenantId!);
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
          await query.order('created_at', ascending: true);

      // Client-side günlük gruplandırma
      final dailyMap = <String, Map<String, int>>{};
      final dailyTotal = <String, int>{};

      for (final e in (response as List)) {
        final row = e as Map<String, dynamic>;
        // start_time (tercihen) veya created_at (fallback) kullan
        final timeStr = row['start_time'] as String?
            ?? row['created_at'] as String?;
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
    int days = 90,
    bool forceRefresh = false,
  }) async {
    final effectiveDays = days.clamp(1, 90);
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
        );
      }
    }

    try {
      final since = DateTime.now()
          .subtract(Duration(days: effectiveDays))
          .toIso8601String();

      // --- Aktif alarm sayısı (alarms tablosu) ---
      // alarms tablosu sadece aktif alarmları içerir
      // NOT: alarms tablosunda tenant_id, site_id yok
      var activeQuery = _supabase
          .from('alarms')
          .select('id')
          .eq('active', true);

      if (controllerId != null) {
        activeQuery = activeQuery.eq('controller_id', controllerId);
      }
      // site_id alarms tablosunda yok, filtreleme yapılamaz

      final activeResponse = await activeQuery;
      final activeCount = (activeResponse as List).length;

      // --- Onaylı aktif alarm sayısı (alarms tablosu) ---
      var ackQuery = _supabase
          .from('alarms')
          .select('id')
          .eq('active', true)
          .not('local_acknowledge_time', 'is', null);

      if (controllerId != null) {
        ackQuery = ackQuery.eq('controller_id', controllerId);
      }

      final ackResponse = await ackQuery;
      final acknowledgedCount = (ackResponse as List).length;

      // --- Resetli alarm sayısı (alarm_histories tablosu: son N gün) ---
      // alarm_histories sadece resetlenmiş alarmları içerir
      var resetQuery = _supabase
          .from('alarm_histories')
          .select('id')
          .not('reset_time', 'is', null)
          .gte('created_at', since);

      if (_currentTenantId != null) {
        resetQuery = resetQuery.eq('tenant_id', _currentTenantId!);
      }
      if (controllerId != null) {
        resetQuery = resetQuery.eq('controller_id', controllerId);
      }
      if (siteId != null) {
        resetQuery = resetQuery.eq('site_id', siteId);
      }

      final resetResponse = await resetQuery;
      final resetCount = (resetResponse as List).length;

      final distribution = AlarmDistribution(
        activeCount: activeCount,
        resetCount: resetCount,
        acknowledgedCount: acknowledgedCount,
      );

      await _cacheManager.set(
        cacheKey,
        {
          'activeCount': activeCount,
          'resetCount': resetCount,
          'acknowledgedCount': acknowledgedCount,
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

  void dispose() {
    _alarmsController.close();
    _historyController.close();
  }
}
