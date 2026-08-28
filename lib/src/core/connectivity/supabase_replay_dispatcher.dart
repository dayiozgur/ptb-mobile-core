import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';
import 'offline_sync_service.dart';

/// Çevrimdışıyken kuyruğa alınmış generic write işlemlerini ([PendingOperation])
/// bağlantı gelince doğru Supabase çağrısına map eden replay dispatcher'ı.
///
/// FORM-SUBMIT DIŞI write akışları için tasarlanmıştır:
///  * [PendingOperationType.genericRpc]   → `client.rpc(fn, params: ...)`
///    (durum-değişimi, worklog-logla, aktivite-log, onay/red gibi RPC yazımları)
///  * [PendingOperationType.tableInsert]  → `client.from(table).insert(row)`
///    (düz tablo-insert akışları)
///
/// [OfflineSyncService.registerDefaultHandler] ile tek noktadan bağlanır; her
/// fonksiyon/tablo için ayrı handler kaydına gerek kalmaz.
///
/// GÜVENLİK — allow-list: kuyruk diskte durur; keyfi/enjekte edilmiş bir
/// kuyruk kaydının rastgele RPC ya da tablo-insert çalıştırmasını önlemek için
/// yalnız [allowedRpcFunctions] / [allowedTables] içindeki adlar replay edilir.
/// Liste dışı işlem ÇALIŞTIRILMAZ: uyarı loglanır ve `false` döner (işlem
/// retry döngüsünde dead-letter'a düşer, incelenebilir). Yeni bir offline
/// write akışı eklerken adı buradaki varsayılan listeye (ya da wiring
/// noktasındaki özel listeye) eklemek ŞARTTIR.
///
/// Sözleşme ([OperationHandler] ile uyumlu):
///  * başarı → `true` döner (işlem kuyruktan düşer)
///  * Supabase hatası → hatayı FIRLATIR; OfflineSyncService yakalar, retry
///    sayacını artırır ve gerçek hata mesajını `lastError`'a yazar
///  * desteklenmeyen tip (create/update/delete) → `false` (bu tipler entity
///    handler'larına bırakılır; dispatcher sessizce devralmaz)
///  * allow-list dışı fn/tablo → `false` + uyarı logu (çağrı YAPILMAZ)
class SupabaseReplayDispatcher {
  SupabaseReplayDispatcher(
    this._client, {
    Set<String>? allowedRpcFunctions,
    Set<String>? allowedTables,
  })  : _allowedRpcFunctions =
            allowedRpcFunctions ?? defaultAllowedRpcFunctions,
        _allowedTables = allowedTables ?? defaultAllowedTables;

  final SupabaseClient _client;

  /// Replay edilmesine izin verilen RPC fonksiyon adları.
  final Set<String> _allowedRpcFunctions;

  /// Replay edilmesine izin verilen insert tablo adları.
  final Set<String> _allowedTables;

  /// Bilinen offline-write RPC'leri (mobil akışların çağırdığı yazımlar).
  static const Set<String> defaultAllowedRpcFunctions = {
    // PPM
    'fn_ppm_log_work',
    'fn_reorder_backlog',
    // CRM aksiyonları
    'fn_crm_log_activity',
    'fn_crm_complete_activity',
    'fn_crm_log_next_step',
    // HR / PDKS
    'fn_hr_onboarding_task_set_status',
    'fn_pdks_geo_punch',
    'fn_work_geo_session',
    // PMS alarm aksiyonları
    'fn_pms_alarm_acknowledge',
    'fn_pms_alarm_reset',
    'fn_pms_alarm_inhibit',
    // Workflow onay/red
    'fn_workflow_approval_decide',
  };

  /// Bilinen offline-insert tabloları (RLS zaten sunucuda geçerlidir; bu
  /// liste istemci tarafında keyfi hedefleri keser).
  static const Set<String> defaultAllowedTables = {
    'comments',
    'attendance_records',
    'leave_requests',
    'calendar_events',
    'todo_items',
    'work_requests',
  };

  /// Bu dispatcher'ın verilen işlemi işleyip işleyemeyeceği (tip bazlı).
  bool canDispatch(PendingOperation op) =>
      op.type == PendingOperationType.genericRpc ||
      op.type == PendingOperationType.tableInsert;

  /// İşlemi uygun Supabase çağrısına map eder. [OperationHandler] olarak
  /// doğrudan [OfflineSyncService.registerDefaultHandler]'a verilebilir.
  Future<bool> dispatch(PendingOperation op) async {
    switch (op.type) {
      case PendingOperationType.genericRpc:
        final fn = op.rpcFunction;
        if (fn == null || fn.isEmpty) {
          Logger.warning('genericRpc replay: fonksiyon adı yok (${op.id})');
          return false;
        }
        if (!_allowedRpcFunctions.contains(fn)) {
          Logger.warning(
              'genericRpc replay REDDEDİLDİ: "$fn" allow-list dışı (${op.id})');
          return false;
        }
        await _client.rpc<dynamic>(fn, params: op.rpcParams);
        Logger.debug('Replayed RPC: $fn (${op.id})');
        return true;

      case PendingOperationType.tableInsert:
        final table = op.tableName;
        if (table == null || table.isEmpty) {
          Logger.warning('tableInsert replay: tablo adı yok (${op.id})');
          return false;
        }
        if (!_allowedTables.contains(table)) {
          Logger.warning(
              'tableInsert replay REDDEDİLDİ: "$table" allow-list dışı (${op.id})');
          return false;
        }
        await _client.from(table).insert(op.insertRow);
        Logger.debug('Replayed INSERT: $table (${op.id})');
        return true;

      case PendingOperationType.create:
      case PendingOperationType.update:
      case PendingOperationType.delete:
        // Entity-CRUD fiilleri entity handler'larına aittir; dispatcher
        // devralmaz (kuyrukta kalır → uygun handler kaydedilince işlenir).
        Logger.debug(
            'SupabaseReplayDispatcher: ${op.type.value} desteklenmiyor (${op.entityType})');
        return false;
    }
  }
}
