import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../tenant/tenant_model.dart';
import '../utils/logger.dart';
import 'permission_model.dart';

/// İzin Servisi
///
/// Kullanıcı izin ve rol yönetimini sağlar.
/// Yetki kontrolü ve rol atamaları için kullanılır.
///
/// Örnek kullanım:
/// ```dart
/// final permissionService = PermissionService(
///   supabase: Supabase.instance.client,
///   cacheManager: CacheManager(),
/// );
///
/// // İzin kontrolü
/// final canEdit = await permissionService.hasPermission(
///   userId: 'user-id',
///   tenantId: 'tenant-id',
///   permission: 'sites.update',
/// );
///
/// // Rol ataması
/// await permissionService.assignRole(
///   userId: 'user-id',
///   tenantId: 'tenant-id',
///   roleCode: 'manager',
/// );
/// ```
class PermissionService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  // Cache keys
  static const String _userPermissionsCacheKey = 'user_permissions';
  static const String _rolesCacheKey = 'tenant_roles';

  // Table names
  static const String _tenantUsersTable = 'tenant_users';
  static const String _rolesTable = 'roles';
  static const String _rolePermissionsTable = 'role_permissions';

  PermissionService({
    required SupabaseClient supabase,
    required CacheManager cacheManager,
  })  : _supabase = supabase,
        _cacheManager = cacheManager;

  // ============================================
  // PERMISSION CHECKS
  // ============================================

  /// Kullanıcının belirli bir izne sahip olup olmadığını kontrol et
  Future<bool> hasPermission({
    required String userId,
    required String tenantId,
    required String permission,
  }) async {
    try {
      // Kullanıcının rolünü al
      final userRole = await getUserRole(userId, tenantId);
      if (userRole == null) return false;

      // Sistem rolü mü kontrol et
      final systemRole = SystemRoles.getByCode(userRole);
      if (systemRole != null) {
        return systemRole.hasPermission(permission);
      }

      // Özel rol için izinleri al
      final permissions = await _getUserPermissions(userId, tenantId);
      return permissions.contains(permission) || permissions.contains('*');
    } catch (e) {
      Logger.error('Failed to check permission', e);
      return false;
    }
  }

  /// Kullanıcının birden fazla izinden birine sahip olup olmadığını kontrol et
  Future<bool> hasAnyPermission({
    required String userId,
    required String tenantId,
    required List<String> permissions,
  }) async {
    for (final permission in permissions) {
      if (await hasPermission(
        userId: userId,
        tenantId: tenantId,
        permission: permission,
      )) {
        return true;
      }
    }
    return false;
  }

  /// Kullanıcının tüm izinlere sahip olup olmadığını kontrol et
  Future<bool> hasAllPermissions({
    required String userId,
    required String tenantId,
    required List<String> permissions,
  }) async {
    for (final permission in permissions) {
      if (!await hasPermission(
        userId: userId,
        tenantId: tenantId,
        permission: permission,
      )) {
        return false;
      }
    }
    return true;
  }

  /// Kullanıcının yönetici olup olmadığını kontrol et
  Future<bool> isAdmin(String userId, String tenantId) async {
    final role = await getUserRole(userId, tenantId);
    if (role == null) return false;

    final systemRole = SystemRoles.getByCode(role);
    if (systemRole != null) {
      return systemRole.level >= SystemRoles.admin.level;
    }

    // Özel rol için level kontrolü
    final customRole = await getRole(role, tenantId);
    return customRole != null && customRole.level >= 80;
  }

  /// Kullanıcının sahip olup olmadığını kontrol et
  Future<bool> isOwner(String userId, String tenantId) async {
    final role = await getUserRole(userId, tenantId);
    return role == SystemRoles.ownerCode;
  }

  /// Kullanıcının başka bir kullanıcıyı yönetip yönetemeyeceğini kontrol et
  Future<bool> canManageUser({
    required String managerId,
    required String targetUserId,
    required String tenantId,
  }) async {
    // Kendini yönetemez (bazı işlemler için)
    if (managerId == targetUserId) return false;

    final managerRole = await getUserRole(managerId, tenantId);
    final targetRole = await getUserRole(targetUserId, tenantId);

    if (managerRole == null || targetRole == null) return false;

    final managerLevel = _getRoleLevel(managerRole);
    final targetLevel = _getRoleLevel(targetRole);

    // Daha yüksek seviyeli kullanıcıları yönetemez
    return managerLevel > targetLevel;
  }

  // ============================================
  // ROLE MANAGEMENT
  // ============================================

  /// Kullanıcının rolünü getir
  Future<String?> getUserRole(String userId, String tenantId) async {
    try {
      // Cache'den dene
      final cacheKey = '${_userPermissionsCacheKey}_${userId}_$tenantId';
      final cached = await _cacheManager.get(cacheKey);
      if (cached != null && cached is Map && cached['role'] != null) {
        return cached['role'] as String;
      }

      // Supabase'den getir
      final response = await _supabase
          .from(_tenantUsersTable)
          .select('role')
          .eq('user_id', userId)
          .eq('tenant_id', tenantId)
          .eq('status', 'active')
          .maybeSingle();

      if (response == null) return null;

      final role = response['role'] as String?;

      // Cache'e kaydet
      await _cacheManager.set(
        cacheKey,
        {'role': role},
        ttl: const Duration(minutes: 15),
      );

      return role;
    } catch (e) {
      Logger.error('Failed to get user role', e);
      return null;
    }
  }

  /// Kullanıcıya rol ata
  Future<bool> assignRole({
    required String userId,
    required String tenantId,
    required String roleCode,
    String? assignedBy,
  }) async {
    try {
      // Owner rolü sadece mevcut owner tarafından atanabilir
      if (roleCode == SystemRoles.ownerCode) {
        if (assignedBy == null) return false;
        final isAssignerOwner = await isOwner(assignedBy, tenantId);
        if (!isAssignerOwner) {
          Logger.warning('Only owner can assign owner role');
          return false;
        }
      }

      await _supabase
          .from(_tenantUsersTable)
          .update({
            'role': roleCode,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('tenant_id', tenantId);

      // Cache'i temizle
      await _cacheManager.delete('${_userPermissionsCacheKey}_${userId}_$tenantId');

      Logger.info('Role assigned: $roleCode to user: $userId');
      return true;
    } catch (e) {
      Logger.error('Failed to assign role', e);
      return false;
    }
  }

  /// Rol detayını getir
  Future<Role?> getRole(String roleCode, String? tenantId) async {
    // Önce sistem rollerini kontrol et
    final systemRole = SystemRoles.getByCode(roleCode);
    if (systemRole != null) return systemRole;

    if (tenantId == null) return null;

    try {
      // Özel rol için veritabanından getir
      final response = await _supabase
          .from(_rolesTable)
          .select('*, permissions:$_rolePermissionsTable(permission_code)')
          .eq('code', roleCode)
          .eq('tenant_id', tenantId)
          .eq('active', true)
          .maybeSingle();

      if (response == null) return null;

      final permissionsList = (response['permissions'] as List<dynamic>?)
              ?.map((p) => (p as Map)['permission_code'] as String)
              .toList() ??
          [];

      return Role(
        id: response['id'] as String,
        code: response['code'] as String,
        name: response['name'] as String,
        description: response['description'] as String?,
        level: response['level'] as int? ?? 0,
        isSystem: response['is_system'] as bool? ?? false,
        permissions: permissionsList,
        active: response['active'] as bool? ?? true,
        createdAt: response['created_at'] != null
            ? DateTime.tryParse(response['created_at'] as String)
            : null,
        updatedAt: response['updated_at'] != null
            ? DateTime.tryParse(response['updated_at'] as String)
            : null,
      );
    } catch (e) {
      Logger.error('Failed to get role', e);
      return null;
    }
  }

  /// Tenant'ın tüm rollerini getir
  Future<List<Role>> getTenantRoles(String tenantId) async {
    try {
      // Cache'den dene
      final cached = await _cacheManager.getList<Role>(
        key: '${_rolesCacheKey}_$tenantId',
        fromJson: Role.fromJson,
      );
      if (cached != null && cached.isNotEmpty) return cached;

      // Sistem rollerini ekle
      final roles = List<Role>.from(SystemRoles.all);

      // Özel rolleri getir
      final response = await _supabase
          .from(_rolesTable)
          .select('*, permissions:$_rolePermissionsTable(permission_code)')
          .eq('tenant_id', tenantId)
          .eq('active', true)
          .order('level', ascending: false);

      for (final item in response) {
        final permissionsList = (item['permissions'] as List<dynamic>?)
                ?.map((p) => (p as Map)['permission_code'] as String)
                .toList() ??
            [];

        roles.add(Role(
          id: item['id'] as String,
          code: item['code'] as String,
          name: item['name'] as String,
          description: item['description'] as String?,
          level: item['level'] as int? ?? 0,
          isSystem: false,
          permissions: permissionsList,
          active: true,
        ));
      }

      // Cache'e kaydet
      await _cacheManager.setList(
        key: '${_rolesCacheKey}_$tenantId',
        value: roles,
        toJson: (r) => r.toJson(),
        ttl: const Duration(hours: 1),
      );

      return roles;
    } catch (e) {
      Logger.error('Failed to get tenant roles', e);
      return SystemRoles.all; // En azından sistem rollerini döndür
    }
  }

  /// Özel rol oluştur
  Future<Role?> createRole({
    required String tenantId,
    required String code,
    required String name,
    String? description,
    int level = 50,
    List<String> permissions = const [],
    String? createdBy,
  }) async {
    try {
      // Kod benzersiz mi kontrol et
      final existing = await getRole(code, tenantId);
      if (existing != null) {
        throw PermissionException('Bu rol kodu zaten kullanılıyor');
      }

      final roleData = {
        'tenant_id': tenantId,
        'code': code,
        'name': name,
        'description': description,
        'level': level,
        'is_system': false,
        'active': true,
        'created_by': createdBy,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from(_rolesTable)
          .insert(roleData)
          .select()
          .single();

      final roleId = response['id'] as String;

      // İzinleri ekle
      if (permissions.isNotEmpty) {
        final permissionInserts = permissions
            .map((p) => {
                  'role_id': roleId,
                  'permission_code': p,
                  'tenant_id': tenantId,
                })
            .toList();

        await _supabase.from(_rolePermissionsTable).insert(permissionInserts);
      }

      // Cache'i temizle
      await _cacheManager.delete('${_rolesCacheKey}_$tenantId');

      Logger.info('Role created: $code');

      return Role(
        id: roleId,
        code: code,
        name: name,
        description: description,
        level: level,
        isSystem: false,
        permissions: permissions,
        active: true,
        createdAt: DateTime.now(),
      );
    } on PermissionException {
      rethrow;
    } catch (e) {
      Logger.error('Failed to create role', e);
      return null;
    }
  }

  /// Rol güncelle
  Future<Role?> updateRole({
    required String roleId,
    required String tenantId,
    String? name,
    String? description,
    int? level,
    List<String>? permissions,
    String? updatedBy,
  }) async {
    try {
      // Sistem rolü güncellenemez
      final existingRole = await _getRoleById(roleId);
      if (existingRole != null && existingRole.isSystem) {
        throw PermissionException('Sistem rolleri güncellenemez');
      }

      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (level != null) updateData['level'] = level;
      if (updatedBy != null) updateData['updated_by'] = updatedBy;

      await _supabase
          .from(_rolesTable)
          .update(updateData)
          .eq('id', roleId)
          .eq('tenant_id', tenantId);

      // İzinleri güncelle
      if (permissions != null) {
        // Eski izinleri sil
        await _supabase
            .from(_rolePermissionsTable)
            .delete()
            .eq('role_id', roleId);

        // Yeni izinleri ekle
        if (permissions.isNotEmpty) {
          final permissionInserts = permissions
              .map((p) => {
                    'role_id': roleId,
                    'permission_code': p,
                    'tenant_id': tenantId,
                  })
              .toList();

          await _supabase.from(_rolePermissionsTable).insert(permissionInserts);
        }
      }

      // Cache'i temizle
      await _cacheManager.delete('${_rolesCacheKey}_$tenantId');

      Logger.info('Role updated: $roleId');
      return await getRole(existingRole?.code ?? '', tenantId);
    } on PermissionException {
      rethrow;
    } catch (e) {
      Logger.error('Failed to update role', e);
      return null;
    }
  }

  /// Rol sil
  Future<bool> deleteRole(String roleId, String tenantId) async {
    try {
      // Sistem rolü silinemez
      final existingRole = await _getRoleById(roleId);
      if (existingRole != null && existingRole.isSystem) {
        throw PermissionException('Sistem rolleri silinemez');
      }

      // Bu role atanmış kullanıcı var mı kontrol et
      final usersWithRole = await _supabase
          .from(_tenantUsersTable)
          .select('id')
          .eq('tenant_id', tenantId)
          .eq('role', existingRole?.code ?? '')
          .limit(1);

      if (usersWithRole.isNotEmpty) {
        throw PermissionException(
          'Bu role atanmış kullanıcılar var. Önce kullanıcıların rollerini değiştirin.',
        );
      }

      // İzinleri sil
      await _supabase
          .from(_rolePermissionsTable)
          .delete()
          .eq('role_id', roleId);

      // Rolü sil
      await _supabase
          .from(_rolesTable)
          .delete()
          .eq('id', roleId)
          .eq('tenant_id', tenantId);

      // Cache'i temizle
      await _cacheManager.delete('${_rolesCacheKey}_$tenantId');

      Logger.info('Role deleted: $roleId');
      return true;
    } on PermissionException {
      rethrow;
    } catch (e) {
      Logger.error('Failed to delete role', e);
      return false;
    }
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  /// Kullanıcının tüm izinlerini getir
  Future<List<String>> _getUserPermissions(String userId, String tenantId) async {
    try {
      final role = await getUserRole(userId, tenantId);
      if (role == null) return [];

      // Sistem rolü
      final systemRole = SystemRoles.getByCode(role);
      if (systemRole != null) return systemRole.permissions;

      // Özel rol
      final customRole = await getRole(role, tenantId);
      return customRole?.permissions ?? [];
    } catch (e) {
      Logger.error('Failed to get user permissions', e);
      return [];
    }
  }

  /// Rol seviyesini getir
  int _getRoleLevel(String roleCode) {
    final systemRole = SystemRoles.getByCode(roleCode);
    if (systemRole != null) return systemRole.level;

    // TenantRole enum'undan kontrol et
    final tenantRole = TenantRole.values.cast<TenantRole?>().firstWhere(
          (r) => r?.value == roleCode,
          orElse: () => null,
        );
    if (tenantRole != null) return tenantRole.level;

    return 0;
  }

  /// ID ile rol getir
  Future<Role?> _getRoleById(String roleId) async {
    try {
      final response = await _supabase
          .from(_rolesTable)
          .select()
          .eq('id', roleId)
          .maybeSingle();

      if (response == null) return null;
      return Role.fromJson(response);
    } catch (e) {
      return null;
    }
  }
}

/// İzin işlemi hatası
class PermissionException implements Exception {
  final String message;
  PermissionException(this.message);

  @override
  String toString() => message;
}
