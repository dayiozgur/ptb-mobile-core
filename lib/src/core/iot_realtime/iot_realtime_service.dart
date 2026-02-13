import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../utils/logger.dart';
import 'iot_realtime_model.dart';

/// IoT Realtime Service
///
/// Controller-Variable bağlantısını realtimes junction tablosu
/// üzerinden yönetir. Bu servis IoT verilerini controller bazlı
/// izole eder ve provider çakışmalarını önler.
///
/// DB Tablosu: realtimes
/// Junction: controllers ↔ variables
class IoTRealtimeService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  /// Realtime listesi stream
  final _realtimesController = StreamController<List<IoTRealtime>>.broadcast();

  /// Mevcut tenant ID
  String? _currentTenantId;

  /// Mevcut realtime listesi
  List<IoTRealtime> _realtimes = [];

  IoTRealtimeService({
    required SupabaseClient supabase,
    required CacheManager cacheManager,
  })  : _supabase = supabase,
        _cacheManager = cacheManager;

  // ============================================
  // GETTERS
  // ============================================

  /// Realtime listesi stream
  Stream<List<IoTRealtime>> get realtimesStream => _realtimesController.stream;

  /// Mevcut realtime listesi
  List<IoTRealtime> get realtimes => List.unmodifiable(_realtimes);

  // ============================================
  // TENANT CONTEXT
  // ============================================

  /// Tenant context'ini ayarla
  void setTenant(String tenantId) {
    if (_currentTenantId != tenantId) {
      _currentTenantId = tenantId;
      _realtimes = [];
      _realtimesController.add(_realtimes);
    }
  }

  /// Tenant context'ini temizle
  void clearTenant() {
    _currentTenantId = null;
    _realtimes = [];
    _realtimesController.add(_realtimes);
  }

  // ============================================
  // QUERY OPERATIONS
  // ============================================

  /// Controller'a ait variable'ları realtimes üzerinden getir
  ///
  /// Bu metod realtimes junction tablosunu kullanarak
  /// controller-level izolasyon sağlar.
  Future<List<IoTRealtime>> getByController(
    String controllerId, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'iot_realtimes_controller_$controllerId';

    // Cache kontrolü
    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        final result = cached
            .map((e) => IoTRealtime.fromJson(e as Map<String, dynamic>))
            .toList();
        return result;
      }
    }

    try {
      final response = await _supabase
          .from('realtimes')
          .select('*, variables(*)')
          .eq('controller_id', controllerId)
          .order('name');

      final result = (response as List)
          .map((e) => IoTRealtime.fromJson(e as Map<String, dynamic>))
          .toList();

      // Cache'e kaydet
      await _cacheManager.set(
        cacheKey,
        response,
        ttl: const Duration(minutes: 2),
      );

      return result;
    } catch (e, stackTrace) {
      Logger.error('Failed to get realtimes by controller', e, stackTrace);
      rethrow;
    }
  }

  /// Site'a ait tüm realtimes verilerini getir
  ///
  /// Controller'lar üzerinden site bazlı filtreleme yapar.
  Future<List<IoTRealtime>> getBySite(
    String siteId, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'iot_realtimes_site_$siteId';

    // Cache kontrolü
    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        final result = cached
            .map((e) => IoTRealtime.fromJson(e as Map<String, dynamic>))
            .toList();
        _realtimes = result;
        _realtimesController.add(_realtimes);
        return result;
      }
    }

    try {
      // Önce site'a ait controller ID'lerini al
      final controllersResponse = await _supabase
          .from('controllers')
          .select('id')
          .eq('site_id', siteId);

      final controllerIds = (controllersResponse as List)
          .map((e) => e['id'] as String)
          .toList();

      if (controllerIds.isEmpty) {
        _realtimes = [];
        _realtimesController.add(_realtimes);
        return _realtimes;
      }

      // Realtimes'ı controller_id'lere göre getir
      final response = await _supabase
          .from('realtimes')
          .select('*, variables(*)')
          .inFilter('controller_id', controllerIds)
          .order('name');

      _realtimes = (response as List)
          .map((e) => IoTRealtime.fromJson(e as Map<String, dynamic>))
          .toList();

      // Cache'e kaydet
      await _cacheManager.set(
        cacheKey,
        response,
        ttl: const Duration(minutes: 2),
      );

      _realtimesController.add(_realtimes);
      return _realtimes;
    } catch (e, stackTrace) {
      Logger.error('Failed to get realtimes by site', e, stackTrace);
      rethrow;
    }
  }

  /// Provider'a ait tüm realtimes verilerini getir
  ///
  /// Provider → Controller → Realtimes zincirini takip eder.
  Future<List<IoTRealtime>> getByProvider(
    String providerId, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'iot_realtimes_provider_$providerId';

    // Cache kontrolü
    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        return cached
            .map((e) => IoTRealtime.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }

    try {
      // Önce provider'a ait controller ID'lerini al
      final controllersResponse = await _supabase
          .from('controllers')
          .select('id')
          .eq('provider_id', providerId);

      final controllerIds = (controllersResponse as List)
          .map((e) => e['id'] as String)
          .toList();

      if (controllerIds.isEmpty) {
        return [];
      }

      // Realtimes'ı controller_id'lere göre getir
      final response = await _supabase
          .from('realtimes')
          .select('*, variables(*)')
          .inFilter('controller_id', controllerIds)
          .order('name');

      final result = (response as List)
          .map((e) => IoTRealtime.fromJson(e as Map<String, dynamic>))
          .toList();

      // Cache'e kaydet
      await _cacheManager.set(
        cacheKey,
        response,
        ttl: const Duration(minutes: 2),
      );

      return result;
    } catch (e, stackTrace) {
      Logger.error('Failed to get realtimes by provider', e, stackTrace);
      rethrow;
    }
  }

  /// Tüm realtimes verilerini getir (tenant bazlı)
  Future<List<IoTRealtime>> getAll({
    bool forceRefresh = false,
  }) async {
    if (_currentTenantId == null) {
      throw Exception('Tenant context is not set');
    }

    final cacheKey = 'iot_realtimes_all_$_currentTenantId';

    // Cache kontrolü
    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        _realtimes = cached
            .map((e) => IoTRealtime.fromJson(e as Map<String, dynamic>))
            .toList();
        _realtimesController.add(_realtimes);
        return _realtimes;
      }
    }

    try {
      // Tenant'a ait controller ID'lerini al
      final controllersResponse = await _supabase
          .from('controllers')
          .select('id')
          .eq('tenant_id', _currentTenantId!);

      final controllerIds = (controllersResponse as List)
          .map((e) => e['id'] as String)
          .toList();

      if (controllerIds.isEmpty) {
        _realtimes = [];
        _realtimesController.add(_realtimes);
        return _realtimes;
      }

      // Realtimes'ı controller_id'lere göre getir
      final response = await _supabase
          .from('realtimes')
          .select('*, variables(*)')
          .inFilter('controller_id', controllerIds)
          .order('name');

      _realtimes = (response as List)
          .map((e) => IoTRealtime.fromJson(e as Map<String, dynamic>))
          .toList();

      // Cache'e kaydet
      await _cacheManager.set(
        cacheKey,
        response,
        ttl: const Duration(minutes: 2),
      );

      _realtimesController.add(_realtimes);
      return _realtimes;
    } catch (e, stackTrace) {
      Logger.error('Failed to get all realtimes', e, stackTrace);
      rethrow;
    }
  }

  /// ID ile realtime getir
  Future<IoTRealtime?> getById(String id) async {
    // Önce memory cache'den kontrol
    final cached = _realtimes.where((r) => r.id == id).firstOrNull;
    if (cached != null) return cached;

    try {
      final response = await _supabase
          .from('realtimes')
          .select('*, variables(*)')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      return IoTRealtime.fromJson(response);
    } catch (e, stackTrace) {
      Logger.error('Failed to get realtime by id', e, stackTrace);
      rethrow;
    }
  }

  /// Variable ID ile realtime (controller bağlantısı) getir
  ///
  /// Variable'ın hangi controller'a bağlı olduğunu bulmak için kullanılır.
  /// Log grafiklerinde variable bazlı sorgulama için controller bilgisine ihtiyaç duyulabilir.
  Future<IoTRealtime?> getByVariableId(String variableId) async {
    // Önce memory cache'den kontrol
    final cached = _realtimes.where((r) => r.variableId == variableId).firstOrNull;
    if (cached != null) return cached;

    try {
      final response = await _supabase
          .from('realtimes')
          .select('*, variables(*)')
          .eq('variable_id', variableId)
          .maybeSingle();

      if (response == null) return null;

      return IoTRealtime.fromJson(response);
    } catch (e, stackTrace) {
      Logger.error('Failed to get realtime by variable_id', e, stackTrace);
      return null;
    }
  }

  /// Variable ID ile controller ID getir
  ///
  /// Variable'ın bağlı olduğu controller'ın ID'sini döner.
  /// Log grafiklerinde hiyerarşi takibi için kullanılır:
  /// Provider → Controller → Device Model → Variable → Logs
  Future<String?> getControllerIdByVariable(String variableId) async {
    final realtime = await getByVariableId(variableId);
    return realtime?.controllerId;
  }

  // ============================================
  // STATISTICS
  // ============================================

  /// Controller bazlı realtime sayılarını getir
  Future<Map<String, int>> getCountsByController(String siteId) async {
    try {
      final controllersResponse = await _supabase
          .from('controllers')
          .select('id')
          .eq('site_id', siteId);

      final controllerIds = (controllersResponse as List)
          .map((e) => e['id'] as String)
          .toList();

      if (controllerIds.isEmpty) return {};

      final response = await _supabase
          .from('realtimes')
          .select('controller_id')
          .inFilter('controller_id', controllerIds);

      final counts = <String, int>{};
      for (final row in response as List) {
        final cId = row['controller_id'] as String;
        counts[cId] = (counts[cId] ?? 0) + 1;
      }

      return counts;
    } catch (e, stackTrace) {
      Logger.error('Failed to get realtime counts', e, stackTrace);
      return {};
    }
  }

  // ============================================
  // HELPERS
  // ============================================

  /// Cache'i temizle
  Future<void> invalidateCache() async {
    await _cacheManager.deleteByPrefix('iot_realtimes_');
  }

  /// Servisi temizle
  void dispose() {
    _realtimesController.close();
  }
}
