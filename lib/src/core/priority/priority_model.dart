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

  /// Üretici (vendor) satırı mı? `null` = platform önceliği (critical/high/…);
  /// `'carel'` vb. = içe aktarıcıların değişkenlere damgaladığı üretici satırı.
  final String? vendor;

  /// Üretici alarm seviyesi — platform satırına `level` ile eşlenir.
  final int? vendorLevel;

  /// Üretici satırının AÇIK platform eşlemesi (DB `platform_priority_id`;
  /// web `v_pms_alarm_*` view'ları da bunu kullanır). Platform satırında null.
  final String? platformPriorityId;

  /// `severity` | `technical` (DB `priority_class`).
  final String? priorityClass;

  /// DB `active` kolonu AÇIKÇA `true` mu? (`active` NULL'ı true sayar; web
  /// platform kataloğu yalnız `active = true` satırları sunar.)
  final bool explicitlyActive;
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
    this.vendor,
    this.vendorLevel,
    this.platformPriorityId,
    this.priorityClass,
    this.explicitlyActive = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Ham (çevrilmemiş) etiket — DB `name`, yoksa `code`. Ekranda
  /// [localizedLabel] kullanın (web ile aynı `alarm.priority.<code>` anahtarı).
  String get label => name ?? code ?? 'Bilinmiyor';

  /// i18n anahtarı: `alarm.priority.<code>` (küçük harf); kodsuz → `undefined`.
  String get labelKey => priorityLabelKey(code);

  /// `alarm.priority.<code>` çevirisi; anahtar çevrilmemişse satırın adı.
  String localizedLabel(String Function(String key) translate) {
    final key = labelKey;
    final t = translate(key);
    if (t != key && t.isNotEmpty) return t;
    return name ?? code ?? t;
  }

  /// Teknik sınıf mı? (`priority_class = 'technical'`)
  bool get isTechnical => priorityClass == 'technical';

  /// Yüksek öncelikli mi?
  /// DB level sıralaması: 0=Technical, 1=Very High, 2=High, 3=Medium, 4=Low
  /// Düşük level = yüksek öncelik
  bool get isHigh => level != null && level! <= 2;

  /// Kritik mi? (Very High veya Technical)
  bool get isCritical => level != null && level! <= 1;

  /// Renk: YALNIZ `priorities.color` kolonu (#RRGGBB). Renk yoksa nötr
  /// [AppColors.systemGray] — seviyeden önem/renk TÜRETİLMEZ (web ile aynı:
  /// sabit severity eşlemesi yok).
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

    return AppColors.systemGray;
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
      level: (json['level'] as num?)?.toInt(),
      active: json['active'] as bool? ?? true,
      vendor: json['vendor'] as String?,
      vendorLevel: (json['vendor_level'] as num?)?.toInt(),
      platformPriorityId: json['platform_priority_id'] as String?,
      priorityClass: json['priority_class'] as String?,
      explicitlyActive: json.containsKey('explicitly_active')
          ? json['explicitly_active'] == true
          : json['active'] == true,
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
      'vendor': vendor,
      'vendor_level': vendorLevel,
      'platform_priority_id': platformPriorityId,
      'priority_class': priorityClass,
      'explicitly_active': explicitlyActive,
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

/// Web `priorityLabelKey` ile aynı: `alarm.priority.<code>` (kodsuz → `undefined`).
String priorityLabelKey(String? code) {
  final c = (code ?? '').trim().toLowerCase();
  return 'alarm.priority.${c.isEmpty ? 'undefined' : c}';
}
