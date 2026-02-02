/// Kullanıcı profil durumu
enum UserProfileStatus {
  /// Aktif
  active,

  /// Pasif
  inactive,

  /// Askıda
  suspended,

  /// Silinmiş
  deleted,

  /// Doğrulama bekliyor
  pendingVerification;

  /// String'den UserProfileStatus'a dönüştür
  static UserProfileStatus fromString(String? value) {
    return UserProfileStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => UserProfileStatus.active,
    );
  }
}

/// Kullanıcı cinsiyet
enum UserGender {
  /// Erkek
  male('male', 'Erkek'),

  /// Kadın
  female('female', 'Kadın'),

  /// Belirtilmemiş
  notSpecified('not_specified', 'Belirtilmemiş');

  final String value;
  final String label;
  const UserGender(this.value, this.label);

  static UserGender fromString(String? value) {
    return UserGender.values.firstWhere(
      (e) => e.value == value || e.name == value,
      orElse: () => UserGender.notSpecified,
    );
  }
}

/// Kullanıcı Profili modeli
///
/// Supabase auth.users tablosunu genişleten profil bilgileri.
/// profiles tablosunda tutulur.
class UserProfile {
  /// Kullanıcı ID (auth.users.id)
  final String id;

  /// Email adresi
  final String email;

  /// Email doğrulanmış mı?
  final bool emailVerified;

  /// Görüntülenecek ad
  final String? displayName;

  /// Ad
  final String? firstName;

  /// Soyad
  final String? lastName;

  /// Avatar URL
  final String? avatarUrl;

  /// Telefon numarası
  final String? phone;

  /// Telefon doğrulanmış mı?
  final bool phoneVerified;

  /// Doğum tarihi
  final DateTime? birthDate;

  /// Cinsiyet
  final UserGender gender;

  /// Biyografi
  final String? bio;

  /// Lokasyon/Şehir
  final String? location;

  /// Website
  final String? website;

  /// Profil durumu
  final UserProfileStatus status;

  /// Askıya alınma tarihi
  final DateTime? suspendedAt;

  /// Askıya alınma nedeni
  final String? suspendedReason;

  // ============================================
  // TERCIHLER
  // ============================================

  /// Tercih edilen dil
  final String preferredLanguage;

  /// Tercih edilen tema
  final String preferredTheme;

  /// Tercih edilen timezone
  final String? preferredTimezone;

  /// Bildirim tercihleri
  final NotificationPreferences notificationPreferences;

  // ============================================
  // METADATA
  // ============================================

  /// Son giriş tarihi
  final DateTime? lastLoginAt;

  /// Son giriş IP'si
  final String? lastLoginIp;

  /// Giriş sayısı
  final int loginCount;

  /// Profil tamamlanma yüzdesi
  final int profileCompleteness;

  // ============================================
  // ZAMAN DAMGALARI
  // ============================================

  /// Oluşturulma tarihi
  final DateTime createdAt;

  /// Güncellenme tarihi
  final DateTime? updatedAt;

  /// Silinme tarihi (soft delete)
  final DateTime? deletedAt;

  // ============================================
  // ORGANİZASYON İLİŞKİLERİ
  // ============================================

  /// Varsayılan organizasyon ID
  final String? organizationId;

  /// Varsayılan site ID
  final String? defaultSiteId;

  const UserProfile({
    required this.id,
    required this.email,
    this.emailVerified = false,
    this.displayName,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.phone,
    this.phoneVerified = false,
    this.birthDate,
    this.gender = UserGender.notSpecified,
    this.bio,
    this.location,
    this.website,
    this.status = UserProfileStatus.active,
    this.suspendedAt,
    this.suspendedReason,
    this.preferredLanguage = 'tr',
    this.preferredTheme = 'system',
    this.preferredTimezone,
    this.notificationPreferences = const NotificationPreferences(),
    this.lastLoginAt,
    this.lastLoginIp,
    this.loginCount = 0,
    this.profileCompleteness = 0,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.organizationId,
    this.defaultSiteId,
  });

