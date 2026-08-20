/// Web builder'ında tasarlanan `dr_report_templates` (+ nested
/// `dr_report_widgets`) kaydının mobil viewer için sadeleştirilmiş modelleri.
///
/// Bu modeller salt-okuma render için gerekli alanları taşır; DB'de var olan
/// ek kolonlar yok sayılır. `fromJson` fabrikaları savunmacıdır — eksik/yanlış
/// tipli alanlar güvenli varsayılanlara düşer.
library;

/// Bir değeri güvenli şekilde `Map<String,dynamic>`'e çevirir (null → boş map).
Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

/// Bir değeri güvenli şekilde `List`'e çevirir (null → boş liste).
List<dynamic> _asList(dynamic value) {
  if (value is List) {
    return List<dynamic>.from(value);
  }
  return <dynamic>[];
}

/// Bir değeri güvenli şekilde `int`'e çevirir; çözemezse [fallback].
int _asInt(dynamic value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

/// Bir raporun global filtre tanımı.
///
/// `global_filters` JSON dizisindeki her eleman:
/// `{code,label,fieldType,defaultValue?,options?}`. `fieldType` ∈
/// `text|number|date|select|daterange`. `daterange` iki değer yazar:
/// `{code}_from` ve `{code}_to`.
class ReportGlobalFilter {
  final String code;
  final String label;
  final String fieldType;
  final dynamic defaultValue;
  final List<dynamic> options;

  const ReportGlobalFilter({
    required this.code,
    required this.label,
    required this.fieldType,
    this.defaultValue,
    this.options = const <dynamic>[],
  });

  factory ReportGlobalFilter.fromJson(Map<String, dynamic> json) {
    final code = json['code']?.toString() ?? '';
    return ReportGlobalFilter(
      code: code,
      label: json['label']?.toString() ?? code,
      fieldType: json['fieldType']?.toString() ?? 'text',
      defaultValue: json['defaultValue'],
      options: _asList(json['options']),
    );
  }
}

/// Tek bir rapor widget'ı (`dr_report_widgets` satırı).
///
/// Her widget kendi [dataSourceId] + [queryConfig] ile bağımsız çözülür.
/// [gridColumn] `'span N'` biçimindedir (N/12 genişlik). [widgetType] hangi
/// dinamik primitifin render edileceğini belirler.
class ReportWidget {
  final String code;
  final String? title;
  final String? subtitle;
  final String widgetType;
  final String dataSourceId;
  final Map<String, dynamic> queryConfig;
  final Map<String, dynamic> visualConfig;
  final String gridColumn;
  final int? gridRow;
  final int? minHeight;
  final int sortOrder;

  const ReportWidget({
    required this.code,
    this.title,
    this.subtitle,
    required this.widgetType,
    required this.dataSourceId,
    this.queryConfig = const <String, dynamic>{},
    this.visualConfig = const <String, dynamic>{},
    this.gridColumn = 'span 12',
    this.gridRow,
    this.minHeight,
    this.sortOrder = 0,
  });

  factory ReportWidget.fromJson(Map<String, dynamic> json) {
    final subtitle = json['subtitle']?.toString();
    return ReportWidget(
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString(),
      subtitle: (subtitle != null && subtitle.isNotEmpty) ? subtitle : null,
      widgetType: json['widget_type']?.toString() ?? '',
      dataSourceId: json['data_source_id']?.toString() ?? '',
      queryConfig: _asMap(json['query_config']),
      visualConfig: _asMap(json['visual_config']),
      gridColumn: json['grid_column']?.toString() ?? 'span 12',
      gridRow: json['grid_row'] == null ? null : _asInt(json['grid_row'], 0),
      minHeight:
          json['min_height'] == null ? null : _asInt(json['min_height'], 0),
      sortOrder: _asInt(json['sort_order'], 0),
    );
  }

  /// [gridColumn] içindeki `span N` tamsayısını çözer (1..12). Çözemezse 12.
  int get spanColumns {
    final match = RegExp(r'(\d+)').firstMatch(gridColumn);
    if (match == null) return 12;
    final n = int.tryParse(match.group(1)!) ?? 12;
    if (n < 1) return 1;
    if (n > 12) return 12;
    return n;
  }
}

/// Bir rapor şablonu (`dr_report_templates` satırı) + widget'ları.
class ReportTemplate {
  final String id;
  final String code;
  final String name;
  final String? description;
  final int layoutColumns;
  final List<ReportGlobalFilter> globalFilters;
  final List<ReportWidget> widgets;

  const ReportTemplate({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.layoutColumns = 12,
    this.globalFilters = const <ReportGlobalFilter>[],
    this.widgets = const <ReportWidget>[],
  });

  factory ReportTemplate.fromJson(Map<String, dynamic> json) {
    // layout_config['columns'] ?? 12
    final layoutConfig = _asMap(json['layout_config']);
    final layoutColumns = _asInt(layoutConfig['columns'], 12);

    // global_filters (JSON array)
    final globalFilters = _asList(json['global_filters'])
        .whereType<dynamic>()
        .map((e) => ReportGlobalFilter.fromJson(_asMap(e)))
        .where((f) => f.code.isNotEmpty)
        .toList();

    // dr_report_widgets(*): active !== false filtre + sort_order sıralama
    final widgets = _asList(json['dr_report_widgets'])
        .whereType<dynamic>()
        .map((e) => _asMap(e))
        .where((m) => m['active'] != false)
        .map(ReportWidget.fromJson)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final description = json['description']?.toString();

    return ReportTemplate(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? '',
      description:
          (description != null && description.isNotEmpty) ? description : null,
      layoutColumns: layoutColumns,
      globalFilters: globalFilters,
      widgets: widgets,
    );
  }
}
