/// Bildirim türleri (mevcut DB şemasına uygun)
enum NotificationType {
  /// Uyarı bildirimi
  alert('ALERT', 'Uyarı'),

  /// Hatırlatma bildirimi
  reminder('REMINDER', 'Hatırlatma'),

  /// Bilgi bildirimi
  info('INFO', 'Bilgi');

  final String value;
  final String label;

  const NotificationType(this.value, this.label);

  static NotificationType? fromString(String? value) {
    if (value == null) return null;
    return NotificationType.values.cast<NotificationType?>().firstWhere(
          (e) => e?.value == value,
          orElse: () => null,
        );
  }
}

/// Entity türleri (mevcut DB şemasına uygun)
enum NotificationEntityType {
  invoice('INVOICE', 'Fatura'),
  production('PRODUCTION', 'Üretim'),
  product('PRODUCT', 'Ürün'),
  blueprint('BLUEPRINT', 'Şablon'),
  productionOrder('PRODUCTION_ORDER', 'Üretim Siparişi'),
  controller('CONTROLLER', 'Kontrol Cihazı'),
  provider('PROVIDER', 'Tedarikçi'),
  item('ITEM', 'Öğe'),
  unit('UNIT', 'Alan');

  final String value;
  final String label;

  const NotificationEntityType(this.value, this.label);

  static NotificationEntityType? fromString(String? value) {
    if (value == null) return null;
    return NotificationEntityType.values.cast<NotificationEntityType?>().firstWhere(
          (e) => e?.value == value,
          orElse: () => null,
        );
  }
}

/// Bildirim önceliği (0-11 arası, DB şemasına uygun)
class NotificationPriority {
  final int value;

  const NotificationPriority(this.value);

  static const NotificationPriority low = NotificationPriority(0);
  static const NotificationPriority normal = NotificationPriority(5);
  static const NotificationPriority high = NotificationPriority(8);
  static const NotificationPriority urgent = NotificationPriority(11);

  String get label {
    if (value <= 2) return 'Düşük';
    if (value <= 5) return 'Normal';
    if (value <= 8) return 'Yüksek';
    return 'Acil';
  }

  bool get isLow => value <= 2;
  bool get isNormal => value > 2 && value <= 5;
  bool get isHigh => value > 5 && value <= 8;
  bool get isUrgent => value > 8;
}

/// Bildirim modeli (mevcut notifications tablosuna uygun)
///
/// Uygulama içi bildirimleri temsil eder.
class AppNotification {
  /// Benzersiz ID
  final String id;

  /// Row ID (serial)
  final int? rowId;

  /// Aktif mi?
  final bool active;

  /// Bildirim başlığı
  final String? title;

  /// Bildirim açıklaması
  final String? description;

  /// Bildirim türü
  final NotificationType? type;

  /// Öncelik (0-11)
  final NotificationPriority priority;

  /// İlgili entity tipi
  final NotificationEntityType? entityType;

  /// İlgili entity ID
  final String? entityId;

  /// Ek meta verisi (JSON string)
  final String? meta;

  /// Bildirim tarihi/saati
  final DateTime? dateTime;

  /// Okundu mu?
  final bool isRead;

  /// Gönderildi mi?
  final bool sent;

  /// Onaylandı mı?
  final bool acknowledged;

  /// Onaylama tarihi
  final DateTime? acknowledgedAt;

  /// Onaylayan kullanıcı ID
  final String? acknowledgedBy;

  /// Platform ID
  final String? platformId;

  /// Profil ID (alıcı)
  final String? profileId;

  /// Oluşturan kullanıcı ID
  final String? createdBy;

  /// Oluşturulma tarihi
  final DateTime? createdAt;

  /// Güncelleyen kullanıcı ID
  final String? updatedBy;

  /// Güncellenme tarihi
  final DateTime? updatedAt;

  /// Profil bilgileri (eager loaded)
  final NotificationProfile? profile;

