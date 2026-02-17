import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

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
  /// DB level sıralaması: 0=Technical, 1=Very High, 2=High, 3=Medium, 4=Low
  /// Düşük level = yüksek öncelik
  bool get isHigh => level != null && level! <= 2;

  /// Kritik mi? (Very High veya Technical)
  bool get isCritical => level != null && level! <= 1;

  /// Renk değeri olarak Color objesi döner
  ///
  /// HEX formatındaki color string'ini (#RRGGBB veya RRGGBB) Flutter Color'a çevirir.
  /// Color değeri yoksa level'a göre fallback renk döner:
  /// DB level sıralaması: 0=Technical, 1=Very High, 2=High, 3=Medium, 4=Low
  /// - level <= 1 (Very High/Technical): AppColors.error
  /// - level == 2 (High): AppColors.warning
  /// - level == 3 (Medium): AppColors.info
  /// - level >= 4 (Low): AppColors.success
  Color get displayColor {
    // HEX renk varsa parse et
    if (color != null && color!.isNotEmpty) {
      final hex = color!.replaceFirst('#', '');
      if (hex.length == 6) {
        try {
          return Color(int.parse('FF$hex', radix: 16));
        } catch (_) {
          // Parse hatası olursa fallback'e düş
        }
      }
    }

    // Level'a göre fallback renkler (düşük level = yüksek öncelik)
    if (isCritical) return AppColors.error;
    if (isHigh) return AppColors.warning;
    if ((level ?? 5) <= 3) return AppColors.info;
    return AppColors.success;
  }

  /// Geçerli HEX renk değeri var mı?
  bool get hasCustomColor {
    if (color == null || color!.isEmpty) return false;
    final hex = color!.replaceFirst('#', '');
    return hex.length == 6;
  }

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
