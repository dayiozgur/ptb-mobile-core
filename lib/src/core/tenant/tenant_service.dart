import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../api/api_client.dart';
import '../storage/cache_manager.dart';
import '../storage/secure_storage.dart';
import '../utils/logger.dart';
import 'tenant_model.dart';

/// Tenant değişikliği callback
typedef TenantChangeCallback = void Function(Tenant? tenant);

/// Tenant Servisi
///
/// Multi-tenant mimarisinde tenant yönetimi için.
/// Tenant seçimi, geçişi ve bilgi erişimi sağlar.
///
/// Örnek kullanım:
/// ```dart
/// final tenantService = TenantService(
///   supabase: Supabase.instance.client,
///   secureStorage: SecureStorage(),
///   cacheManager: CacheManager(),
/// );
///
/// // Tenant listesi
/// final tenants = await tenantService.getUserTenants(userId);
///
/// // Tenant seç
/// await tenantService.selectTenant(tenantId);
///
/// // Mevcut tenant
/// final current = tenantService.currentTenant;
/// ```
class TenantService {
  final SupabaseClient _supabase;
  final SecureStorage _secureStorage;
  final CacheManager _cacheManager;
  final ApiClient? _apiClient;

  // State
  Tenant? _currentTenant;
  List<Tenant> _userTenants = [];
  TenantMembership? _currentMembership;

  // Stream controllers
  final _tenantController = StreamController<Tenant?>.broadcast();
  final _tenantsController = StreamController<List<Tenant>>.broadcast();

  // Cache keys
  static const String _currentTenantKey = 'current_tenant_id';
  static const String _tenantsCacheKey = 'user_tenants';

  TenantService({
    required SupabaseClient supabase,
    required SecureStorage secureStorage,
    required CacheManager cacheManager,
    ApiClient? apiClient,
  })  : _supabase = supabase,
        _secureStorage = secureStorage,
        _cacheManager = cacheManager,
        _apiClient = apiClient;

  // ============================================
  // GETTERS
  // ============================================

  /// Mevcut seçili tenant
  Tenant? get currentTenant => _currentTenant;

  /// Tenant ID
  String? get currentTenantId => _currentTenant?.id;

  /// Kullanıcının tenant listesi
  List<Tenant> get userTenants => List.unmodifiable(_userTenants);

  /// Mevcut membership
  TenantMembership? get currentMembership => _currentMembership;

  /// Mevcut rol
  TenantRole? get currentRole => _currentMembership?.role;

  /// Tenant seçili mi?
  bool get hasTenant => _currentTenant != null;

  /// Tenant değişiklik stream'i
  Stream<Tenant?> get tenantStream => _tenantController.stream;

  /// Tenant listesi değişiklik stream'i
  Stream<List<Tenant>> get tenantsStream => _tenantsController.stream;

  // ============================================
  // INITIALIZATION
  // ============================================

  /// Son seçili tenant'ı restore et
  Future<Tenant?> restoreLastTenant() async {
    try {
      final tenantId = await _secureStorage.read(_currentTenantKey);
      if (tenantId == null) return null;

      // Cache'den dene
      final cachedTenant = await _cacheManager.getTyped<Tenant>(
        key: 'tenant_$tenantId',
        fromJson: Tenant.fromJson,
      );

      if (cachedTenant != null) {
        _setCurrentTenant(cachedTenant);
        return cachedTenant;
      }

      // API'den getir
      final tenant = await getTenant(tenantId);
      if (tenant != null) {
        _setCurrentTenant(tenant);
      }
      return tenant;
    } catch (e) {
      Logger.error('Failed to restore last tenant', e);
      return null;
    }
  }

  // ============================================
  // TENANT OPERATIONS
  // ============================================

  /// Tenant seç
  Future<bool> selectTenant(String tenantId) async {
    try {
      Logger.debug('Selecting tenant: $tenantId');

      // Tenant bilgisi al
      final tenant = await getTenant(tenantId);
      if (tenant == null) {
        Logger.warning('Tenant not found: $tenantId');
        return false;
      }

      // Tenant aktif mi kontrol et
      if (!tenant.isActive && !tenant.isTrial) {
        Logger.warning('Tenant is not active: $tenantId (${tenant.status})');
        return false;
      }

      // Seçili tenant'ı güncelle
      _setCurrentTenant(tenant);

      // Storage'a kaydet
      await _secureStorage.write(key: _currentTenantKey, value: tenantId);

      Logger.info('Tenant selected: ${tenant.name}');
      return true;
    } catch (e) {
      Logger.error('Failed to select tenant', e);
      return false;
    }
  }

