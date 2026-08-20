/// Genel Entity (Generic Entity)
///
/// Dinamik form/entity motorunun ürettiği tek bir kayıt satırını temsil eder.
/// `form_submissions` tablosundaki bir satıra (bağımsız entity) ya da
/// [linkedTable] üzerindeki bir kayda karşılık gelir. Alan değerleri
/// [fieldValues] içinde alan kodu → değer olarak düzleştirilir.
class GenericEntity {
  /// Benzersiz ID
  final String id;

  /// Otomatik üretilen kod
  final String? code;

  /// Entity tipi
  final String? entityType;

  /// Konu / başlık
  final String? subject;

  /// Durum
  final String? status;

  /// Öncelik
  final String? priority;

  /// Atanan kullanıcı ID
  final String? assignedTo;

  /// Atanan kullanıcı adı (ayrı sorgu ile çözülür)
  final String? assignedToName;

  /// Termin tarihi
  final DateTime? dueDate;

  /// Organization ID
  final String? organizationId;

  /// Form şablonu ID
  final String? formTemplateId;

  /// Şablon adı (join ile çözülür)
  final String? formTemplateName;

  /// Oluşturulma tarihi
  final DateTime? createdAt;

  /// Alan değerleri (alan kodu → değer)
  final Map<String, dynamic> fieldValues;

  const GenericEntity({
    required this.id,
    this.code,
    this.entityType,
    this.subject,
    this.status,
    this.priority,
    this.assignedTo,
    this.assignedToName,
    this.dueDate,
    this.organizationId,
    this.formTemplateId,
    this.formTemplateName,
    this.createdAt,
    this.fieldValues = const {},
  });

  /// `form_submissions` satırından oluştur.
  ///
  /// [fieldValues] çağıran servis tarafından düzleştirilip verilir.
  factory GenericEntity.fromSubmission(
    Map<String, dynamic> json, {
    Map<String, dynamic> fieldValues = const {},
    String? assignedToName,
  }) {
    final template = json['form_templates'];
    final templateName = template is Map<String, dynamic>
        ? template['name'] as String?
        : null;

    return GenericEntity(
      id: json['id'] as String,
      code: json['code'] as String?,
      entityType: json['entity_type'] as String?,
      subject: json['subject'] as String?,
      status: json['status'] as String?,
      priority: json['priority'] as String?,
      assignedTo: json['assigned_to'] as String?,
      assignedToName: assignedToName,
      dueDate: _parseDate(json['due_date']),
      organizationId: json['organization_id'] as String?,
      formTemplateId: json['form_template_id'] as String?,
      formTemplateName: templateName,
      createdAt: _parseDate(json['created_at']),
      fieldValues: fieldValues,
    );
  }

  /// Bağlı tablo (linked_table) satırından oluştur (best-effort).
  factory GenericEntity.fromLinkedRow(
    Map<String, dynamic> json,
    String entityType,
  ) {
    return GenericEntity(
      id: json['id']?.toString() ?? '',
      code: json['code'] as String?,
      entityType: entityType,
      subject: (json['subject'] ?? json['name'] ?? json['title']) as String?,
      status: json['status'] as String?,
      priority: json['priority'] as String?,
      assignedTo: json['assigned_to'] as String?,
      dueDate: _parseDate(json['due_date']),
      organizationId: json['organization_id'] as String?,
      createdAt: _parseDate(json['created_at']),
      fieldValues: Map<String, dynamic>.from(json),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  /// Görünen başlık (subject → code → id).
  String get displayTitle => subject ?? code ?? id;

  GenericEntity copyWith({
    String? assignedToName,
    Map<String, dynamic>? fieldValues,
  }) {
    return GenericEntity(
      id: id,
      code: code,
      entityType: entityType,
      subject: subject,
      status: status,
      priority: priority,
      assignedTo: assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      dueDate: dueDate,
      organizationId: organizationId,
      formTemplateId: formTemplateId,
      formTemplateName: formTemplateName,
      createdAt: createdAt,
      fieldValues: fieldValues ?? this.fieldValues,
    );
  }

  @override
  String toString() => 'GenericEntity($entityType, $displayTitle)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GenericEntity && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
