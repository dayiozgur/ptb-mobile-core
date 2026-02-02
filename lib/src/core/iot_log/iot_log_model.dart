import '../utils/db_field_helpers.dart';

/// IoT Log modeli
///
/// DB tablosu: logs
/// Controller, provider ve variable ile ilişkili operasyonel log kayıtları.
///
/// Description Kaynağı:
///   - description: Doğrudan logs tablosundan gelen açıklama
///   - variableName/variableDescription: Variable JOIN ile çekilirse doldurulur
///   - effectiveDescription: description ?? variableDescription (öncelikli)
///
/// NOT: DB'de dual column yapısı vardır:
///   - datetime (legacy) / date_time (current) → zaman damgası
///   - onoff (legacy) / on_off (current) → on/off durumu
/// DbFieldHelpers kullanılarak her iki kolon da desteklenir.
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

  // Variable ilişkisinden gelen bilgiler (JOIN ile)
  final String? variableName;
  final String? variableDescription;
  final String? variableUnit;

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
    this.variableName,
    this.variableDescription,
    this.variableUnit,
    this.createdAt,
    this.updatedAt,
  });

  /// Etkin açıklama - öncelik: logs.description → variable.description → name
  String? get effectiveDescription =>
      description ?? variableDescription ?? name;

  /// Etkin isim - öncelik: logs.name → variable.name
  String? get effectiveName => name ?? variableName;

  /// Etkin birim - variable'dan gelen unit
  String? get effectiveUnit => variableUnit;

  /// On/Off durumu etiketi
  String get onOffLabel {
    if (onOff == null) return '-';
    return onOff == 1 ? 'ON' : 'OFF';
  }

  factory IoTLog.fromJson(Map<String, dynamic> json) {
    // Variable JOIN ile geldiyse nested object olarak gelir
    final variable = json['variable'] as Map<String, dynamic>?;

    return IoTLog(
      id: json['id'] as String,
      name: json['name'] as String?,
      code: json['code'] as String?,
      description: json['description'] as String?,
      value: json['value'] as String?,
      maintenance: json['maintenance'] as String?,
      // Dual column: on_off (current) / onoff (legacy)
      onOff: DbFieldHelpers.parseLogOnOff(json),
      active: json['active'] as bool? ?? true,
      cancelled: json['cancelled'] as bool?,
      isArchive: json['is_archive'] as bool?,
      archiveGroup: json['archive_group'] as String?,
      // Dual column: date_time (current) / datetime (legacy)
      dateTime: DbFieldHelpers.parseLogDateTime(json),
      tenantId: json['tenant_id'] as String?,
      controllerId: json['controller_id'] as String?,
      providerId: json['provider_id'] as String?,
      variableId: json['variable_id'] as String?,
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
      'value': value,
      'maintenance': maintenance,
      'on_off': onOff,
      'active': active,
      'cancelled': cancelled,
      'is_archive': isArchive,
      'archive_group': archiveGroup,
      'date_time': dateTime?.toIso8601String(),
      'tenant_id': tenantId,
      'controller_id': controllerId,
      'provider_id': providerId,
      'variable_id': variableId,
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
  String toString() => 'IoTLog($id, $name, value: $value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is IoTLog && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