  /// Tenant seçimini temizle
  Future<void> clearTenant() async {
    _currentTenant = null;
    _currentMembership = null;
    _tenantController.add(null);
    await _secureStorage.delete(_currentTenantKey);
    Logger.debug('Tenant cleared');
  }

  /// Tenant bilgisi getir
  Future<Tenant?> getTenant(String tenantId) async {
    try {
      // Cache'den dene
      final cached = await _cacheManager.getTyped<Tenant>(
        key: 'tenant_$tenantId',
        fromJson: Tenant.fromJson,
      );
      if (cached != null) return cached;

      // Supabase'den getir
      final response = await _supabase
          .from('tenants')
          .select()
          .eq('id', tenantId)
          .maybeSingle();

      if (response == null) return null;

      final tenant = Tenant.fromJson(response);

      // Cache'e kaydet
      await _cacheManager.set(
        'tenant_$tenantId',
        tenant.toJson(),
        ttl: const Duration(hours: 1),
      );

      return tenant;
    } catch (e) {
      Logger.error('Failed to get tenant: $tenantId', e);
      return null;
    }
  }

  /// Kullanıcının tenant listesini getir
  Future<List<Tenant>> getUserTenants(String userId, {bool forceRefresh = false}) async {
    try {
      // Cache'den dene
      if (!forceRefresh) {
        final cached = await _cacheManager.getList<Tenant>(
          key: '${_tenantsCacheKey}_$userId',
          fromJson: Tenant.fromJson,
        );
        if (cached != null && cached.isNotEmpty) {
          _userTenants = cached;
          _tenantsController.add(_userTenants);
          return cached;
        }
      }

      // Supabase'den getir (membership üzerinden)
      final memberships = await _supabase
          .from('tenant_memberships')
          .select('*, tenant:tenants(*)')
          .eq('user_id', userId)
          .eq('is_active', true);

      final tenants = <Tenant>[];
      for (final membership in memberships) {
        if (membership['tenant'] != null) {
          tenants.add(Tenant.fromJson(membership['tenant']));
        }
      }

      // Cache'e kaydet
      await _cacheManager.setList(
        key: '${_tenantsCacheKey}_$userId',
        value: tenants,
        toJson: (t) => t.toJson(),
        ttl: const Duration(minutes: 30),
      );

      _userTenants = tenants;
      _tenantsController.add(_userTenants);

      Logger.debug('Loaded ${tenants.length} tenants for user');
      return tenants;
    } catch (e) {
      Logger.error('Failed to get user tenants', e);
      return [];
    }
  }

  /// Kullanıcının membership bilgisini getir
  Future<TenantMembership?> getUserMembership(
    String userId,
    String tenantId,
  ) async {
    try {
      final response = await _supabase
          .from('tenant_memberships')
          .select()
          .eq('user_id', userId)
          .eq('tenant_id', tenantId)
          .maybeSingle();

      if (response == null) return null;
      return TenantMembership.fromJson(response);
    } catch (e) {
      Logger.error('Failed to get user membership', e);
      return null;
    }
  }

  // ============================================
  // TENANT MANAGEMENT (Admin operations)
  // ============================================

