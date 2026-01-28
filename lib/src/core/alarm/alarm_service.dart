import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../utils/logger.dart';
import 'alarm_model.dart';
import 'alarm_history_model.dart';

/// Alarm Service
///
/// Aktif alarm ve alarm geçmişi verilerini yönetir.
/// DB tabloları: alarms, alarm_histories
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
  Future<List<Alarm>> getActiveAlarms({
    String? controllerId,
    String? variableId,
  }) async {
    try {
      var query = _supabase
          .from('alarms')
          .select()
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

  /// Alarm geçmişini getir
  Future<List<AlarmHistory>> getHistory({
    String? siteId,
    String? providerId,
    String? controllerId,
    String? variableId,
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    final filterKey = siteId ?? providerId ?? controllerId ?? 'all';
    final cacheKey = 'alarm_history_${_currentTenantId}_$filterKey';

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
      var query = _supabase
          .from('alarm_histories')
          .select();

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

  /// Site bazlı alarm sayısı (aktif alarmlar)
  Future<int> getActiveAlarmCountBySite(String siteId) async {
    try {
      final response = await _supabase
          .from('alarm_histories')
          .select('id')
          .eq('site_id', siteId)
          .isFilter('end_time', null);

      return (response as List).length;
    } catch (e) {
      Logger.warning('Failed to get alarm count for site: $e');
      return 0;
    }
  }

  /// Provider bazlı alarm sayısı
  Future<int> getActiveAlarmCountByProvider(String providerId) async {
    try {
      final response = await _supabase
          .from('alarm_histories')
          .select('id')
          .eq('provider_id', providerId)
          .isFilter('end_time', null);

      return (response as List).length;
    } catch (e) {
      Logger.warning('Failed to get alarm count for provider: $e');
      return 0;
    }
  }

  void dispose() {
    _alarmsController.close();
    _historyController.close();
  }
}
