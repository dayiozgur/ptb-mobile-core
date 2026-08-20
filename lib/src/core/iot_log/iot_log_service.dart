import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/iot_config.dart';
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
    int limit = IoTConfig.defaultListLimit,
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

      // TODO(perf): 1.97M satırlık `logs` fact tablosunu doğrudan tarar.
      // Bu yol ham log satırlarına ihtiyaç duyuyor (variable listesi değil);
      // özet/agregasyon gerektiğinde fn_pms_telemetry_summary tercih edilmeli.
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

      // DB'de created_at NULL olabilir, date_time dolu - date_time üzerinden sırala
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

  /// Log kayıtlarını variable description ile birlikte getir
  ///
  /// Variable tablosundan description, name ve unit bilgilerini de çeker.
  /// Description önceliği: logs.description → variable.description
  Future<List<IoTLog>> getLogsWithVariable({
    String? controllerId,
    String? providerId,
    String? variableId,
    int limit = IoTConfig.defaultListLimit,
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
      // TODO(perf): 1.97M satırlık `logs` fact tablosunu tarar (provider bazlı
      // ham satır sayımı). Server-side sayım için özel bir RPC yok.
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
        // DB'de created_at NULL - date_time üzerinden filtrele
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
  ///
  /// Multi-tenant izolasyon: tenant_id, organization_id, site_id ile filtrelenir.
  Future<int> getLogCountByController(String controllerId,
      {int? lastHours}) async {
    try {
      // TODO(perf): 1.97M satırlık `logs` fact tablosunu tarar (controller bazlı
      // ham satır sayımı). Server-side sayım için özel bir RPC yok.
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
        // DB'de created_at NULL - date_time üzerinden filtrele
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
  /// DB'deki logs tablosunda hem 'date_time' hem 'datetime' (legacy) kolon var.
  /// Backend verilerini hangi kolona yazdığı bilinemediğinden,
  /// tüm kolonları çekip client-side fallback yapılır.
  /// Sıralama: created_at ASC (chart'ta kronolojik görüntü).
  ///
  /// [controllerId] ve [variableId] parametrelerinden en az biri gereklidir.
  /// Variable bazlı grafik gösterimi için sadece variableId yeterlidir.
  /// Logs tablosunda: logs → variables → device_models → controllers → providers
  Future<List<LogTimeSeriesEntry>> getLogTimeSeries({
    String? controllerId,
    String? variableId,
    int days = IoTConfig.defaultDaysRange,
    bool forceRefresh = false,
  }) async {
    // En az bir filtre gerekli
    if (controllerId == null && variableId == null) {
      Logger.warning('getLogTimeSeries: controllerId or variableId required');
      return [];
    }

    final effectiveDays = IoTConfig.clampDaysRange(days);
    final filterKey = variableId ?? controllerId ?? 'unknown';
    final cacheKey =
        'log_ts_${_currentTenantId}_${filterKey}_${effectiveDays}d';

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
      final now = DateTime.now();
      final since =
          now.subtract(Duration(days: effectiveDays)).toIso8601String();

      // Öncelik: bugüne kadar olan son [effectiveDays] günlük pencere.
      // Prod verisinde bu yol her zaman güncel veriyi döner.
      var entries = await _queryLogTimeSeries(
        controllerId: controllerId,
        variableId: variableId,
        since: since,
      );

      // Fallback: güncel pencerede veri yoksa (geçmiş/boşluklu/demo verisi),
      // filtrelenen küme için EN SON mevcut date_time'ı bul ve pencereyi
      // ORADAN geriye [effectiveDays] gün al. Böylece grafik "bugün"e sabit
      // pencere yerine mevcut EN SON veriyi gösterir (boş grafik yerine).
      if (entries.isEmpty) {
        final latest = await _latestLogDateTime(
          controllerId: controllerId,
          variableId: variableId,
        );
        if (latest != null) {
          final fallbackSince = latest
              .subtract(Duration(days: effectiveDays))
              .toIso8601String();
          entries = await _queryLogTimeSeries(
            controllerId: controllerId,
            variableId: variableId,
            since: fallbackSince,
          );
        }
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

  /// [getLogTimeSeries] için ham sorgu + parse yardımcısı.
  ///
  /// Verilen [since] (ISO string, `date_time >=`) alt sınırından itibaren tüm
  /// tenant/organization/site/controller/variable filtrelerini uygular ve
  /// satırları [LogTimeSeriesEntry]'e çevirir. Sıralama: date_time ASC.
  Future<List<LogTimeSeriesEntry>> _queryLogTimeSeries({
    String? controllerId,
    String? variableId,
    required String since,
  }) async {
    // Tüm kolonları çek - hem date_time hem datetime (legacy) destekle.
    var query = _supabase.from('logs').select().gte('date_time', since);

    // Birincil filtre: controllerId veya variableId
    if (variableId != null) {
      query = query.eq('variable_id', variableId);
    }
    if (controllerId != null) {
      query = query.eq('controller_id', controllerId);
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

    final response = await query.order('date_time', ascending: true);

    final entries = <LogTimeSeriesEntry>[];
    for (final e in (response as List)) {
      final row = e as Map<String, dynamic>;

      // Dual column: date_time (current) / datetime (legacy)
      final dt = DbFieldHelpers.parseLogDateTime(row);
      if (dt == null) continue;

      final rawValue = row['value'] as String?;
      final numericValue = rawValue != null ? double.tryParse(rawValue) : null;

      // Dual column: on_off (current) / onoff (legacy)
      var onOff = DbFieldHelpers.parseLogOnOff(row);

      // DB'de on_off/onoff NULL olabilir - digital variable'lar
      // value alanında "0.0"/"1.0" tutar, bu durumda value'dan türet
      if (onOff == null && numericValue != null) {
        if (numericValue == 0.0 || numericValue == 1.0) {
          onOff = numericValue.toInt();
        }
      }

      entries.add(LogTimeSeriesEntry(
        dateTime: dt,
        value: numericValue,
        onOff: onOff,
        rawValue: rawValue,
      ));
    }
    return entries;
  }

  /// Filtrelenen küme için EN SON `date_time` değerini döndürür (yoksa null).
  ///
  /// Ucuz sorgu: yalnız date_time kolonu, date_time DESC, limit 1. Güncel
  /// pencere boş dönünce "son mevcut veri" penceresini konumlandırmak için
  /// kullanılır. NULL date_time satırları hariç tutulur (nullsFirst=false).
  Future<DateTime?> _latestLogDateTime({
    String? controllerId,
    String? variableId,
  }) async {
    var query = _supabase.from('logs').select('date_time');

    if (variableId != null) {
      query = query.eq('variable_id', variableId);
    }
    if (controllerId != null) {
      query = query.eq('controller_id', controllerId);
    }
    if (_currentTenantId != null) {
      query = query.eq('tenant_id', _currentTenantId!);
    }
    if (_currentOrganizationId != null) {
      query = query.eq('organization_id', _currentOrganizationId!);
    }
    if (_currentSiteId != null) {
      query = query.eq('site_id', _currentSiteId!);
    }

    final response = await query
        .order('date_time', ascending: false, nullsFirst: false)
        .limit(1);

    final list = response as List;
    if (list.isEmpty) return null;
    return DbFieldHelpers.parseLogDateTime(
        Map<String, dynamic>.from(list.first as Map));
  }

  /// Tarih aralığına göre log kayıtları
  ///
  /// [from] ve [to] arasındaki logları getirir.
  /// created_at üzerinden filtreleme yapılır (date_time NULL olabilir).
  /// Sıralama: created_at ASC (chart uyumlu).
  ///
  /// [controllerId] ve [variableId] parametrelerinden en az biri gereklidir.
  Future<List<IoTLog>> getLogsByTimeRange({
    String? controllerId,
    String? variableId,
    required DateTime from,
    required DateTime to,
    int limit = IoTConfig.maxListLimit,
  }) async {
    // En az bir filtre gerekli
    if (controllerId == null && variableId == null) {
      Logger.warning('getLogsByTimeRange: controllerId or variableId required');
      return [];
    }

    try {
      // DB'de created_at NULL - date_time üzerinden filtrele
      // TODO(perf): 1.97M satırlık `logs` fact tablosunu tarar (tarih aralığında
      // ham log satırları gerekiyor). Ham satır ihtiyacı olduğundan bırakıldı.
      var query = _supabase
          .from('logs')
          .select()
          .gte('date_time', from.toIso8601String())
          .lte('date_time', to.toIso8601String());

      // Birincil filtreler: controllerId veya variableId
      if (variableId != null) {
        query = query.eq('variable_id', variableId);
      }
      if (controllerId != null) {
        query = query.eq('controller_id', controllerId);
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
  ///
  /// [controllerId] ve [variableId] parametrelerinden en az biri gereklidir.
  Future<LogValueStats> getLogValueStats({
    String? controllerId,
    String? variableId,
    int days = IoTConfig.defaultDaysRange,
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

  /// Controller'a ait loglanmış variable listesini getirir
  ///
  /// Server RPC `fn_controller_logged_variables(p_controller_id)` üzerinden
  /// çalışır: RPC, `logs` fact tablosunda GERÇEKTEN loglanmış (distinct
  /// variable_id) variable'ları sunucu tarafında indexli olarak çözer;
  /// client'ta 1.97M satırlık logs taraması YAPILMAZ.
  ///
  /// RPC şu kolonları döner: id, name, code, description, measure_unit,
  /// data_type. Tüketiciler `variable_type` (ANALOG/INTEGER/DIGITAL) ile
  /// filtreliyor ve `unit`/`minimum`/`maximum` okuyabildiği için, dönen küçük
  /// id kümesi `variables` boyut tablosundan (PK'ye IN sorgusu) zenginleştirilir.
  /// variable_type (ANALOG, DIGITAL, INTEGER, ALARM) ile filtreleme desteklenir.
  Future<List<Map<String, dynamic>>> getLoggedVariables({
    required String controllerId,
    String? variableType,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'logged_vars_${controllerId}_${variableType ?? 'all'}';

    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        return cached.cast<Map<String, dynamic>>();
      }
    }

    // Server-side: controller için loglanmış distinct variable'lar.
    final rpcResponse = await _supabase.rpc(
      'fn_controller_logged_variables',
      params: {'p_controller_id': controllerId},
    );

    final rpcRows = (rpcResponse as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    if (rpcRows.isEmpty) {
      await _cacheManager.set(cacheKey, <Map<String, dynamic>>[],
          ttl: const Duration(minutes: 10));
      return [];
    }

    // RPC variable_type/unit/minimum/maximum döndürmüyor; tüketiciler bunlara
    // ihtiyaç duyduğundan küçük id kümesini variables boyut tablosundan
    // zenginleştir (logs fact tablosuna DOKUNMAZ).
    final ids = rpcRows
        .map((r) => r['id'] as String?)
        .whereType<String>()
        .toList();

    final enrichById = <String, Map<String, dynamic>>{};
    final enrichResponse = await _supabase
        .from('variables')
        .select('id, variable_type, unit, minimum, maximum')
        .inFilter('id', ids);
    for (final row in (enrichResponse as List)) {
      final m = Map<String, dynamic>.from(row as Map);
      final id = m['id'] as String?;
      if (id != null) enrichById[id] = m;
    }

    final results = <Map<String, dynamic>>[];
    for (final base in rpcRows) {
      final id = base['id'] as String?;
      if (id == null) continue;

      final merged = Map<String, dynamic>.from(base);
      final extra = enrichById[id];
      if (extra != null) {
        merged['variable_type'] = extra['variable_type'];
        merged['unit'] = extra['unit'];
        merged['minimum'] = extra['minimum'];
        merged['maximum'] = extra['maximum'];
      }

      // variable_type filtresi (tüketiciler ANALOG/INTEGER/DIGITAL geçiyor)
      if (variableType != null && merged['variable_type'] != variableType) {
        continue;
      }

      results.add(merged);
    }

    // İsme göre sırala
    results.sort((a, b) =>
        (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));

    await _cacheManager.set(cacheKey, results,
        ttl: const Duration(minutes: 10));

    return results;
  }

  void dispose() {
    _logsController.close();
  }
}
