/// Kullanıcı Profili modeli
///
/// `profiles` tablosunun CANLI şemasına hizalanmıştır (2026-08).
/// NOT: Web backend sertleştirildikten sonra bir dizi kolon DROP edildi /
/// yeniden adlandırıldı. Bu model yalnızca GERÇEK kolonları map/write eder;
/// aksi halde Supabase 400 döner (sessiz drift).
///
/// Coarse-role / tenant_name / organization_id alanları `fn_my_profile_bundle`
/// RPC'sinden gelir (tek round-trip cold-start). Düz `profiles` select'inde
/// bu üç alan null olur.
class UserProfile {
  /// Kullanıcı ID (auth.users.id == profiles.id)
  final String id;

  /// Email adresi (profiles.email — null olabilir)
  final String email;

  /// Kullanıcı adı (profiles.username)
  final String? username;

  /// Tam ad (profiles.full_name)
  final String? fullName;

  /// Ad (profiles.first_name)
  final String? firstName;

  /// Soyad (profiles.last_name)
  final String? lastName;

  /// Avatar URL (profiles.avatar_url) — ham storage path olabilir; görüntülemek
  /// için signed URL üret (bkz. FileStorageService.getAvatarUrl).
  final String? avatarUrl;

  /// Telefon numarası (profiles.phone)
  final String? phone;

  /// Biyografi (profiles.bio)
  final String? bio;

  /// İki faktörlü kimlik doğrulama açık mı? (profiles.two_factor_enabled)
  final bool twoFactorEnabled;

  /// Aktif mi? (profiles.active) — pasif kullanıcıları gate'lemek için.
  final bool active;

  /// Tenant ID (profiles.tenant_id)
  final String? tenantId;

  /// Tercih edilen dil (profiles.preferred_language)
  final String preferredLanguage;

  /// Profil tipi (profiles.type)
  final String? type;

  /// Varsayılan site ID (profiles.site_id)
  final String? siteId;

  /// İsim etiketi (profiles.name)
  final String? name;

  /// Açıklama (profiles.description)
  final String? description;

  /// Varsayılan profil mi? (profiles.is_default)
  final bool isDefault;

  /// Son giriş tarihi (profiles.last_login)
  final DateTime? lastLogin;

  /// Oluşturulma tarihi (profiles.created_at)
  final DateTime? createdAt;

  /// Güncellenme tarihi (profiles.updated_at)
  final DateTime? updatedAt;

  // ============================================
  // BUNDLE EKSTRALARI (fn_my_profile_bundle)
  // ============================================

  /// Coarse rol: ROLE_ADMIN | ROLE_MANAGER | ROLE_USER | ROLE_CUSTOMER
  final String? coarseRole;

  /// Tenant adı (bundle: tenant_name)
  final String? tenantName;

  /// Organizasyon ID (bundle: organization_id — staffs'tan; ≠1 staff satırı → null)
  final String? organizationId;

  const UserProfile({
    required this.id,
    this.email = '',
    this.username,
    this.fullName,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.phone,
    this.bio,
    this.twoFactorEnabled = false,
    this.active = true,
    this.tenantId,
    this.preferredLanguage = 'tr',
    this.type,
    this.siteId,
    this.name,
    this.description,
    this.isDefault = false,
    this.lastLogin,
    this.createdAt,
    this.updatedAt,
    this.coarseRole,
    this.tenantName,
    this.organizationId,
  });

  // ============================================
  // COMPUTED PROPERTIES
  // ============================================

  /// Görüntülenecek ad (non-null) — full_name > ad soyad > username > email öneki
  String get displayName {
    final fn = fullName?.trim();
    if (fn != null && fn.isNotEmpty) return fn;
    final combined = '${firstName ?? ''} ${lastName ?? ''}'.trim();
    if (combined.isNotEmpty) return combined;
    if (name != null && name!.trim().isNotEmpty) return name!.trim();
    if (username != null && username!.trim().isNotEmpty) return username!.trim();
    if (email.isNotEmpty) return email.split('@').first;
    return id;
  }

