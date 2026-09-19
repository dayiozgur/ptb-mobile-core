import 'package:supabase_flutter/supabase_flutter.dart';

import '../connectivity/connectivity_service.dart';
import '../connectivity/offline_sync_service.dart';
import '../di/service_locator.dart';
import '../utils/logger.dart';

/// Bir CRM otomasyon-dizisi (email/cadence) özeti — `fn_crm_sequences_list`
/// satırı. Dizi-seçici (enroll) için hafif model.
class CrmSequence {
  final String id;
  final String name;
  final String? description;
  final int stepCount;
  final int activeEnrollments;

  const CrmSequence({
    required this.id,
    required this.name,
    this.description,
    this.stepCount = 0,
    this.activeEnrollments = 0,
  });

  /// SAF satır→model (ayrı test edilebilir). `fn_crm_sequences_list` kolonları:
  /// `id, name, description, active, step_count, active_enrollments`.
  static CrmSequence fromRow(Map<String, dynamic> r) => CrmSequence(
        id: r['id']?.toString() ?? '',
        name: (r['name'] as String?) ?? '',
        description: r['description'] as String?,
        stepCount: (r['step_count'] as num?)?.toInt() ?? 0,
        activeEnrollments: (r['active_enrollments'] as num?)?.toInt() ?? 0,
      );
}

/// **CRM aksiyon-çubuğu servisi** — web CRM entity-detay aksiyon-çubuğunun
/// (aktivite-logla / sonraki-adım-planla / aktivite-tamamla) yazma-paritesini
/// mobilde kurar. Üç CRM SECDEF RPC'si üzerinden çalışır; tenant + created_by
/// sunucuda (`get_my_tenant_id()` + `auth.uid()`) set edilir.
///
/// RPC İMZALARI (koddan doğrulandı — DB'ye tahmin edilmedi):
///   • `fn_crm_log_activity(p_subject, p_activity_type, p_notes, p_outcome,
///     p_related_contact_id, p_related_contact_name, p_related_deal_id,
///     p_related_deal_name)` — web `crm-activity-timeline` / `crm-email-compose`
///     ve mobil `crm_entity_actions.dart` ile birebir. Opsiyonel alanlar
///     DEFAULT NULL varsayımıyla, boşsa gönderilmez (web açık `null` gönderir;
///     ikisi de SECDEF fn'de eşdeğer).
///   • `fn_crm_complete_activity(p_activity_id uuid)` — web `my-work.component`
///     ve migration imzası `(uuid)`. **`outcome` DB imzasında YOK** → gönderilmez
///     (fazladan param PGRST404 verirdi).
///   • `fn_crm_log_next_step(p_deal_id uuid, p_next_date date)` — web `my-work`
///     ve migration imzası `(uuid,date)`. **Serbest `note` DB imzasında YOK**
///     → yalnız tarih gönderilir; not gerekiyorsa ayrı `logActivity` çağrılır.
///
/// Ctor-inject (sl gerekmez — [WorklogService] deseni). Hata veya geçersiz
/// giriş → `false` (UI'a ASLA fırlatmaz).
class CrmActionsService {
  final SupabaseClient _supabase;

  CrmActionsService({required SupabaseClient supabase}) : _supabase = supabase;

