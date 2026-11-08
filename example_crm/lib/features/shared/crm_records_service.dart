import 'crm_backend.dart';
import 'crm_record.dart';

/// CRM entity kayıtları (deal / lead / company) okuma servisi — web
/// `PtbEntityService.getEntities(type, {pageSize: 200})` paritesi.
class CrmRecordsService {
  CrmRecordsService({CrmBackend? backend})
      : _backend = backend ?? SupabaseCrmBackend();

  final CrmBackend _backend;

  /// Web sayfa tavanı (PAGE_CAP = 200) — büyük listede sessiz kırpma
  /// [isTruncated] ile bildirilir.
  static const int pageCap = 200;

  /// Kayıtları listele (hata fırlatır → ekran hata/yeniden-dene gösterir).
  Future<List<CrmRecord>> list(String entityType, {int limit = pageCap}) async {
    final rows = await _backend.listSubmissions(entityType, limit: limit);
    return rows.map(CrmRecord.fromRow).where((r) => r.id.isNotEmpty).toList();
  }

  /// Liste sayfa tavanına ulaştı mı (daha fazla kayıt olabilir)?
  static bool isTruncated(int loaded, {int cap = pageCap}) => loaded >= cap;
}
