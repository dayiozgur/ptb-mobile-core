import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../utils/logger.dart';
import 'permission_model.dart';

/// Coarse rol seti — modern RBAC.
///
/// Roller `rbac_user_roles` JOIN `rbac_roles` üzerinde yaşar ve coarse-role
/// RPC'leri ile yüzeye çıkar (`fn_my_coarse_role` / `fn_coarse_role_of`).
/// İstemci `rbac_*` tablolarını DOĞRUDAN sorgulamaz.
///
/// Eşleme (DB tarafı): super_admin/admin → ROLE_ADMIN, manager → ROLE_MANAGER,
/// (staff/technician/dispatcher/inspector/reporter/...) → ROLE_USER,
/// customer → ROLE_CUSTOMER.
class CoarseRoles {
  static const String admin = 'ROLE_ADMIN';
  static const String manager = 'ROLE_MANAGER';
  static const String user = 'ROLE_USER';
  static const String customer = 'ROLE_CUSTOMER';

  static const List<String> all = [admin, manager, user, customer];

  static const Map<String, int> _levels = {
    admin: 80,
    manager: 60,
    user: 40,
    customer: 20,
  };

  /// Rol hiyerarşi seviyesi (yüksek = daha yetkili).
  static int levelOf(String? role) => _levels[role] ?? 0;

  static bool isValid(String? role) => role != null && _levels.containsKey(role);

  /// Coarse rolü [Role] modeline dönüştür (UI/etiket için).
  static Role toRole(String code) {
    const names = {
      admin: 'Yönetici',
      manager: 'Müdür',
      user: 'Kullanıcı',
      customer: 'Müşteri',
    };
    return Role(
      id: 'coarse-$code',
      code: code,
      name: names[code] ?? code,
      level: levelOf(code),
      isSystem: true,
    );
  }

  static List<Role> get roles => all.map(toRole).toList();
}

