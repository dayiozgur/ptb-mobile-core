import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../utils/logger.dart';
import 'iot_log_model.dart';

/// IoT Log Service
///
/// Operasyonel log kayıtlarını yönetir.
/// DB tablosu: logs
class IoTLogService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  String? _currentTenantId;

  final _logsController = StreamController<List<IoTLog>>.broadcast();

  IoTLogService({
    required SupabaseClient supabase,
    required CacheManager cacheManager,
  })  : _supabase = supabase,
        _cacheManager = cacheManager;

  // ============================================
  // GETTERS
  // ============================================

  Stream<List<IoTLog>> get logsStream => _logsController.stream;

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
  // OPERATIONS
  // ============================================

  /// Log kayıtlarını getir
  Future<List<IoTLog>> getLogs({
    String? controllerId,
    String? providerId,
    String? variableId,
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    final filterKey = controllerId ?? providerId ?? variableId ?? 'all';
    final cacheKey = 'iot_logs_${_currentTenantId}_$filterKey';

    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        final logs = cached
            .map((e) => IoTLog.fromJson(e as Map<String, dynamic>))
            .toList();
        _logsController.add(logs);
        return logs;
      }
    }

    try {
      var query = _supabase.from('logs').select();

      if (_currentTenantId != null) {
        query = query.eq('tenant_id', _currentTenantId!);
      }

      if (controllerId != null) {
        query = query.eq('controller_id', controllerId);
      }

      if (providerId != null) {
        query = query.eq('provider_id', providerId);
      }

      if (variableId != null) {
        query = query.eq('variable_id', variableId);
      }

      final response = await query
          .order('date_time', ascending: false)
          .limit(limit);

      final logs = <IoTLog>[];
      for (final e in (response as List)) {
        try {
          logs.add(IoTLog.fromJson(e as Map<String, dynamic>));
        } catch (parseError) {
          Logger.warning('Failed to parse IoT log: $parseError');
        }
      }

      await _cacheManager.set(
        cacheKey,
        logs.map((e) => e.toJson()).toList(),
        ttl: const Duration(minutes: 5),
      );

      _logsController.add(logs);
      return logs;
    } catch (e, stackTrace) {
      Logger.error('Failed to get IoT logs', e, stackTrace);
      return [];
    }
  }

  /// Provider bazlı log sayısı
  Future<int> getLogCountByProvider(String providerId, {int? lastHours}) async {
    try {
      var query = _supabase
          .from('logs')
          .select('id')
          .eq('provider_id', providerId);

      if (lastHours != null) {
        final since = DateTime.now()
            .subtract(Duration(hours: lastHours))
            .toIso8601String();
        query = query.gte('date_time', since);
      }

      final response = await query;
      return (response as List).length;
    } catch (e) {
      Logger.warning('Failed to get log count for provider: $e');
      return 0;
    }
  }

  /// Controller bazlı log sayısı
  Future<int> getLogCountByController(String controllerId,
      {int? lastHours}) async {
    try {
      var query = _supabase
          .from('logs')
          .select('id')
          .eq('controller_id', controllerId);

      if (lastHours != null) {
        final since = DateTime.now()
            .subtract(Duration(hours: lastHours))
            .toIso8601String();
        query = query.gte('date_time', since);
      }

      final response = await query;
      return (response as List).length;
    } catch (e) {
      Logger.warning('Failed to get log count for controller: $e');
      return 0;
    }
  }

  void dispose() {
    _logsController.close();
  }
}