  /// Kısa ad (baş harfler)
  String get initials {
    final label = displayName;
    final parts = label.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    if (label.isEmpty) return '?';
    return label.substring(0, label.length >= 2 ? 2 : 1).toUpperCase();
  }

  /// Aktif mi? (profiles.active)
  bool get isActive => active;

  /// Avatar var mı?
  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;

  /// Telefon var mı?
  bool get hasPhone => phone != null && phone!.isNotEmpty;

  /// Organizasyon atanmış mı?
  bool get hasOrganization =>
      organizationId != null && organizationId!.isNotEmpty;

  /// Varsayılan site atanmış mı?
  bool get hasDefaultSite => siteId != null && siteId!.isNotEmpty;

  // ============================================
  // COARSE ROLE HELPERS
  // ============================================

  /// Yönetici mi? (super_admin/admin → ROLE_ADMIN)
  bool get isAdmin => coarseRole == 'ROLE_ADMIN';

  /// Müdür mü? (manager → ROLE_MANAGER)
  bool get isManager => coarseRole == 'ROLE_MANAGER';

  /// Standart kullanıcı mı? (staff/technician/... → ROLE_USER)
  bool get isUser => coarseRole == 'ROLE_USER';

  /// Müşteri mi? (customer → ROLE_CUSTOMER, yalnız /portal/*)
  bool get isCustomer => coarseRole == 'ROLE_CUSTOMER';

  // ============================================
  // JSON SERIALIZATION
  // ============================================

  /// Düz `profiles` satırından (veya bundle'dan) parse et.
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    return UserProfile(
      id: json['id'] as String,
      email: (json['email'] as String?) ?? '',
      username: json['username'] as String?,
      fullName: json['full_name'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      phone: json['phone'] as String?,
      bio: json['bio'] as String?,
      twoFactorEnabled: json['two_factor_enabled'] as bool? ?? false,
      active: json['active'] as bool? ?? true,
      tenantId: json['tenant_id'] as String?,
      preferredLanguage: json['preferred_language'] as String? ?? 'tr',
      type: json['type'] as String?,
      siteId: json['site_id'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      lastLogin: parseDate(json['last_login']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      // Bundle ekstraları (düz select'te null)
      coarseRole: json['coarse_role'] as String?,
      tenantName: json['tenant_name'] as String?,
      organizationId: json['organization_id'] as String?,
    );
  }

  /// `fn_my_profile_bundle` çıktısından parse et.
  ///
  /// Bundle = `to_jsonb(profiles.*)` + `tenant_name` + `organization_id`
  /// + `coarse_role`. Tek round-trip cold-start kaynağı.
  factory UserProfile.fromBundle(Map<String, dynamic> bundle) =>
      UserProfile.fromJson(bundle);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'full_name': fullName,
      'first_name': firstName,
      'last_name': lastName,
      'avatar_url': avatarUrl,
      'phone': phone,
      'bio': bio,
      'two_factor_enabled': twoFactorEnabled,
      'active': active,
      'tenant_id': tenantId,
      'preferred_language': preferredLanguage,
      'type': type,
      'site_id': siteId,
      'name': name,
      'description': description,
      'is_default': isDefault,
      'last_login': lastLogin?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'coarse_role': coarseRole,
      'tenant_name': tenantName,
      'organization_id': organizationId,
    };
  }

