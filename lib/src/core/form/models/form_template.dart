import 'form_field.dart';

/// Dinamik Form Şablonu (Form Template) modelleri
///
/// Low-code builder tarafından tasarlanan tüm form ağacını temsil eder:
/// FormTemplate → FormSection → FormField (+ FormFieldRule).

/// Form Bölümü (Form Section).
///
/// Bir şablonu mantıksal gruplara böler (group | step | tab | accordion).
class FormSection {
  /// Benzersiz ID
  final String id;

  /// Bağlı olduğu şablon (form_templates) ID
  final String formTemplateId;

  /// Bölüm kodu
  final String code;

  /// Başlık
  final String title;

  /// Açıklama
  final String? description;

  /// Bölüm tipi: group | step | tab | accordion
  final String sectionType;

  /// Adım numarası (step tipinde)
  final int? stepNumber;

  /// Sıralama
  final int sortOrder;

  /// Daraltılabilir mi?
  final bool isCollapsible;

  /// Tekrarlanabilir mi?
  final bool isRepeatable;

  /// Maksimum tekrar sayısı
  final int? maxRepetitions;

  /// Görünürlük kuralı (jsonb)
  final Map<String, dynamic>? visibilityRule;

  /// İkon
  final String? icon;

  /// Bölüme ait alanlar (sort_order'a göre sıralı)
  final List<FormField> fields;

  const FormSection({
    required this.id,
    required this.formTemplateId,
    required this.code,
    required this.title,
    this.description,
    this.sectionType = 'group',
    this.stepNumber,
    this.sortOrder = 0,
    this.isCollapsible = false,
    this.isRepeatable = false,
    this.maxRepetitions,
    this.visibilityRule,
    this.icon,
    this.fields = const [],
  });

