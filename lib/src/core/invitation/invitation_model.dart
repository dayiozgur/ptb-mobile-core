import '../tenant/tenant_model.dart';

/// Davet durumu
enum InvitationStatus {
  /// Beklemede
  pending('pending'),

  /// Kabul edildi
  accepted('accepted'),

  /// Reddedildi
  rejected('rejected'),

  /// Süresi doldu
  expired('expired'),

  /// İptal edildi
  cancelled('cancelled');

  final String value;
  const InvitationStatus(this.value);

  static InvitationStatus fromString(String? value) {
    return InvitationStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => InvitationStatus.pending,
    );
  }

  /// Türkçe gösterim
  String get displayName {
    switch (this) {
      case InvitationStatus.pending:
        return 'Beklemede';
      case InvitationStatus.accepted:
        return 'Kabul Edildi';
      case InvitationStatus.rejected:
        return 'Reddedildi';
      case InvitationStatus.expired:
        return 'Süresi Doldu';
      case InvitationStatus.cancelled:
        return 'İptal Edildi';
    }
  }

  /// Durum aktif mi? (işlem yapılabilir mi?)
  bool get isActive => this == InvitationStatus.pending;
}

/// Kullanıcı daveti modeli
///
/// Tenant'a yeni kullanıcı davet etmek için kullanılır.
/// Email ile davet gönderilir, kullanıcı kabul ederse tenant_users'a eklenir.
class Invitation {
  /// Benzersiz ID
  final String id;

  /// Davet edilen email
  final String email;

  /// Davet edilen tenant ID
  final String tenantId;

  /// Davet edilen tenant (opsiyonel, join ile gelebilir)
  final String? tenantName;

  /// Atanan rol
  final TenantRole role;

  /// Davet durumu
  final InvitationStatus status;

  /// Davet token (benzersiz, URL'de kullanılır)
  final String token;

  /// Davet mesajı (opsiyonel)
  final String? message;

  /// Davet eden kullanıcı ID
  final String invitedBy;

  /// Davet eden kullanıcı adı (opsiyonel)
  final String? invitedByName;

  /// Davet tarihi
  final DateTime createdAt;

  /// Son geçerlilik tarihi
  final DateTime expiresAt;

  /// Kabul/red tarihi
  final DateTime? respondedAt;

  /// Kabul eden kullanıcı ID (yeni kayıt veya mevcut)
  final String? acceptedUserId;

  /// Metadata (ek bilgiler)
  final Map<String, dynamic>? metadata;

  Invitation({
    required this.id,
    required this.email,
    required this.tenantId,
    this.tenantName,
    required this.role,
    required this.status,
    required this.token,
    this.message,
    required this.invitedBy,
    this.invitedByName,
    required this.createdAt,
    required this.expiresAt,
    this.respondedAt,
    this.acceptedUserId,
    this.metadata,
  });

  // ============================================
  // JSON SERIALIZATION
  // ============================================