  // ============================================
  // COMPUTED PROPERTIES
  // ============================================

  /// Tam ad
  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return displayName ?? firstName ?? lastName ?? email.split('@').first;
  }

  /// Kısa ad (baş harfler)
  String get initials {
    final name = fullName;
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  /// Aktif mi?
  bool get isActive => status == UserProfileStatus.active;

  /// Askıda mı?
  bool get isSuspended => status == UserProfileStatus.suspended;

  /// Silinmiş mi?
  bool get isDeleted => status == UserProfileStatus.deleted;

  /// Doğrulama bekliyor mu?
  bool get isPendingVerification => status == UserProfileStatus.pendingVerification;

  /// Profil tamamlandı mı? (%80 üzeri)
  bool get isProfileComplete => profileCompleteness >= 80;

  /// Avatar var mı?
  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;

  /// Telefon var mı?
  bool get hasPhone => phone != null && phone!.isNotEmpty;

  /// Yaş (birthDate varsa)
  int? get age {
    if (birthDate == null) return null;
    final now = DateTime.now();
    int age = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      age--;
    }
    return age;
  }

  /// Organizasyon atanmış mı?
  bool get hasOrganization => organizationId != null && organizationId!.isNotEmpty;

  /// Varsayılan site atanmış mı?
  bool get hasDefaultSite => defaultSiteId != null && defaultSiteId!.isNotEmpty;

  // ============================================
  // JSON SERIALIZATION
  // ============================================

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      emailVerified: json['email_verified'] as bool? ?? false,
      displayName: json['display_name'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      phone: json['phone'] as String?,
      phoneVerified: json['phone_verified'] as bool? ?? false,
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'] as String)
          : null,
      gender: UserGender.fromString(json['gender'] as String?),
      bio: json['bio'] as String?,
      location: json['location'] as String?,
      website: json['website'] as String?,
      status: UserProfileStatus.fromString(json['status'] as String?),
      suspendedAt: json['suspended_at'] != null
          ? DateTime.tryParse(json['suspended_at'] as String)
          : null,
      suspendedReason: json['suspended_reason'] as String?,
      preferredLanguage: json['preferred_language'] as String? ?? 'tr',
      preferredTheme: json['preferred_theme'] as String? ?? 'system',
      preferredTimezone: json['preferred_timezone'] as String?,
      notificationPreferences: json['notification_preferences'] != null
          ? NotificationPreferences.fromJson(
              json['notification_preferences'] as Map<String, dynamic>)
          : const NotificationPreferences(),
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.tryParse(json['last_login_at'] as String)
          : null,
      lastLoginIp: json['last_login_ip'] as String?,
      loginCount: json['login_count'] as int? ?? 0,
      profileCompleteness: json['profile_completeness'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'] as String)
          : null,
      organizationId: json['organization_id'] as String?,
      defaultSiteId: json['default_site_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'email_verified': emailVerified,
      'display_name': displayName,
      'first_name': firstName,
      'last_name': lastName,
      'avatar_url': avatarUrl,
      'phone': phone,
      'phone_verified': phoneVerified,
      'birth_date': birthDate?.toIso8601String(),
      'gender': gender.value,
      'bio': bio,
      'location': location,
      'website': website,
      'status': status.name,
      'suspended_at': suspendedAt?.toIso8601String(),
      'suspended_reason': suspendedReason,
      'preferred_language': preferredLanguage,
      'preferred_theme': preferredTheme,
      'preferred_timezone': preferredTimezone,
      'notification_preferences': notificationPreferences.toJson(),
      'last_login_at': lastLoginAt?.toIso8601String(),
      'last_login_ip': lastLoginIp,
      'login_count': loginCount,
      'profile_completeness': profileCompleteness,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'organization_id': organizationId,
      'default_site_id': defaultSiteId,
    };
  }

  /// Güncelleme için JSON (sadece değiştirilebilir alanlar)
  Map<String, dynamic> toUpdateJson() {
    return {
      'display_name': displayName,
      'first_name': firstName,
      'last_name': lastName,
      'avatar_url': avatarUrl,
      'phone': phone,
      'birth_date': birthDate?.toIso8601String(),
      'gender': gender.value,
      'bio': bio,
      'location': location,
      'website': website,
      'preferred_language': preferredLanguage,
      'preferred_theme': preferredTheme,
      'preferred_timezone': preferredTimezone,
      'notification_preferences': notificationPreferences.toJson(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  // ============================================
  // COPY WITH
  // ============================================

  UserProfile copyWith({
    String? id,
    String? email,
    bool? emailVerified,
    String? displayName,
    String? firstName,
    String? lastName,
    String? avatarUrl,
    String? phone,
    bool? phoneVerified,
    DateTime? birthDate,
    UserGender? gender,
    String? bio,
    String? location,
    String? website,
    UserProfileStatus? status,
    DateTime? suspendedAt,
    String? suspendedReason,
    String? preferredLanguage,
    String? preferredTheme,
    String? preferredTimezone,
    NotificationPreferences? notificationPreferences,
    DateTime? lastLoginAt,
    String? lastLoginIp,
    int? loginCount,
    int? profileCompleteness,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? organizationId,
    String? defaultSiteId,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      displayName: displayName ?? this.displayName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      website: website ?? this.website,
      status: status ?? this.status,
      suspendedAt: suspendedAt ?? this.suspendedAt,
      suspendedReason: suspendedReason ?? this.suspendedReason,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      preferredTheme: preferredTheme ?? this.preferredTheme,
      preferredTimezone: preferredTimezone ?? this.preferredTimezone,
      notificationPreferences: notificationPreferences ?? this.notificationPreferences,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      lastLoginIp: lastLoginIp ?? this.lastLoginIp,
      loginCount: loginCount ?? this.loginCount,
      profileCompleteness: profileCompleteness ?? this.profileCompleteness,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      organizationId: organizationId ?? this.organizationId,
      defaultSiteId: defaultSiteId ?? this.defaultSiteId,
    );
  }

  @override
  String toString() => 'UserProfile($id, $fullName, $email)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is UserProfile && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Bildirim tercihleri
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
      promotionalNotifications: json['promotional_notifications'] as bool? ?? false,
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
      activityNotifications: activityNotifications ?? this.activityNotifications,
      updateNotifications: updateNotifications ?? this.updateNotifications,
      promotionalNotifications: promotionalNotifications ?? this.promotionalNotifications,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
    );
  }
}

/// Profil tamamlanma yüzdesini hesapla
int calculateProfileCompleteness(UserProfile profile) {
  int score = 0;
  const int maxScore = 100;

  // Zorunlu alanlar (50 puan)
  if (profile.email.isNotEmpty) score += 10;
  if (profile.emailVerified) score += 10;
  if (profile.displayName != null) score += 10;
  if (profile.firstName != null) score += 10;
  if (profile.lastName != null) score += 10;

  // İsteğe bağlı alanlar (50 puan)
  if (profile.hasAvatar) score += 10;
  if (profile.hasPhone) score += 5;
  if (profile.phoneVerified) score += 5;
  if (profile.birthDate != null) score += 5;
  if (profile.gender != UserGender.notSpecified) score += 5;
  if (profile.bio != null && profile.bio!.isNotEmpty) score += 5;
  if (profile.location != null && profile.location!.isNotEmpty) score += 5;
  if (profile.preferredTimezone != null) score += 5;
  if (profile.website != null && profile.website!.isNotEmpty) score += 5;

  return (score / maxScore * 100).round().clamp(0, 100);
}
