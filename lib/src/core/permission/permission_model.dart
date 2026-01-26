/// İzin kapsamı (hangi seviyede geçerli)
enum PermissionScope {
  /// Platform geneli (super admin)
  platform('platform'),

  /// Tenant seviyesi
  tenant('tenant'),

  /// Organization seviyesi
  organization('organization'),

  /// Site seviyesi
  site('site'),

  /// Unit seviyesi
  unit('unit');

  final String value;
  const PermissionScope(this.value);

  static PermissionScope fromString(String? value) {
    return PermissionScope.values.firstWhere(
      (s) => s.value == value,
      orElse: () => PermissionScope.tenant,
    );
  }
}

/// İzin kategorisi
enum PermissionCategory {
  /// Kullanıcı yönetimi
  users('users', 'Kullanıcı Yönetimi'),

  /// Organizasyon yönetimi
  organizations('organizations', 'Organizasyon Yönetimi'),

  /// Site yönetimi
  sites('sites', 'Site Yönetimi'),

  /// Unit yönetimi
  units('units', 'Unit Yönetimi'),

  /// Envanter yönetimi
  inventory('inventory', 'Envanter Yönetimi'),

  /// Raporlama
  reports('reports', 'Raporlama'),

  /// Ayarlar
  settings('settings', 'Ayarlar'),

  /// Faturalama
  billing('billing', 'Faturalama'),

  /// Entegrasyonlar
  integrations('integrations', 'Entegrasyonlar');

  final String value;
  final String displayName;
  const PermissionCategory(this.value, this.displayName);

  static PermissionCategory fromString(String? value) {
    return PermissionCategory.values.firstWhere(
      (c) => c.value == value,
      orElse: () => PermissionCategory.users,
    );
  }
}

/// İzin eylemi
enum PermissionAction {
  /// Görüntüleme
  view('view', 'Görüntüle'),

  /// Oluşturma
  create('create', 'Oluştur'),

  /// Güncelleme
  update('update', 'Güncelle'),

  /// Silme
  delete('delete', 'Sil'),

  /// Yönetme (tam yetki)
  manage('manage', 'Yönet'),

  /// Dışa aktarma
  export('export', 'Dışa Aktar'),

  /// İçe aktarma
  import('import', 'İçe Aktar');

  final String value;
  final String displayName;
  const PermissionAction(this.value, this.displayName);

  static PermissionAction fromString(String? value) {
    return PermissionAction.values.firstWhere(
      (a) => a.value == value,
      orElse: () => PermissionAction.view,
    );
  }
}

/// Tek bir izin tanımı
class Permission {
  /// Benzersiz izin kodu (örn: "users.create", "sites.manage")
  final String code;

  /// Kategori
  final PermissionCategory category;

  /// Eylem
  final PermissionAction action;

  /// Kapsam
  final PermissionScope scope;

  /// Açıklama
  final String? description;

  /// Aktif mi?
  final bool active;

  Permission({
    required this.code,
    required this.category,
    required this.action,
    this.scope = PermissionScope.tenant,
    this.description,
    this.active = true,
  });

  factory Permission.fromCode(String code) {
    final parts = code.split('.');
    if (parts.length != 2) {
      throw ArgumentError('Invalid permission code: $code');
    }

    return Permission(
      code: code,
      category: PermissionCategory.fromString(parts[0]),
      action: PermissionAction.fromString(parts[1]),
    );
  }

  factory Permission.fromJson(Map<String, dynamic> json) {
    return Permission(
      code: json['code'] as String,
      category: PermissionCategory.fromString(json['category'] as String?),
      action: PermissionAction.fromString(json['action'] as String?),
      scope: PermissionScope.fromString(json['scope'] as String?),
      description: json['description'] as String?,
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'category': category.value,
        'action': action.value,
        'scope': scope.value,
        'description': description,
        'active': active,
      };

  /// Görüntüleme adı
  String get displayName => '${category.displayName} - ${action.displayName}';

  @override
  String toString() => code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Permission && runtimeType == other.runtimeType && code == other.code;

  @override
  int get hashCode => code.hashCode;
}

/// Rol tanımı
class Role {
  /// Benzersiz ID
  final String id;

  /// Rol kodu (örn: "admin", "manager", "viewer")
  final String code;

  /// Rol adı
  final String name;

  /// Açıklama
  final String? description;

  /// Seviye (yetki hiyerarşisi için, yüksek = daha yetkili)
  final int level;