  /// Bir CRM kaydına (deal/contact) aktivite logla (`fn_crm_log_activity`).
  ///
  /// [subject] zorunlu ve boş olamaz (boşsa RPC çağrılmaz, `false` döner).
  /// [activityType] varsayılan `'note'` (web composer varsayılanıyla aynı).
  /// Boş metin-opsiyoneller (notes/outcome/name'ler) gönderilmez. En az bir
  /// ilişki (`relatedDealId` / `relatedContactId`) verilmesi beklenir ama RPC
  /// ilişkisiz "serbest" aktiviteyi de kabul edebilir → burada zorlanmaz.
  Future<bool> logActivity({
    required String subject,
    String activityType = 'note',
    String? notes,
    String? outcome,
    String? relatedContactId,
    String? relatedContactName,
    String? relatedDealId,
    String? relatedDealName,
  }) async {
    final s = subject.trim();
    if (s.isEmpty) return false;
    return _rpcOrQueue(
      'fn_crm_log_activity',
      {
        'p_subject': s,
        'p_activity_type': activityType,
        if (_has(notes)) 'p_notes': notes!.trim(),
        if (_has(outcome)) 'p_outcome': outcome!.trim(),
        if (_has(relatedContactId)) 'p_related_contact_id': relatedContactId!.trim(),
        if (_has(relatedContactName))
          'p_related_contact_name': relatedContactName!.trim(),
        if (_has(relatedDealId)) 'p_related_deal_id': relatedDealId!.trim(),
        if (_has(relatedDealName)) 'p_related_deal_name': relatedDealName!.trim(),
      },
      entityId: relatedDealId?.trim() ?? relatedContactId?.trim(),
      errorContext: 'logActivity',
    );
  }

  /// Bir deal için "sonraki adım" tarihi planla (`fn_crm_log_next_step`).
  ///
  /// [dealId] boşsa RPC çağrılmaz, `false` döner. [dueDate] yalnız tarih
  /// bileşenine (YYYY-MM-DD) indirgenir (saat düşer) — DB param'ı `date`.
  Future<bool> logNextStep({
    required String dealId,
    required DateTime dueDate,
  }) async {
    final id = dealId.trim();
    if (id.isEmpty) return false;
    return _rpcOrQueue(
      'fn_crm_log_next_step',
      {'p_deal_id': id, 'p_next_date': _dateOnly(dueDate)},
      entityId: id,
      errorContext: 'logNextStep ($dealId)',
    );
  }

  /// Bir aktiviteyi tamamlandı işaretle (`fn_crm_complete_activity`).
  ///
  /// [activityId] boşsa RPC çağrılmaz, `false` döner.
  Future<bool> completeActivity({required String activityId}) async {
    final id = activityId.trim();
    if (id.isEmpty) return false;
    return _rpcOrQueue(
      'fn_crm_complete_activity',
      {'p_activity_id': id},
      entityId: id,
      errorContext: 'completeActivity ($activityId)',
    );
  }

  /// Bir web-lead'i contact/deal'e dönüştür (`fn_crm_convert_web_lead(p_id)`).
  ///
  /// [leadId] boşsa RPC çağrılmaz, `false` döner. **ONLINE-only, bilinçli:**
  /// dönüşüm yeni kayıt (contact/deal) ÜRETİR; offline-kuyruk replay'i çift-
  /// dönüşüm riski taşırdı ve RPC zaten `defaultAllowedRpcFunctions` allow-
  /// list'inde DEĞİL. Offline'da `false` döner (UI "çevrimdışı" der). Hata →
  /// `false` (UI'a ASLA fırlatmaz), diğer aksiyonlarla aynı sözleşme.
  Future<bool> convertWebLead({required String leadId}) async {
    final id = leadId.trim();
    if (id.isEmpty) return false;
    if (_connectivityOrNull?.isOffline ?? false) return false;
    try {
      await _supabase.rpc('fn_crm_convert_web_lead', params: {'p_id': id});
      return true;
    } catch (e) {
      Logger.error('crm convertWebLead ($leadId) hata', e);
      return false;
    }
  }

  /// Bir lead'i yeniden skorla (`fn_crm_score_lead(p_entity_id)`) — gece
  /// `fn_crm_score_all` çalışmadan on-demand skor. Idempotent (yeniden-hesap),
  /// o yüzden online doğrudan çağrılır. Sonuç TABLE(score, band, ...); ilk
  /// satırın toplam skoru döner. Boş id / hata / sonuç-yok → `null`.
  Future<int?> scoreLead({required String leadId}) async {
    final id = leadId.trim();
    if (id.isEmpty) return null;
    try {
      final res = await _supabase.rpc('fn_crm_score_lead', params: {'p_entity_id': id});
      final list = (res as List?) ?? const [];
      if (list.isEmpty) return null;
      final s = Map<String, dynamic>.from(list.first as Map)['score'];
      return s is int ? s : (s is num ? s.toInt() : null);
    } catch (e) {
      Logger.error('crm scoreLead ($leadId) hata', e);
      return null;
    }
  }

