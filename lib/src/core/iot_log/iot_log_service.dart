import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../utils/logger.dart';
import 'iot_log_model.dart';
import 'iot_log_stats_model.dart';

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

  // ============================================
  // TIME SERIES & STATS
  // ============================================

  /// Log zaman serisi verileri (line chart için)
  ///
  /// IoTLog.value → double parse ile numerik dönüşüm yapar.
  /// Sıralama: date_time ASC (chart'ta kronolojik görüntü).
  Future<List<LogTimeSeriesEntry>> getLogTimeSeries({
    required String controllerId,
    String? variableId,
    int days = 7,
    bool forceRefresh = false,
  }) async {
    final filterKey = variableId ?? controllerId;
    final cacheKey =
        'log_ts_${_currentTenantId}_${filterKey}_${days}d';

    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        return cached.map((e) {
          final map = e as Map<String, dynamic>;
          return LogTimeSeriesEntry(
            dateTime: DateTime.parse(map['dateTime'] as String),
            value: (map['value'] as num?)?.toDouble(),
            onOff: map['onOff'] as int?,
            rawValue: map['rawValue'] as String?,
          );
        }).toList();
      }
    }

    try {
      final since = DateTime.now()
          .subtract(Duration(days: days))
          .toIso8601String();

      var query = _supabase
          .from('logs')
          .select('date_time,value,on_off')
          .eq('controller_id', controllerId)
          .gte('date_time', since);

      if (_currentTenantId != null) {
        query = query.eq('tenant_id', _currentTenantId!);
      }
      if (variableId != null) {
        query = query.eq('variable_id', variableId);
      }

      final response =
          await query.order('date_time', ascending: true);

      final entries = <LogTimeSeriesEntry>[];
      for (final e in (response as List)) {
        final row = e as Map<String, dynamic>;
        final dateStr = row['date_time'] as String?;
        if (dateStr == null) continue;

        final dt = DateTime.tryParse(dateStr);
        if (dt == null) continue;

        final rawValue = row['value'] as String?;
        final numericValue =
            rawValue != null ? double.tryParse(rawValue) : null;
        final onOff = row['on_off'] as int? ?? row['onoff'] as int?;

        entries.add(LogTimeSeriesEntry(
          dateTime: dt,
          value: numericValue,
          onOff: onOff,
          rawValue: rawValue,
        ));
      }

      await _cacheManager.set(
        cacheKey,
        entries
            .map((e) => {
                  'dateTime': e.dateTime.toIso8601String(),
                  'value': e.value,
                  'onOff': e.onOff,
                  'rawValue': e.rawValue,
                })
            .toList(),
        ttl: const Duration(minutes: 5),
      );

      return entries;
    } catch (e, stackTrace) {
      Logger.error('Failed to get log time series', e, stackTrace);
      return [];
    }
  }

  /// Tarih aralığına göre log kayıtları
  ///
  /// [from] ve [to] arasındaki logları getirir.
  /// Sıralama: date_time ASC (chart uyumlu).
  Future<List<IoTLog>> getLogsByTimeRange({
    required String controllerId,
    String? variableId,
    required DateTime from,
    required DateTime to,
    int limit = 500,
  }) async {
    try {
      var query = _supabase
          .from('logs')
          .select()
          .eq('controller_id', controllerId)
          .gte('date_time', from.toIso8601String())
          .lte('date_time', to.toIso8601String());

      if (_currentTenantId != null) {
        query = query.eq('tenant_id', _currentTenantId!);
      }
      if (variableId != null) {
        query = query.eq('variable_id', variableId);
      }

      final response = await query
          .order('date_time', ascending: true)
          .limit(limit);

      final logs = <IoTLog>[];
      for (final e in (response as List)) {
        try {
          logs.add(IoTLog.fromJson(e as Map<String, dynamic>));
        } catch (parseError) {
          Logger.warning('Failed to parse IoT log: $parseError');
        }
      }

      return logs;
    } catch (e, stackTrace) {
      Logger.error('Failed to get logs by time range', e, stackTrace);
      return [];
    }
  }

  /// Log değer istatistikleri
  ///
  /// Controller/variable bazlı min, max, avg, son değer hesaplar.
  /// Client-side hesaplama (Supabase aggregate fonksiyonları yerine).
  Future<LogValueStats> getLogValueStats({
    required String controllerId,
    String? variableId,
    int days = 7,
  }) async {
    try {
      final entries = await getLogTimeSeries(
        controllerId: controllerId,
        variableId: variableId,
        days: days,
      );

      if (entries.isEmpty) {
        return const LogValueStats();
      }

      final numericValues = entries
          .where((e) => e.hasNumericValue)
          .map((e) => e.value!)
          .toList();

      if (numericValues.isEmpty) {
        return LogValueStats(
          totalCount: entries.length,
          firstDate: entries.first.dateTime,
          lastDate: entries.last.dateTime,
        );
      }

      final sum = numericValues.reduce((a, b) => a + b);
      final min = numericValues.reduce(
          (a, b) => a < b ? a : b);
      final max = numericValues.reduce(
          (a, b) => a > b ? a : b);

      return LogValueStats(
        minValue: min,
        maxValue: max,
        avgValue: sum / numericValues.length,
        lastValue: numericValues.last,
        totalCount: entries.length,
        firstDate: entries.first.dateTime,
        lastDate: entries.last.dateTime,
      );
    } catch (e, stackTrace) {
      Logger.error('Failed to get log value stats', e, stackTrace);
      return const LogValueStats();
    }
  }

  void dispose() {
    _logsController.close();
  }
}
