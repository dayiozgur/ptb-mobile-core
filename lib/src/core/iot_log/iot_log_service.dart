import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../utils/db_field_helpers.dart';
import '../utils/logger.dart';
import 'iot_log_model.dart';
import 'iot_log_stats_model.dart';

/// IoT Log Service
///
/// Operasyonel log kayıtlarını yönetir.
/// DB tablosu: logs
///
/// NOT: logs tablosunda dual kolon yapısı vardır:
///   - datetime (legacy) / date_time (current) → zaman damgası
///   - onoff (legacy) / on_off (current) → on/off durumu
/// Her iki kolon da veritabanında mevcuttur. Backend uygulaması
/// verilerini legacy veya current kolona yazabilir.
/// Bu servis her iki kolonu da destekler.
///
/// Multi-Tenant İzolasyon:
///   - tenant_id: Zorunlu - tenant bazlı izolasyon
///   - organization_id: Opsiyonel - organization bazlı filtreleme
///   - site_id: Opsiyonel - site bazlı filtreleme
///   - provider_id: Opsiyonel - provider bazlı filtreleme
///
/// Description Kaynağı:
///   - logs.description: Doğrudan tabloda saklanır
///   - logs.variable_id → variables.description: Variable ile ilişkili açıklama
///   Supabase JOIN ile variable description'ı da çekilebilir.
class IoTLogService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  // Multi-Tenant İzolasyon Context
  String? _currentTenantId;
  String? _currentOrganizationId;
  String? _currentSiteId;

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
  // OPERATIONS
  // ============================================

  /// Log kayıtlarını getir
  ///
  /// Tüm kolonları çeker, IoTLog.fromJson hem date_time hem datetime
  /// kolonlarını fallback olarak destekler.
  ///
  /// [includeVariable]: true ise variable bilgisini JOIN ile çeker
  /// [activeOnly]: true ise sadece active=true kayıtları getirir (default: false)
  Future<List<IoTLog>> getLogs({
    String? controllerId,
    String? providerId,
    String? variableId,
    int limit = 50,
    bool forceRefresh = false,
    bool includeVariable = false,
    bool activeOnly = false,
  }) async {
    final filterKey = controllerId ?? providerId ?? variableId ?? 'all';
    final cacheKey = 'iot_logs_${_currentTenantId}_${filterKey}_v${includeVariable ? 1 : 0}';

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
      // Variable JOIN opsiyonel: variable description'ı çekmek için
      final selectClause = includeVariable
          ? '*, variable:variables(id, name, description, unit)'
          : '*';

      var query = _supabase.from('logs').select(selectClause);

      // Active filtresi - bazı sistemlerde active null olabilir
      // Bu yüzden varsayılan olarak false, isteğe bağlı aktifleştirilebilir
      if (activeOnly) {
        query = query.eq('active', true);
      }

      // Multi-Tenant İzolasyon Filtreleri
      if (_currentTenantId != null) {
        query = query.eq('tenant_id', _currentTenantId!);
      }

      if (_currentOrganizationId != null) {
        query = query.eq('organization_id', _currentOrganizationId!);
      }

      if (_currentSiteId != null) {
        query = query.eq('site_id', _currentSiteId!);
      }

      // Ek filtreler
      if (controllerId != null) {
        query = query.eq('controller_id', controllerId);
      }

      if (providerId != null) {
        query = query.eq('provider_id', providerId);
      }

      if (variableId != null) {
        query = query.eq('variable_id', variableId);
      }

      // created_at her zaman dolu olduğu için güvenilir sıralama sağlar.
      // (date_time NULL olabilir, datetime NULL olabilir, ama created_at her zaman var)
      final response = await query
          .order('created_at', ascending: false)
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

  /// Log kayıtlarını variable description ile birlikte getir
  ///
  /// Variable tablosundan description, name ve unit bilgilerini de çeker.
  /// Description önceliği: logs.description → variable.description
  Future<List<IoTLog>> getLogsWithVariable({
    String? controllerId,
    String? providerId,
    String? variableId,
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    return getLogs(
      controllerId: controllerId,
      providerId: providerId,
      variableId: variableId,
      limit: limit,
      forceRefresh: forceRefresh,
      includeVariable: true,
    );
  }

  /// Provider bazlı log sayısı
  ///
  /// Multi-tenant izolasyon: tenant_id, organization_id, site_id ile filtrelenir.
  Future<int> getLogCountByProvider(String providerId, {int? lastHours}) async {
    try {
      var query = _supabase
          .from('logs')
          .select('id')
          .eq('provider_id', providerId);

      // Multi-Tenant İzolasyon Filtreleri (KRİTİK: Önceden eksikti!)
      if (_currentTenantId != null) {
        query = query.eq('tenant_id', _currentTenantId!);
      }

      if (_currentOrganizationId != null) {
        query = query.eq('organization_id', _currentOrganizationId!);
      }

      if (_currentSiteId != null) {
        query = query.eq('site_id', _currentSiteId!);
      }

      if (lastHours != null) {
        final since = DateTime.now()
            .subtract(Duration(hours: lastHours))
            .toIso8601String();
        // created_at her zaman dolu - güvenilir zaman filtresi
        query = query.gte('created_at', since);
      }

      final response = await query;
      return (response as List).length;
    } catch (e) {
      Logger.warning('Failed to get log count for provider: $e');
      return 0;
    }
  }

  /// Controller bazlı log sayısı
  ///
  /// Multi-tenant izolasyon: tenant_id, organization_id, site_id ile filtrelenir.
  Future<int> getLogCountByController(String controllerId,
      {int? lastHours}) async {
    try {
      var query = _supabase
          .from('logs')
          .select('id')
          .eq('controller_id', controllerId);

      // Multi-Tenant İzolasyon Filtreleri (KRİTİK: Önceden eksikti!)
      if (_currentTenantId != null) {
        query = query.eq('tenant_id', _currentTenantId!);
      }

      if (_currentOrganizationId != null) {
        query = query.eq('organization_id', _currentOrganizationId!);
      }

      if (_currentSiteId != null) {
        query = query.eq('site_id', _currentSiteId!);
      }

      if (lastHours != null) {
        final since = DateTime.now()
            .subtract(Duration(hours: lastHours))
            .toIso8601String();
        // created_at her zaman dolu - güvenilir zaman filtresi
        query = query.gte('created_at', since);
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
  /// DB'deki logs tablosunda hem 'date_time' hem 'datetime' (legacy) kolon var.
  /// Backend verilerini hangi kolona yazdığı bilinemediğinden,
  /// tüm kolonları çekip client-side fallback yapılır.
  /// Sıralama: created_at ASC (chart'ta kronolojik görüntü).
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

      // Tüm kolonları çek - hem date_time hem datetime (legacy) destekle
      // created_at üzerinden filtrele (her zaman dolu)
      var query = _supabase
          .from('logs')
          .select()
          .eq('controller_id', controllerId)
          .gte('created_at', since);

      // Multi-Tenant İzolasyon Filtreleri
      if (_currentTenantId != null) {
        query = query.eq('tenant_id', _currentTenantId!);
      }

      if (_currentOrganizationId != null) {
        query = query.eq('organization_id', _currentOrganizationId!);
      }

      if (_currentSiteId != null) {
        query = query.eq('site_id', _currentSiteId!);
      }

      // Ek filtreler
      if (variableId != null) {
        query = query.eq('variable_id', variableId);
      }

      final response =
          await query.order('created_at', ascending: true);

      final entries = <LogTimeSeriesEntry>[];
      for (final e in (response as List)) {
        final row = e as Map<String, dynamic>;

        // Dual column: date_time (current) / datetime (legacy)
        final dt = DbFieldHelpers.parseLogDateTime(row);
        if (dt == null) continue;

        final rawValue = row['value'] as String?;
        final numericValue =
            rawValue != null ? double.tryParse(rawValue) : null;

        // Dual column: on_off (current) / onoff (legacy)
        final onOff = DbFieldHelpers.parseLogOnOff(row);

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
  /// created_at üzerinden filtreleme yapılır (date_time NULL olabilir).
  /// Sıralama: created_at ASC (chart uyumlu).
  Future<List<IoTLog>> getLogsByTimeRange({
    required String controllerId,
    String? variableId,
    required DateTime from,
    required DateTime to,
    int limit = 500,
  }) async {
    try {
      // created_at üzerinden filtrele - her zaman dolu
      var query = _supabase
          .from('logs')
          .select()
          .eq('controller_id', controllerId)
          .gte('created_at', from.toIso8601String())
          .lte('created_at', to.toIso8601String());

      // Multi-Tenant İzolasyon Filtreleri
      if (_currentTenantId != null) {
        query = query.eq('tenant_id', _currentTenantId!);
      }

      if (_currentOrganizationId != null) {
        query = query.eq('organization_id', _currentOrganizationId!);
      }

      if (_currentSiteId != null) {
        query = query.eq('site_id', _currentSiteId!);
      }

      // Ek filtreler
      if (variableId != null) {
        query = query.eq('variable_id', variableId);
      }

      final response = await query
          .order('created_at', ascending: true)
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
