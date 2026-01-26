import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

void main() {
  group('SyncOperationType', () {
    test('has correct values', () {
      expect(SyncOperationType.create.value, 'create');
      expect(SyncOperationType.update.value, 'update');
      expect(SyncOperationType.delete.value, 'delete');
    });

    test('fromValue returns correct type', () {
      expect(SyncOperationType.fromValue('create'), SyncOperationType.create);
      expect(SyncOperationType.fromValue('update'), SyncOperationType.update);
      expect(SyncOperationType.fromValue('delete'), SyncOperationType.delete);
      expect(SyncOperationType.fromValue('invalid'), SyncOperationType.create);
    });
  });

  group('SyncStatus', () {
    test('has correct values', () {
      expect(SyncStatus.pending.value, 'pending');
      expect(SyncStatus.syncing.value, 'syncing');
      expect(SyncStatus.completed.value, 'completed');
      expect(SyncStatus.failed.value, 'failed');
    });

    test('isPending returns correct value', () {
      expect(SyncStatus.pending.isPending, true);
      expect(SyncStatus.syncing.isPending, false);
      expect(SyncStatus.completed.isPending, false);
      expect(SyncStatus.failed.isPending, false);
    });

    test('isSyncing returns correct value', () {
      expect(SyncStatus.pending.isSyncing, false);
      expect(SyncStatus.syncing.isSyncing, true);
      expect(SyncStatus.completed.isSyncing, false);
      expect(SyncStatus.failed.isSyncing, false);
    });

    test('isCompleted returns correct value', () {
      expect(SyncStatus.pending.isCompleted, false);
      expect(SyncStatus.syncing.isCompleted, false);
      expect(SyncStatus.completed.isCompleted, true);
      expect(SyncStatus.failed.isCompleted, false);
    });

    test('isFailed returns correct value', () {
      expect(SyncStatus.pending.isFailed, false);
      expect(SyncStatus.syncing.isFailed, false);
      expect(SyncStatus.completed.isFailed, false);
      expect(SyncStatus.failed.isFailed, true);
    });
  });

  group('SyncEntityType', () {
    test('has correct values', () {
      expect(SyncEntityType.organization.value, 'organization');
      expect(SyncEntityType.site.value, 'site');
      expect(SyncEntityType.unit.value, 'unit');
      expect(SyncEntityType.activity.value, 'activity');
      expect(SyncEntityType.notification.value, 'notification');
    });

    test('has correct labels', () {
      expect(SyncEntityType.organization.label, 'Organizasyon');
      expect(SyncEntityType.site.label, 'Saha');
      expect(SyncEntityType.unit.label, 'Alan');
      expect(SyncEntityType.activity.label, 'Aktivite');
      expect(SyncEntityType.notification.label, 'Bildirim');
    });

    test('fromValue returns correct type', () {
      expect(SyncEntityType.fromValue('organization'), SyncEntityType.organization);
      expect(SyncEntityType.fromValue('site'), SyncEntityType.site);
      expect(SyncEntityType.fromValue('unit'), SyncEntityType.unit);
      expect(SyncEntityType.fromValue('activity'), SyncEntityType.activity);
      expect(SyncEntityType.fromValue('notification'), SyncEntityType.notification);
      expect(SyncEntityType.fromValue('invalid'), SyncEntityType.organization);
    });
  });

  group('PendingOperation', () {
    test('creates correctly', () {
      final operation = PendingOperation(
        id: 'op-123',
        entityType: SyncEntityType.unit,
        entityId: 'unit-123',
        operationType: SyncOperationType.create,
        data: {'name': 'Test Unit'},
        status: SyncStatus.pending,
        createdAt: DateTime.now(),
        retryCount: 0,
      );

      expect(operation.id, 'op-123');
      expect(operation.entityType, SyncEntityType.unit);
      expect(operation.entityId, 'unit-123');
      expect(operation.operationType, SyncOperationType.create);
      expect(operation.status, SyncStatus.pending);
      expect(operation.retryCount, 0);
    });

    test('fromJson parses correctly', () {
      final json = {
        'id': 'op-123',
        'entityType': 'unit',
        'entityId': 'unit-123',
        'operationType': 'create',
        'data': {'name': 'Test Unit'},
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
        'retryCount': 0,
      };

      final operation = PendingOperation.fromJson(json);

      expect(operation.id, 'op-123');
      expect(operation.entityType, SyncEntityType.unit);
      expect(operation.entityId, 'unit-123');
      expect(operation.operationType, SyncOperationType.create);
      expect(operation.status, SyncStatus.pending);
    });

    test('toJson serializes correctly', () {
      final operation = PendingOperation(
        id: 'op-123',
        entityType: SyncEntityType.site,
        entityId: 'site-123',
        operationType: SyncOperationType.update,
        data: {'name': 'Updated Site'},
        status: SyncStatus.pending,
        createdAt: DateTime(2024, 1, 15),
        retryCount: 0,
      );

      final json = operation.toJson();

      expect(json['id'], 'op-123');
      expect(json['entityType'], 'site');
      expect(json['entityId'], 'site-123');
      expect(json['operationType'], 'update');
      expect(json['status'], 'pending');
    });

    test('copyWith creates correct copy', () {
      final operation = PendingOperation(
        id: 'op-123',
        entityType: SyncEntityType.unit,
        entityId: 'unit-123',
        operationType: SyncOperationType.create,
        data: {},
        status: SyncStatus.pending,
        createdAt: DateTime.now(),
        retryCount: 0,
      );

      final copy = operation.copyWith(
        status: SyncStatus.syncing,
        retryCount: 1,
      );

      expect(copy.id, 'op-123');
      expect(copy.status, SyncStatus.syncing);
      expect(copy.retryCount, 1);
    });

    test('canRetry returns correct value', () {
      final operationWithLowRetry = PendingOperation(
        id: 'op-1',
        entityType: SyncEntityType.unit,
        entityId: 'unit-123',
        operationType: SyncOperationType.create,
        data: {},
        status: SyncStatus.failed,
        createdAt: DateTime.now(),
        retryCount: 2,
      );
      expect(operationWithLowRetry.canRetry, true);

      final operationWithHighRetry = PendingOperation(
        id: 'op-2',
        entityType: SyncEntityType.unit,
        entityId: 'unit-123',
        operationType: SyncOperationType.create,
        data: {},
        status: SyncStatus.failed,
        createdAt: DateTime.now(),
        retryCount: 5,
      );
      expect(operationWithHighRetry.canRetry, false);
    });

    test('isPending returns correct value', () {
      final pendingOp = PendingOperation(
        id: 'op-1',
        entityType: SyncEntityType.unit,
        entityId: 'unit-123',
        operationType: SyncOperationType.create,
        data: {},
        status: SyncStatus.pending,
        createdAt: DateTime.now(),
        retryCount: 0,
      );
      expect(pendingOp.isPending, true);

      final completedOp = PendingOperation(
        id: 'op-2',
        entityType: SyncEntityType.unit,
        entityId: 'unit-123',
        operationType: SyncOperationType.create,
        data: {},
        status: SyncStatus.completed,
        createdAt: DateTime.now(),
        retryCount: 0,
      );
      expect(completedOp.isPending, false);
    });
  });

  group('SyncState', () {
    test('creates correctly', () {
      final state = SyncState(
        isOnline: true,
        isSyncing: false,
        pendingCount: 5,
        lastSyncAt: DateTime.now(),
      );

      expect(state.isOnline, true);
      expect(state.isSyncing, false);
      expect(state.pendingCount, 5);
    });

    test('hasPending returns correct value', () {
      final stateWithPending = SyncState(
        isOnline: true,
        isSyncing: false,
        pendingCount: 5,
      );
      expect(stateWithPending.hasPending, true);

      final stateWithoutPending = SyncState(
        isOnline: true,
        isSyncing: false,
        pendingCount: 0,
      );
      expect(stateWithoutPending.hasPending, false);
    });

    test('canSync returns correct value', () {
      final canSyncState = SyncState(
        isOnline: true,
        isSyncing: false,
        pendingCount: 5,
      );
      expect(canSyncState.canSync, true);

      final offlineState = SyncState(
        isOnline: false,
        isSyncing: false,
        pendingCount: 5,
      );
      expect(offlineState.canSync, false);

      final syncingState = SyncState(
        isOnline: true,
        isSyncing: true,
        pendingCount: 5,
      );
      expect(syncingState.canSync, false);

      final noPendingState = SyncState(
        isOnline: true,
        isSyncing: false,
        pendingCount: 0,
      );
      expect(noPendingState.canSync, false);
    });

    test('copyWith creates correct copy', () {
      final state = SyncState(
        isOnline: true,
        isSyncing: false,
        pendingCount: 5,
      );

      final copy = state.copyWith(
        isSyncing: true,
        pendingCount: 3,
      );

      expect(copy.isOnline, true);
      expect(copy.isSyncing, true);
      expect(copy.pendingCount, 3);
    });

    test('initial factory creates correct state', () {
      final state = SyncState.initial();

      expect(state.isOnline, false);
      expect(state.isSyncing, false);
      expect(state.pendingCount, 0);
      expect(state.lastSyncAt, isNull);
    });

    test('equality works correctly', () {
      final state1 = SyncState(
        isOnline: true,
        isSyncing: false,
        pendingCount: 5,
      );
      final state2 = SyncState(
        isOnline: true,
        isSyncing: false,
        pendingCount: 5,
      );
      final state3 = SyncState(
        isOnline: false,
        isSyncing: false,
        pendingCount: 5,
      );

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });
  });

  group('SyncResult', () {
    test('success factory creates correct result', () {
      final result = SyncResult.success(syncedCount: 5);

      expect(result.isSuccess, true);
      expect(result.syncedCount, 5);
      expect(result.failedCount, 0);
      expect(result.error, isNull);
    });

    test('failure factory creates correct result', () {
      final result = SyncResult.failure(error: 'Network error', failedCount: 3);

      expect(result.isSuccess, false);
      expect(result.syncedCount, 0);
      expect(result.failedCount, 3);
      expect(result.error, 'Network error');
    });

    test('partial factory creates correct result', () {
      final result = SyncResult.partial(
        syncedCount: 7,
        failedCount: 3,
        error: 'Some operations failed',
      );

      expect(result.isSuccess, false);
      expect(result.syncedCount, 7);
      expect(result.failedCount, 3);
      expect(result.error, 'Some operations failed');
    });

    test('totalCount returns correct value', () {
      final result = SyncResult.partial(
        syncedCount: 7,
        failedCount: 3,
      );

      expect(result.totalCount, 10);
    });

    test('hasFailures returns correct value', () {
      final successResult = SyncResult.success(syncedCount: 5);
      expect(successResult.hasFailures, false);

      final failureResult = SyncResult.failure(error: 'Error', failedCount: 3);
      expect(failureResult.hasFailures, true);

      final partialResult = SyncResult.partial(syncedCount: 5, failedCount: 2);
      expect(partialResult.hasFailures, true);
    });
  });
}
