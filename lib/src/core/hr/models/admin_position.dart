/// Pozisyon (kadro) satırı görüntü-modeli (salt-okuma).
///
/// Web `PositionService` (`libs/core/services/src/position.service.ts`) list
/// yolunun aynası — `positions` tablosu tenant-kapsamlı okunur. NOT: canlı
/// şemada `positions` üzerinde departman FK'si YOK; bu yüzden departman adı
/// taşınmaz (web modeli de taşımaz).
class AdminPosition {
  final String id;
  final String? code;
  final String? name;
  final String? description;

  /// Kademe/seviye (küçük = üst). Sıralamada kullanılır.
  final int? level;
  final bool active;

  const AdminPosition({
    required this.id,
    this.code,
    this.name,
    this.description,
    this.level,
    this.active = true,
  });

  factory AdminPosition.fromJson(Map<String, dynamic> json) {
    return AdminPosition(
      id: json['id'] as String,
      code: json['code'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      level: (json['level'] as num?)?.toInt(),
      active: json['active'] as bool? ?? true,
    );
  }
}
