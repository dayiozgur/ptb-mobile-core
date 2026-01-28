/// Tenant durumu
enum TenantStatus {
  /// Aktif
  active,

  /// Pasif
  inactive,

  /// Askıda
  suspended,

  /// Deneme sürümü
  trial,

  /// Süresi dolmuş
  expired,

  /// İptal edilmiş
  cancelled,

  /// Silinmiş
  deleted;

  /// String'den TenantStatus'a dönüştür
  static TenantStatus fromString(String? value) {
    return TenantStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TenantStatus.active,
    );
  }
}

/// Abonelik planı
enum SubscriptionPlan {
  /// Ücretsiz
  free,

  /// Temel
  basic,

  /// Profesyonel
  professional,

  /// Kurumsal
  enterprise,
}

/// Tenant (Kiracı) modeli
///
/// Multi-tenant mimarisinde organizasyon/şirket temsili.
/// Gerçek veritabanı şemasına uygun yapı.
class Tenant {
  /// Benzersiz ID
  final String id;

  /// Tenant adı
  final String name;

  /// Tenant kodu (unique identifier)
  final String? code;

  /// Açıklama
  final String? description;

  /// Logo URL / Image path
  final String? logoUrl;

  /// Aktif mi? (geriye uyumluluk için korundu)
  final bool active;

  /// Tenant durumu
  final TenantStatus status;

  /// Askıya alınma tarihi
  final DateTime? suspendedAt;

  /// Askıya alınma nedeni
  final String? suspendedReason;

  /// Silinme tarihi (soft delete)
  final DateTime? deletedAt;

  // ============================================
  // KONUM BİLGİLERİ
  // ============================================

  /// Adres
  final String? address;

  /// Şehir
  final String? city;

  /// İlçe
  final String? town;

  /// Ülke
  final String? country;

  /// Enlem
  final double? latitude;

  /// Boylam
  final double? longitude;

  /// Zoom seviyesi (harita için)
  final int? zoom;

  /// Timezone
  final String? timeZone;

  // ============================================
  // ZAMAN DAMGALARI
  // ============================================

  /// Oluşturulma tarihi
  final DateTime? createdAt;

  /// Güncellenme tarihi
  final DateTime? updatedAt;

  /// Oluşturan kullanıcı
  final String? createdBy;

  /// Güncelleyen kullanıcı
  final String? updatedBy;

  /// Row ID (sıralama için)
  final int? rowId;

  // ============================================
  // COMPUTED / İLİŞKİLİ (tenant_users üzerinden)
  // ============================================

  /// Kullanıcının bu tenant'taki rolü (tenant_users'dan gelir)
  final TenantRole? userRole;

  /// Varsayılan tenant mı? (tenant_users.is_default)
  final bool isDefault;

  /// Katılım tarihi (tenant_users.joined_at)
  final DateTime? joinedAt;

  const Tenant({
    required this.id,
    required this.name,
    this.code,
    this.description,
    this.logoUrl,
    this.active = true,
    this.status = TenantStatus.active,
    this.suspendedAt,
    this.suspendedReason,
    this.deletedAt,
    this.address,
    this.city,
    this.town,
    this.country,
    this.latitude,
    this.longitude,
    this.zoom,
    this.timeZone,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.rowId,
    this.userRole,
    this.isDefault = false,
    this.joinedAt,
  });

  /// Aktif mi?
  bool get isActive => active && status == TenantStatus.active;

  /// Deneme sürümünde mi?
  bool get isTrial => status == TenantStatus.trial;

  /// Askıda mı?
  bool get isSuspended => status == TenantStatus.suspended;

  /// Silinmiş mi?
  bool get isDeleted => status == TenantStatus.deleted;

  /// Süresi dolmuş mu?
  bool get isExpired => status == TenantStatus.expired;

  /// İptal edilmiş mi?
  bool get isCancelled => status == TenantStatus.cancelled;

  /// Plan (geriye uyumluluk - subscription tablosundan alınmalı)
  SubscriptionPlan get plan => SubscriptionPlan.free;

