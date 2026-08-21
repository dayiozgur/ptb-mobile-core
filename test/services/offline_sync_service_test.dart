import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

void main() {
  // API drift: the old typed Sync* enums (SyncEntityType, SyncOperationType,
  // SyncStatus) and the SyncState class were replaced. PendingOperation now
  // uses a String `entityType`, a `type` of PendingOperationType and a `status`
  // of PendingOperationStatus (enum values are UPPERCASE, e.g. 'CREATE'); JSON
  // uses snake_case keys. The old `.isPending`/`.canRetry` convenience getters
  // were removed. SyncResult exposes `success`/`message`/`processed`/`failed`
  // (its success()/failure()/partial() factories and isSuccess/hasFailures/
  // totalCount/syncedCount getters are gone).
  group('PendingOperationType', () {
    test('has correct values', () {
      expect(PendingOperationType.create.value, 'CREATE');
      expect(PendingOperationType.update.value, 'UPDATE');
      expect(PendingOperationType.delete.value, 'DELETE');
    });

    test('fromString returns correct type', () {
      expect(PendingOperationType.fromString('CREATE'),
          PendingOperationType.create);
      expect(PendingOperationType.fromString('UPDATE'),
          PendingOperationType.update);
      expect(PendingOperationType.fromString('DELETE'),
          PendingOperationType.delete);
      expect(PendingOperationType.fromString('invalid'), isNull);
    });
  });

  group('PendingOperationStatus', () {
    test('has correct values', () {
      expect(PendingOperationStatus.pending.value, 'PENDING');
      expect(PendingOperationStatus.processing.value, 'PROCESSING');
      expect(PendingOperationStatus.completed.value, 'COMPLETED');
      expect(PendingOperationStatus.failed.value, 'FAILED');
    });

    test('fromString returns correct status', () {
      expect(PendingOperationStatus.fromString('PENDING'),
          PendingOperationStatus.pending);
      expect(PendingOperationStatus.fromString('PROCESSING'),
          PendingOperationStatus.processing);
      expect(PendingOperationStatus.fromString('COMPLETED'),
          PendingOperationStatus.completed);
      expect(PendingOperationStatus.fromString('FAILED'),
          PendingOperationStatus.failed);
      expect(PendingOperationStatus.fromString('invalid'), isNull);
    });
  });

  group('PendingOperation', () {
    test('creates correctly', () {
      final operation = PendingOperation(
        id: 'op-123',
        entityType: 'unit',
        entityId: 'unit-123',
        type: PendingOperationType.create,
        data: {'name': 'Test Unit'},
        status: PendingOperationStatus.pending,
        createdAt: DateTime.now(),
        retryCount: 0,
      );

      expect(operation.id, 'op-123');
      expect(operation.entityType, 'unit');
      expect(operation.entityId, 'unit-123');
      expect(operation.type, PendingOperationType.create);
      expect(operation.status, PendingOperationStatus.pending);
      expect(operation.retryCount, 0);
    });

    test('fromJson parses correctly', () {
      final json = {
        'id': 'op-123',
        'entity_type': 'unit',
        'entity_id': 'unit-123',
        'type': 'CREATE',
        'data': {'name': 'Test Unit'},
        'status': 'PENDING',
        'created_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
      };

      final operation = PendingOperation.fromJson(json);

      expect(operation.id, 'op-123');
      expect(operation.entityType, 'unit');
      expect(operation.entityId, 'unit-123');
      expect(operation.type, PendingOperationType.create);
      expect(operation.status, PendingOperationStatus.pending);
    });

    test('toJson serializes correctly', () {
      final operation = PendingOperation(
        id: 'op-123',
        entityType: 'site',
        entityId: 'site-123',
        type: PendingOperationType.update,
        data: {'name': 'Updated Site'},
        status: PendingOperationStatus.pending,
        createdAt: DateTime(2024, 1, 15),
        retryCount: 0,
      );

      final json = operation.toJson();

      expect(json['id'], 'op-123');
      expect(json['entity_type'], 'site');
      expect(json['entity_id'], 'site-123');
      expect(json['type'], 'UPDATE');
      expect(json['status'], 'PENDING');
    });

    test('round-trip serialization preserves fields', () {
      final operation = PendingOperation(
        id: 'op-123',
        entityType: 'unit',
        entityId: 'unit-123',
        type: PendingOperationType.delete,
        data: {'reason': 'obsolete'},
        status: PendingOperationStatus.completed,
        createdAt: DateTime(2024, 1, 15),
        retryCount: 2,
      );

      final restored = PendingOperation.fromJson(operation.toJson());

      expect(restored.id, 'op-123');
      expect(restored.entityType, 'unit');
      expect(restored.type, PendingOperationType.delete);
      expect(restored.status, PendingOperationStatus.completed);
      expect(restored.retryCount, 2);
    });

    test('copyWith creates correct copy', () {
      final operation = PendingOperation(
        id: 'op-123',
        entityType: 'unit',
        entityId: 'unit-123',
        type: PendingOperationType.create,
        data: {},
        status: PendingOperationStatus.pending,
        createdAt: DateTime.now(),
        retryCount: 0,
      );

      final copy = operation.copyWith(
        status: PendingOperationStatus.processing,
        retryCount: 1,
      );

      expect(copy.id, 'op-123');
      expect(copy.status, PendingOperationStatus.processing);
      expect(copy.retryCount, 1);
    });
  });

  group('SyncResult', () {
    test('successful result', () {
      final result = SyncResult(
        success: true,
        message: 'All synced',
        processed: 5,
        failed: 0,
      );

      expect(result.success, true);
      expect(result.processed, 5);
      expect(result.failed, 0);
    });

    test('failure result', () {
      final result = SyncResult(
        success: false,
        message: 'Network error',
        processed: 0,
        failed: 3,
      );

      expect(result.success, false);
      expect(result.processed, 0);
      expect(result.failed, 3);
    });

    test('partial result', () {
      final result = SyncResult(
        success: false,
        message: 'Some operations failed',
        processed: 7,
        failed: 3,
      );

      expect(result.success, false);
      expect(result.processed, 7);
      expect(result.failed, 3);
      expect(result.processed + result.failed, 10);
    });
  });
}
