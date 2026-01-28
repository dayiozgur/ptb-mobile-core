/// Alarm geçmişi modeli
///
/// DB tablosu: alarm_histories
/// Site, provider, controller, variable ilişkileri ile kapsamlı alarm kaydı.
class AlarmHistory {
  final String id;
  final String? name;
  final String? code;
  final String? description;
  final int? category;
  final bool active;

  // Zaman bilgileri
  final DateTime? startTime;
  final DateTime? endTime;
  final DateTime? arrivalStartTime;
  final DateTime? arrivalEndTime;
  final DateTime? inhibitTime;
  final DateTime? resetTime;
  final DateTime? lastUpdate;
  final DateTime? deleteActionTime;

  // Onay bilgileri
  final DateTime? localAcknowledgeTime;
  final String? localAcknowledgeUser;
  final DateTime? remoteAcknowledgeTime;
  final String? remoteAcknowledgeUser;
  final String? deleteActionUser;
  final String? resetUser;

  // Durum
  final bool? inhibited;
  final bool? isLogic;
  final bool? isArchive;
  final String? archiveGroup;
  final String? txnGroupId;

  // İlişkiler
  final String? tenantId;
  final String? organizationId;
  final String? siteId;
  final String? controllerId;
  final String? canceledControllerId;
  final String? contractorId;
  final String? providerId;
  final String? variableId;
  final String? priorityId;
  final String? realtimeId;

  // Zaman damgaları
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AlarmHistory({
    required this.id,
    this.name,
    this.code,
    this.description,
    this.category,
    this.active = true,
    this.startTime,
    this.endTime,
    this.arrivalStartTime,
    this.arrivalEndTime,
    this.inhibitTime,
    this.resetTime,
    this.lastUpdate,
    this.deleteActionTime,
    this.localAcknowledgeTime,
    this.localAcknowledgeUser,
    this.remoteAcknowledgeTime,
    this.remoteAcknowledgeUser,
    this.deleteActionUser,
    this.resetUser,
    this.inhibited,
    this.isLogic,
    this.isArchive,
    this.archiveGroup,
    this.txnGroupId,
    this.tenantId,
    this.organizationId,
    this.siteId,
    this.controllerId,
    this.canceledControllerId,
    this.contractorId,
    this.providerId,
    this.variableId,
    this.priorityId,
    this.realtimeId,
    this.createdAt,
    this.updatedAt,
  });

  /// Alarm süresi
  Duration? get duration {
    if (startTime == null) return null;
    final end = endTime ?? DateTime.now();
    return end.difference(startTime!);
  }

  /// Süre formatlanmış
  String get durationFormatted {
    final d = duration;
    if (d == null) return '-';
    if (d.inDays > 0) return '${d.inDays}g ${d.inHours % 24}s';
    if (d.inHours > 0) return '${d.inHours}s ${d.inMinutes % 60}dk';
    return '${d.inMinutes}dk';
  }

  /// Çözülmüş mü?
  bool get isResolved => endTime != null;

  factory AlarmHistory.fromJson(Map<String, dynamic> json) {
    return AlarmHistory(
      id: json['id'] as String,
      name: json['name'] as String?,
      code: json['code'] as String?,
      description: json['description'] as String?,
      category: json['category'] as int?,
      active: json['active'] as bool? ?? true,
      startTime: json['start_time'] != null
          ? DateTime.tryParse(json['start_time'] as String)
          : null,
      endTime: json['end_time'] != null
          ? DateTime.tryParse(json['end_time'] as String)
          : null,
      arrivalStartTime: json['arrival_start_time'] != null
          ? DateTime.tryParse(json['arrival_start_time'] as String)
          : null,
      arrivalEndTime: json['arrival_end_time'] != null
          ? DateTime.tryParse(json['arrival_end_time'] as String)
          : null,
      inhibitTime: json['inhibit_time'] != null
          ? DateTime.tryParse(json['inhibit_time'] as String)
          : null,
      resetTime: json['reset_time'] != null
          ? DateTime.tryParse(json['reset_time'] as String)
          : null,
      lastUpdate: json['last_update'] != null
          ? DateTime.tryParse(json['last_update'] as String)
          : null,
      deleteActionTime: json['delete_action_time'] != null
          ? DateTime.tryParse(json['delete_action_time'] as String)
          : null,
      localAcknowledgeTime: json['local_acknowledge_time'] != null
          ? DateTime.tryParse(json['local_acknowledge_time'] as String)
          : null,
      localAcknowledgeUser: json['local_acknowledge_user'] as String?,
      remoteAcknowledgeTime: json['remote_acknowledge_time'] != null
          ? DateTime.tryParse(json['remote_acknowledge_time'] as String)
          : null,
      remoteAcknowledgeUser: json['remote_acknowledge_user'] as String?,
      deleteActionUser: json['delete_action_user'] as String?,
      resetUser: json['reset_user'] as String?,
      inhibited: json['inhibited'] as bool?,
      isLogic: json['is_logic'] as bool?,
      isArchive: json['is_archive'] as bool?,
      archiveGroup: json['archive_group'] as String?,
      txnGroupId: json['txn_group_id'] as String?,
      tenantId: json['tenant_id'] as String?,
      organizationId: json['organization_id'] as String?,
      siteId: json['site_id'] as String?,
      controllerId: json['controller_id'] as String?,
      canceledControllerId: json['canceled_controller_id'] as String?,
      contractorId: json['contractor_id'] as String?,
      providerId: json['provider_id'] as String?,
      variableId: json['variable_id'] as String?,
      priorityId: json['priority_id'] as String?,
      realtimeId: json['realtime_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'description': description,
      'category': category,
      'active': active,
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'tenant_id': tenantId,
      'organization_id': organizationId,
      'site_id': siteId,
      'controller_id': controllerId,
      'provider_id': providerId,
      'variable_id': variableId,
      'priority_id': priorityId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  String toString() => 'AlarmHistory($id, $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AlarmHistory && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
