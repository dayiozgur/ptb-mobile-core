import 'dart:async';
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../utils/logger.dart';
import 'connectivity_service.dart';

/// Bekleyen işlem türü
enum PendingOperationType {
  create('CREATE'),
  update('UPDATE'),
  delete('DELETE');

  final String value;
  const PendingOperationType(this.value);

  static PendingOperationType? fromString(String? value) {
    if (value == null) return null;
    return PendingOperationType.values.cast<PendingOperationType?>().firstWhere(
          (e) => e?.value == value,
          orElse: () => null,
        );
  }
}

/// Bekleyen işlem durumu
enum PendingOperationStatus {
  pending('PENDING'),
  processing('PROCESSING'),
  completed('COMPLETED'),
  failed('FAILED');

  final String value;
  const PendingOperationStatus(this.value);

  static PendingOperationStatus? fromString(String? value) {
    if (value == null) return null;
    return PendingOperationStatus.values.cast<PendingOperationStatus?>().firstWhere(
          (e) => e?.value == value,
          orElse: () => null,
        );
  }
}

/// Bekleyen işlem modeli
class PendingOperation {
  final String id;
  final PendingOperationType type;
  final String entityType;
  final String? entityId;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;
  PendingOperationStatus status;

  PendingOperation({
    required this.id,
    required this.type,
    required this.entityType,
    this.entityId,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
    this.status = PendingOperationStatus.pending,
  });

  factory PendingOperation.fromJson(Map<String, dynamic> json) {
    return PendingOperation(
      id: json['id'] as String,
      type: PendingOperationType.fromString(json['type'] as String?) ??
          PendingOperationType.create,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String?,
      data: json['data'] as Map<String, dynamic>? ?? {},
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      retryCount: json['retry_count'] as int? ?? 0,
      lastError: json['last_error'] as String?,
      status: PendingOperationStatus.fromString(json['status'] as String?) ??
          PendingOperationStatus.pending,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.value,
        'entity_type': entityType,
        'entity_id': entityId,
        'data': data,
        'created_at': createdAt.toIso8601String(),
        'retry_count': retryCount,
        'last_error': lastError,
        'status': status.value,
      };

  PendingOperation copyWith({
    String? id,
    PendingOperationType? type,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    int? retryCount,
    String? lastError,
    PendingOperationStatus? status,
  }) {
    return PendingOperation(
      id: id ?? this.id,
      type: type ?? this.type,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      status: status ?? this.status,
    );
  }
}

/// İşlem handler tipi
typedef OperationHandler = Future<bool> Function(PendingOperation operation);

/// Offline senkronizasyon servisi
///
/// Offline durumda yapılan işlemleri kuyruğa alır ve
/// online olunca senkronize eder.
///
/// Örnek kullanım:
/// ```dart
/// final syncService = OfflineSyncService(
///   connectivityService: connectivityService,
/// );
/// await syncService.initialize();
///
/// // Handler kaydet
/// syncService.registerHandler('unit', (op) async {
///   if (op.type == PendingOperationType.create) {
///     await unitService.createUnit(...);
///   }
///   return true;
/// });
///
/// // İşlem ekle
/// await syncService.addOperation(
///   type: PendingOperationType.create,
///   entityType: 'unit',
///   data: {'name': 'Test Unit'},
/// );
/// ```
class OfflineSyncService {
  final ConnectivityService _connectivityService;

  static const String _boxName = 'ptb_pending_operations';
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 5);

  Box<String>? _box;
  bool _isInitialized = false;
  bool _isSyncing = false;
  StreamSubscription? _connectivitySubscription;

  // Handler'lar (entity type -> handler)
  final Map<String, OperationHandler> _handlers = {};

  // Stream controllers
  final _syncProgressController = StreamController<SyncProgress>.broadcast();
  final _operationAddedController = StreamController<PendingOperation>.broadcast();
  final _operationCompletedController = StreamController<PendingOperation>.broadcast();
  final _operationFailedController = StreamController<PendingOperation>.broadcast();

  OfflineSyncService({
    required ConnectivityService connectivityService,
  }) : _connectivityService = connectivityService;

