/// Entity Tip Yapılandırması (Entity Type Config)
///
/// Low-code builder tarafından tanımlanan bir entity tipini temsil eder.
/// `entity_type_configs` tablosundaki bir satıra karşılık gelir.
///
/// [isStandalone] true ise kayıtlar `form_submissions` tablosunda tutulur;
/// false ise [linkedTable] ile belirtilen özel bir tabloya bağlıdır.
class EntityTypeConfig {
  /// Benzersiz ID
  final String id;

  /// Tenant ID (null = sistem/paylaşımlı)
  final String? tenantId;

  /// Entity tipi anahtarı (entityType key)
  final String code;

  /// Ad
  final String name;

  /// Çok dilli ad ({lang: value})
  final Map<String, String> nameI18n;

  /// Açıklama
  final String? description;

  /// Kod öneki (otomatik kod üretimi)
  final String? codePrefix;

  /// İkon
  final String? icon;

  /// Renk
  final String? color;

  /// Bağımsız mı? (true = form_submissions, false = linked_table)
  final bool isStandalone;

  /// Bağlı tablo (isStandalone false ise)
  final String? linkedTable;

  /// Varsayılan form şablonu ID
  final String? defaultFormTemplateId;

  /// Menüde göster
  final bool showInMenu;

  /// Menü sırası
  final int menuOrder;

  /// Menü üst öğesi
  final String? menuParent;

  /// Yorumlar etkin mi?
  final bool enableComments;

  /// İş kayıtları (worklog) etkin mi?
  final bool enableWorklogs;

  /// Ekler etkin mi?
  final bool enableAttachments;

  /// Onay akışı etkin mi?
  final bool enableApproval;

  /// SLA etkin mi?
  final bool enableSla;

  /// Sistem tanımı mı?
  final bool isSystem;

  /// Aktif mi?
  final bool active;

  /// Platform ID
  final String? platformId;

  const EntityTypeConfig({
    required this.id,
    this.tenantId,
    required this.code,
    required this.name,
    this.nameI18n = const {},
    this.description,
    this.codePrefix,
    this.icon,
    this.color,
    this.isStandalone = true,
    this.linkedTable,
    this.defaultFormTemplateId,
    this.showInMenu = true,
    this.menuOrder = 0,
    this.menuParent,
    this.enableComments = false,
    this.enableWorklogs = false,
    this.enableAttachments = false,
    this.enableApproval = false,
    this.enableSla = false,
    this.isSystem = false,
    this.active = true,
    this.platformId,
  });

  /// Verilen dil için yerelleştirilmiş ad (yoksa [name]).
  String localizedName(String? langCode) {
    if (langCode != null && nameI18n[langCode] != null) {
      return nameI18n[langCode]!;
    }
    return name;
  }

  factory EntityTypeConfig.fromJson(Map<String, dynamic> json) {
    final rawI18n = json['name_i18n'];
    final i18n = <String, String>{};
    if (rawI18n is Map) {
      rawI18n.forEach((key, value) {
        if (value != null) i18n[key.toString()] = value.toString();
      });
    }

    return EntityTypeConfig(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String?,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      nameI18n: i18n,
      description: json['description'] as String?,
      codePrefix: json['code_prefix'] as String?,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      isStandalone: json['is_standalone'] as bool? ?? true,
      linkedTable: json['linked_table'] as String?,
      defaultFormTemplateId: json['default_form_template_id'] as String?,
      showInMenu: json['show_in_menu'] as bool? ?? true,
      menuOrder: (json['menu_order'] as num?)?.toInt() ?? 0,
      menuParent: json['menu_parent'] as String?,
      enableComments: json['enable_comments'] as bool? ?? false,
      enableWorklogs: json['enable_worklogs'] as bool? ?? false,
      enableAttachments: json['enable_attachments'] as bool? ?? false,
      enableApproval: json['enable_approval'] as bool? ?? false,
      enableSla: json['enable_sla'] as bool? ?? false,
      isSystem: json['is_system'] as bool? ?? false,
      active: json['active'] as bool? ?? true,
      platformId: json['platform_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'code': code,
      'name': name,
      'name_i18n': nameI18n,
      'description': description,
      'code_prefix': codePrefix,
      'icon': icon,
      'color': color,
      'is_standalone': isStandalone,
      'linked_table': linkedTable,
      'default_form_template_id': defaultFormTemplateId,
      'show_in_menu': showInMenu,
      'menu_order': menuOrder,
      'menu_parent': menuParent,
      'enable_comments': enableComments,
      'enable_worklogs': enableWorklogs,
      'enable_attachments': enableAttachments,
      'enable_approval': enableApproval,
      'enable_sla': enableSla,
      'is_system': isSystem,
      'active': active,
      'platform_id': platformId,
    };
  }

  @override
  String toString() => 'EntityTypeConfig($code, $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is EntityTypeConfig && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