  /// Sistem rolü mü? (silinemez/değiştirilemez)
  final bool isSystem;

  /// Bu role ait izinler
  final List<String> permissions;

  /// Aktif mi?
  final bool active;

  /// Oluşturulma tarihi
  final DateTime? createdAt;

  /// Güncellenme tarihi
  final DateTime? updatedAt;

  Role({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.level = 0,
    this.isSystem = false,
    this.permissions = const [],
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      level: json['level'] as int? ?? 0,
      isSystem: json['is_system'] as bool? ?? false,
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      active: json['active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'description': description,
        'level': level,
        'is_system': isSystem,
        'permissions': permissions,
        'active': active,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  Role copyWith({
    String? id,
    String? code,
    String? name,
    String? description,
    int? level,
    bool? isSystem,
    List<String>? permissions,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Role(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      level: level ?? this.level,
      isSystem: isSystem ?? this.isSystem,
      permissions: permissions ?? this.permissions,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Belirli bir izne sahip mi?
  bool hasPermission(String permissionCode) {
    return permissions.contains(permissionCode) ||
        permissions.contains('*'); // Wildcard
  }

  /// Belirli bir kategorideki tüm izinlere sahip mi?
  bool hasCategoryPermission(PermissionCategory category, PermissionAction action) {
    return hasPermission('${category.value}.${action.value}') ||
        hasPermission('${category.value}.*') ||
        hasPermission('*');
  }

  @override
  String toString() => 'Role(id: $id, code: $code, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Role && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Varsayılan sistem rolleri
class SystemRoles {
  static const String ownerCode = 'owner';
  static const String adminCode = 'admin';
  static const String managerCode = 'manager';
  static const String memberCode = 'member';
  static const String viewerCode = 'viewer';

  /// Owner (Sahip) - Tüm yetkiler
  static Role get owner => Role(
        id: 'system-owner',
        code: ownerCode,
        name: 'Sahip',
        description: 'Tenant sahibi, tüm yetkilere sahip',
        level: 100,
        isSystem: true,
        permissions: ['*'], // Tüm izinler
      );

  /// Admin (Yönetici) - Faturalama hariç tüm yetkiler
  static Role get admin => Role(
        id: 'system-admin',
        code: adminCode,
        name: 'Yönetici',
        description: 'Yönetici, faturalama hariç tüm yetkilere sahip',
        level: 80,
        isSystem: true,
        permissions: [
          'users.*',
          'organizations.*',
          'sites.*',
          'units.*',
          'inventory.*',
          'reports.*',
          'settings.*',
          'integrations.*',
        ],
      );

  /// Manager (Müdür) - Operasyonel yetkiler
  static Role get manager => Role(
        id: 'system-manager',
        code: managerCode,
        name: 'Müdür',
        description: 'Operasyonel yönetim yetkileri',
        level: 60,
        isSystem: true,
        permissions: [
          'users.view',
          'users.create',
          'users.update',
          'organizations.view',
          'sites.*',
          'units.*',
          'inventory.*',
          'reports.view',
          'reports.export',
        ],
      );

  /// Member (Üye) - Temel yetkiler
  static Role get member => Role(
        id: 'system-member',
        code: memberCode,
        name: 'Üye',
        description: 'Temel kullanıcı yetkileri',
        level: 40,
        isSystem: true,
        permissions: [
          'organizations.view',
          'sites.view',
          'units.view',
          'inventory.view',
          'inventory.create',
          'inventory.update',
          'reports.view',
        ],
      );

  /// Viewer (Görüntüleyici) - Sadece okuma
  static Role get viewer => Role(
        id: 'system-viewer',
        code: viewerCode,
        name: 'Görüntüleyici',
        description: 'Sadece görüntüleme yetkisi',
        level: 20,
        isSystem: true,
        permissions: [
          'organizations.view',
          'sites.view',
          'units.view',
          'inventory.view',
          'reports.view',
        ],
      );

  /// Tüm sistem rolleri
  static List<Role> get all => [owner, admin, manager, member, viewer];

  /// Kod ile rol getir
  static Role? getByCode(String code) {
    try {
      return all.firstWhere((r) => r.code == code);
    } catch (_) {
      return null;
    }
  }
}

/// Tüm izinler
class AllPermissions {
  static List<Permission> get all => [
        // Users
        Permission(code: 'users.view', category: PermissionCategory.users, action: PermissionAction.view),
        Permission(code: 'users.create', category: PermissionCategory.users, action: PermissionAction.create),
        Permission(code: 'users.update', category: PermissionCategory.users, action: PermissionAction.update),
        Permission(code: 'users.delete', category: PermissionCategory.users, action: PermissionAction.delete),
        Permission(code: 'users.manage', category: PermissionCategory.users, action: PermissionAction.manage),

        // Organizations
        Permission(code: 'organizations.view', category: PermissionCategory.organizations, action: PermissionAction.view),
        Permission(code: 'organizations.create', category: PermissionCategory.organizations, action: PermissionAction.create),
        Permission(code: 'organizations.update', category: PermissionCategory.organizations, action: PermissionAction.update),
        Permission(code: 'organizations.delete', category: PermissionCategory.organizations, action: PermissionAction.delete),
        Permission(code: 'organizations.manage', category: PermissionCategory.organizations, action: PermissionAction.manage),

        // Sites
        Permission(code: 'sites.view', category: PermissionCategory.sites, action: PermissionAction.view),
        Permission(code: 'sites.create', category: PermissionCategory.sites, action: PermissionAction.create),
        Permission(code: 'sites.update', category: PermissionCategory.sites, action: PermissionAction.update),
        Permission(code: 'sites.delete', category: PermissionCategory.sites, action: PermissionAction.delete),
        Permission(code: 'sites.manage', category: PermissionCategory.sites, action: PermissionAction.manage),

        // Units
        Permission(code: 'units.view', category: PermissionCategory.units, action: PermissionAction.view),
        Permission(code: 'units.create', category: PermissionCategory.units, action: PermissionAction.create),
        Permission(code: 'units.update', category: PermissionCategory.units, action: PermissionAction.update),
        Permission(code: 'units.delete', category: PermissionCategory.units, action: PermissionAction.delete),
        Permission(code: 'units.manage', category: PermissionCategory.units, action: PermissionAction.manage),

        // Inventory
        Permission(code: 'inventory.view', category: PermissionCategory.inventory, action: PermissionAction.view),
        Permission(code: 'inventory.create', category: PermissionCategory.inventory, action: PermissionAction.create),
        Permission(code: 'inventory.update', category: PermissionCategory.inventory, action: PermissionAction.update),
        Permission(code: 'inventory.delete', category: PermissionCategory.inventory, action: PermissionAction.delete),
        Permission(code: 'inventory.manage', category: PermissionCategory.inventory, action: PermissionAction.manage),
        Permission(code: 'inventory.export', category: PermissionCategory.inventory, action: PermissionAction.export),
        Permission(code: 'inventory.import', category: PermissionCategory.inventory, action: PermissionAction.import),

        // Reports
        Permission(code: 'reports.view', category: PermissionCategory.reports, action: PermissionAction.view),
        Permission(code: 'reports.create', category: PermissionCategory.reports, action: PermissionAction.create),
        Permission(code: 'reports.export', category: PermissionCategory.reports, action: PermissionAction.export),
        Permission(code: 'reports.manage', category: PermissionCategory.reports, action: PermissionAction.manage),

        // Settings
        Permission(code: 'settings.view', category: PermissionCategory.settings, action: PermissionAction.view),
        Permission(code: 'settings.update', category: PermissionCategory.settings, action: PermissionAction.update),
        Permission(code: 'settings.manage', category: PermissionCategory.settings, action: PermissionAction.manage),

        // Billing
        Permission(code: 'billing.view', category: PermissionCategory.billing, action: PermissionAction.view),
        Permission(code: 'billing.manage', category: PermissionCategory.billing, action: PermissionAction.manage),

        // Integrations
        Permission(code: 'integrations.view', category: PermissionCategory.integrations, action: PermissionAction.view),
        Permission(code: 'integrations.create', category: PermissionCategory.integrations, action: PermissionAction.create),
        Permission(code: 'integrations.update', category: PermissionCategory.integrations, action: PermissionAction.update),
        Permission(code: 'integrations.delete', category: PermissionCategory.integrations, action: PermissionAction.delete),
        Permission(code: 'integrations.manage', category: PermissionCategory.integrations, action: PermissionAction.manage),
      ];

  /// Kategoriye göre izinler
  static List<Permission> byCategory(PermissionCategory category) {
    return all.where((p) => p.category == category).toList();
  }

  /// Kod ile izin getir
  static Permission? getByCode(String code) {
    try {
      return all.firstWhere((p) => p.code == code);
    } catch (_) {
      return null;
    }
  }
}
