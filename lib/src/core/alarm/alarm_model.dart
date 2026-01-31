/// Aktif alarm modeli
///
/// DB tablosu: alarms
/// Controller ve variable ile ilişkili, priority_id ile öncelik belirlenir.
///
/// Description Kaynağı:
///   - description: Doğrudan alarms tablosundan gelen açıklama
///   - variableName/variableDescription: Variable JOIN ile çekilirse doldurulur
///   - effectiveDescription: description ?? variableDescription (öncelikli)
class Alarm {
  final String id;
  final String? name;
  final String? code;
  final String? description;
  final String? status;
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

  // Onay bilgileri
  final DateTime? localAcknowledgeTime;
  final String? localAcknowledgeUser;
  final DateTime? remoteAcknowledgeTime;
  final String? remoteAcknowledgeUser;
  final DateTime? localDeleteTime;
  final String? localDeleteUser;
  final String? resetUser;

  // Durum
  final bool? inhibited;
  final bool? isLogic;

  // İlişkiler
  final String? controllerId;
  final String? variableId;
  final String? priorityId;
  final String? realtimeId;

  // Variable ilişkisinden gelen bilgiler (JOIN ile)
  final String? variableName;
  final String? variableDescription;
  final String? variableUnit;

  // Zaman damgaları
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Alarm({
    required this.id,
    this.name,
    this.code,
    this.description,
    this.status,
    this.category,
    this.active = true,
    this.startTime,
    this.endTime,
    this.arrivalStartTime,
    this.arrivalEndTime,
    this.inhibitTime,
    this.resetTime,
    this.lastUpdate,
    this.localAcknowledgeTime,
    this.localAcknowledgeUser,
    this.remoteAcknowledgeTime,
    this.remoteAcknowledgeUser,
    this.localDeleteTime,
    this.localDeleteUser,
    this.resetUser,
    this.inhibited,
    this.isLogic,
    this.controllerId,
    this.variableId,
    this.priorityId,
    this.realtimeId,
    this.variableName,
    this.variableDescription,
    this.variableUnit,
    this.createdAt,
    this.updatedAt,
  });

  /// Etkin açıklama - öncelik: alarms.description → variable.description → name
  String? get effectiveDescription =>
      description ?? variableDescription ?? name;

  /// Etkin isim - öncelik: alarms.name → variable.name → code
  String? get effectiveName => name ?? variableName ?? code;

  /// Alarm aktif mi (henüz kapanmamış)?
  bool get isActive => endTime == null && status != 'resolved';

  /// Onaylanmış mı?
  bool get isAcknowledged =>
      localAcknowledgeTime != null || remoteAcknowledgeTime != null;

  /// Süresi (aktifse şu ana kadar, kapandıysa toplam süre)
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

  factory Alarm.fromJson(Map<String, dynamic> json) {
    // Variable JOIN ile geldiyse nested object olarak gelir
    final variable = json['variable'] as Map<String, dynamic>?;

    return Alarm(
      id: json['id'] as String,
      name: json['name'] as String?,
      code: json['code'] as String?,
      description: json['description'] as String?,
      status: json['status'] as String?,
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
      arrivalEndTime: json['arrival_endtime'] != null
          ? DateTime.tryParse(json['arrival_endtime'] as String)
          : json['arrival_end_time'] != null
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
      localAcknowledgeTime: json['local_acknowledge_time'] != null
          ? DateTime.tryParse(json['local_acknowledge_time'] as String)
          : null,
      localAcknowledgeUser: json['local_acknowledge_user'] as String?,
      remoteAcknowledgeTime: json['remote_acknowledge_time'] != null
          ? DateTime.tryParse(json['remote_acknowledge_time'] as String)
          : null,
      remoteAcknowledgeUser: json['remote_acknowledge_user'] != null
          ? json['remote_acknowledge_user'].toString()
          : null,
      localDeleteTime: json['local_delete_time'] != null
          ? DateTime.tryParse(json['local_delete_time'] as String)
          : null,
      localDeleteUser: json['local_delete_user'] as String?,
      resetUser: json['reset_user'] as String?,
      inhibited: json['inhibited'] as bool?,
      isLogic: json['is_logic'] as bool?,
      controllerId: json['controller_id'] as String?,
      variableId: json['variable_id'] as String?,
      priorityId: json['priority_id'] as String?,
      realtimeId: json['realtime_id'] as String?,
      // Variable bilgileri (JOIN ile gelirse)
      variableName: variable?['name'] as String?,
      variableDescription: variable?['description'] as String?,
      variableUnit: variable?['unit'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'name': name,
      'code': code,
      'description': description,
      'status': status,
      'category': category,
      'active': active,
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'controller_id': controllerId,
      'variable_id': variableId,
      'priority_id': priorityId,
      'realtime_id': realtimeId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };

    // Variable bilgileri varsa ekle (cache için)
    if (variableName != null || variableDescription != null || variableUnit != null) {
      json['variable'] = {
        'name': variableName,
        'description': variableDescription,
        'unit': variableUnit,
      };
    }

    return json;
  }

  @override
  String toString() => 'Alarm($id, $name, status: $status)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Alarm && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
