import 'package:supabase_flutter/supabase_flutter.dart';

import '../connectivity/connectivity_service.dart';
import '../connectivity/offline_sync_service.dart';
import '../di/service_locator.dart';
import '../utils/logger.dart';

/// Bir iş öğesine (epic/story/task/sub_task = `form_submissions` satırı) ait
/// tek efor kaydı — kanonik `worklogs` satırı.
///
/// KONSOLIDASYON (2026-09-19): eski mobil-özel `ppm_worklogs` tablosu, web PPM +
/// FixFlow ile PAYLAŞILAN `worklogs` tablosuna birleştirildi (option D). Artık
/// web PPM issue-detail ve mobil aynı `worklogs`'u okur/yazar → issue başına
/// birleşik efor geçmişi. `fn_ppm_log_work` imzası DEĞİŞMEDİ ([logWork] aynen
/// çalışır), yalnız hedef tablo `worklogs`.
///
/// ŞEMA — `worklogs(id, entity_type, entity_id, time_spent[DAKİKA int],
/// remaining_estimate, description, created_by, created_at, work_date)`. Kanonik
/// birim DAKİKA (FixFlow+geofence ile aynı); mobil saat gösterir, o yüzden
/// [fromRow] `time_spent/60` ile saate çevirir ve `hours_spent` yazarken
/// `fn_ppm_log_work` saat→dakika çevirir. `note`↔`description` eşlenir.
class WorklogEntry {
  final String id;
  final String? submissionId;
  final double? hoursSpent;
  final double? remainingEstimate;
  final String? note;
  final String? createdBy;
  final DateTime? createdAt;

  const WorklogEntry({
    required this.id,
    this.submissionId,
    this.hoursSpent,
    this.remainingEstimate,
    this.note,
    this.createdBy,
    this.createdAt,
  });

  /// SAF satır→model eşleyici (ayrı test edilebilir). Kanonik `worklogs` şeması:
  /// `entity_id`→submissionId, `time_spent`(DAKİKA)→`hoursSpent` (÷60),
  /// `description`→note. Tip-esnek: `time_spent` int/num gelebilir → `toDouble()`.
  static WorklogEntry fromRow(Map<String, dynamic> r) => WorklogEntry(
        id: r['id']?.toString() ?? '',
        submissionId: r['entity_id']?.toString(),
        hoursSpent: (r['time_spent'] as num?) == null
            ? null
            : (r['time_spent'] as num).toDouble() / 60.0,
        remainingEstimate: (r['remaining_estimate'] as num?)?.toDouble(),
        note: r['description'] as String?,
        createdBy: r['created_by'] as String?,
        createdAt: r['created_at'] != null
            ? DateTime.tryParse(r['created_at'].toString())
            : null,
      );
}

/// **PPM efor (worklog) servisi** — bir iş öğesine efor kaydeder ve o öğenin
/// efor geçmişini listeler. Yazma `fn_ppm_log_work` RPC'si üzerinden (tenant +
/// created_by sunucuda set edilir); listeleme kanonik `worklogs` üstünde
/// tenant-scoped RLS'e (`tenant_id = get_my_tenant_id()`) güvenir. Geçmiş artık
/// web PPM ile PAYLAŞIMLIDIR (aynı `worklogs`).
///
/// "Bana atanan iş" (my-work) BURADA DEĞİL: çekirdek [work_inbox_service.dart]
/// `WorkInboxService` + PPM `WorkInboxSource(fn_ppm_my_work)` bunu zaten generic
/// karşılar → tekrar yazılmadı (çekirdek yeniden-kullanım).
///
/// Ctor-inject (sl gerekmez); hata durumunda `false`/`[]` döner (UI'a fırlatmaz).
class WorklogService {
  final SupabaseClient _supabase;

  WorklogService({required SupabaseClient supabase}) : _supabase = supabase;

  /// Efor kaydet (`fn_ppm_log_work`). Başarı → `true`.
  ///
  /// [hours] `<= 0` ise RPC çağrılmaz, `false` döner (geçersiz efor). [note] boş
  /// ise gönderilmez; [remainingEstimate] null ise gönderilmez (RPC varsayılanı
  /// korunur).
  ///
  /// OFFLINE: bağlantı yoksa RPC kuyruğa alınır (`enqueueRpc` → replay sırasında
  /// [SupabaseReplayDispatcher] `fn_ppm_log_work`'ü oynatır — bu RPC zaten
  /// `defaultAllowedRpcFunctions` allow-list'inde) ve iyimser `true` döner
  /// (worklog online olunca gerçekten yazılır). Online path DEĞİŞMEDİ.
  Future<bool> logWork({
    required String submissionId,
    required num hours,
    num? remainingEstimate,
    String? note,
  }) async {
    if (hours <= 0) return false;
    final params = <String, dynamic>{
      'p_submission_id': submissionId,
      'p_hours_spent': hours,
      if (remainingEstimate != null) 'p_remaining_estimate': remainingEstimate,
      if (note != null && note.trim().isNotEmpty) 'p_note': note.trim(),
    };

    final sync = _offlineSyncOrNull;
    if (sync != null && (_connectivityOrNull?.isOffline ?? false)) {
      final op = await sync.enqueueRpc(
        function: 'fn_ppm_log_work',
        params: params,
        entityId: submissionId,
      );
      Logger.info('Offline: ppm logWork queued (${op.id}, $submissionId)');
      return true;
    }

    try {
      await _supabase.rpc('fn_ppm_log_work', params: params);
      return true;
    } catch (e) {
      Logger.error('ppm logWork ($submissionId) hata', e);
      return false;
    }
  }

  // Offline-queue erişimi (kayıtlı/başlatılmamışsa null → logWork doğrudan ağ
  // path'ine düşer, davranış değişmez).
  ConnectivityService? get _connectivityOrNull =>
      sl.isRegistered<ConnectivityService>() ? sl<ConnectivityService>() : null;

  OfflineSyncService? get _offlineSyncOrNull {
    if (!sl.isRegistered<OfflineSyncService>()) return null;
    final s = sl<OfflineSyncService>();
    return s.isInitialized ? s : null;
  }

  /// Bir iş öğesinin efor kayıtları (yeniden eskiye). RLS tenant-scoped;
  /// hata/boş → `[]` (UI'a fırlatmaz).
  Future<List<WorklogEntry>> listWorklogs(String submissionId) async {
    try {
      // Kanonik `worklogs`: iş öğesi = `entity_id` (submission uuid globaldir,
      // entity_type filtresi gerekmez). En yeni önce. `time_spent` DAKİKA olarak
      // gelir → `fromRow` saate çevirir.
      final res = await _supabase
          .from('worklogs')
          .select(
              'id, entity_id, time_spent, remaining_estimate, description, created_by, created_at')
          .eq('entity_id', submissionId)
          .order('created_at', ascending: false);
      final rows = (res as List).cast<Map<String, dynamic>>();
      return rows.map(WorklogEntry.fromRow).toList();
    } catch (e) {
      Logger.error('ppm listWorklogs ($submissionId) hata', e);
      return [];
    }
  }
}
