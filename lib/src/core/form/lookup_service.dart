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

      // Statik filtreler
      final filters = options.filters;
      if (filters != null) {
        filters.forEach((column, value) {
          builder = builder.eq(column, value as Object);
        });
      }

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