  /// Aktif CRM dizilerini listele (`fn_crm_sequences_list`) — dizi-seçici için.
  /// SECDEF + tenant-scoped. Yalnız enroll edilebilir (adım-içeren) diziler
  /// gösterilsin diye `step_count > 0` süzülür. Hata/boş → `[]` (fırlatmaz).
  Future<List<CrmSequence>> listSequences() async {
    try {
      final res = await _supabase.rpc('fn_crm_sequences_list');
      final list = (res as List?) ?? const [];
      return list
          .map((e) => CrmSequence.fromRow(Map<String, dynamic>.from(e as Map)))
          .where((s) => s.id.isNotEmpty && s.stepCount > 0)
          .toList();
    } catch (e) {
      Logger.error('crm listSequences hata', e);
      return [];
    }
  }

  /// Bir kişiyi bir diziye ekle (`fn_crm_sequence_enroll(p_sequence_id,
  /// p_contact_id)`). **ONLINE-only, bilinçli:** enroll yeni bir enrollment
  /// satırı ÜRETİR → offline-replay çift-kayıt riski taşır (RPC zaten 'already
  /// enrolled' fırlatır) ve `defaultAllowedRpcFunctions` allow-list'inde DEĞİL —
  /// [convertWebLead] ile aynı sözleşme. Boş id / offline / hata → `false`.
  Future<bool> enrollInSequence({
    required String contactId,
    required String sequenceId,
  }) async {
    final cid = contactId.trim();
    final sid = sequenceId.trim();
    if (cid.isEmpty || sid.isEmpty) return false;
    if (_connectivityOrNull?.isOffline ?? false) return false;
    try {
      await _supabase.rpc('fn_crm_sequence_enroll',
          params: {'p_sequence_id': sid, 'p_contact_id': cid});
      return true;
    } catch (e) {
      Logger.error('crm enrollInSequence ($cid→$sid) hata', e);
      return false;
    }
  }

  /// Ortak yaz-yolu: OFFLINE ise RPC'yi kuyruğa alır (`enqueueRpc` → replay
  /// sırasında [SupabaseReplayDispatcher] oynatır; üç CRM RPC'si de zaten
  /// `defaultAllowedRpcFunctions` allow-list'inde) ve iyimser `true` döner.
  /// ONLINE ise doğrudan `rpc` çağırır (önceki davranış — hata/`false`).
  Future<bool> _rpcOrQueue(
    String function,
    Map<String, dynamic> params, {
    String? entityId,
    required String errorContext,
  }) async {
    final sync = _offlineSyncOrNull;
    if (sync != null && (_connectivityOrNull?.isOffline ?? false)) {
      final op = await sync.enqueueRpc(
          function: function, params: params, entityId: entityId);
      Logger.info('Offline: $function queued (${op.id})');
      return true;
    }
    try {
      await _supabase.rpc(function, params: params);
      return true;
    } catch (e) {
      Logger.error('crm $errorContext hata', e);
      return false;
    }
  }

  // Offline-queue erişimi (kayıtlı/başlatılmamışsa null → doğrudan ağ path'i).
  ConnectivityService? get _connectivityOrNull =>
      sl.isRegistered<ConnectivityService>() ? sl<ConnectivityService>() : null;

  OfflineSyncService? get _offlineSyncOrNull {
    if (!sl.isRegistered<OfflineSyncService>()) return null;
    final s = sl<OfflineSyncService>();
    return s.isInitialized ? s : null;
  }

  static bool _has(String? v) => v != null && v.trim().isNotEmpty;

  /// `DateTime` → `YYYY-MM-DD` (yerel tarih, sıfır-dolgulu). `toIso8601String`
  /// UTC'ye kaydırabildiği için manuel biçimlendirilir (gün sınırı kaymasın).
  static String _dateOnly(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}
