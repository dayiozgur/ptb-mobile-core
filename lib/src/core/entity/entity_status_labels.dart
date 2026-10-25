import 'dart:ui' show Color;

/// Display name + colour of one entity status code (`status_definitions`).
///
/// Entity rows (`form_submissions.status`) store the status CODE
/// (`needs_service`). Lists, detail headers and charts must show the NAME
/// (`status_definitions.name`, system rows translated via `status.<code>`) and
/// its colour — never the raw code. Web parity: PtbStatusLabelService /
/// status-value-labels.ts.
class EntityStatusLabel {
  final String code;
  final String name;

  /// Hex colour from `status_definitions.color` (e.g. `#22c55e`), if any.
  final String? colorHex;

  const EntityStatusLabel({
    required this.code,
    required this.name,
    this.colorHex,
  });

  /// Parsed [colorHex] (`#RRGGBB` / `#AARRGGBB`), or null.
  Color? get color => EntityStatusLabels.parseHex(colorHex);
}

/// Pure helpers for resolving status codes to display labels.
class EntityStatusLabels {
  EntityStatusLabels._();

  /// Readable fallback for a code without a definition or translation:
  /// `needs_service` → `Needs service`. Used only as a last resort so a raw
  /// snake_case code never reaches the UI.
  static String humanize(String code) {
    final s = code.trim().replaceAll(RegExp(r'[_\-.]+'), ' ').trim();
    if (s.isEmpty) return code;
    return s[0].toUpperCase() + s.substring(1);
  }

  /// Label for [code]: definition name → humanized code. Empty/null → ''.
  static String nameOf(
    String? code,
    Map<String, EntityStatusLabel> labels,
  ) {
    if (code == null || code.isEmpty) return '';
    final l = labels[code];
    if (l != null && l.name.isNotEmpty && l.name != code) return l.name;
    return humanize(code);
  }

  /// Display name of one `status_definitions` row: its `name`, else the
  /// humanized `code`.
  static String rowName(Map<String, dynamic> row) {
    final name = (row['name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;
    return humanize((row['code'] as String?) ?? '');
  }

  /// `#RRGGBB` / `RRGGBB` / `#AARRGGBB` → [Color]; anything else → null.
  static Color? parseHex(String? hex) {
    if (hex == null || hex.trim().isEmpty) return null;
    var value = hex.trim().replaceFirst('#', '');
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8) return null;
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  /// Builds code → label from `status_definitions` rows (already platform
  /// filtered, deduped and translated by EntityDataService).
  static Map<String, EntityStatusLabel> fromDefinitions(
    List<Map<String, dynamic>> rows,
  ) {
    final out = <String, EntityStatusLabel>{};
    for (final r in rows) {
      final code = r['code'] as String?;
      if (code == null || code.isEmpty) continue;
      out[code] = EntityStatusLabel(
        code: code,
        name: rowName(r),
        colorHex: r['color'] as String?,
      );
    }
    return out;
  }

  /// Rows with the status column [field] (default `status`) replaced by its
  /// display name — for report/chart widgets over an entity data source.
  /// Unknown codes are humanized; rows without a string status are returned
  /// unchanged (same object).
  static List<Map<String, dynamic>> relabelRows(
    List<Map<String, dynamic>> rows,
    Map<String, EntityStatusLabel> labels, {
    String field = 'status',
  }) {
    if (labels.isEmpty) return rows;
    return rows.map((row) {
      final v = row[field];
      if (v is! String) return row;
      final name = nameOf(v, labels);
      if (name == v) return row;
      return {...row, field: name};
    }).toList();
  }
}