  // ============================================
  // GETTERS
  // ============================================

  /// Başlatıldı mı?
  bool get isInitialized => _isInitialized;

  /// Senkronizasyon devam ediyor mu?
  bool get isSyncing => _isSyncing;

  /// Bekleyen işlem sayısı
  Future<int> get pendingCount async {
    final operations = await getPendingOperations();
    return operations.length;
  }

  /// Senkronizasyon ilerleme stream'i
  Stream<SyncProgress> get syncProgressStream => _syncProgressController.stream;

  /// İşlem eklendi stream'i
  Stream<PendingOperation> get operationAddedStream =>
      _operationAddedController.stream;

  /// İşlem tamamlandı stream'i
  Stream<PendingOperation> get operationCompletedStream =>
      _operationCompletedController.stream;

  /// İşlem başarısız stream'i
  Stream<PendingOperation> get operationFailedStream =>
      _operationFailedController.stream;

  // ============================================
  // INITIALIZATION
  // ============================================

  /// Servisi başlat
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _box = await Hive.openBox<String>(_boxName);

      // Bağlantı değişikliklerini dinle
      _connectivitySubscription =
          _connectivityService.statusStream.listen((info) {
        if (info.isOnline && !_isSyncing) {
          Logger.info('Online olundu, senkronizasyon başlatılıyor...');
          syncPendingOperations();
        }
      });

      // Online ise bekleyen işlemleri senkronize et
      if (_connectivityService.isOnline) {
        syncPendingOperations();
      }