  factory Invitation.fromJson(Map<String, dynamic> json) {
    return Invitation(
      id: json['id'] as String,
      email: json['email'] as String,
      tenantId: json['tenant_id'] as String,
      tenantName: json['tenant_name'] as String? ??
          (json['tenant'] as Map<String, dynamic>?)?['name'] as String?,
      role: TenantRole.fromString(json['role'] as String? ?? 'member'),
      status: InvitationStatus.fromString(json['status'] as String?),
      token: json['token'] as String,
      message: json['message'] as String?,
      invitedBy: json['invited_by'] as String,
      invitedByName: json['invited_by_name'] as String? ??
          (json['inviter'] as Map<String, dynamic>?)?['full_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      respondedAt: json['responded_at'] != null
          ? DateTime.tryParse(json['responded_at'] as String)
          : null,
      acceptedUserId: json['accepted_user_id'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'tenant_id': tenantId,
      'tenant_name': tenantName,
      'role': role.value,
      'status': status.value,
      'token': token,
      'message': message,
      'invited_by': invitedBy,
      'invited_by_name': invitedByName,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'responded_at': respondedAt?.toIso8601String(),
      'accepted_user_id': acceptedUserId,
      'metadata': metadata,
    };
  }

  // ============================================
  // COPY WITH
  // ============================================

  Invitation copyWith({
    String? id,
    String? email,
    String? tenantId,
    String? tenantName,
    TenantRole? role,
    InvitationStatus? status,
    String? token,
    String? message,
    String? invitedBy,
    String? invitedByName,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? respondedAt,
    String? acceptedUserId,
    Map<String, dynamic>? metadata,
  }) {
    return Invitation(
      id: id ?? this.id,
      email: email ?? this.email,
      tenantId: tenantId ?? this.tenantId,
      tenantName: tenantName ?? this.tenantName,
      role: role ?? this.role,
      status: status ?? this.status,
      token: token ?? this.token,
      message: message ?? this.message,
      invitedBy: invitedBy ?? this.invitedBy,
      invitedByName: invitedByName ?? this.invitedByName,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      respondedAt: respondedAt ?? this.respondedAt,
      acceptedUserId: acceptedUserId ?? this.acceptedUserId,
      metadata: metadata ?? this.metadata,
    );
  }

  // ============================================
  // HELPERS
  // ============================================

  /// Davet süresi dolmuş mu?
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Davet geçerli mi? (pending ve süresi dolmamış)
  bool get isValid => status == InvitationStatus.pending && !isExpired;

  /// Kalan süre
  Duration get remainingTime {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) return Duration.zero;
    return expiresAt.difference(now);
  }

  /// Kalan gün
  int get remainingDays => remainingTime.inDays;

  /// Kalan saat
  int get remainingHours => remainingTime.inHours % 24;

  @override
  String toString() =>
      'Invitation(id: $id, email: $email, tenantId: $tenantId, status: $status)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Invitation && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Davet oluşturma isteği
class CreateInvitationRequest {
  /// Davet edilecek email
  final String email;

  /// Hedef tenant ID
  final String tenantId;

  /// Atanacak rol
  final TenantRole role;

  /// Opsiyonel mesaj
  final String? message;

  /// Geçerlilik süresi (gün cinsinden, varsayılan 7)
  final int expirationDays;

  CreateInvitationRequest({
    required this.email,
    required this.tenantId,
    this.role = TenantRole.member,
    this.message,
    this.expirationDays = 7,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'tenant_id': tenantId,
        'role': role.value,
        'message': message,
        'expiration_days': expirationDays,
      };
}

/// Toplu davet oluşturma isteği
class BulkInvitationRequest {
  /// Davet edilecek email listesi
  final List<String> emails;

  /// Hedef tenant ID
  final String tenantId;

  /// Atanacak rol (tümü için aynı)
  final TenantRole role;

  /// Opsiyonel mesaj
  final String? message;

  /// Geçerlilik süresi (gün cinsinden)
  final int expirationDays;

  BulkInvitationRequest({
    required this.emails,
    required this.tenantId,
    this.role = TenantRole.member,
    this.message,
    this.expirationDays = 7,
  });

  Map<String, dynamic> toJson() => {
        'emails': emails,
        'tenant_id': tenantId,
        'role': role.value,
        'message': message,
        'expiration_days': expirationDays,
      };
}

/// Davet yanıtı (kabul/red)
class InvitationResponse {
  /// Davet token
  final String token;

  /// Kabul mü red mi?
  final bool accepted;

  /// Red nedeni (opsiyonel)
  final String? rejectionReason;

  InvitationResponse({
    required this.token,
    required this.accepted,
    this.rejectionReason,
  });

  Map<String, dynamic> toJson() => {
        'token': token,
        'accepted': accepted,
        'rejection_reason': rejectionReason,
      };
}