  /// JSON'dan oluştur (tenants tablosu)
  factory Tenant.fromJson(Map<String, dynamic> json) {
    return Tenant(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      description: json['description'] as String?,
      logoUrl: json['logo_url'] as String? ?? json['image_path'] as String?,
      active: json['active'] as bool? ?? true,
      status: TenantStatus.fromString(json['status'] as String?),
      suspendedAt: json['suspended_at'] != null
          ? DateTime.tryParse(json['suspended_at'] as String)
          : null,
      suspendedReason: json['suspended_reason'] as String?,
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'] as String)
          : null,
      address: json['address'] as String?,
      city: json['city'] as String?,
      town: json['town'] as String?,
      country: json['country'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      zoom: json['zoom'] as int?,
      timeZone: json['time_zone'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      rowId: json['row_id'] as int?,
      // tenant_users join'den gelen alanlar
      userRole: json['role'] != null
          ? TenantRole.fromString(json['role'] as String)
          : null,
      isDefault: json['is_default'] as bool? ?? false,
      joinedAt: json['joined_at'] != null
          ? DateTime.tryParse(json['joined_at'] as String)
          : null,
    );
  }

  /// JSON'a dönüştür
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'description': description,
      'logo_url': logoUrl,
      'active': active,
      'status': status.name,
      'suspended_at': suspendedAt?.toIso8601String(),
      'suspended_reason': suspendedReason,
      'deleted_at': deletedAt?.toIso8601String(),
      'address': address,
      'city': city,
      'town': town,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'zoom': zoom,
      'time_zone': timeZone,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
    };
  }