      _isInitialized = true;
      Logger.info('OfflineSyncService initialized');
    } catch (e) {
      Logger.error('Failed to initialize OfflineSyncService', e);
    }
  }

  // ============================================
  // HANDLER REGISTRATION
  // ============================================

  /// Entity türü için handler kaydet
  void registerHandler(String entityType, OperationHandler handler) {
    _handlers[entityType] = handler;
    Logger.debug('Handler registered for: $entityType');
  }

  /// Handler kaldır
  void unregisterHandler(String entityType) {
    _handlers.remove(entityType);
    Logger.debug('Handler unregistered for: $entityType');
  }

  // ============================================
  // OPERATIONS MANAGEMENT
  // ============================================

  /// Bekleyen işlem ekle
  Future<PendingOperation> addOperation({
    required PendingOperationType type,
    required String entityType,
    String? entityId,
    required Map<String, dynamic> data,
  }) async {
    _ensureInitialized();

    final operation = PendingOperation(
      id: _generateId(),
      type: type,
      entityType: entityType,
      entityId: entityId,
      data: data,
      createdAt: DateTime.now(),
    );

    await _saveOperation(operation);
    _operationAddedController.add(operation);

    Logger.debug(
        'Operation added: ${operation.type.value} ${operation.entityType}');

    // Online ise hemen senkronize et
    if (_connectivityService.isOnline && !_isSyncing) {
      syncPendingOperations();
    }

    return operation;
  }

  /// Bekleyen işlemleri getir
  Future<List<PendingOperation>> getPendingOperations() async {
    _ensureInitialized();

    final operations = <PendingOperation>[];
    for (final key in _box!.keys) {
      final json = _box!.get(key);
      if (json != null) {
        try {
          final data = jsonDecode(json) as Map<String, dynamic>;
          final operation = PendingOperation.fromJson(data);
          if (operation.status == PendingOperationStatus.pending ||
              operation.status == PendingOperationStatus.failed) {
            operations.add(operation);
          }
        } catch (e) {
          Logger.warning('Failed to parse operation: $key', e);
        }
      }
    }

    // Oluşturulma tarihine göre sırala
    operations.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return operations;
  }

  /// İşlem sil
  Future<void> removeOperation(String operationId) async {
    _ensureInitialized();
    await _box!.delete(operationId);
    Logger.debug('Operation removed: $operationId');
  }

  /// Tüm bekleyen işlemleri temizle
  Future<void> clearAllOperations() async {
    _ensureInitialized();
    await _box!.clear();
    Logger.info('All pending operations cleared');
  }

  // ============================================
  // SYNCHRONIZATION
  // ============================================

  /// Bekleyen işlemleri senkronize et
  Future<SyncResult> syncPendingOperations() async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        message: 'Senkronizasyon zaten devam ediyor',
        processed: 0,
        failed: 0,
      );
    }

    if (!_connectivityService.isOnline) {
      return SyncResult(
        success: false,
        message: 'Offline durumda',
        processed: 0,
        failed: 0,
      );
    }

    _isSyncing = true;
    int processed = 0;
    int failed = 0;

    try {
      final operations = await getPendingOperations();

      if (operations.isEmpty) {
        return SyncResult(
          success: true,
          message: 'Bekleyen işlem yok',
          processed: 0,
          failed: 0,
        );
      }

      Logger.info('Syncing ${operations.length} pending operations...');

      for (int i = 0; i < operations.length; i++) {
        final operation = operations[i];

        // İlerleme bildir
        _syncProgressController.add(SyncProgress(
          current: i + 1,
          total: operations.length,
          currentOperation: operation,
        ));

        final success = await _processOperation(operation);

        if (success) {
          await removeOperation(operation.id);
          _operationCompletedController.add(operation);
          processed++;
        } else {
          failed++;
        }
      }

      Logger.info(
          'Sync completed: $processed processed, $failed failed');

      return SyncResult(
        success: failed == 0,
        message: failed == 0
            ? 'Senkronizasyon tamamlandı'
            : '$failed işlem başarısız oldu',
        processed: processed,
        failed: failed,
      );
    } catch (e) {
      Logger.error('Sync failed', e);
      return SyncResult(
        success: false,
        message: 'Senkronizasyon hatası: $e',
        processed: processed,
        failed: failed,
      );
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _processOperation(PendingOperation operation) async {
    final handler = _handlers[operation.entityType];

    if (handler == null) {
      Logger.warning('No handler for entity type: ${operation.entityType}');
      return false;
    }

    // İşlemi processing olarak işaretle
    operation.status = PendingOperationStatus.processing;
    await _saveOperation(operation);

    try {
      final success = await handler(operation);

      if (success) {
        operation.status = PendingOperationStatus.completed;
        return true;
      } else {
        throw Exception('Handler returned false');
      }
    } catch (e) {
      Logger.error('Operation failed: ${operation.id}', e);

      // Retry sayısını artır
      final updatedOperation = operation.copyWith(
        retryCount: operation.retryCount + 1,
        lastError: e.toString(),
        status: operation.retryCount + 1 >= _maxRetries
            ? PendingOperationStatus.failed
            : PendingOperationStatus.pending,
      );

      await _saveOperation(updatedOperation);
      _operationFailedController.add(updatedOperation);

      return false;
    }
  }

  // ============================================
  // HELPERS
  // ============================================

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('OfflineSyncService henüz başlatılmadı');
    }
  }

  Future<void> _saveOperation(PendingOperation operation) async {
    final json = jsonEncode(operation.toJson());
    await _box!.put(operation.id, json);
  }

  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_box!.length}';
  }

  // ============================================
  // CLEANUP
  // ============================================

  /// Servisi durdur
  Future<void> dispose() async {
    _connectivitySubscription?.cancel();
    _syncProgressController.close();
    _operationAddedController.close();
    _operationCompletedController.close();
    _operationFailedController.close();
    await _box?.close();
    _isInitialized = false;
    Logger.debug('OfflineSyncService disposed');
  }
}

/// Senkronizasyon ilerleme bilgisi
class SyncProgress {
  final int current;
  final int total;
  final PendingOperation currentOperation;

  SyncProgress({
    required this.current,
    required this.total,
    required this.currentOperation,
  });

  double get percentage => total > 0 ? current / total : 0;

  @override
  String toString() => 'SyncProgress($current/$total)';
}

/// Senkronizasyon sonucu
class SyncResult {
  final bool success;
  final String message;
  final int processed;
  final int failed;

  SyncResult({
    required this.success,
    required this.message,
    required this.processed,
    required this.failed,
  });

  @override
  String toString() =>
      'SyncResult(success: $success, processed: $processed, failed: $failed)';
}
