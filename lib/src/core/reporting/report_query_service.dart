import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../entity/entity_data_service.dart';
import '../entity/entity_status_labels.dart';
import '../utils/logger.dart';

/// Report/Page dinamik widget'ları için tek veri yolu.
///
/// Web viewer'ların kullandığı **`report-query`** Edge Function'ını çağırır.
/// Her widget kendi `dataSourceId` + `queryConfig` değerleriyle çözülür;
/// `templateId`/`widgetId` gönderilmez. Bearer token (Supabase session)
/// satırları RLS ile arayanın tenant'ına göre kapsar — ek tenant parametresi
/// gerekmez.
///
/// İstek gövdesi:
/// ```json
/// {
///   "dataSourceId": "<uuid>",
///   "queryConfig": { "measures": [...], "dimensions": [...], ... },
///   "filterValues": { "<code>": <value> }
/// }
/// ```
///
/// Yanıt zarfı: `{ success, data, meta }` — `data` düz bir satır dizisidir
/// (`Record<String,dynamic>[]`); her key bir measure/dimension alias'ıdır.
/// `meta = { totalRows, executionMs }`. Hata durumunda invoke sonucu
/// `{ error: { code, message } }` ya da `success: false` taşır.
///
/// Örnek kullanım:
/// ```dart
/// final rows = await reportQueryService.runWidget(
///   dataSourceId: 'a0000000-...-0001',
///   queryConfig: {
///     'measures': [
///       {'field': 'amount', 'aggregation': 'sum', 'alias': 'total'}
///     ],
///     'dimensions': [
///       {'field': 'created_at', 'alias': 'day', 'granularity': 'day'}
///     ],
///   },
///   filterValues: {'status': 'open'},
/// );
/// ```
class ReportQueryService {
  final SupabaseClient _supabase;

  /// `report-query` Edge Function adı.
  static const String _functionName = 'report-query';

  ReportQueryService(this._supabase);

  /// Tek bir widget için veriyi getirir.
  ///
  /// `report-query` Edge Function'ını verilen [dataSourceId], [queryConfig] ve
  /// [filterValues] ile çağırır; yanıt zarfını açar ve satır listesini döner.
  ///
  /// Hata durumunda mesajı çıkararak yeniden fırlatır (rethrow).
  Future<List<Map<String, dynamic>>> runWidget({
    required String dataSourceId,
    Map<String, dynamic>? queryConfig,
    Map<String, dynamic>? filterValues,
  }) async {
    try {
      final res = await _supabase.functions.invoke(
        _functionName,
        body: <String, dynamic>{
          'dataSourceId': dataSourceId,
          'queryConfig': queryConfig ?? <String, dynamic>{},
          'filterValues': filterValues ?? <String, dynamic>{},
        },
      );

      final body = res.data;

      // Hata zarfı: { success:false } ya da { error: { code, message } }
      if (body is Map) {
        final map = Map<String, dynamic>.from(body);

        final error = map['error'];
        if (error != null) {
          final message = error is Map
              ? (error['message']?.toString() ?? error.toString())
              : error.toString();
          throw Exception('report-query hatası: $message');
        }

        if (map['success'] == false) {
          final message = map['message']?.toString() ?? 'Bilinmeyen hata';
          throw Exception('report-query başarısız: $message');
        }

        // Başarılı zarf: satırlar body['data'] içinde.
        final rows = map['data'];
        return await _withStatusNames(dataSourceId, _asRowList(rows));
      }

      // Zarf yoksa body zaten satır listesi olabilir.
      return await _withStatusNames(dataSourceId, _asRowList(body));
    } catch (e) {
      Logger.error('ReportQueryService.runWidget başarısız (ds=$dataSourceId)', e);
      rethrow;
    }
  }

  final Map<String, Future<String?>> _dsEntityType = {};

  /// Entity veri kaynağı (`base_filters`: `entity_type = '<type>'`) ve bir
  /// `status` boyut kolonu varsa satırlardaki durum KODLARINI görünen ada
  /// çevirir (grafik lejantı / tablo hücresi `needs_service` yerine ad). Web
  /// parity: status-value-labels.ts. Hata → satırlar aynen döner.
  Future<List<Map<String, dynamic>>> _withStatusNames(
    String dataSourceId,
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty || !rows.any((r) => r['status'] is String)) return rows;
    if (!sl.isRegistered<EntityDataService>()) return rows;
    try {
      final et = await _dsEntityType.putIfAbsent(
          dataSourceId, () => _loadEntityType(dataSourceId));
      if (et == null) return rows;
      final labels = await sl<EntityDataService>().statusLabels(et);
      return EntityStatusLabels.relabelRows(rows, labels);
    } catch (e) {
      _dsEntityType.remove(dataSourceId);
      Logger.warning('report-query status relabel atlandı (ds=$dataSourceId): $e');
      return rows;
    }
  }

  Future<String?> _loadEntityType(String dataSourceId) async {
    final row = await _supabase
        .from('dr_data_sources')
        .select('base_filters, columns')
        .eq('id', dataSourceId)
        .maybeSingle();
    if (row == null) return null;
    return entityTypeOfDataSource(row['base_filters'], row['columns']);
  }

  /// `base_filters` içindeki `entity_type = '<type>'` (parametresiz) filtresi
  /// ve `status` boyut kolonu varsa entity tipi; aksi halde null.
  static String? entityTypeOfDataSource(dynamic baseFilters, dynamic columns) {
    String? type;
    if (baseFilters is List) {
      for (final f in baseFilters) {
        if (f is! Map) continue;
        final op = (f['operator'] ?? 'eq').toString();
        final v = f['value'];
        if (f['field'] == 'entity_type' &&
            op == 'eq' &&
            (f['param'] == null || f['param'] == false || f['param'] == '') &&
            v is String &&
            v.trim().isNotEmpty &&
            !v.startsWith(':')) {
          type = v.trim();
          break;
        }
      }
    }
    if (type == null) return null;
    final hasStatus = columns is List &&
        columns.any((c) =>
            c is Map &&
            c['code'] == 'status' &&
            c['role'] != 'measure' &&
            c['role'] != 'time');
    return hasStatus ? type : null;
  }

  /// Gelen değeri `List<Map<String,dynamic>>` biçimine güvenli şekilde çevirir.
  List<Map<String, dynamic>> _asRowList(dynamic value) {
    if (value is List) {
      return value
          .whereType<dynamic>()
          .map<Map<String, dynamic>>((row) {
            if (row is Map) {
              return Map<String, dynamic>.from(row);
            }
            return <String, dynamic>{'value': row};
          })
          .toList();
    }
    return <Map<String, dynamic>>[];
  }
}
