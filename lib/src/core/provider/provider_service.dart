import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../utils/logger.dart';
import 'provider_model.dart';

/// Provider Service
///
/// IoT veri sağlayıcılarını yönetir.
class ProviderService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  /// Provider listesi stream
  final _providersController = StreamController<List<Provider>>.broadcast();

  /// Seçili provider stream
  final _selectedProvider = StreamController<Provider?>.broadcast();

  /// Mevcut tenant ID
  String? _currentTenantId;

  /// Mevcut provider listesi
  List<Provider> _providers = [];

  /// Seçili provider
  Provider? _selected;

  ProviderService({
    required SupabaseClient supabase,
    required CacheManager cacheManager,
  })  : _supabase = supabase,
        _cacheManager = cacheManager;

  // ============================================
  // GETTERS
  // ============================================

  /// Provider listesi stream
  Stream<List<Provider>> get providersStream => _providersController.stream;

  /// Seçili provider stream
  Stream<Provider?> get selectedStream => _selectedProvider.stream;

  /// Mevcut provider listesi
  List<Provider> get providers => List.unmodifiable(_providers);

  /// Seçili provider
  Provider? get selected => _selected;

  /// Aktif provider listesi
  List<Provider> get activeProviders =>
      _providers.where((p) => p.isActive).toList();

  /// Hata durumundaki provider listesi
  List<Provider> get errorProviders =>
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
  Future<List<Provider>> getAll({
    ProviderType? type,
    ProviderStatus? status,
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
            .map((e) => Provider.fromJson(e as Map<String, dynamic>))
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

      if (type != null) {
        query = query.eq('type', type.value);
      }

      if (status != null) {
        query = query.eq('status', status.name);
      }

      final response = await query.order('name');

      _providers = (response as List)
          .map((e) => Provider.fromJson(e as Map<String, dynamic>))
          .toList();

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
  Future<Provider?> getById(String id) async {
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

      return Provider.fromJson(response);
    } catch (e, stackTrace) {
      Logger.error('Failed to get provider by id', e, stackTrace);
      rethrow;
    }
  }

  /// Provider oluştur
  Future<Provider> create(Provider provider) async {
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

      final created = Provider.fromJson(response);

      _providers.add(created);
      _providersController.add(_providers);

      // Cache'i temizle
      await _invalidateCache();

      Logger.info('Provider created: ${created.name}');
      return created;
    } catch (e, stackTrace) {
      Logger.error('Failed to create provider', e, stackTrace);
      rethrow;
    }
  }

  /// Provider güncelle
  Future<Provider> update(Provider provider) async {
    try {
      final data = provider.toJson();
      data['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('providers')
          .update(data)
          .eq('id', provider.id)
          .select()
          .single();

      final updated = Provider.fromJson(response);

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

      Logger.info('Provider updated: ${updated.name}');
      return updated;
    } catch (e, stackTrace) {
      Logger.error('Failed to update provider', e, stackTrace);
      rethrow;
    }
  }

  /// Provider sil
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

      Logger.info('Provider deleted: $id');
    } catch (e, stackTrace) {
      Logger.error('Failed to delete provider', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // STATUS OPERATIONS
  // ============================================

  /// Provider durumunu güncelle
  Future<void> updateStatus(String id, ProviderStatus status) async {
    try {
      await _supabase.from('providers').update({
        'status': status.name,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      // Liste güncelle
      final index = _providers.indexWhere((p) => p.id == id);
      if (index != -1) {
        _providers[index] = _providers[index].copyWith(status: status);
        _providersController.add(_providers);
      }

      Logger.debug('Provider status updated: $id -> ${status.name}');
    } catch (e, stackTrace) {
      Logger.error('Failed to update provider status', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // CONNECTION TEST
  // ============================================

  /// Provider bağlantısını test et
  Future<ProviderConnectionTestResult> testConnection(Provider provider) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Bu metod gerçek uygulamada protokole göre farklı
      // bağlantı testleri yapacaktır.
      // Şimdilik basit bir simülasyon yapıyoruz.

      await Future.delayed(const Duration(milliseconds: 500));

      stopwatch.stop();

      // Bağlantı bilgisi kontrolü
      if (!provider.hasConnectionInfo) {
        return ProviderConnectionTestResult.failure(
          message: 'Bağlantı bilgisi eksik',
          errorDetail: 'Host veya connection string belirtilmemiş',
        );
      }

      return ProviderConnectionTestResult.success(
        message: 'Bağlantı başarılı',
        responseTimeMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return ProviderConnectionTestResult.failure(
        message: 'Bağlantı başarısız',
        errorDetail: e.toString(),
      );
    }
  }

  // ============================================
  // SELECTION
  // ============================================

  /// Provider seç
  void select(Provider? provider) {
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

  /// Provider ara
  Future<List<Provider>> search(String query) async {
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
      await _cacheManager.removeByPrefix('providers_$_currentTenantId');
    }
  }

  /// Servisi temizle
  void dispose() {
    _providersController.close();
    _selectedProvider.close();
  }
}
