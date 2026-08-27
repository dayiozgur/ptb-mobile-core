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
