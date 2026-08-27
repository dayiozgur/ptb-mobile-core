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
/// Sözleşme ([OperationHandler] ile uyumlu):
///  * başarı → `true` döner (işlem kuyruktan düşer)
///  * Supabase hatası → hatayı FIRLATIR; OfflineSyncService yakalar, retry
///    sayacını artırır ve gerçek hata mesajını `lastError`'a yazar
///  * desteklenmeyen tip (create/update/delete) → `false` (bu tipler entity
///    handler'larına bırakılır; dispatcher sessizce devralmaz)
class SupabaseReplayDispatcher {
  SupabaseReplayDispatcher(this._client);

  final SupabaseClient _client;

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
        await _client.rpc<dynamic>(fn, params: op.rpcParams);
        Logger.debug('Replayed RPC: $fn (${op.id})');
        return true;

      case PendingOperationType.tableInsert:
        final table = op.tableName;
        if (table == null || table.isEmpty) {
          Logger.warning('tableInsert replay: tablo adı yok (${op.id})');
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
