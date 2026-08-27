import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Offline-sync + connectivity **saf-mantık** testleri: op-serialize (JSON
/// round-trip), enum parse, retry/status kararı (copyWith), SyncProgress
/// yüzde-hesabı ve ConnectivityInfo durum-türetimi. Hive/gerçek-IO YOK —
/// yalnız değer/model mantığı.
void main() {
  group('PendingOperationType.fromString', () {
    test('geçerli değerler doğru enum', () {
      expect(PendingOperationType.fromString('CREATE'),
          PendingOperationType.create);
      expect(PendingOperationType.fromString('UPDATE'),
          PendingOperationType.update);
      expect(PendingOperationType.fromString('DELETE'),
          PendingOperationType.delete);
    });

    test('null / bilinmeyen → null', () {
      expect(PendingOperationType.fromString(null), isNull);
      expect(PendingOperationType.fromString('MERGE'), isNull);
    });

    test('generic write türleri (RPC / INSERT) parse edilir', () {
      // MOB-09: form-submit dışı generic write akışları için yeni tipler.
      expect(PendingOperationType.fromString('RPC'),
          PendingOperationType.genericRpc);
      expect(PendingOperationType.fromString('INSERT'),
          PendingOperationType.tableInsert);
      expect(PendingOperationType.genericRpc.value, 'RPC');
      expect(PendingOperationType.tableInsert.value, 'INSERT');
    });
  });

  group('PendingOperationStatus.fromString', () {
    test('geçerli değerler doğru enum', () {
      expect(PendingOperationStatus.fromString('PENDING'),
          PendingOperationStatus.pending);
      expect(PendingOperationStatus.fromString('PROCESSING'),
          PendingOperationStatus.processing);
      expect(PendingOperationStatus.fromString('COMPLETED'),
          PendingOperationStatus.completed);
      expect(PendingOperationStatus.fromString('FAILED'),
          PendingOperationStatus.failed);
    });

    test('null / bilinmeyen → null', () {
      expect(PendingOperationStatus.fromString(null), isNull);
      expect(PendingOperationStatus.fromString('QUEUED'), isNull);
    });
  });

  group('PendingOperation JSON round-trip (op-serialize)', () {
    test('toJson → fromJson tüm alanları korur', () {
      final created = DateTime.parse('2026-08-20T10:30:00.000');
      final op = PendingOperation(
        id: 'op-1',
        type: PendingOperationType.update,
        entityType: 'unit',
        entityId: 'unit-42',
        data: {'name': 'Kompresör', 'count': 3},
        createdAt: created,
        retryCount: 2,
        lastError: 'timeout',
        status: PendingOperationStatus.failed,
      );

      final restored = PendingOperation.fromJson(op.toJson());

      expect(restored.id, 'op-1');
      expect(restored.type, PendingOperationType.update);
      expect(restored.entityType, 'unit');
      expect(restored.entityId, 'unit-42');
      expect(restored.data['name'], 'Kompresör');
      expect(restored.data['count'], 3);
      expect(restored.createdAt, created);
      expect(restored.retryCount, 2);
      expect(restored.lastError, 'timeout');
      expect(restored.status, PendingOperationStatus.failed);
    });

    test('toJson string değerleri enum .value ile yazar', () {
      final op = PendingOperation(
        id: 'op-2',
        type: PendingOperationType.create,
        entityType: 'contact',
        data: const {},
        createdAt: DateTime.parse('2026-08-20T00:00:00.000'),
      );
      final json = op.toJson();
      expect(json['type'], 'CREATE');
      expect(json['status'], 'PENDING'); // varsayılan
      expect(json['retry_count'], 0);
    });

    test('fromJson eksik/bozuk enum → güvenli varsayılan', () {
      final restored = PendingOperation.fromJson({
        'id': 'op-3',
        'type': 'GARBAGE',
        'entity_type': 'note',
        'data': {'x': 1},
        'created_at': '2026-08-20T00:00:00.000',
        'status': 'GARBAGE',
      });
      // Bilinmeyen enum → create / pending fallback (fromString null → ??)
      expect(restored.type, PendingOperationType.create);
      expect(restored.status, PendingOperationStatus.pending);
      expect(restored.retryCount, 0); // eksik alan → 0
      expect(restored.entityId, isNull);
    });
  });

  group('PendingOperation generic-write (MOB-09: form-submit dışı)', () {
    test('PendingOperation.rpc → payload + entityType = fn adı', () {
      final op = PendingOperation.rpc(
        id: 'rpc-1',
        function: 'fn_ppm_log_work',
        params: {'p_submission_id': 's1', 'p_hours_spent': 2.5},
        createdAt: DateTime.parse('2026-08-25T09:00:00.000'),
        idempotencyKey: 'idem-abc',
      );

      expect(op.type, PendingOperationType.genericRpc);
      expect(op.entityType, 'fn_ppm_log_work'); // dispatch-doğal-anahtar
      expect(op.rpcFunction, 'fn_ppm_log_work');
      expect(op.rpcParams, {'p_submission_id': 's1', 'p_hours_spent': 2.5});
      expect(op.idempotencyKey, 'idem-abc');
      // tip uyuşmazlığı getter'ları → null/boş
      expect(op.tableName, isNull);
      expect(op.insertRow, isEmpty);
    });

    test('PendingOperation.rpc params yoksa boş map', () {
      final op = PendingOperation.rpc(
        id: 'rpc-2',
        function: 'fn_status_change',
        createdAt: DateTime.parse('2026-08-25T00:00:00.000'),
      );
      expect(op.rpcParams, isEmpty);
      expect(op.idempotencyKey, isNull);
    });

    test('PendingOperation.tableInsert → payload + entityType = tablo adı', () {
      final op = PendingOperation.tableInsert(
        id: 'ins-1',
        table: 'activity_logs',
        row: {'action': 'approve', 'entity_id': 'e1'},
        createdAt: DateTime.parse('2026-08-25T09:00:00.000'),
      );

      expect(op.type, PendingOperationType.tableInsert);
      expect(op.entityType, 'activity_logs');
      expect(op.tableName, 'activity_logs');
      expect(op.insertRow, {'action': 'approve', 'entity_id': 'e1'});
      // tip uyuşmazlığı getter'ları → null/boş
      expect(op.rpcFunction, isNull);
      expect(op.rpcParams, isEmpty);
    });

    test('genericRpc JSON round-trip (idempotency_key dahil)', () {
      final op = PendingOperation.rpc(
        id: 'rpc-3',
        function: 'fn_approve',
        params: {'p_id': 'x', 'p_note': 'ok'},
        createdAt: DateTime.parse('2026-08-25T12:00:00.000'),
        idempotencyKey: 'idem-1',
        retryCount: 1,
        status: PendingOperationStatus.pending,
      );

      final json = op.toJson();
      expect(json['type'], 'RPC');
      expect(json['idempotency_key'], 'idem-1');

      final restored = PendingOperation.fromJson(json);
      expect(restored.type, PendingOperationType.genericRpc);
      expect(restored.rpcFunction, 'fn_approve');
      expect(restored.rpcParams, {'p_id': 'x', 'p_note': 'ok'});
      expect(restored.idempotencyKey, 'idem-1');
      expect(restored.retryCount, 1);
    });

    test('tableInsert JSON round-trip', () {
      final op = PendingOperation.tableInsert(
        id: 'ins-2',
        table: 'worklog_events',
        row: {'hours': 3},
        createdAt: DateTime.parse('2026-08-25T12:00:00.000'),
      );
      final restored = PendingOperation.fromJson(op.toJson());
      expect(restored.type, PendingOperationType.tableInsert);
      expect(restored.tableName, 'worklog_events');
      expect(restored.insertRow, {'hours': 3});
    });

    test('geriye-uyum: idempotency_key olmayan eski kayıt → null', () {
      // MOB-10 formatında yazılmış (idempotency_key alanı yok) bir kaydın
      // hâlâ sorunsuz parse edilmesi gerekir.
      final restored = PendingOperation.fromJson({
        'id': 'legacy-1',
        'type': 'CREATE',
        'entity_type': 'unit',
        'data': {'name': 'X'},
        'created_at': '2026-08-20T00:00:00.000',
        'status': 'PENDING',
      });
      expect(restored.idempotencyKey, isNull);
      expect(restored.type, PendingOperationType.create);
    });
  });

  group('PendingOperation.copyWith (retry / status kararı)', () {
    test('retry artışı + status geçişi orijinali bozmaz', () {
      final op = PendingOperation(
        id: 'op-4',
        type: PendingOperationType.create,
        entityType: 'unit',
        data: const {'a': 1},
        createdAt: DateTime.parse('2026-08-20T00:00:00.000'),
      );

      final retried = op.copyWith(
        retryCount: op.retryCount + 1,
        lastError: 'net fail',
        status: PendingOperationStatus.pending,
      );

      expect(op.retryCount, 0); // orijinal değişmedi
      expect(retried.retryCount, 1);
      expect(retried.lastError, 'net fail');
      expect(retried.id, 'op-4'); // diğer alanlar korunur
      expect(retried.data, const {'a': 1});
    });

    test('maxRetries (3) eşiğinde failed karar mantığı', () {
      // _processOperation'daki karar: retryCount+1 >= 3 ? failed : pending
      const maxRetries = 3;
      PendingOperationStatus decide(int currentRetry) =>
          currentRetry + 1 >= maxRetries
              ? PendingOperationStatus.failed
              : PendingOperationStatus.pending;

      expect(decide(0), PendingOperationStatus.pending); // → retry 1
      expect(decide(1), PendingOperationStatus.pending); // → retry 2
      expect(decide(2), PendingOperationStatus.failed); // → retry 3 = eşik
    });
  });

  group('SyncProgress.percentage', () {
    test('normal ilerleme oranı', () {
      final op = PendingOperation(
        id: 'op-5',
        type: PendingOperationType.create,
        entityType: 'unit',
        data: const {},
        createdAt: DateTime.parse('2026-08-20T00:00:00.000'),
      );
      expect(SyncProgress(current: 1, total: 4, currentOperation: op).percentage,
          0.25);
      expect(SyncProgress(current: 4, total: 4, currentOperation: op).percentage,
          1.0);
    });

    test('total 0 → sıfıra bölme yok (0.0)', () {
      final op = PendingOperation(
        id: 'op-6',
        type: PendingOperationType.create,
        entityType: 'unit',
        data: const {},
        createdAt: DateTime.parse('2026-08-20T00:00:00.000'),
      );
      expect(SyncProgress(current: 0, total: 0, currentOperation: op).percentage,
          0.0);
    });
  });

  group('SyncResult', () {
    test('alanları taşır + toString özet', () {
      final r = SyncResult(
          success: false, message: '1 fail', processed: 3, failed: 1);
      expect(r.success, isFalse);
      expect(r.processed, 3);
      expect(r.failed, 1);
      expect(r.toString(), contains('processed: 3'));
      expect(r.toString(), contains('failed: 1'));
    });
  });

  group('ConnectivityInfo (durum türetimi)', () {
    test('online factory → isOnline true / isOffline false', () {
      final info = ConnectivityInfo.online(type: ConnectionType.wifi);
      expect(info.status, ConnectivityStatus.online);
      expect(info.type, ConnectionType.wifi);
      expect(info.isOnline, isTrue);
      expect(info.isOffline, isFalse);
    });

    test('offline factory → isOffline true / type none', () {
      final info = ConnectivityInfo.offline();
      expect(info.status, ConnectivityStatus.offline);
      expect(info.type, ConnectionType.none);
      expect(info.isOnline, isFalse);
      expect(info.isOffline, isTrue);
    });

    test('unknown factory → ne online ne offline', () {
      final info = ConnectivityInfo.unknown();
      expect(info.status, ConnectivityStatus.unknown);
      expect(info.isOnline, isFalse);
      expect(info.isOffline, isFalse);
    });
  });
}
