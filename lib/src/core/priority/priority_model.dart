/// Alarm öncelik (priority) modeli
///
/// DB tablosu: priorities
/// Alarm'lar ve alarm_histories tabloları priority_id FK ile referans verir.
class Priority {
  final String id;
  final String? name;
  final String? code;
  final String? description;
  final String? color;
  final int? level;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Priority({
    required this.id,
    this.name,
    this.code,
    this.description,
    this.color,
    this.level,
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  /// Öncelik seviyesi etiketi
  String get label => name ?? code ?? 'Bilinmiyor';

  /// Yüksek öncelikli mi?
  bool get isHigh => (level ?? 0) >= 3;

  /// Kritik mi?
  bool get isCritical => (level ?? 0) >= 4;

  factory Priority.fromJson(Map<String, dynamic> json) {
    return Priority(
      id: json['id'] as String,
      name: json['name'] as String?,
      code: json['code'] as String?,
      description: json['description'] as String?,
      color: json['color'] as String?,
      level: json['level'] as int?,
      active: json['active'] as bool? ?? true,
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
      'color': color,
      'level': level,
      'active': active,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  String toString() => 'Priority($id, $label, level: $level)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Priority && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
