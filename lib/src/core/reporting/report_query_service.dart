import 'package:supabase_flutter/supabase_flutter.dart';

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
        return _asRowList(rows);
      }

      // Zarf yoksa body zaten satır listesi olabilir.
      return _asRowList(body);
    } catch (e) {
      Logger.error('ReportQueryService.runWidget başarısız (ds=$dataSourceId)', e);
      rethrow;
    }
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
