import '../variable/variable_model.dart';

/// IoT Realtime (Gerçek Zamanlı Veri) modeli
///
/// Controller ile Variable arasındaki junction/bridge tablosudur.
/// Her controller'ın hangi variable'lara sahip olduğunu belirler.
///
/// DB Tablosu: realtimes
/// İlişkiler:
///   - controller_id → controllers.id
///   - variable_id → variables.id
///   - device_model_id → device_models.id
///   - priority_id → priorities.id
///   - cancelled_controller_id → controllers.id
class IoTRealtime {
  /// Benzersiz ID
  final String id;

  /// Realtime adı
  final String? name;

  /// Kodu
  final String? code;

  /// Açıklama
  final String? description;

  /// Aktif mi?
  final bool active;

  /// Loglanabilir mi?
  final bool? isLoggable;

  // ============================================
  // İLİŞKİLER
  // ============================================

  /// Bağlı olduğu Controller ID
  final String? controllerId;

  /// Bağlı olduğu Variable ID
  final String? variableId;

  /// Device Model ID
  final String? deviceModelId;

  /// Priority ID
  final String? priorityId;

  /// İptal edilen Controller ID
  final String? cancelledControllerId;

  // ============================================
  // İLİŞKİLİ NESNELER (Supabase select ile)
  // ============================================

  /// İlişkili variable (join ile gelir)
  final Variable? variable;

  // ============================================
  // ZAMAN DAMGALARI
  // ============================================

  /// Oluşturulma tarihi
  final DateTime? createdAt;

  /// Güncellenme tarihi
  final DateTime? updatedAt;

  /// Oluşturan kullanıcı
  final String? createdBy;

  /// Güncelleyen kullanıcı
  final String? updatedBy;

  const IoTRealtime({
    required this.id,
    this.name,
    this.code,
    this.description,
    this.active = true,
    this.isLoggable,
    this.controllerId,
    this.variableId,
    this.deviceModelId,
    this.priorityId,
    this.cancelledControllerId,
    this.variable,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  // ============================================
  // JSON SERIALIZATION
  // ============================================

  factory IoTRealtime.fromJson(Map<String, dynamic> json) {
    return IoTRealtime(
      id: json['id'] as String,
      name: json['name'] as String?,
      code: json['code'] as String?,
      description: json['description'] as String?,
      active: json['active'] as bool? ?? true,
      isLoggable: json['is_loggable'] as bool?,
      controllerId: json['controller_id'] as String?,
      variableId: json['variable_id'] as String?,
      deviceModelId: json['device_model_id'] as String?,
      priorityId: json['priority_id'] as String?,
      cancelledControllerId: json['cancelled_controller_id'] as String?,
      variable: json['variables'] != null && json['variables'] is Map
          ? Variable.fromJson(json['variables'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'description': description,
      'active': active,
      'is_loggable': isLoggable,
      'controller_id': controllerId,
      'variable_id': variableId,
      'device_model_id': deviceModelId,
      'priority_id': priorityId,
      'cancelled_controller_id': cancelledControllerId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
    };
  }

  // ============================================
  // COPY WITH
  // ============================================

  IoTRealtime copyWith({
    String? id,
    String? name,
    String? code,
    String? description,
    bool? active,
    bool? isLoggable,
    String? controllerId,
    String? variableId,
    String? deviceModelId,
    String? priorityId,
    String? cancelledControllerId,
    Variable? variable,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return IoTRealtime(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      active: active ?? this.active,
      isLoggable: isLoggable ?? this.isLoggable,
      controllerId: controllerId ?? this.controllerId,
      variableId: variableId ?? this.variableId,
      deviceModelId: deviceModelId ?? this.deviceModelId,
      priorityId: priorityId ?? this.priorityId,
      cancelledControllerId: cancelledControllerId ?? this.cancelledControllerId,
      variable: variable ?? this.variable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  @override
  String toString() => 'IoTRealtime($id, controller: $controllerId, variable: $variableId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is IoTRealtime && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
