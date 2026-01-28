import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../utils/logger.dart';
import 'controller_model.dart';

/// Controller Service
///
/// IoT controller'larını yönetir.
class ControllerService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  /// Controller listesi stream
  final _controllersController = StreamController<List<Controller>>.broadcast();

  /// Seçili controller stream
  final _selectedController = StreamController<Controller?>.broadcast();

  /// Mevcut tenant ID
  String? _currentTenantId;

  /// Mevcut controller listesi
  List<Controller> _controllers = [];

  /// Seçili controller
  Controller? _selected;

  ControllerService({
    required SupabaseClient supabase,
    required CacheManager cacheManager,
  })  : _supabase = supabase,
        _cacheManager = cacheManager;

  // ============================================
  // GETTERS
  // ============================================

  /// Controller listesi stream
  Stream<List<Controller>> get controllersStream => _controllersController.stream;

  /// Seçili controller stream
  Stream<Controller?> get selectedStream => _selectedController.stream;

  /// Mevcut controller listesi
  List<Controller> get controllers => List.unmodifiable(_controllers);

  /// Seçili controller
  Controller? get selected => _selected;

  /// Çevrimiçi controller listesi
  List<Controller> get onlineControllers =>
      _controllers.where((c) => c.isOnline).toList();

  /// Çevrimdışı controller listesi
  List<Controller> get offlineControllers =>
      _controllers.where((c) => c.isOffline).toList();

  /// Hata durumundaki controller listesi
  List<Controller> get errorControllers =>
      _controllers.where((c) => c.hasError).toList();

  // ============================================
  // TENANT CONTEXT
  // ============================================

  /// Tenant context'ini ayarla
  void setTenant(String tenantId) {
    if (_currentTenantId != tenantId) {
      _currentTenantId = tenantId;
      _controllers = [];
      _selected = null;
      _controllersController.add(_controllers);
      _selectedController.add(_selected);
    }
  }

  /// Tenant context'ini temizle
  void clearTenant() {
    _currentTenantId = null;
    _controllers = [];
    _selected = null;
    _controllersController.add(_controllers);
    _selectedController.add(_selected);
  }

  // ============================================
  // CRUD OPERATIONS
  // ============================================

  /// Tüm controller'ları getir
  Future<List<Controller>> getAll({
    String? siteId,
    String? unitId,
    ControllerStatus? status,
    ControllerType? type,
    bool forceRefresh = false,
  }) async {
    if (_currentTenantId == null) {
      throw Exception('Tenant context is not set');
    }

    final cacheKey = 'controllers_${_currentTenantId}_${siteId ?? 'all'}_${unitId ?? 'all'}';

    // Cache kontrolü
    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        try {
          _controllers = cached
              .map((e) => Controller.fromJson(e as Map<String, dynamic>))
              .toList();
          _controllersController.add(_controllers);
          return _controllers;
        } catch (cacheError) {
          Logger.warning('Failed to parse controllers from cache, fetching fresh: $cacheError');
          // Cache bozuksa temizle ve DB'den yükle
          await _cacheManager.delete(cacheKey);
        }
      }
    }

    try {
      var query = _supabase
          .from('controllers')
          .select()
          .eq('tenant_id', _currentTenantId!);

      if (siteId != null) {
        query = query.eq('site_id', siteId);
      }

      if (unitId != null) {
        query = query.eq('unit_id', unitId);
      }

      // NOT: DB'de 'status' ve 'type' kolonları yok.
      // status → is_enabled + is_canceled, type → supervisor_type_id (FK)
      // Filtreleme client-side yapılır.

      final response = await query.order('name');
      final responseList = response as List;
      Logger.debug('Controllers query returned ${responseList.length} records for tenant: $_currentTenantId');

      var controllers = <Controller>[];
      for (final e in responseList) {
        try {
          controllers.add(Controller.fromJson(e as Map<String, dynamic>));
        } catch (parseError) {
          Logger.warning('Failed to parse controller: $parseError, data: ${(e as Map)['id'] ?? 'unknown'}');
        }
      }
      Logger.debug('Parsed ${controllers.length}/${responseList.length} controllers successfully');

      // Client-side filtreleme
      if (status != null) {
        controllers = controllers.where((c) => c.status == status).toList();
      }

      if (type != null) {
        controllers = controllers.where((c) => c.type == type).toList();
      }

      _controllers = controllers;

      // Cache'e kaydet
      await _cacheManager.set(
        cacheKey,
        _controllers.map((e) => e.toJson()).toList(),
        ttl: const Duration(minutes: 5),
      );

      _controllersController.add(_controllers);
      return _controllers;
    } catch (e, stackTrace) {
      Logger.error('Failed to get controllers', e, stackTrace);
      rethrow;
    }
  }

  /// ID ile controller getir
  Future<Controller?> getById(String id) async {
    // Önce memory cache'den kontrol
    final cached = _controllers.where((c) => c.id == id).firstOrNull;
    if (cached != null) return cached;

    try {
      final response = await _supabase
          .from('controllers')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      return Controller.fromJson(response);
    } catch (e, stackTrace) {
      Logger.error('Failed to get controller by id', e, stackTrace);
      rethrow;
    }
  }

  /// Controller oluştur
  Future<Controller> create(Controller controller) async {
    if (_currentTenantId == null) {
      throw Exception('Tenant context is not set');
    }

    try {
      final data = controller.toJson();
      data['tenant_id'] = _currentTenantId;
      data.remove('id');
      data['created_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('controllers')
          .insert(data)
          .select()
          .single();

      final created = Controller.fromJson(response);

      _controllers.add(created);
      _controllersController.add(_controllers);

      // Cache'i temizle
      await _invalidateCache();

      Logger.info('Controller created: ${created.name}');
      return created;
    } catch (e, stackTrace) {
      Logger.error('Failed to create controller', e, stackTrace);
      rethrow;
    }
  }

  /// Controller güncelle
  Future<Controller> update(Controller controller) async {
    try {
      final data = controller.toJson();
      data['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('controllers')
          .update(data)
          .eq('id', controller.id)
          .select()
          .single();

      final updated = Controller.fromJson(response);

      // Liste güncelle
      final index = _controllers.indexWhere((c) => c.id == controller.id);
      if (index != -1) {
        _controllers[index] = updated;
        _controllersController.add(_controllers);
      }

      // Seçili controller güncelle
      if (_selected?.id == controller.id) {
        _selected = updated;
        _selectedController.add(_selected);
      }

      // Cache'i temizle
      await _invalidateCache();

      Logger.info('Controller updated: ${updated.name}');
      return updated;
    } catch (e, stackTrace) {
      Logger.error('Failed to update controller', e, stackTrace);
      rethrow;
    }
  }

  /// Controller sil
  Future<void> delete(String id) async {
    try {
      await _supabase.from('controllers').delete().eq('id', id);

      _controllers.removeWhere((c) => c.id == id);
      _controllersController.add(_controllers);

      if (_selected?.id == id) {
        _selected = null;
        _selectedController.add(_selected);
      }

      // Cache'i temizle
      await _invalidateCache();

      Logger.info('Controller deleted: $id');
    } catch (e, stackTrace) {
      Logger.error('Failed to delete controller', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // STATUS OPERATIONS
  // ============================================

  /// Controller durumunu güncelle
  Future<void> updateStatus(String id, ControllerStatus status) async {
    try {
      // DB'de status kolonu yok, is_enabled ve is_canceled kullanılır
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (status == ControllerStatus.disabled) {
        updates['is_canceled'] = true;
      } else if (status == ControllerStatus.offline) {
        updates['is_enabled'] = false;
      } else {
        updates['is_enabled'] = true;
        updates['is_canceled'] = false;
      }
      await _supabase.from('controllers').update(updates).eq('id', id);

      // Liste güncelle
      final index = _controllers.indexWhere((c) => c.id == id);
      if (index != -1) {
        _controllers[index] = _controllers[index].copyWith(status: status);
        _controllersController.add(_controllers);
      }

      Logger.debug('Controller status updated: $id -> ${status.name}');
    } catch (e, stackTrace) {
      Logger.error('Failed to update controller status', e, stackTrace);
      rethrow;
    }
  }

  /// Son bağlantı zamanını güncelle
  Future<void> updateLastConnected(String id, {String? error}) async {
    try {
      final updates = <String, dynamic>{
        'last_connection_time': DateTime.now().toIso8601String(),
      };

      if (error != null) {
        updates['is_enabled'] = false;
      } else {
        updates['is_enabled'] = true;
      }

      await _supabase.from('controllers').update(updates).eq('id', id);

      Logger.debug('Controller last connected updated: $id');
    } catch (e, stackTrace) {
      Logger.error('Failed to update last connected', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // STATISTICS
  // ============================================

  /// Controller istatistiklerini getir
  Future<ControllerStats> getStats() async {
    if (_currentTenantId == null) {
      return const ControllerStats();
    }

    try {
      final response = await _supabase
          .from('controllers')
          .select('id, is_enabled, is_canceled, active')
          .eq('tenant_id', _currentTenantId!);

      final rows = response as List;
      int enabledCount = 0;
      int disabledCount = 0;
      int canceledCount = 0;

      for (final row in rows) {
        final isCanceled = row['is_canceled'] as bool? ?? false;
        final isEnabled = row['is_enabled'] as bool? ?? true;
        if (isCanceled) {
          canceledCount++;
        } else if (isEnabled) {
          enabledCount++;
        } else {
          disabledCount++;
        }
      }

      return ControllerStats(
        totalCount: rows.length,
        onlineCount: enabledCount,
        offlineCount: disabledCount,
        errorCount: canceledCount,
        maintenanceCount: 0,
      );
    } catch (e, stackTrace) {
      Logger.error('Failed to get controller stats', e, stackTrace);
      return const ControllerStats();
    }
  }

  // ============================================
  // SELECTION
  // ============================================

  /// Controller seç
  void select(Controller? controller) {
    _selected = controller;
    _selectedController.add(_selected);
  }

  /// ID ile controller seç
  Future<void> selectById(String id) async {
    final controller = await getById(id);
    select(controller);
  }

  // ============================================
  // SEARCH
  // ============================================

  /// Controller ara
  Future<List<Controller>> search(String query) async {
    if (_currentTenantId == null) {
      return [];
    }

    if (query.isEmpty) {
      return _controllers;
    }

    final lowerQuery = query.toLowerCase();
    return _controllers.where((c) {
      return c.name.toLowerCase().contains(lowerQuery) ||
          (c.code?.toLowerCase().contains(lowerQuery) ?? false) ||
          (c.ipAddress?.contains(query) ?? false) ||
          (c.brand?.toLowerCase().contains(lowerQuery) ?? false) ||
          (c.model?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  // ============================================
  // HELPERS
  // ============================================

  /// Cache'i temizle
  Future<void> _invalidateCache() async {
    if (_currentTenantId != null) {
      await _cacheManager.deleteByPrefix('controllers_$_currentTenantId');
    }
  }

  /// Servisi temizle
  void dispose() {
    _controllersController.close();
    _selectedController.close();
  }
}