  AppNotification({
    required this.id,
    this.rowId,
    this.active = true,
    this.title,
    this.description,
    this.type,
    this.priority = const NotificationPriority(5),
    this.entityType,
    this.entityId,
    this.meta,
    this.dateTime,
    this.isRead = false,
    this.sent = false,
    this.acknowledged = false,
    this.acknowledgedAt,
    this.acknowledgedBy,
    this.platformId,
    this.profileId,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
    this.profile,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      rowId: json['row_id'] as int?,
      active: json['active'] as bool? ?? true,
      title: json['title'] as String?,
      description: json['description'] as String?,
      type: NotificationType.fromString(json['notification_type'] as String?),
      priority: NotificationPriority(json['priority'] as int? ?? 5),
      entityType: NotificationEntityType.fromString(json['entity_type'] as String?),
      entityId: json['entity_id'] as String?,
      meta: json['meta'] as String?,
      dateTime: json['date_time'] != null
          ? DateTime.tryParse(json['date_time'] as String)
          : null,
      isRead: json['read'] as bool? ?? false,
      sent: json['sent'] as bool? ?? false,
      acknowledged: json['acknowledged'] as bool? ?? false,
      acknowledgedAt: json['acknowledged_at'] != null
          ? DateTime.tryParse(json['acknowledged_at'] as String)
          : null,
      acknowledgedBy: json['acknowledged_by'] as String?,
      platformId: json['platform_id'] as String?,
      profileId: json['profile_id'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedBy: json['updated_by'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      profile: json['profile'] != null
          ? NotificationProfile.fromJson(json['profile'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'row_id': rowId,
        'active': active,
        'title': title,
        'description': description,
        'notification_type': type?.value,
        'priority': priority.value,
        'entity_type': entityType?.value,
        'entity_id': entityId,
        'meta': meta,
        'date_time': dateTime?.toIso8601String(),
        'read': isRead,
        'sent': sent,
        'acknowledged': acknowledged,
        'acknowledged_at': acknowledgedAt?.toIso8601String(),
        'acknowledged_by': acknowledgedBy,
        'platform_id': platformId,
        'profile_id': profileId,
        'created_by': createdBy,
        'created_at': createdAt?.toIso8601String(),
        'updated_by': updatedBy,
        'updated_at': updatedAt?.toIso8601String(),
      };

  AppNotification copyWith({
    String? id,
    int? rowId,
    bool? active,
    String? title,
    String? description,
    NotificationType? type,
    NotificationPriority? priority,
    NotificationEntityType? entityType,
    String? entityId,
    String? meta,
    DateTime? dateTime,
    bool? isRead,
    bool? sent,
    bool? acknowledged,
    DateTime? acknowledgedAt,
    String? acknowledgedBy,
    String? platformId,
    String? profileId,
    String? createdBy,
    DateTime? createdAt,
    String? updatedBy,
    DateTime? updatedAt,
    NotificationProfile? profile,
  }) {
    return AppNotification(
      id: id ?? this.id,
      rowId: rowId ?? this.rowId,
      active: active ?? this.active,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      meta: meta ?? this.meta,
      dateTime: dateTime ?? this.dateTime,
      isRead: isRead ?? this.isRead,
      sent: sent ?? this.sent,
      acknowledged: acknowledged ?? this.acknowledged,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      acknowledgedBy: acknowledgedBy ?? this.acknowledgedBy,
      platformId: platformId ?? this.platformId,
      profileId: profileId ?? this.profileId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      profile: profile ?? this.profile,
    );
  }

  /// Bildirim ne kadar önce oluşturuldu
  String get timeAgo {
    final date = dateTime ?? createdAt ?? DateTime.now();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Az önce';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dakika önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} saat önce';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} hafta önce';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()} ay önce';
    } else {
      return '${(difference.inDays / 365).floor()} yıl önce';
    }
  }

  /// Mesaj metni (title veya description)
  String get message => description ?? title ?? '';

  @override
  String toString() =>
      'AppNotification(id: $id, title: $title, type: ${type?.value})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotification &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Bildirim profil bilgisi
class NotificationProfile {
  final String id;
  final String? fullName;
  final String? avatarUrl;

  NotificationProfile({
    required this.id,
    this.fullName,
    this.avatarUrl,
  });

  factory NotificationProfile.fromJson(Map<String, dynamic> json) {
    return NotificationProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'avatar_url': avatarUrl,
      };
}

/// Bildirim özeti
class NotificationSummary {
  /// Toplam bildirim sayısı
  final int total;

  /// Okunmamış bildirim sayısı
  final int unread;

  /// Onaylanmamış bildirim sayısı
  final int unacknowledged;

  /// Türe göre sayılar
  final Map<NotificationType, int> byType;

  NotificationSummary({
    required this.total,
    required this.unread,
    this.unacknowledged = 0,
    this.byType = const {},
  });

  factory NotificationSummary.empty() => NotificationSummary(
        total: 0,
        unread: 0,
        unacknowledged: 0,
        byType: {},
      );

  /// Okunmamış bildirim var mı?
  bool get hasUnread => unread > 0;

  /// Onaylanmamış bildirim var mı?
  bool get hasUnacknowledged => unacknowledged > 0;
}
