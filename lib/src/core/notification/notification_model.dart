/// Bildirim türleri
enum NotificationType {
  /// Sistem bildirimi
  system('SYSTEM', 'Sistem'),

  /// Bilgi bildirimi
  info('INFO', 'Bilgi'),

  /// Uyarı bildirimi
  warning('WARNING', 'Uyarı'),

  /// Hata bildirimi
  error('ERROR', 'Hata'),

  /// Başarı bildirimi
  success('SUCCESS', 'Başarı'),

  /// Görev bildirimi
  task('TASK', 'Görev'),

  /// Aktivite bildirimi
  activity('ACTIVITY', 'Aktivite'),

  /// Davet bildirimi
  invitation('INVITATION', 'Davet'),

  /// Yorum bildirimi
  comment('COMMENT', 'Yorum'),

  /// Mention bildirimi
  mention('MENTION', 'Bahsetme');

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

/// Bildirim önceliği
enum NotificationPriority {
  low('LOW', 'Düşük'),
  normal('NORMAL', 'Normal'),
  high('HIGH', 'Yüksek'),
  urgent('URGENT', 'Acil');

  final String value;
  final String label;

  const NotificationPriority(this.value, this.label);

  static NotificationPriority? fromString(String? value) {
    if (value == null) return null;
    return NotificationPriority.values.cast<NotificationPriority?>().firstWhere(
          (e) => e?.value == value,
          orElse: () => null,
        );
  }
}

/// Bildirim modeli
///
/// Uygulama içi bildirimleri temsil eder.
class AppNotification {
  /// Benzersiz ID
  final String id;

  /// Bildirim başlığı
  final String title;

  /// Bildirim mesajı
  final String message;

  /// Bildirim türü
  final NotificationType type;

  /// Bildirim önceliği
  final NotificationPriority priority;

  /// İlgili entity tipi
  final String? entityType;

  /// İlgili entity ID
  final String? entityId;

  /// Yönlendirme URL'i
  final String? actionUrl;

  /// Ek veri
  final Map<String, dynamic>? data;

  /// Okundu mu?
  final bool isRead;

  /// Okunma tarihi
  final DateTime? readAt;

  /// Oluşturulma tarihi
  final DateTime createdAt;

  /// Tenant ID
  final String? tenantId;

  /// Kullanıcı ID (alıcı)
  final String userId;

  /// Gönderen kullanıcı ID
  final String? senderId;

  /// Gönderen bilgileri (eager loaded)
  final NotificationSender? sender;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    this.type = NotificationType.info,
    this.priority = NotificationPriority.normal,
    this.entityType,
    this.entityId,
    this.actionUrl,
    this.data,
    this.isRead = false,
    this.readAt,
    required this.createdAt,
    this.tenantId,
    required this.userId,
    this.senderId,
    this.sender,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: NotificationType.fromString(json['type'] as String?) ??
          NotificationType.info,
      priority:
          NotificationPriority.fromString(json['priority'] as String?) ??
              NotificationPriority.normal,
      entityType: json['entity_type'] as String?,
      entityId: json['entity_id'] as String?,
      actionUrl: json['action_url'] as String?,
      data: json['data'] as Map<String, dynamic>?,
      isRead: json['is_read'] as bool? ?? false,
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      tenantId: json['tenant_id'] as String?,
      userId: json['user_id'] as String,
      senderId: json['sender_id'] as String?,
      sender: json['sender'] != null
          ? NotificationSender.fromJson(json['sender'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'type': type.value,
        'priority': priority.value,
        'entity_type': entityType,
        'entity_id': entityId,
        'action_url': actionUrl,
        'data': data,
        'is_read': isRead,
        'read_at': readAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'tenant_id': tenantId,
        'user_id': userId,
        'sender_id': senderId,
      };

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    NotificationPriority? priority,
    String? entityType,
    String? entityId,
    String? actionUrl,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? readAt,
    DateTime? createdAt,
    String? tenantId,
    String? userId,
    String? senderId,
    NotificationSender? sender,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      actionUrl: actionUrl ?? this.actionUrl,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      tenantId: tenantId ?? this.tenantId,
      userId: userId ?? this.userId,
      senderId: senderId ?? this.senderId,
      sender: sender ?? this.sender,
    );
  }

  /// Bildirim ne kadar önce oluşturuldu
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

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

  @override
  String toString() =>
      'AppNotification(id: $id, title: $title, type: ${type.value})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotification &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Bildirim gönderen bilgisi
class NotificationSender {
  final String id;
  final String? fullName;
  final String? avatarUrl;

  NotificationSender({
    required this.id,
    this.fullName,
    this.avatarUrl,
  });

  factory NotificationSender.fromJson(Map<String, dynamic> json) {
    return NotificationSender(
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

  /// Türe göre sayılar
  final Map<NotificationType, int> byType;

  NotificationSummary({
    required this.total,
    required this.unread,
    this.byType = const {},
  });

  factory NotificationSummary.empty() => NotificationSummary(
        total: 0,
        unread: 0,
        byType: {},
      );

  factory NotificationSummary.fromJson(Map<String, dynamic> json) {
    final byTypeJson = json['by_type'] as Map<String, dynamic>? ?? {};
    final byType = <NotificationType, int>{};

    byTypeJson.forEach((key, value) {
      final type = NotificationType.fromString(key);
      if (type != null) {
        byType[type] = value as int;
      }
    });

    return NotificationSummary(
      total: json['total'] as int? ?? 0,
      unread: json['unread'] as int? ?? 0,
      byType: byType,
    );
  }

  Map<String, dynamic> toJson() {
    final byTypeJson = <String, int>{};
    byType.forEach((key, value) {
      byTypeJson[key.value] = value;
    });

    return {
      'total': total,
      'unread': unread,
      'by_type': byTypeJson,
    };
  }

  /// Okunmamış bildirim var mı?
  bool get hasUnread => unread > 0;
}
