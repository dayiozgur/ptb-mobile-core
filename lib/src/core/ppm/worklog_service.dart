import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';

/// Bir iş öğesine (epic/story/task/sub_task = `form_submissions` satırı) ait
/// tek efor kaydı — `ppm_worklogs` satırı.
///
/// ŞEMA VARSAYIMI (koddaki `fn_ppm_log_work` kullanımından türetildi, DB'den
/// değil): `ppm_worklogs(id, submission_id, hours_spent, remaining_estimate,
/// note, created_by, created_at)`. Yazma RPC parametreleri `p_submission_id` +
/// `p_hours_spent` + `p_remaining_estimate` + `p_note` olduğu için kolonların
/// bunları yansıttığı varsayıldı. Kolon adı farklıysa `select` sessizce
/// PGRST400 verir → `listWorklogs` boş döner (fırlatmaz).
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

  /// SAF satır→model eşleyici (ayrı test edilebilir). Tip-esnek: `hours_spent`
  /// int/num/double gelebilir → `toDouble()`.
  static WorklogEntry fromRow(Map<String, dynamic> r) => WorklogEntry(
        id: r['id']?.toString() ?? '',
        submissionId: r['submission_id']?.toString(),
        hoursSpent: (r['hours_spent'] as num?)?.toDouble(),
        remainingEstimate: (r['remaining_estimate'] as num?)?.toDouble(),
        note: r['note'] as String?,
        createdBy: r['created_by'] as String?,
        createdAt: r['created_at'] != null
            ? DateTime.tryParse(r['created_at'].toString())
            : null,
      );
}

/// **PPM efor (worklog) servisi** — bir iş öğesine efor kaydeder ve o öğenin
/// efor geçmişini listeler. Yazma `fn_ppm_log_work` SECDEF RPC'si üzerinden
/// (tenant + created_by sunucuda set edilir); listeleme `ppm_worklogs` üstünde
/// tenant-scoped RLS'e (`tenant_id = get_my_tenant_id()`) güvenir.
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
  Future<bool> logWork({
    required String submissionId,
    required num hours,
    num? remainingEstimate,
    String? note,
  }) async {
    if (hours <= 0) return false;
    try {
      await _supabase.rpc('fn_ppm_log_work', params: {
        'p_submission_id': submissionId,
        'p_hours_spent': hours,
        if (remainingEstimate != null) 'p_remaining_estimate': remainingEstimate,
        if (note != null && note.trim().isNotEmpty) 'p_note': note.trim(),
      });
      return true;
    } catch (e) {
      Logger.error('ppm logWork ($submissionId) hata', e);
      return false;
    }
  }

  /// Bir iş öğesinin efor kayıtları (yeniden eskiye). RLS tenant-scoped;
  /// hata/boş → `[]` (UI'a fırlatmaz).
  Future<List<WorklogEntry>> listWorklogs(String submissionId) async {
    try {
      final res = await _supabase
          .from('ppm_worklogs')
          .select(
              'id, submission_id, hours_spent, remaining_estimate, note, created_by, created_at')
          .eq('submission_id', submissionId)
          .order('created_at', ascending: false);
      final rows = (res as List).cast<Map<String, dynamic>>();
      return rows.map(WorklogEntry.fromRow).toList();
    } catch (e) {
      Logger.error('ppm listWorklogs ($submissionId) hata', e);
      return [];
    }
  }
}
