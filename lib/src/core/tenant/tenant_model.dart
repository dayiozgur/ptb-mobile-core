/// Tenant durumu
enum TenantStatus {
  /// Aktif
  active,

  /// Askıda
  suspended,

  /// Deneme sürümü
  trial,

  /// Süresi dolmuş
  expired,

  /// İptal edilmiş
  cancelled,
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
class Tenant {
  /// Benzersiz ID
  final String id;

  /// Tenant adı
  final String name;

  /// Slug (URL-friendly identifier)
  final String slug;

  /// Logo URL
  final String? logoUrl;

  /// Domain (özel domain varsa)
  final String? domain;

  /// Durum
  final TenantStatus status;

  /// Abonelik planı
  final SubscriptionPlan plan;

  /// Ayarlar
  final TenantSettings settings;

  /// Oluşturulma tarihi
  final DateTime createdAt;

  /// Güncellenme tarihi
  final DateTime? updatedAt;

  /// Deneme bitiş tarihi
  final DateTime? trialEndsAt;

  /// Abonelik bitiş tarihi
  final DateTime? subscriptionEndsAt;

  /// Metadata
  final Map<String, dynamic>? metadata;

  const Tenant({
    required this.id,
    required this.name,
    required this.slug,
    this.logoUrl,
    this.domain,
    this.status = TenantStatus.active,
    this.plan = SubscriptionPlan.free,
    this.settings = const TenantSettings(),
    required this.createdAt,
    this.updatedAt,
    this.trialEndsAt,
    this.subscriptionEndsAt,
    this.metadata,
  });

  /// Aktif mi?
  bool get isActive => status == TenantStatus.active;

  /// Deneme sürümünde mi?
  bool get isTrial => status == TenantStatus.trial;

  /// Deneme süresi dolmuş mu?
  bool get isTrialExpired {
    if (!isTrial || trialEndsAt == null) return false;
    return DateTime.now().isAfter(trialEndsAt!);
  }

  /// Abonelik aktif mi?
  bool get hasActiveSubscription {
    if (plan == SubscriptionPlan.free) return true;
    if (subscriptionEndsAt == null) return false;
    return DateTime.now().isBefore(subscriptionEndsAt!);
  }

  /// JSON'dan oluştur
  factory Tenant.fromJson(Map<String, dynamic> json) {
    return Tenant(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      logoUrl: json['logo_url'] as String?,
      domain: json['domain'] as String?,
      status: TenantStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TenantStatus.active,
      ),
      plan: SubscriptionPlan.values.firstWhere(
        (e) => e.name == json['plan'],
        orElse: () => SubscriptionPlan.free,
      ),
      settings: json['settings'] != null
          ? TenantSettings.fromJson(json['settings'] as Map<String, dynamic>)
          : const TenantSettings(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      trialEndsAt: json['trial_ends_at'] != null
          ? DateTime.parse(json['trial_ends_at'] as String)
          : null,
      subscriptionEndsAt: json['subscription_ends_at'] != null
          ? DateTime.parse(json['subscription_ends_at'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// JSON'a dönüştür
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'logo_url': logoUrl,
      'domain': domain,
      'status': status.name,
      'plan': plan.name,
      'settings': settings.toJson(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'trial_ends_at': trialEndsAt?.toIso8601String(),
      'subscription_ends_at': subscriptionEndsAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Kopyala
  Tenant copyWith({
    String? id,
    String? name,
    String? slug,
    String? logoUrl,
    String? domain,
    TenantStatus? status,
    SubscriptionPlan? plan,
    TenantSettings? settings,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? trialEndsAt,
    DateTime? subscriptionEndsAt,
    Map<String, dynamic>? metadata,
  }) {
    return Tenant(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      logoUrl: logoUrl ?? this.logoUrl,
      domain: domain ?? this.domain,
      status: status ?? this.status,
      plan: plan ?? this.plan,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      trialEndsAt: trialEndsAt ?? this.trialEndsAt,
      subscriptionEndsAt: subscriptionEndsAt ?? this.subscriptionEndsAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() => 'Tenant($id, $name, $status)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Tenant && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Tenant ayarları
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

/// Tenant üyeliği
class TenantMembership {
  /// Üyelik ID
  final String id;

  /// Kullanıcı ID
  final String userId;

  /// Tenant ID
  final String tenantId;

  /// Rol
  final TenantRole role;

  /// Aktif mi?
  final bool isActive;

  /// Davet edilme tarihi
  final DateTime? invitedAt;

  /// Kabul tarihi
  final DateTime? acceptedAt;

  /// Oluşturulma tarihi
  final DateTime createdAt;

  const TenantMembership({
    required this.id,
    required this.userId,
    required this.tenantId,
    required this.role,
    this.isActive = true,
    this.invitedAt,
    this.acceptedAt,
    required this.createdAt,
  });

  factory TenantMembership.fromJson(Map<String, dynamic> json) {
    return TenantMembership(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      tenantId: json['tenant_id'] as String,
      role: TenantRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => TenantRole.member,
      ),
      isActive: json['is_active'] as bool? ?? true,
      invitedAt: json['invited_at'] != null
          ? DateTime.parse(json['invited_at'] as String)
          : null,
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'tenant_id': tenantId,
      'role': role.name,
      'is_active': isActive,
      'invited_at': invitedAt?.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Tenant rolleri
enum TenantRole {
  /// Sahip (tam yetki)
  owner,

  /// Admin (yönetim yetkisi)
  admin,

  /// Üye (standart yetki)
  member,

  /// Misafir (sınırlı yetki)
  guest,
}

/// TenantRole extension
extension TenantRoleExtension on TenantRole {
  /// Görüntüleme adı
  String get displayName {
    switch (this) {
      case TenantRole.owner:
        return 'Sahip';
      case TenantRole.admin:
        return 'Yönetici';
      case TenantRole.member:
        return 'Üye';
      case TenantRole.guest:
        return 'Misafir';
    }
  }

  /// Yetki seviyesi (yüksek = daha yetkili)
  int get level {
    switch (this) {
      case TenantRole.owner:
        return 100;
      case TenantRole.admin:
        return 80;
      case TenantRole.member:
        return 50;
      case TenantRole.guest:
        return 10;
    }
  }

  /// Bu rol verilen rolden daha yetkili mi?
  bool isHigherThan(TenantRole other) => level > other.level;

  /// Bu rol verilen rolden daha yetkili veya eşit mi?
  bool isHigherOrEqualTo(TenantRole other) => level >= other.level;
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
