/// IoT Log modeli
///
/// DB tablosu: logs
/// Controller, provider ve variable ile ilişkili operasyonel log kayıtları.
class IoTLog {
  final String id;
  final String? name;
  final String? code;
  final String? description;
  final String? value;
  final String? maintenance;
  final int? onOff;
  final bool active;
  final bool? cancelled;
  final bool? isArchive;
  final String? archiveGroup;

  // Zaman bilgileri
  final DateTime? dateTime;

  // İlişkiler
  final String? tenantId;
  final String? controllerId;
  final String? providerId;
  final String? variableId;
  final String? realtimeId;

  // Zaman damgaları
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const IoTLog({
    required this.id,
    this.name,
    this.code,
    this.description,
    this.value,
    this.maintenance,
    this.onOff,
    this.active = true,
    this.cancelled,
    this.isArchive,
    this.archiveGroup,
    this.dateTime,
    this.tenantId,
    this.controllerId,
    this.providerId,
    this.variableId,
    this.realtimeId,
    this.createdAt,
    this.updatedAt,
  });

  /// On/Off durumu etiketi
  String get onOffLabel {
    if (onOff == null) return '-';
    return onOff == 1 ? 'ON' : 'OFF';
  }

  factory IoTLog.fromJson(Map<String, dynamic> json) {
    return IoTLog(
      id: json['id'] as String,
      name: json['name'] as String?,
      code: json['code'] as String?,
      description: json['description'] as String?,
      value: json['value'] as String?,
      maintenance: json['maintenance'] as String?,
      onOff: json['on_off'] as int? ?? json['onoff'] as int?,
      active: json['active'] as bool? ?? true,
      cancelled: json['cancelled'] as bool?,
      isArchive: json['is_archive'] as bool?,
      archiveGroup: json['archive_group'] as String?,
      dateTime: json['date_time'] != null
          ? DateTime.tryParse(json['date_time'] as String)
          : json['datetime'] != null
              ? DateTime.tryParse(json['datetime'] as String)
              : null,
      tenantId: json['tenant_id'] as String?,
      controllerId: json['controller_id'] as String?,
      providerId: json['provider_id'] as String?,
      variableId: json['variable_id'] as String?,
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
      'value': value,
      'maintenance': maintenance,
      'on_off': onOff,
      'active': active,
      'cancelled': cancelled,
      'date_time': dateTime?.toIso8601String(),
      'tenant_id': tenantId,
      'controller_id': controllerId,
      'provider_id': providerId,
      'variable_id': variableId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  String toString() => 'IoTLog($id, $name, value: $value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is IoTLog && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
