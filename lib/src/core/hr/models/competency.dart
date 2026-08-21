/// Yetkinlik — `competencies` tablosunun bir satırı.
///
/// Web `CompetencyService.list` / `map` ile aynı sözleşme. Satır ya tenant'a
/// aittir (`tenant_id` = benim tenant'ım) ya da global şablondur (`tenant_id`
/// null). Her ikisi de listelenir (RLS okuma kapsamı).
class Competency {
  final String id;
  final String? tenantId;
  final String? code;
  final String? name;

  /// Kategori/grup (ör. "Teknik", "Liderlik").
  final String? category;
  final String? description;
  final bool active;

  const Competency({
    required this.id,
    this.tenantId,
    this.code,
    this.name,
    this.category,
    this.description,
    this.active = true,
  });

  /// Global (paylaşımlı) şablon mu — `tenant_id` null ise evet.
  bool get isGlobal => tenantId == null;

  factory Competency.fromJson(Map<String, dynamic> json) {
    return Competency(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String?,
      code: json['code'] as String?,
      name: json['name'] as String?,
      category: json['category'] as String?,
      description: json['description'] as String?,
      active: json['active'] != false,
    );
  }
}
