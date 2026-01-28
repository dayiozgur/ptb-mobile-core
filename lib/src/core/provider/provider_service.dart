import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../utils/logger.dart';
import 'provider_model.dart';

/// DataProvider Service
///
/// IoT veri sağlayıcılarını yönetir.
class DataProviderService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  /// DataProvider listesi stream
  final _providersController = StreamController<List<DataProvider>>.broadcast();

  /// Seçili provider stream
  final _selectedProvider = StreamController<DataProvider?>.broadcast();

  /// Mevcut tenant ID
  String? _currentTenantId;

  /// Mevcut provider listesi
  List<DataProvider> _providers = [];

  /// Seçili provider
  DataProvider? _selected;

  DataProviderService({
    required SupabaseClient supabase,
    required CacheManager cacheManager,
  })  : _supabase = supabase,
        _cacheManager = cacheManager;

  // ============================================
  // GETTERS
  // ============================================

  /// DataProvider listesi stream
  Stream<List<DataProvider>> get providersStream => _providersController.stream;

  /// Seçili provider stream
  Stream<DataProvider?> get selectedStream => _selectedProvider.stream;

  /// Mevcut provider listesi
  List<DataProvider> get providers => List.unmodifiable(_providers);

  /// Seçili provider
  DataProvider? get selected => _selected;

  /// Aktif provider listesi
  List<DataProvider> get activeProviders =>
      _providers.where((p) => p.isActive).toList();

  /// Hata durumundaki provider listesi
  List<DataProvider> get errorProviders =>
      _providers.where((p) => p.hasError).toList();

  // ============================================
  // TENANT CONTEXT
  // ============================================

  /// Tenant context'ini ayarla
  void setTenant(String tenantId) {
    if (_currentTenantId != tenantId) {
      _currentTenantId = tenantId;
      _providers = [];
      _selected = null;
      _providersController.add(_providers);
      _selectedProvider.add(_selected);
    }
  }

  /// Tenant context'ini temizle
  void clearTenant() {
    _currentTenantId = null;
    _providers = [];
    _selected = null;
    _providersController.add(_providers);
    _selectedProvider.add(_selected);
  }

  // ============================================
  // CRUD OPERATIONS
  // ============================================

  /// Tüm provider'ları getir
  Future<List<DataProvider>> getAll({
    DataProviderType? type,
    DataProviderStatus? status,
    bool forceRefresh = false,
  }) async {
    if (_currentTenantId == null) {
      throw Exception('Tenant context is not set');
    }

    final cacheKey = 'providers_${_currentTenantId}_${type?.value ?? 'all'}';

    // Cache kontrolü
    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        _providers = cached
            .map((e) => DataProvider.fromJson(e as Map<String, dynamic>))
            .toList();
        _providersController.add(_providers);
        return _providers;
      }
    }

    try {
      var query = _supabase
          .from('providers')
          .select()
          .eq('tenant_id', _currentTenantId!);

      // NOT: DB'de 'type' ve 'status' kolonları yok.
      // type → protocol_type_id (FK), status yok.
      // Filtreleme client-side yapılır.

      final response = await query.order('name');

      var providers = (response as List)
          .map((e) => DataProvider.fromJson(e as Map<String, dynamic>))
          .toList();

      // Client-side filtreleme
      if (type != null) {
        providers = providers.where((p) => p.type == type).toList();
      }

      if (status != null) {
        providers = providers.where((p) => p.status == status).toList();
      }

      _providers = providers;

      // Cache'e kaydet
      await _cacheManager.set(
        cacheKey,
        _providers.map((e) => e.toJson()).toList(),
        ttl: const Duration(minutes: 5),
      );

      _providersController.add(_providers);
      return _providers;
    } catch (e, stackTrace) {
      Logger.error('Failed to get providers', e, stackTrace);
      rethrow;
    }
  }

  /// ID ile provider getir
  Future<DataProvider?> getById(String id) async {
    // Önce memory cache'den kontrol
    final cached = _providers.where((p) => p.id == id).firstOrNull;
    if (cached != null) return cached;

    try {
      final response = await _supabase
          .from('providers')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      return DataProvider.fromJson(response);
    } catch (e, stackTrace) {
      Logger.error('Failed to get provider by id', e, stackTrace);
      rethrow;
    }
  }

  /// DataProvider oluştur
  Future<DataProvider> create(DataProvider provider) async {
    if (_currentTenantId == null) {
      throw Exception('Tenant context is not set');
    }

    try {
      final data = provider.toJson();
      data['tenant_id'] = _currentTenantId;
      data.remove('id');
      data['created_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('providers')
          .insert(data)
          .select()
          .single();

      final created = DataProvider.fromJson(response);

      _providers.add(created);
      _providersController.add(_providers);

      // Cache'i temizle
      await _invalidateCache();

      Logger.info('DataProvider created: ${created.name}');
      return created;
    } catch (e, stackTrace) {
      Logger.error('Failed to create provider', e, stackTrace);
      rethrow;
    }
  }

  /// DataProvider güncelle
  Future<DataProvider> update(DataProvider provider) async {
    try {
      final data = provider.toJson();
      data['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('providers')
          .update(data)
          .eq('id', provider.id)
          .select()
          .single();

      final updated = DataProvider.fromJson(response);

      // Liste güncelle
      final index = _providers.indexWhere((p) => p.id == provider.id);
      if (index != -1) {
        _providers[index] = updated;
        _providersController.add(_providers);
      }

      // Seçili provider güncelle
      if (_selected?.id == provider.id) {
        _selected = updated;
        _selectedProvider.add(_selected);
      }

      // Cache'i temizle
      await _invalidateCache();

      Logger.info('DataProvider updated: ${updated.name}');
      return updated;
    } catch (e, stackTrace) {
      Logger.error('Failed to update provider', e, stackTrace);
      rethrow;
    }
  }

  /// DataProvider sil
  Future<void> delete(String id) async {
    try {
      await _supabase.from('providers').delete().eq('id', id);

      _providers.removeWhere((p) => p.id == id);
      _providersController.add(_providers);

      if (_selected?.id == id) {
        _selected = null;
        _selectedProvider.add(_selected);
      }

      // Cache'i temizle
      await _invalidateCache();

      Logger.info('DataProvider deleted: $id');
    } catch (e, stackTrace) {
      Logger.error('Failed to delete provider', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // STATUS OPERATIONS
  // ============================================

  /// DataProvider durumunu güncelle
  ///
  /// NOT: DB'de status kolonu yok. Bu metod sadece memory state'i günceller.
  Future<void> updateStatus(String id, DataProviderStatus status) async {
    try {
      await _supabase.from('providers').update({
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      // Liste güncelle
      final index = _providers.indexWhere((p) => p.id == id);
      if (index != -1) {
        _providers[index] = _providers[index].copyWith(status: status);
        _providersController.add(_providers);
      }

      Logger.debug('DataProvider status updated: $id -> ${status.name}');
    } catch (e, stackTrace) {
      Logger.error('Failed to update provider status', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // CONNECTION TEST
  // ============================================

  /// DataProvider bağlantısını test et
  Future<DataProviderConnectionTestResult> testConnection(DataProvider provider) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Bu metod gerçek uygulamada protokole göre farklı
      // bağlantı testleri yapacaktır.
      // Şimdilik basit bir simülasyon yapıyoruz.

      await Future.delayed(const Duration(milliseconds: 500));

      stopwatch.stop();

      // Bağlantı bilgisi kontrolü
      if (!provider.hasConnectionInfo) {
        return DataProviderConnectionTestResult.failure(
          message: 'Bağlantı bilgisi eksik',
          errorDetail: 'Host veya connection string belirtilmemiş',
        );
      }

      return DataProviderConnectionTestResult.success(
        message: 'Bağlantı başarılı',
        responseTimeMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return DataProviderConnectionTestResult.failure(
        message: 'Bağlantı başarısız',
        errorDetail: e.toString(),
      );
    }
  }

  // ============================================
  // SELECTION
  // ============================================

  /// DataProvider seç
  void select(DataProvider? provider) {
    _selected = provider;
    _selectedProvider.add(_selected);
  }

  /// ID ile provider seç
  Future<void> selectById(String id) async {
    final provider = await getById(id);
    select(provider);
  }

  // ============================================
  // SEARCH
  // ============================================

  /// DataProvider ara
  Future<List<DataProvider>> search(String query) async {
    if (_currentTenantId == null) {
      return [];
    }

    if (query.isEmpty) {
      return _providers;
    }

    final lowerQuery = query.toLowerCase();
    return _providers.where((p) {
      return p.name.toLowerCase().contains(lowerQuery) ||
          (p.code?.toLowerCase().contains(lowerQuery) ?? false) ||
          (p.host?.contains(query) ?? false) ||
          p.type.label.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  // ============================================
  // HELPERS
  // ============================================

  /// Cache'i temizle
  Future<void> _invalidateCache() async {
    if (_currentTenantId != null) {
      await _cacheManager.deleteByPrefix('providers_$_currentTenantId');
    }
  }

  /// Servisi temizle
  void dispose() {
    _providersController.close();
    _selectedProvider.close();
  }
}
