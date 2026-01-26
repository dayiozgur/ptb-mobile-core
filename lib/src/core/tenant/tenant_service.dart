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

  // Table names
  static const String _tenantsTable = 'tenants';
  static const String _tenantUsersTable = 'tenant_users';

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
      if (!tenant.isActive) {
        Logger.warning('Tenant is not active: $tenantId');
        return false;
      }

      // Seçili tenant'ı güncelle
      _setCurrentTenant(tenant);

      // Storage'a kaydet
      await _secureStorage.write(key: _currentTenantKey, value: tenantId);

      // RPC ile varsayılan tenant olarak işaretle (opsiyonel)
      try {
        await _supabase.rpc('set_default_tenant', params: {
          'p_tenant_id': tenantId,
        });
      } catch (e) {
        // RPC yoksa veya hata olursa sessizce devam et
        Logger.debug('set_default_tenant RPC not available or failed: $e');
      }

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
          .from(_tenantsTable)
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

      // Önce RPC dene (daha performanslı)
      try {
        final rpcResponse = await _supabase.rpc(
          'get_user_tenants',
          params: {'p_user_id': userId},
        );

        if (rpcResponse != null && rpcResponse is List) {
          final tenants = <Tenant>[];
          for (final item in rpcResponse) {
            tenants.add(Tenant(
              id: item['tenant_id'] as String,
              name: item['tenant_name'] as String? ?? '',
              userRole: TenantRole.fromString(item['role'] as String? ?? 'member'),
              isDefault: item['is_default'] as bool? ?? false,
              joinedAt: item['joined_at'] != null
                  ? DateTime.tryParse(item['joined_at'] as String)
                  : null,
            ));
          }

          _userTenants = tenants;
          _tenantsController.add(_userTenants);

          // Cache'e kaydet
          await _cacheManager.setList(
            key: '${_tenantsCacheKey}_$userId',
            value: tenants,
            toJson: (t) => t.toJson(),
            ttl: const Duration(minutes: 30),
          );

          Logger.debug('Loaded ${tenants.length} tenants for user via RPC');
          return tenants;
        }
      } catch (e) {
        Logger.debug('RPC get_user_tenants not available, falling back to query: $e');
      }

      // Fallback: Doğrudan sorgu
      final memberships = await _supabase
          .from(_tenantUsersTable)
          .select('*, tenant:$_tenantsTable(*)')
          .eq('user_id', userId)
          .eq('status', 'active');

      final tenants = <Tenant>[];
      for (final membership in memberships) {
        if (membership['tenant'] != null) {
          final tenantJson = membership['tenant'] as Map<String, dynamic>;
          // Membership bilgilerini tenant'a ekle
          tenantJson['role'] = membership['role'];
          tenantJson['is_default'] = membership['is_default'];
          tenantJson['joined_at'] = membership['joined_at'];
          tenants.add(Tenant.fromJson(tenantJson));
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
          .from(_tenantUsersTable)
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

  /// Kullanıcının varsayılan tenant'ını getir
  Future<String?> getUserDefaultTenantId(String userId) async {
    try {
      // Önce RPC dene
      try {
        final result = await _supabase.rpc(
          'get_user_default_tenant',
          params: {'p_user_id': userId},
        );
        if (result != null) {
          return result as String;
        }
      } catch (e) {
        Logger.debug('RPC get_user_default_tenant not available: $e');
      }

      // Fallback: Doğrudan sorgu
      final response = await _supabase
          .from(_tenantUsersTable)
          .select('tenant_id')
          .eq('user_id', userId)
          .eq('is_default', true)
          .eq('status', 'active')
          .maybeSingle();

      return response?['tenant_id'] as String?;
    } catch (e) {
      Logger.error('Failed to get user default tenant', e);
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
    String? code,
    String? description,
    String? logoUrl,
  }) async {
    try {
      // Tenant oluştur
      final tenantData = {
        'name': name,
        'code': code ?? slug,
        'description': description,
        'active': true,
        'created_at': DateTime.now().toIso8601String(),
        'created_by': ownerId,
      };

      final response = await _supabase
          .from(_tenantsTable)
          .insert(tenantData)
          .select()
          .single();

      final tenant = Tenant.fromJson(response);

      // Owner olarak tenant_users'a ekle
      await _supabase.from(_tenantUsersTable).insert({
        'user_id': ownerId,
        'tenant_id': tenant.id,
        'role': TenantRole.owner.value,
        'status': TenantMemberStatus.active.value,
        'is_default': true, // İlk tenant varsayılan olsun
        'joined_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

      // Cache'i temizle
      await _cacheManager.remove('${_tenantsCacheKey}_$ownerId');

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
    String? code,
    String? description,
    String? logoUrl,
    bool? active,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) updateData['name'] = name;
      if (code != null) updateData['code'] = code;
      if (description != null) updateData['description'] = description;
      if (logoUrl != null) updateData['logo_url'] = logoUrl;
      if (active != null) updateData['active'] = active;

      final response = await _supabase
          .from(_tenantsTable)
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

  /// Kullanıcıyı tenant'a ekle
  Future<TenantMembership?> addUserToTenant({
    required String tenantId,
    required String userId,
    TenantRole role = TenantRole.member,
    String? invitedBy,
  }) async {
    try {
      final membershipData = {
        'user_id': userId,
        'tenant_id': tenantId,
        'role': role.value,
        'status': TenantMemberStatus.active.value,
        'is_default': false,
        'invited_by': invitedBy,
        'invited_at': invitedBy != null ? DateTime.now().toIso8601String() : null,
        'joined_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from(_tenantUsersTable)
          .insert(membershipData)
          .select()
          .single();

      Logger.info('User $userId added to tenant $tenantId with role ${role.displayName}');
      return TenantMembership.fromJson(response);
    } catch (e) {
      Logger.error('Failed to add user to tenant', e);
      return null;
    }
  }

  /// Üye rolünü güncelle
  Future<bool> updateMemberRole({
    required String membershipId,
    required TenantRole newRole,
  }) async {
    try {
      await _supabase
          .from(_tenantUsersTable)
          .update({
            'role': newRole.value,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', membershipId);

      Logger.info('Member role updated: ${newRole.displayName}');
      return true;
    } catch (e) {
      Logger.error('Failed to update member role', e);
      return false;
    }
  }

  /// Üyeyi deaktif et (soft delete)
  Future<bool> removeMember(String membershipId) async {
    try {
      await _supabase
          .from(_tenantUsersTable)
          .update({
            'status': TenantMemberStatus.inactive.value,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', membershipId);

      Logger.info('Member removed (deactivated)');
      return true;
    } catch (e) {
      Logger.error('Failed to remove member', e);
      return false;
    }
  }

  /// Üyeyi kalıcı olarak sil
  Future<bool> deleteMember(String membershipId) async {
    try {
      await _supabase
          .from(_tenantUsersTable)
          .delete()
          .eq('id', membershipId);

      Logger.info('Member permanently deleted');
      return true;
    } catch (e) {
      Logger.error('Failed to delete member', e);
      return false;
    }
  }

  /// Tenant üyelerini getir
  Future<List<TenantMembership>> getTenantMembers(String tenantId) async {
    try {
      final response = await _supabase
          .from(_tenantUsersTable)
          .select()
          .eq('tenant_id', tenantId)
          .eq('status', 'active')
          .order('created_at');

      return response
          .map<TenantMembership>((json) => TenantMembership.fromJson(json))
          .toList();
    } catch (e) {
      Logger.error('Failed to get tenant members', e);
      return [];
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

  /// Yönetebilir mi?
  bool get canManage => hasPermission(TenantRole.manager);

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
      final response = await _supabase
          .from(_tenantUsersTable)
          .select()
          .eq('tenant_id', _currentTenant!.id)
          .eq('status', 'active');

      return response.length >= features.maxUsers;
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
