import 'package:supabase_flutter/supabase_flutter.dart';

import '../connectivity/connectivity_service.dart';
import '../connectivity/offline_sync_service.dart';
import '../di/service_locator.dart';
import '../utils/logger.dart';

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
