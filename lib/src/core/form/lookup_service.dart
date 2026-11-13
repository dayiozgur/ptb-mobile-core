import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';
import 'models/form_field.dart';

/// Lookup Service
///
/// `lookup` tipindeki form alanları için dinamik referans verisi sağlar.
/// [FieldOptions] yapılandırmasına göre hedef tabloyu sorgular; arama,
/// statik filtreler ve kaskad (dependsOn) bağımlılıklarını uygular.
class LookupService {
  final SupabaseClient _supabase;

  LookupService({required SupabaseClient supabase}) : _supabase = supabase;

  /// Static `options.filters` of a field: `{"col": value}` → `col = value`;
  /// `{"col": null}` → `col IS NULL`. Same rule as the web form engine
  /// (`ptb-field-select`): `eq(col, null)` would be sent as `col=eq.null`,
  /// which matches nothing (and a `null as Object` cast threw here before).
  static PostgrestFilterBuilder<T> applyStaticFilters<T>(
    PostgrestFilterBuilder<T> builder,
    Map<String, dynamic>? filters,
  ) {
    if (filters == null) return builder;
    var b = builder;
    filters.forEach((column, value) {
      b = value == null ? b.isFilter(column, null) : b.eq(column, value as Object);
    });
    return b;
  }

  /// Options of a `select` field whose source is a table
  /// (`options.type == 'lookup'`, e.g. the service-request priority:
  /// `{table: priorities, valueField: code, labelField: name, orderBy: level}`).
  ///
  /// Mirrors the web `ptb-field-select.loadLookupOptions`: `active = true`,
  /// static [FieldOptions.filters] (null → IS NULL), the `dependsOn` cascade
  /// when the source value is set, `orderBy` ascending; value and label are
  /// the row's [FieldOptions.valueField] (default `id`) / [FieldOptions.labelField]
  /// (default `name`) as strings. A failed read is rethrown (the field says
  /// "options could not be loaded", not "no options").
  Future<List<FieldOption>> selectOptions(
    FieldOptions options, {
    Map<String, dynamic>? dependsOnValues,
  }) async {
    final table = options.table;
    if (table == null || table.isEmpty) return const [];
    final valueField = options.valueField ?? 'id';
    final labelField = options.labelField ?? 'name';
    try {
      var builder = _supabase.from(table).select('*').eq('active', true);
      builder = applyStaticFilters(builder, options.filters);
      final dependsOn = options.dependsOn;
      if (dependsOn != null &&
          dependsOn.filterColumn.isNotEmpty &&
          dependsOn.fieldCode.isNotEmpty) {
        final depValue = dependsOnValues?[dependsOn.fieldCode];
        if (depValue != null && depValue != '') {
          builder = builder.eq(dependsOn.filterColumn, depValue as Object);
        }
      }
      final orderBy = options.orderBy;
      final response = (orderBy != null && orderBy.isNotEmpty)
          ? await builder.order(orderBy, ascending: true)
          : await builder;
      return (response as List).map((row) {
        final map = row as Map<String, dynamic>;
        return FieldOption(
          value: map[valueField]?.toString(),
          label: map[labelField]?.toString() ?? '',
        );
      }).toList();
    } catch (e) {
      Logger.error('Error loading select options from $table: $e');
      rethrow;
    }
  }

  /// Lookup sonuçlarını getir.
  ///
  /// Dönen her satır `{entityType, entityId, displayValue}` biçimine map'lenir.
  /// [query] verilirse (min 2 karakter) arama kolonlarında ilike uygulanır.
  /// [dependsOnValues] kaskad bağımlılık için kaynak alan değerlerini taşır.
  Future<List<Map<String, dynamic>>> search(
    FieldOptions options, {
    String? query,
    Map<String, dynamic>? dependsOnValues,
  }) async {
    final table = options.table;
    if (table == null || table.isEmpty) {
      Logger.warning('LookupService.search called without a table');
      return [];
    }

    final valueField = options.valueField ?? 'id';
    final labelField = options.labelField ?? 'name';

    try {
      var builder = _supabase.from(table).select('*');

      // Statik filtreler (`"col": null` → IS NULL, like the web form engine)
      builder = applyStaticFilters(builder, options.filters);

      // Kaskad bağımlılık: dependsOn.filterColumn = dependsOnValues[fieldCode]
      final dependsOn = options.dependsOn;
      if (dependsOn != null &&
          dependsOn.filterColumn.isNotEmpty &&
          dependsOn.fieldCode.isNotEmpty) {
        final depValue = dependsOnValues?[dependsOn.fieldCode];
        if (depValue != null) {
          builder = builder.eq(dependsOn.filterColumn, depValue as Object);
        }
      }

      // Aktiflik filtresi (tablo destekliyorsa; hata olursa yine de döneriz)
      builder = builder.eq('active', true);

      // Arama (min 2 karakter)
      if (query != null && query.trim().length >= 2) {
        final term = query.trim();
        final searchFields = options.searchFields ?? [labelField];
        final orExpr =
            searchFields.map((f) => '$f.ilike.%$term%').join(',');
        builder = builder.or(orExpr);
      }

      final response = await builder.limit(10);
      final rows = response as List;

      return rows.map((row) {
        final map = row as Map<String, dynamic>;
        return <String, dynamic>{
          'entityType': table,
          'entityId': map[valueField],
          'displayValue': map[labelField]?.toString() ?? '',
        };
      }).toList();
    } catch (e) {
      Logger.error('Error running lookup search on $table: $e');
      rethrow;
    }
  }
}