/// İzin Servisi
///
/// Modern RBAC'e hizalanmıştır. Rol çözümü coarse-role RPC'lerinden gelir;
/// ölü `tenant_users.role` / `roles` / `role_permissions` yolları KALDIRILDI.
///
/// Fine-grained izinler (platform_menu_items.permission) M1'de gelecek; şu an
/// izin kontrolleri coarse rol hiyerarşisine (admin > manager > user > customer)
/// göre yapılır.
///
/// Örnek:
/// ```dart
/// final role = await permissionService.getCoarseRole();      // self
/// final isAdmin = await permissionService.isCurrentUserAdmin();
/// ```
class PermissionService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  // Cache
  static const String _coarseRoleCacheKey = 'coarse_role';
  static const Duration _cacheTtl = Duration(minutes: 15);

  PermissionService({
    required SupabaseClient supabase,
    required CacheManager cacheManager,
  })  : _supabase = supabase,
        _cacheManager = cacheManager;

  // ============================================
  // COARSE ROLE RESOLUTION (RBAC)
  // ============================================

  /// Coarse rolü çöz.
  ///
  /// [profileId] null ya da mevcut kullanıcı ise `fn_my_coarse_role`,
  /// aksi halde `fn_coarse_role_of(p_profile)` çağrılır.
  /// Dönüş: ROLE_ADMIN | ROLE_MANAGER | ROLE_USER | ROLE_CUSTOMER | null.
  Future<String?> getCoarseRole({
    String? profileId,
    bool forceRefresh = false,
  }) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    final targetId = profileId ?? currentUserId;
    if (targetId == null) return null;

    final isSelf = targetId == currentUserId;
    final cacheKey = '${_coarseRoleCacheKey}_$targetId';

    if (!forceRefresh) {
      final cached = await _cacheManager.get(cacheKey);
      if (cached != null && cached is Map && cached['role'] != null) {
        return cached['role'] as String;
      }
    }

    try {
      final dynamic response = isSelf
          ? await _supabase.rpc('fn_my_coarse_role')
          : await _supabase
              .rpc('fn_coarse_role_of', params: {'p_profile': targetId});

      final role = response is String ? response : response?.toString();
      if (role == null || role.isEmpty) return null;

      await _cacheManager.set(cacheKey, {'role': role}, ttl: _cacheTtl);
      return role;
    } catch (e) {
      Logger.error('Failed to resolve coarse role', e);
      return null;
    }
  }

  /// Mevcut kullanıcının coarse rolünü çöz.
  Future<String?> getCurrentUserRole({bool forceRefresh = false}) =>
      getCoarseRole(forceRefresh: forceRefresh);

  /// Rol önbelleğini temizle (rol değişimi / re-login sonrası).
  Future<void> invalidateRoleCache([String? profileId]) async {
    final id = profileId ?? _supabase.auth.currentUser?.id;
    if (id != null) {
      await _cacheManager.delete('${_coarseRoleCacheKey}_$id');
    }
  }

  // ============================================
  // ROLE CHECKS
  // ============================================

  /// Mevcut kullanıcı yönetici mi? (server-truth `fn_is_admin`)
  Future<bool> isCurrentUserAdmin() async {
    try {
      final dynamic res = await _supabase.rpc('fn_is_admin');
      if (res is bool) return res;
    } catch (e) {
      Logger.warning('fn_is_admin failed, falling back to coarse role: $e');
    }
    final role = await getCoarseRole();
    return role == CoarseRoles.admin;
  }

  /// Belirli kullanıcı yönetici mi? (coarse rol ROLE_ADMIN)
  ///
  /// [tenantId] geriye-uyumluluk için korunuyor; RBAC profil-kapsamlıdır.
  Future<bool> isAdmin(String userId, [String? tenantId]) async {
    final role = await getCoarseRole(profileId: userId);
    return role == CoarseRoles.admin;
  }

  /// Mevcut kullanıcı belirtilen organizasyonun üyesi mi? (`fn_user_in_org`)
  Future<bool> isInOrganization(String organizationId) async {
    try {
      final dynamic res = await _supabase
          .rpc('fn_user_in_org', params: {'p_org_id': organizationId});
      return res is bool ? res : false;
    } catch (e) {
      Logger.error('Failed fn_user_in_org', e);
      return false;
    }
  }

  /// Kullanıcının başka bir kullanıcıyı yönetip yönetemeyeceğini kontrol et.
  ///
  /// Coarse rol hiyerarşisine göre: yönetici hedeften daha yüksek seviyede
  /// olmalı.
  Future<bool> canManageUser({
    required String managerId,
    required String targetUserId,
    String? tenantId,
  }) async {
    if (managerId == targetUserId) return false;

    final managerRole = await getCoarseRole(profileId: managerId);
    final targetRole = await getCoarseRole(profileId: targetUserId);
    if (managerRole == null || targetRole == null) return false;

    return CoarseRoles.levelOf(managerRole) > CoarseRoles.levelOf(targetRole);
  }

  // ============================================
  // PERMISSION CHECKS (coarse-role gated)
  // ============================================

  // TODO(M1): fine-grained perms via platform_menu_items (roles[]/permission).
  // Şimdilik izin kodları coarse rol hiyerarşisine indirgeniyor.

  /// Mevcut kullanıcı verilen izne sahip mi? (coarse rol tabanlı)
  Future<bool> hasPermission({
    String? userId,
    String? tenantId,
    required String permission,
  }) async {
    final role = await getCoarseRole(profileId: userId);
    if (role == null) return false;
    return CoarseRoles.levelOf(role) >= _requiredLevel(permission);
  }

  /// İzinlerden herhangi birine sahip mi?
  Future<bool> hasAnyPermission({
    String? userId,
    String? tenantId,
    required List<String> permissions,
  }) async {
    final role = await getCoarseRole(profileId: userId);
    if (role == null) return false;
    final level = CoarseRoles.levelOf(role);
    return permissions.any((p) => level >= _requiredLevel(p));
  }

  /// İzinlerin tümüne sahip mi?
  Future<bool> hasAllPermissions({
    String? userId,
    String? tenantId,
    required List<String> permissions,
  }) async {
    final role = await getCoarseRole(profileId: userId);
    if (role == null) return false;
    final level = CoarseRoles.levelOf(role);
    return permissions.every((p) => level >= _requiredLevel(p));
  }

  /// Bir izin kodu için gereken minimum coarse seviye.
  ///
  /// TODO(M1): platform_menu_items.roles / permission ile değiştir.
  int _requiredLevel(String permission) {
    final parts = permission.split('.');
    final category = parts.isNotEmpty ? parts[0] : '';
    final action = parts.length > 1 ? parts[1] : 'view';

    // Yalnızca yöneticiye açık alanlar
    if (category == 'billing' || category == 'integrations') {
      return CoarseRoles.levelOf(CoarseRoles.admin);
    }
    if (category == 'users' || category == 'settings') {
      return action == 'view'
          ? CoarseRoles.levelOf(CoarseRoles.manager)
          : CoarseRoles.levelOf(CoarseRoles.admin);
    }

    switch (action) {
      case 'view':
      case 'list':
      case 'export':
        return CoarseRoles.levelOf(CoarseRoles.user);
      case 'create':
      case 'update':
      case 'delete':
      case 'manage':
      case 'import':
      default:
        return CoarseRoles.levelOf(CoarseRoles.manager);
    }
  }

  // ============================================
  // ROLE CATALOG (coarse — no DB)
  // ============================================

  /// Coarse rolü [Role] modeline çöz (etiket/UI için). DB sorgusu yok.
  Role? getRole(String roleCode) {
    if (!CoarseRoles.isValid(roleCode)) return null;
    return CoarseRoles.toRole(roleCode);
  }

  /// Kullanılabilir coarse roller. DB sorgusu yok.
  List<Role> getAvailableRoles() => CoarseRoles.roles;

  // ============================================
  // DEPRECATED WRITE OPS
  // ============================================
  // Rol atama/oluşturma/güncelleme/silme artık server-side (rbac_user_roles /
  // rbac_roles + admin EF/RPC) ile yönetiliyor. Ölü `roles`/`role_permissions`/
  // `tenant_users.role` yazımları KALDIRILDI (400/no-op üretiyorlardı).
  // TODO(M1): gerekirse admin EF üzerinden rol atama akışı.

  @Deprecated('RBAC roller server-side yönetiliyor; client rol atamaz.')
  Future<bool> assignRole({
    required String userId,
    String? tenantId,
    required String roleCode,
    String? assignedBy,
  }) async {
    Logger.warning('assignRole no-op: RBAC server-side (rbac_user_roles).');
    return false;
  }
}

/// İzin işlemi hatası
class PermissionException implements Exception {
  final String message;
  PermissionException(this.message);

  @override
  String toString() => message;
}