  /// Kopyala
  Tenant copyWith({
    String? id,
    String? name,
    String? code,
    String? description,
    String? logoUrl,
    bool? active,
    TenantStatus? status,
    DateTime? suspendedAt,
    String? suspendedReason,
    DateTime? deletedAt,
    String? address,
    String? city,
    String? town,
    String? country,
    double? latitude,
    double? longitude,
    int? zoom,
    String? timeZone,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    int? rowId,
    TenantRole? userRole,
    bool? isDefault,
    DateTime? joinedAt,
  }) {
    return Tenant(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      active: active ?? this.active,
      status: status ?? this.status,
      suspendedAt: suspendedAt ?? this.suspendedAt,
      suspendedReason: suspendedReason ?? this.suspendedReason,
      deletedAt: deletedAt ?? this.deletedAt,
      address: address ?? this.address,
      city: city ?? this.city,
      town: town ?? this.town,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      zoom: zoom ?? this.zoom,
      timeZone: timeZone ?? this.timeZone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      rowId: rowId ?? this.rowId,
      userRole: userRole ?? this.userRole,
      isDefault: isDefault ?? this.isDefault,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  @override
  String toString() => 'Tenant($id, $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Tenant && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Tenant üyeliği (tenant_users tablosu)
class TenantMembership {
  /// Üyelik ID
  final String id;

  /// Kullanıcı ID (auth.users.id)
  final String userId;

  /// Tenant ID
  final String tenantId;

  /// Rol
  final TenantRole role;

  /// Durum
  final TenantMemberStatus status;

  /// Varsayılan tenant mı?
  final bool isDefault;

  /// Davet eden kullanıcı
  final String? invitedBy;

  /// Davet tarihi
  final DateTime? invitedAt;

  /// Davet token'ı
  final String? invitationToken;

  /// Davet son kullanma tarihi
  final DateTime? invitationExpiresAt;

  /// Katılım tarihi
  final DateTime? joinedAt;

  /// Son erişim tarihi
  final DateTime? lastAccessedAt;

  /// Oluşturulma tarihi
  final DateTime createdAt;

  /// Güncellenme tarihi
  final DateTime? updatedAt;

  const TenantMembership({
    required this.id,
    required this.userId,
    required this.tenantId,
    required this.role,
    this.status = TenantMemberStatus.active,
    this.isDefault = false,
    this.invitedBy,
    this.invitedAt,
    this.invitationToken,
    this.invitationExpiresAt,
    this.joinedAt,
    this.lastAccessedAt,
    required this.createdAt,
    this.updatedAt,
  });

  /// Aktif mi?
  bool get isActive => status == TenantMemberStatus.active;

  /// Beklemede mi?
  bool get isPending => status == TenantMemberStatus.pending;

  factory TenantMembership.fromJson(Map<String, dynamic> json) {
    return TenantMembership(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      tenantId: json['tenant_id'] as String,
      role: TenantRole.fromString(json['role'] as String? ?? 'member'),
      status: TenantMemberStatus.fromString(json['status'] as String? ?? 'active'),
      isDefault: json['is_default'] as bool? ?? false,
      invitedBy: json['invited_by'] as String?,
      invitedAt: json['invited_at'] != null
          ? DateTime.tryParse(json['invited_at'] as String)
          : null,
      invitationToken: json['invitation_token'] as String?,
      invitationExpiresAt: json['invitation_expires_at'] != null
          ? DateTime.tryParse(json['invitation_expires_at'] as String)
          : null,
      joinedAt: json['joined_at'] != null
          ? DateTime.tryParse(json['joined_at'] as String)
          : null,
      lastAccessedAt: json['last_accessed_at'] != null
          ? DateTime.tryParse(json['last_accessed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'tenant_id': tenantId,
      'role': role.value,
      'status': status.value,
      'is_default': isDefault,
      'invited_by': invitedBy,
      'invited_at': invitedAt?.toIso8601String(),
      'invitation_token': invitationToken,
      'invitation_expires_at': invitationExpiresAt?.toIso8601String(),
      'joined_at': joinedAt?.toIso8601String(),
      'last_accessed_at': lastAccessedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

/// Tenant üyelik durumu
enum TenantMemberStatus {
  /// Aktif
  active('active'),

  /// Pasif
  inactive('inactive'),

  /// Askıda
  suspended('suspended'),

  /// Beklemede (davet kabul edilmedi)
  pending('pending');

  final String value;
  const TenantMemberStatus(this.value);

  static TenantMemberStatus fromString(String value) {
    return TenantMemberStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TenantMemberStatus.active,
    );
  }
}

/// Tenant rolleri
enum TenantRole {
  /// Sahip (tam yetki)
  owner('owner', 'Sahip', 100),

  /// Admin (yönetim yetkisi)
  admin('admin', 'Yönetici', 80),

  /// Müdür (orta seviye yönetim)
  manager('manager', 'Müdür', 60),

  /// Üye (standart yetki)
  member('member', 'Üye', 40),

  /// Görüntüleyici (sadece okuma)
  viewer('viewer', 'Görüntüleyici', 20);

  final String value;
  final String displayName;
  final int level;

  const TenantRole(this.value, this.displayName, this.level);

  static TenantRole fromString(String value) {
    return TenantRole.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TenantRole.member,
    );
  }

  /// Bu rol verilen rolden daha yetkili mi?
  bool isHigherThan(TenantRole other) => level > other.level;

  /// Bu rol verilen rolden daha yetkili veya eşit mi?
  bool isHigherOrEqualTo(TenantRole other) => level >= other.level;

  /// Yönetici mi? (admin veya owner)
  bool get isAdminOrHigher => isHigherOrEqualTo(TenantRole.admin);

  /// Yönetici olabilir mi? (manager veya üstü)
  bool get canManage => isHigherOrEqualTo(TenantRole.manager);
}

/// Tenant ayarları (ayrı tabloda veya jsonb alanında tutulabilir)
class TenantSettings {
  /// Varsayılan dil
  final String defaultLanguage;

  /// Varsayılan timezone
  final String defaultTimezone;

  /// Varsayılan para birimi
  final String defaultCurrency;

  /// Tarih formatı
  final String dateFormat;

  /// Saat formatı (12h/24h)
  final String timeFormat;

  /// Tema modu (light/dark/system)
  final String themeMode;

  /// Özellik bayrakları
  final Map<String, bool> featureFlags;

  /// Özel ayarlar
  final Map<String, dynamic> custom;

  const TenantSettings({
    this.defaultLanguage = 'tr',
    this.defaultTimezone = 'Europe/Istanbul',
    this.defaultCurrency = 'TRY',
    this.dateFormat = 'dd.MM.yyyy',
    this.timeFormat = '24h',
    this.themeMode = 'system',
    this.featureFlags = const {},
    this.custom = const {},
  });

  /// Özellik aktif mi?
  bool isFeatureEnabled(String feature) {
    return featureFlags[feature] ?? false;
  }

  factory TenantSettings.fromJson(Map<String, dynamic> json) {
    return TenantSettings(
      defaultLanguage: json['default_language'] as String? ?? 'tr',
      defaultTimezone: json['default_timezone'] as String? ?? 'Europe/Istanbul',
      defaultCurrency: json['default_currency'] as String? ?? 'TRY',
      dateFormat: json['date_format'] as String? ?? 'dd.MM.yyyy',
      timeFormat: json['time_format'] as String? ?? '24h',
      themeMode: json['theme_mode'] as String? ?? 'system',
      featureFlags: (json['feature_flags'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as bool)) ??
          {},
      custom: json['custom'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'default_language': defaultLanguage,
      'default_timezone': defaultTimezone,
      'default_currency': defaultCurrency,
      'date_format': dateFormat,
      'time_format': timeFormat,
      'theme_mode': themeMode,
      'feature_flags': featureFlags,
      'custom': custom,
    };
  }

  TenantSettings copyWith({
    String? defaultLanguage,
    String? defaultTimezone,
    String? defaultCurrency,
    String? dateFormat,
    String? timeFormat,
    String? themeMode,
    Map<String, bool>? featureFlags,
    Map<String, dynamic>? custom,
  }) {
    return TenantSettings(
      defaultLanguage: defaultLanguage ?? this.defaultLanguage,
      defaultTimezone: defaultTimezone ?? this.defaultTimezone,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      dateFormat: dateFormat ?? this.dateFormat,
      timeFormat: timeFormat ?? this.timeFormat,
      themeMode: themeMode ?? this.themeMode,
      featureFlags: featureFlags ?? this.featureFlags,
      custom: custom ?? this.custom,
    );
  }
}

/// Plan özellikleri
class PlanFeatures {
  /// Maksimum kullanıcı sayısı
  final int maxUsers;

  /// Maksimum depolama (MB)
  final int maxStorageMb;

  /// Maksimum proje sayısı
  final int maxProjects;

  /// API erişimi
  final bool hasApiAccess;

  /// Özel domain
  final bool hasCustomDomain;

  /// Öncelikli destek
  final bool hasPrioritySupport;

  /// SSO desteği
  final bool hasSsoSupport;

  /// Audit log
  final bool hasAuditLog;

  /// Özel özellikler
  final List<String> additionalFeatures;

  const PlanFeatures({
    this.maxUsers = 5,
    this.maxStorageMb = 1024,
    this.maxProjects = 3,
    this.hasApiAccess = false,
    this.hasCustomDomain = false,
    this.hasPrioritySupport = false,
    this.hasSsoSupport = false,
    this.hasAuditLog = false,
    this.additionalFeatures = const [],
  });

  /// Plan'a göre özellikleri getir
  factory PlanFeatures.forPlan(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return const PlanFeatures(
          maxUsers: 3,
          maxStorageMb: 512,
          maxProjects: 2,
        );
      case SubscriptionPlan.basic:
        return const PlanFeatures(
          maxUsers: 10,
          maxStorageMb: 5120,
          maxProjects: 10,
          hasApiAccess: true,
        );
      case SubscriptionPlan.professional:
        return const PlanFeatures(
          maxUsers: 50,
          maxStorageMb: 51200,
          maxProjects: 50,
          hasApiAccess: true,
          hasCustomDomain: true,
          hasPrioritySupport: true,
          hasAuditLog: true,
        );
      case SubscriptionPlan.enterprise:
        return const PlanFeatures(
          maxUsers: -1, // Sınırsız
          maxStorageMb: -1, // Sınırsız
          maxProjects: -1, // Sınırsız
          hasApiAccess: true,
          hasCustomDomain: true,
          hasPrioritySupport: true,
          hasSsoSupport: true,
          hasAuditLog: true,
          additionalFeatures: [
            'dedicated_support',
            'custom_integrations',
            'sla_guarantee',
          ],
        );
    }
  }

  /// Sınırsız mı?
  bool get hasUnlimitedUsers => maxUsers == -1;
  bool get hasUnlimitedStorage => maxStorageMb == -1;
  bool get hasUnlimitedProjects => maxProjects == -1;
}

/// Tenant context wrapper
///
/// Widget ağacında tenant bilgisine erişim için kullanılabilir.
class TenantContext {
  final Tenant tenant;
  final TenantMembership? membership;
  final TenantRole role;

  const TenantContext({
    required this.tenant,
    this.membership,
    required this.role,
  });

  /// Admin mi?
  bool get isAdmin => role.isAdminOrHigher;

  /// Owner mı?
  bool get isOwner => role == TenantRole.owner;

  /// Yönetebilir mi?
  bool get canManage => role.canManage;
}
