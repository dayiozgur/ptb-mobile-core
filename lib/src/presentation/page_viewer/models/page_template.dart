/// Web builder'da (low-code page designer) tasarlanmış bir dashboard sayfası
/// modeli. `pb_page_templates` + iç içe `pb_page_widgets` satırlarından
/// çözülür ve mobil [PageViewerScreen] tarafından render edilir.
///
/// Model salt-okunur ve düzdür; herhangi bir servis/UI bağımlılığı taşımaz.
library;

/// Bir dashboard sayfası şablonu (`pb_page_templates`).
class PageTemplate {
  /// Şablon UUID'i.
  final String id;

  /// Benzersiz sayfa kodu (menü/rota anahtarı).
  final String code;

  /// Şablon adı.
  final String name;

  /// `header_config.title` — sayfa başlığı (opsiyonel).
  final String? headerTitle;

  /// `header_config.subtitle` — sayfa alt başlığı (opsiyonel).
  final String? headerSubtitle;

  /// Grid kolon sayısı (`layout_config.columns`), varsayılan 12.
  final int layoutColumns;

  /// Yalnız üst-seviye (parent_widget_id == null) widget'lar, sort_order sırası.
  final List<PageWidget> widgets;

  const PageTemplate({
    required this.id,
    required this.code,
    required this.name,
    this.headerTitle,
    this.headerSubtitle,
    this.layoutColumns = 12,
    this.widgets = const [],
  });

  /// `pb_page_templates` satırından (+ iç içe `pb_page_widgets`) çözer.
  ///
  /// Yalnız üst-seviye widget'ları alır (MVP); alt widget'lar (tab/parent
  /// içerikleri) atlanır. Widget'lar `sort_order` artan sırada sıralanır.
  factory PageTemplate.fromJson(Map<String, dynamic> json) {
    final header = _asMap(json['header_config']);
    final layout = _asMap(json['layout_config']);

    final rawWidgets = json['pb_page_widgets'];
    final widgets = <PageWidget>[];
    if (rawWidgets is List) {
      for (final w in rawWidgets) {
        if (w is Map) {
          final widget = PageWidget.fromJson(Map<String, dynamic>.from(w));
          // MVP: yalnız üst-seviye widget'lar render edilir.
          if (widget.parentWidgetId == null) {
            widgets.add(widget);
          }
        }
      }
    }
    widgets.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return PageTemplate(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      headerTitle: header['title']?.toString(),
      headerSubtitle: header['subtitle']?.toString(),
      layoutColumns: _asInt(layout['columns']) ?? 12,
      widgets: widgets,
    );
  }
}

/// Bir sayfa widget'ı (`pb_page_widgets`).
class PageWidget {
  /// Widget kodu (benzersiz anahtar).
  final String code;

  /// Başlık (kart header'ı).
  final String? title;

  /// Alt başlık.
  final String? subtitle;

  /// Widget tipi (ör. `stat_card`, `chart_widget`, `data_table`, `heading`).
  final String widgetType;

  /// Widget yapılandırması (görsel + statik içerik).
  final Map<String, dynamic> config;

  /// Veri kaynağı UUID'i (data-backed widget'lar için).
  final String? dataSourceId;

  /// Sorgu yapılandırması (`report-query` için measures/dimensions/filters).
  final Map<String, dynamic> queryConfig;

  /// Grid kolon aralığı (ör. `'span 6'`). Ham string.
  final String gridColumn;

  /// Grid satırı (ham string; `pb_page_widgets.grid_row` varchar).
  final String? gridRow;

  /// Minimum yükseklik (ham string; ör. `'200px'`).
  final String? minHeight;

  /// Sıralama indeksi.
  final int sortOrder;

  /// Üst widget UUID'i (null = üst-seviye).
  final String? parentWidgetId;

  const PageWidget({
    required this.code,
    this.title,
    this.subtitle,
    required this.widgetType,
    this.config = const {},
    this.dataSourceId,
    this.queryConfig = const {},
    this.gridColumn = 'span 12',
    this.gridRow,
    this.minHeight,
    this.sortOrder = 0,
    this.parentWidgetId,
  });

  /// `pb_page_widgets` satırından çözer.
  factory PageWidget.fromJson(Map<String, dynamic> json) {
    return PageWidget(
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString(),
      subtitle: json['subtitle']?.toString(),
      widgetType: json['widget_type']?.toString() ?? 'unknown',
      config: _asMap(json['config']),
      dataSourceId: json['data_source_id']?.toString(),
      queryConfig: _asMap(json['query_config']),
      gridColumn: json['grid_column']?.toString() ?? 'span 12',
      gridRow: json['grid_row']?.toString(),
      minHeight: json['min_height']?.toString(),
      sortOrder: _asInt(json['sort_order']) ?? 0,
      parentWidgetId: json['parent_widget_id']?.toString(),
    );
  }

  /// `grid_column` içindeki span değerini (1..layoutColumns) çözer.
  ///
  /// `'span 6'` → 6, `'6'` → 6. Çözülemezse [fallback] döner.
  int spanColumns(int layoutColumns, {int fallback = 12}) {
    final match = RegExp(r'(\d+)').firstMatch(gridColumn);
    if (match == null) return fallback.clamp(1, layoutColumns);
    final value = int.tryParse(match.group(1)!) ?? fallback;
    if (value <= 0) return fallback.clamp(1, layoutColumns);
    return value.clamp(1, layoutColumns);
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