  /// Yeni tenant oluştur
  Future<Tenant?> createTenant({
    required String name,
    required String slug,
    required String ownerId,
    String? logoUrl,
    TenantSettings? settings,
  }) async {
    try {
      // Tenant oluştur
      final tenantData = {
        'name': name,
        'slug': slug,
        'logo_url': logoUrl,
        'status': TenantStatus.active.name,
        'plan': SubscriptionPlan.free.name,
        'settings': (settings ?? const TenantSettings()).toJson(),
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('tenants')
          .insert(tenantData)
          .select()
          .single();

      final tenant = Tenant.fromJson(response);

      // Owner membership oluştur
      await _supabase.from('tenant_memberships').insert({
        'user_id': ownerId,
        'tenant_id': tenant.id,
        'role': TenantRole.owner.name,
        'is_active': true,
        'accepted_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

      Logger.info('Tenant created: ${tenant.name}');
      return tenant;
    } catch (e) {
      Logger.error('Failed to create tenant', e);
      return null;
    }
  }

  /// Tenant güncelle
  Future<Tenant?> updateTenant({
    required String tenantId,
    String? name,
    String? logoUrl,
    TenantSettings? settings,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) updateData['name'] = name;
      if (logoUrl != null) updateData['logo_url'] = logoUrl;
      if (settings != null) updateData['settings'] = settings.toJson();

      final response = await _supabase
          .from('tenants')
          .update(updateData)
          .eq('id', tenantId)
          .select()
          .single();

      final tenant = Tenant.fromJson(response);

      // Cache'i güncelle
      await _cacheManager.set(
        'tenant_$tenantId',
        tenant.toJson(),
        ttl: const Duration(hours: 1),
      );

      // Mevcut tenant ise state'i güncelle
      if (_currentTenant?.id == tenantId) {
        _setCurrentTenant(tenant);
      }

      Logger.info('Tenant updated: ${tenant.name}');
      return tenant;
    } catch (e) {
      Logger.error('Failed to update tenant', e);
      return null;
    }
  }

  /// Kullanıcıyı tenant'a davet et
  Future<bool> inviteUser({
    required String tenantId,
    required String email,
    TenantRole role = TenantRole.member,
  }) async {
    try {
      // Kullanıcı var mı kontrol et
      // NOT: Gerçek uygulamada email ile kullanıcı bulma
      // veya davet sistemi kullanılmalı

      Logger.info('User invited to tenant: $email (${role.displayName})');
      return true;
    } catch (e) {
      Logger.error('Failed to invite user', e);
      return false;
    }
  }

  /// Üye rolünü güncelle
  Future<bool> updateMemberRole({
    required String membershipId,
    required TenantRole newRole,
  }) async {
    try {
      await _supabase
          .from('tenant_memberships')
          .update({'role': newRole.name})
          .eq('id', membershipId);

      Logger.info('Member role updated: ${newRole.displayName}');
      return true;
    } catch (e) {
      Logger.error('Failed to update member role', e);
      return false;
    }
  }

  /// Üyeyi kaldır
  Future<bool> removeMember(String membershipId) async {
    try {
      await _supabase
          .from('tenant_memberships')
          .update({'is_active': false})
          .eq('id', membershipId);

      Logger.info('Member removed');
      return true;
    } catch (e) {
      Logger.error('Failed to remove member', e);
      return false;
    }
  }

  // ============================================
  // PERMISSION CHECKS
  // ============================================

  /// Belirli yetkiye sahip mi?
  bool hasPermission(TenantRole requiredRole) {
    if (_currentMembership == null) return false;
    return _currentMembership!.role.isHigherOrEqualTo(requiredRole);
  }

  /// Admin mi?
  bool get isAdmin => hasPermission(TenantRole.admin);

  /// Owner mı?
  bool get isOwner => _currentMembership?.role == TenantRole.owner;

  /// Özellik aktif mi?
  bool isFeatureEnabled(String feature) {
    return _currentTenant?.settings.isFeatureEnabled(feature) ?? false;
  }

  /// Plan özelliğine sahip mi?
  bool hasPlanFeature(bool Function(PlanFeatures) check) {
    if (_currentTenant == null) return false;
    final features = PlanFeatures.forPlan(_currentTenant!.plan);
    return check(features);
  }

  // ============================================
  // PLAN & LIMITS
  // ============================================

  /// Mevcut plan özellikleri
  PlanFeatures? get planFeatures {
    if (_currentTenant == null) return null;
    return PlanFeatures.forPlan(_currentTenant!.plan);
  }

  /// Kullanıcı limiti aşıldı mı?
  Future<bool> isUserLimitReached() async {
    if (_currentTenant == null) return true;

    final features = PlanFeatures.forPlan(_currentTenant!.plan);
    if (features.hasUnlimitedUsers) return false;

    try {
      final count = await _supabase
          .from('tenant_memberships')
          .select()
          .eq('tenant_id', _currentTenant!.id)
          .eq('is_active', true)
          .count();

      return count.count >= features.maxUsers;
    } catch (e) {
      Logger.error('Failed to check user limit', e);
      return true;
    }
  }

  // ============================================
  // PRIVATE METHODS
  // ============================================

  void _setCurrentTenant(Tenant tenant) {
    _currentTenant = tenant;
    _tenantController.add(tenant);
  }

  // ============================================
  // CLEANUP
  // ============================================

  /// Servisi kapat
  void dispose() {
    _tenantController.close();
    _tenantsController.close();
    Logger.debug('TenantService disposed');
  }
}

/// Tenant context wrapper
///
/// Widget ağacında tenant bilgisine erişim için kullanılabilir.
class TenantContext {
  final Tenant tenant;
  final TenantMembership membership;
  final TenantRole role;

  const TenantContext({
    required this.tenant,
    required this.membership,
    required this.role,
  });

  /// Admin mi?
  bool get isAdmin => role.isHigherOrEqualTo(TenantRole.admin);

  /// Owner mı?
  bool get isOwner => role == TenantRole.owner;

  /// Özellik aktif mi?
  bool isFeatureEnabled(String feature) {
    return tenant.settings.isFeatureEnabled(feature);
  }

  /// Plan özellikleri
  PlanFeatures get planFeatures => PlanFeatures.forPlan(tenant.plan);
}