  factory FormSection.fromJson(Map<String, dynamic> json) {
    final rawFields = json['form_fields'];
    final fields = rawFields is List
        ? rawFields
            .whereType<Map<String, dynamic>>()
            .where((e) => e['active'] != false)
            .map(FormField.fromJson)
            .toList()
        : <FormField>[];
    fields.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return FormSection(
      id: json['id'] as String,
      formTemplateId: json['form_template_id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      sectionType: json['section_type'] as String? ?? 'group',
      stepNumber: (json['step_number'] as num?)?.toInt(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isCollapsible: json['is_collapsible'] as bool? ?? false,
      isRepeatable: json['is_repeatable'] as bool? ?? false,
      maxRepetitions: (json['max_repetitions'] as num?)?.toInt(),
      visibilityRule: json['visibility_rule'] is Map
          ? Map<String, dynamic>.from(json['visibility_rule'] as Map)
          : null,
      icon: json['icon'] as String?,
      fields: fields,
    );
  }

  @override
  String toString() => 'FormSection($code, ${fields.length} fields)';
}

/// Form Alan Kuralı (Form Field Rule).
///
/// Alanlar arası dinamik davranışları tanımlar (görünürlük, zorunluluk,
/// değer atama, seçenek filtreleme). Kaynak/hedef alanların `code` değerleri
/// nested select ile çözülür.
class FormFieldRule {
  /// Benzersiz ID
  final String id;

  /// Bağlı olduğu şablon ID
  final String formTemplateId;

  /// Kaynak alan ID
  final String? sourceFieldId;

  /// Hedef alan ID
  final String? targetFieldId;

  /// Nested select'ten çözülen kaynak alan kodu
  final String? sourceFieldCode;

  /// Nested select'ten çözülen hedef alan kodu
  final String? targetFieldCode;

  /// Kural tipi: visibility | required | value | options_filter
  final String ruleType;

  /// Koşul (jsonb)
  final Map<String, dynamic> condition;

  /// Aksiyon (jsonb)
  final Map<String, dynamic> action;

  /// Sıralama
  final int sortOrder;

  const FormFieldRule({
    required this.id,
    required this.formTemplateId,
    this.sourceFieldId,
    this.targetFieldId,
    this.sourceFieldCode,
    this.targetFieldCode,
    this.ruleType = 'visibility',
    this.condition = const {},
    this.action = const {},
    this.sortOrder = 0,
  });

  factory FormFieldRule.fromJson(Map<String, dynamic> json) {
    // Nested select joined FK objects: source_field / target_field → {code}
    String? extractCode(dynamic joined) {
      if (joined is Map<String, dynamic>) {
        return joined['code'] as String?;
      }
      if (joined is List && joined.isNotEmpty && joined.first is Map) {
        return (joined.first as Map)['code'] as String?;
      }
      return null;
    }

    return FormFieldRule(
      id: json['id'] as String,
      formTemplateId: json['form_template_id'] as String? ?? '',
      sourceFieldId: json['source_field_id'] as String?,
      targetFieldId: json['target_field_id'] as String?,
      sourceFieldCode: extractCode(json['source_field']),
      targetFieldCode: extractCode(json['target_field']),
      ruleType: json['rule_type'] as String? ?? 'visibility',
      condition: json['condition'] is Map
          ? Map<String, dynamic>.from(json['condition'] as Map)
          : const {},
      action: json['action'] is Map
          ? Map<String, dynamic>.from(json['action'] as Map)
          : const {},
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  String toString() => 'FormFieldRule($ruleType, $sourceFieldCode → $targetFieldCode)';
}

/// Dinamik Form Şablonu (Form Template).
///
/// Bir entity tipi için tüm form yapısını (bölümler, alanlar, kurallar)
/// taşır. Nested PostgREST select ile tek seferde yüklenir.
class FormTemplate {
  /// Benzersiz ID
  final String id;

  /// Tenant ID
  final String? tenantId;

  /// Şablon kodu
  final String code;

  /// Ad
  final String name;

  /// Açıklama
  final String? description;

  /// Kategori
  final String? category;

  /// Entity tipi (entity_type_configs.code ile eşleşir)
  final String? entityType;

  /// Versiyon
  final int version;

  /// Yayınlandı mı?
  final bool isPublished;

  /// Ek meta veri ({icon?, color?})
  final Map<String, dynamic> metadata;

  /// Aktif mi?
  final bool active;

  /// Bölümler (sort_order'a göre sıralı)
  final List<FormSection> sections;

  /// Alan kuralları
  final List<FormFieldRule> rules;

  const FormTemplate({
    required this.id,
    this.tenantId,
    required this.code,
    required this.name,
    this.description,
    this.category,
    this.entityType,
    this.version = 1,
    this.isPublished = false,
    this.metadata = const {},
    this.active = true,
    this.sections = const [],
    this.rules = const [],
  });

  /// metadata.icon
  String? get icon => metadata['icon'] as String?;

  /// metadata.color
  String? get color => metadata['color'] as String?;

  /// Şablondaki tüm alanlar (bölüm sırasına göre düz liste)
  List<FormField> get allFields =>
      sections.expand((s) => s.fields).toList();

  factory FormTemplate.fromJson(Map<String, dynamic> json) {
    final rawSections = json['form_sections'];
    final sections = rawSections is List
        ? rawSections
            .whereType<Map<String, dynamic>>()
            .where((e) => e['active'] != false)
            .map(FormSection.fromJson)
            .toList()
        : <FormSection>[];
    sections.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final rawRules = json['form_field_rules'];
    final rules = rawRules is List
        ? rawRules
            .whereType<Map<String, dynamic>>()
            .where((e) => e['active'] != false)
            .map(FormFieldRule.fromJson)
            .toList()
        : <FormFieldRule>[];
    rules.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return FormTemplate(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String?,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      category: json['category'] as String?,
      entityType: json['entity_type'] as String?,
      version: (json['version'] as num?)?.toInt() ?? 1,
      isPublished: json['is_published'] as bool? ?? false,
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
      active: json['active'] as bool? ?? true,
      sections: sections,
      rules: rules,
    );
  }

  @override
  String toString() =>
      'FormTemplate($code v$version, ${sections.length} sections)';
}
