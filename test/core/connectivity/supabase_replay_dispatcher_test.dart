import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../helpers/supabase_fakes.dart';

/// MOB-09 — [SupabaseReplayDispatcher] **saf dispatch** testleri.
///
/// Çevrimdışıyken kuyruğa alınmış generic write işlemleri (genericRpc /
/// tableInsert) bağlantı gelince doğru Supabase çağrısına map edilir. Gerçek ağ
/// YOK: [SupabaseHarness] chain-thenable fake'leri kullanılır. Sözleşme:
/// başarı → `true` (kuyruktan düşer), Supabase hatası → FIRLATIR (üstteki
/// OfflineSyncService retry sayacını artırır).
void main() {
  late SupabaseHarness h;
  late SupabaseReplayDispatcher dispatcher;

  final createdAt = DateTime.parse('2026-08-25T09:00:00.000');

  setUp(() {
    h = SupabaseHarness();
    dispatcher = SupabaseReplayDispatcher(h.client);
  });

  group('canDispatch', () {
    test('yalnız generic write türlerini üstlenir', () {
      final rpc = PendingOperation.rpc(
          id: 'r', function: 'fn_x', createdAt: createdAt);
      final ins = PendingOperation.tableInsert(
          id: 'i', table: 't', row: const {}, createdAt: createdAt);
      final crud = PendingOperation(
        id: 'c',
        type: PendingOperationType.create,
        entityType: 'unit',
        data: const {},
        createdAt: createdAt,
      );
      expect(dispatcher.canDispatch(rpc), isTrue);
      expect(dispatcher.canDispatch(ins), isTrue);
      expect(dispatcher.canDispatch(crud), isFalse);
    });
  });

  group('genericRpc replay', () {
    test('doğru fn + params ile RPC → true', () async {
      h.stubRpc('fn_ppm_log_work', result: null);

      final op = PendingOperation.rpc(
        id: 'rpc-1',
        function: 'fn_ppm_log_work',
        params: {'p_submission_id': 's1', 'p_hours_spent': 2.5},
        createdAt: createdAt,
      );

      final ok = await dispatcher.dispatch(op);

      expect(ok, isTrue);
      expect(h.capturedRpcParams('fn_ppm_log_work'),
          {'p_submission_id': 's1', 'p_hours_spent': 2.5});
    });

    test('params yoksa boş map ile çağrılır', () async {
      h.stubRpc('fn_status_change', result: null);

      final op = PendingOperation.rpc(
          id: 'rpc-2', function: 'fn_status_change', createdAt: createdAt);

      expect(await dispatcher.dispatch(op), isTrue);
      expect(h.capturedRpcParams('fn_status_change'), isEmpty);
    });

    test('Supabase hatası → FIRLATIR (retry için)', () async {
      h.stubRpc('fn_approve', error: Exception('boom'));

      final op = PendingOperation.rpc(
          id: 'rpc-3', function: 'fn_approve', createdAt: createdAt);

      expect(() => dispatcher.dispatch(op), throwsA(isA<Exception>()));
    });

    test('fn adı boş → false (çağrı yapılmaz)', () async {
      // Bozuk payload: fn boş. Kuyrukta kalmasın diye false döner.
      final op = PendingOperation(
        id: 'rpc-4',
        type: PendingOperationType.genericRpc,
        entityType: '',
        data: const {PendingOperation.kRpcFn: '', PendingOperation.kRpcParams: {}},
        createdAt: createdAt,
      );
      expect(await dispatcher.dispatch(op), isFalse);
      verifyNever(() => h.client.rpc<dynamic>(any()));
    });
  });

  group('tableInsert replay', () {
    test('doğru tabloya insert(row) → true', () async {
      h.stubFrom('activity_logs', result: null);

      final op = PendingOperation.tableInsert(
        id: 'ins-1',
        table: 'activity_logs',
        row: {'action': 'approve', 'entity_id': 'e1'},
        createdAt: createdAt,
      );

      final ok = await dispatcher.dispatch(op);

      expect(ok, isTrue);
      final calls = h.queryByTable['activity_logs']!.calls;
      final insert = calls.firstWhere((c) => c.memberName == #insert);
      expect(insert.positionalArguments.first,
          {'action': 'approve', 'entity_id': 'e1'});
    });

    test('Supabase hatası → FIRLATIR (retry için)', () async {
      h.stubFrom('worklog_events', error: Exception('db down'));

      final op = PendingOperation.tableInsert(
        id: 'ins-2',
        table: 'worklog_events',
        row: const {'hours': 3},
        createdAt: createdAt,
      );

      expect(() => dispatcher.dispatch(op), throwsA(isA<Exception>()));
    });

    test('tablo adı boş → false (çağrı yapılmaz)', () async {
      final op = PendingOperation(
        id: 'ins-3',
        type: PendingOperationType.tableInsert,
        entityType: '',
        data: const {PendingOperation.kTable: '', PendingOperation.kRow: {}},
        createdAt: createdAt,
      );
      expect(await dispatcher.dispatch(op), isFalse);
      verifyNever(() => h.client.from(any()));
    });
  });

  group('desteklenmeyen tip (entity-CRUD) → false', () {
    test('create/update/delete dispatcher tarafından üstlenilmez', () async {
      for (final t in [
        PendingOperationType.create,
        PendingOperationType.update,
        PendingOperationType.delete,
      ]) {
        final op = PendingOperation(
          id: 'c-${t.value}',
          type: t,
          entityType: 'unit',
          data: const {},
          createdAt: createdAt,
        );
        expect(await dispatcher.dispatch(op), isFalse,
            reason: '${t.value} entity handler\'ına bırakılmalı');
      }
    });
  });
}