  /// Güncelleme için JSON — YALNIZCA gerçek, yazılabilir kolonlar.
  ///
  /// coarse_role/tenant_name/organization_id türetilmiştir (yazılamaz);
  /// active/tenant_id/type gibi alanlar backend/RLS tarafından yönetilir.
  Map<String, dynamic> toUpdateJson() {
    return {
      'full_name': fullName,
      'first_name': firstName,
      'last_name': lastName,
      'avatar_url': avatarUrl,
      'phone': phone,
      'bio': bio,
      'preferred_language': preferredLanguage,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  // ============================================
  // COPY WITH
  // ============================================

  UserProfile copyWith({
    String? id,
    String? email,
    String? username,
    String? fullName,
    String? firstName,
    String? lastName,
    String? avatarUrl,
    String? phone,
    String? bio,
    bool? twoFactorEnabled,
    bool? active,
    String? tenantId,
    String? preferredLanguage,
    String? type,
    String? siteId,
    String? name,
    String? description,
    bool? isDefault,
    DateTime? lastLogin,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? coarseRole,
    String? tenantName,
    String? organizationId,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      active: active ?? this.active,
      tenantId: tenantId ?? this.tenantId,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      type: type ?? this.type,
      siteId: siteId ?? this.siteId,
      name: name ?? this.name,
      description: description ?? this.description,
      isDefault: isDefault ?? this.isDefault,
      lastLogin: lastLogin ?? this.lastLogin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      coarseRole: coarseRole ?? this.coarseRole,
      tenantName: tenantName ?? this.tenantName,
      organizationId: organizationId ?? this.organizationId,
    );
  }

  @override
  String toString() => 'UserProfile($id, $displayName, $email)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is UserProfile && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Bildirim tercihleri (uygulama-yerel; `profiles` tablosunda persist EDİLMEZ).
///
/// NOT: eski `notification_preferences` kolonu DROP edildi. Bu sınıf yalnızca
/// uygulama içi tercih taşımak için tutuluyor; DB'ye yazılmaz.
class NotificationPreferences {
  /// Email bildirimleri
  final bool emailNotifications;

  /// Push bildirimleri
  final bool pushNotifications;

  /// SMS bildirimleri
  final bool smsNotifications;

  /// Aktivite bildirimleri
  final bool activityNotifications;

  /// Güncelleme bildirimleri
  final bool updateNotifications;

  /// Promosyon bildirimleri
  final bool promotionalNotifications;

  /// Sessiz saatler aktif mi?
  final bool quietHoursEnabled;

  /// Sessiz saat başlangıcı (HH:mm)
  final String? quietHoursStart;

  /// Sessiz saat bitişi (HH:mm)
  final String? quietHoursEnd;

  const NotificationPreferences({
    this.emailNotifications = true,
    this.pushNotifications = true,
    this.smsNotifications = false,
    this.activityNotifications = true,
    this.updateNotifications = true,
    this.promotionalNotifications = false,
    this.quietHoursEnabled = false,
    this.quietHoursStart,
    this.quietHoursEnd,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      emailNotifications: json['email_notifications'] as bool? ?? true,
      pushNotifications: json['push_notifications'] as bool? ?? true,
      smsNotifications: json['sms_notifications'] as bool? ?? false,
      activityNotifications: json['activity_notifications'] as bool? ?? true,
      updateNotifications: json['update_notifications'] as bool? ?? true,
      promotionalNotifications:
          json['promotional_notifications'] as bool? ?? false,
      quietHoursEnabled: json['quiet_hours_enabled'] as bool? ?? false,
      quietHoursStart: json['quiet_hours_start'] as String?,
      quietHoursEnd: json['quiet_hours_end'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email_notifications': emailNotifications,
      'push_notifications': pushNotifications,
      'sms_notifications': smsNotifications,
      'activity_notifications': activityNotifications,
      'update_notifications': updateNotifications,
      'promotional_notifications': promotionalNotifications,
      'quiet_hours_enabled': quietHoursEnabled,
      'quiet_hours_start': quietHoursStart,
      'quiet_hours_end': quietHoursEnd,
    };
  }

  NotificationPreferences copyWith({
    bool? emailNotifications,
    bool? pushNotifications,
    bool? smsNotifications,
    bool? activityNotifications,
    bool? updateNotifications,
    bool? promotionalNotifications,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
  }) {
    return NotificationPreferences(
      emailNotifications: emailNotifications ?? this.emailNotifications,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      smsNotifications: smsNotifications ?? this.smsNotifications,
      activityNotifications:
          activityNotifications ?? this.activityNotifications,
      updateNotifications: updateNotifications ?? this.updateNotifications,
      promotionalNotifications:
          promotionalNotifications ?? this.promotionalNotifications,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
    );
  }
}
