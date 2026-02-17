/// Aktivite aksiyonları
enum ActivityAction {
  create('create', 'Oluşturma'),
  read('read', 'Görüntüleme'),
  update('update', 'Güncelleme'),
  delete('delete', 'Silme'),
  login('login', 'Giriş'),
  logout('logout', 'Çıkış'),
  export_('export', 'Dışa Aktarma'),
  import_('import', 'İçe Aktarma'),
  enable('enable', 'Etkinleştirme'),
  disable('disable', 'Devre Dışı Bırakma');

  final String value;
  final String displayName;
  const ActivityAction(this.value, this.displayName);

  static ActivityAction fromString(String value) {
    return ActivityAction.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ActivityAction.read,
    );
  }
}

/// Entity türleri
enum EntityType {
  tenant('tenant', 'Tenant'),
  organization('organization', 'Organizasyon'),
  site('site', 'Site'),
  unit('unit', 'Alan'),
  user('user', 'Kullanıcı'),
  invitation('invitation', 'Davet'),
  profile('profile', 'Profil'),
  settings('settings', 'Ayarlar'),
  other('other', 'Diğer');

  final String value;
  final String displayName;
  const EntityType(this.value, this.displayName);

  static EntityType fromString(String value) {
    return EntityType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EntityType.other,
    );
  }
}

/// Aktivite log modeli
class ActivityLog {
  final String id;
  final String? tenantId;
  final String? userId;
  final EntityType entityType;
  final String entityId;
  final ActivityAction action;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final String? ipAddress;
  final String? userAgent;
  final String? requestId;
  final DateTime createdAt;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? updatedAt;

  // Joined data
  final String? userName;
  final String? userEmail;
  final String? entityName;

  const ActivityLog({
    required this.id,
    this.tenantId,
    this.userId,
    required this.entityType,
    required this.entityId,
    required this.action,
    this.oldValues,
    this.newValues,
    this.ipAddress,
    this.userAgent,
    this.requestId,
    required this.createdAt,
    this.createdBy,
    this.updatedBy,
    this.updatedAt,
    this.userName,
    this.userEmail,
    this.entityName,
  });

  /// JSON'dan oluştur
  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String?,
      userId: json['user_id'] as String?,
      entityType: EntityType.fromString(json['entity_type'] as String? ?? 'other'),
      entityId: json['entity_id'] as String,
      action: ActivityAction.fromString(json['action'] as String),
      oldValues: json['old_values'] as Map<String, dynamic>?,
      newValues: json['new_values'] as Map<String, dynamic>?,
      ipAddress: json['ip_address'] as String?,
      userAgent: json['user_agent'] as String?,
      requestId: json['request_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      userName: json['user_name'] as String? ??
                (json['profiles'] as Map<String, dynamic>?)?['full_name'] as String?,
      userEmail: json['user_email'] as String?,
      entityName: json['entity_name'] as String?,
    );
  }

  /// JSON'a dönüştür
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'user_id': userId,
      'entity_type': entityType.value,
      'entity_id': entityId,
      'action': action.value,
      'old_values': oldValues,
      'new_values': newValues,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'request_id': requestId,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Okunabilir aktivite metni
  String get displayText {
    final actionText = action.displayName.toLowerCase();
    final entityText = entityType.displayName.toLowerCase();

    switch (action) {
      case ActivityAction.login:
        return 'Sisteme giriş yapıldı';
      case ActivityAction.logout:
        return 'Sistemden çıkış yapıldı';
      case ActivityAction.create:
        return '${entityType.displayName} oluşturuldu${entityName != null ? ': $entityName' : ''}';
      case ActivityAction.update:
        return '${entityType.displayName} güncellendi${entityName != null ? ': $entityName' : ''}';
      case ActivityAction.delete:
        return '${entityType.displayName} silindi${entityName != null ? ': $entityName' : ''}';
      default:
        return '$entityText $actionText';
    }
  }

  /// Göreceli zaman metni
  String get relativeTime {
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
    } else {
      return '${createdAt.day}.${createdAt.month}.${createdAt.year}';
    }
  }

  @override
  String toString() => 'ActivityLog($id, $action, $entityType)';
}
