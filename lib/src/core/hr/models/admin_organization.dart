/// Organizasyon satırı görüntü-modeli (salt-okuma).
///
/// Web `OrganizationService` (`libs/core/services/src/organization.service.ts`)
/// list yolunun aynası — `organizations` tablosu tenant-kapsamlı okunur.
/// Hiyerarşi `parent_organization_id` + `hierarchy_level` ile taşınır
/// (canlı şemada ayrık bir "type" kolonu yoktur).
class AdminOrganization {
  final String id;
  final String? code;
  final String? name;
  final String? description;
  final String? city;

  /// Üst organizasyon (varsa) — hiyerarşi kökü NULL.
  final String? parentOrganizationId;

  /// Hiyerarşi derinliği (0 = kök).
  final int? hierarchyLevel;
  final bool active;

  const AdminOrganization({
    required this.id,
    this.code,
    this.name,
    this.description,
    this.city,
    this.parentOrganizationId,
    this.hierarchyLevel,
    this.active = true,
  });

  /// Kök organizasyon mu (üstü yok).
  bool get isRoot => parentOrganizationId == null;

  factory AdminOrganization.fromJson(Map<String, dynamic> json) {
    return AdminOrganization(
      id: json['id'] as String,
      code: json['code'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      city: json['city'] as String?,
      parentOrganizationId: json['parent_organization_id'] as String?,
      hierarchyLevel: (json['hierarchy_level'] as num?)?.toInt(),
      active: json['active'] as bool? ?? true,
    );
  }
}
