import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/secure_storage_channel_mock.dart';

class _MockConnectivity extends Mock implements ConnectivityService {}

/// WP-A: lisans reddi offline kuyrukta KALICI hata — retry harcanmaz, dead-letter
/// olmaz, kuyruk duraklar, erişim dönünce devam eder.
void main() {
  late Directory tempDir;
  late _MockConnectivity connectivity;
  late OfflineSyncService sync;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('ptb_offline_ent_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tempDir.path,
    );
    mockFlutterSecureStorageChannel();
    connectivity = _MockConnectivity();
    // initialize() sırasında otomatik sync tetiklenmesin diye offline başla.
    when(() => connectivity.isOnline).thenReturn(false);
    when(() => connectivity.statusStream)
        .thenAnswer((_) => const Stream<ConnectivityInfo>.empty());
    sync = OfflineSyncService(connectivityService: connectivity);
    await sync.initialize();
    await sync.clearAllOperations();
  });

  tearDown(() async {
    await sync.dispose();
    await Hive.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  Future<void> enqueueTwo() async {
    await sync.enqueueRpc(function: 'fn_a', params: {'x': 1});
    await sync.enqueueRpc(function: 'fn_b', params: {'x': 2});
  }

  test('25006 → kuyruk duraklar, retry artmaz, işlemler kuyrukta kalır',
      () async {
    await enqueueTwo();
    var calls = 0;
    sync.registerDefaultHandler((op) async {
      calls++;
      throw const PostgrestException(
          message: 'cannot execute INSERT in a read-only transaction',
          code: '25006');
    });
    final signals = <LicenseAccessState>[];
    final sub = EntitlementSignals.stream.listen(signals.add);
    when(() => connectivity.isOnline).thenReturn(true);

    final result = await sync.syncPendingOperations();

    expect(result.pausedForEntitlement, isTrue);
    expect(result.success, isFalse);
    expect(calls, 1, reason: 'ilk red sonrası kalan işlemler denenmez');
    expect(sync.isPausedForEntitlement, isTrue);
    expect(sync.entitlementPause, LicenseAccessState.readOnly);

    final pending = await sync.getPendingOperations();
    expect(pending.length, 2);
    expect(pending.every((op) => op.retryCount == 0), isTrue);
    expect(pending.every((op) => op.status == PendingOperationStatus.pending),
        isTrue);
    expect(await sync.getDeadLetteredOperations(), isEmpty);

    await Future<void>.delayed(Duration.zero);
    expect(signals, contains(LicenseAccessState.readOnly));
    await sub.cancel();

    // Duraklatılmışken yeni sync denemesi handler'a hiç gitmez.
    final again = await sync.syncPendingOperations();
    expect(again.pausedForEntitlement, isTrue);
    expect(calls, 1);
  });

  test('PTB402 (locked) → entitlementPause locked', () async {
    await sync.enqueueRpc(function: 'fn_a');
    sync.registerDefaultHandler((op) async {
      throw const PostgrestException(
          message: 'entitlement_locked', code: 'PTB402');
    });
    when(() => connectivity.isOnline).thenReturn(true);
    await sync.syncPendingOperations();
    expect(sync.entitlementPause, LicenseAccessState.locked);
    expect((await sync.getPendingOperations()).single.retryCount, 0);
  });

  test('resumeAfterEntitlement → kuyruk devam eder ve boşalır', () async {
    await enqueueTwo();
    var blocked = true;
    sync.registerDefaultHandler((op) async {
      if (blocked) throw const FunctionException(status: 402);
      return true;
    });
    when(() => connectivity.isOnline).thenReturn(true);
    await sync.syncPendingOperations();
    expect(sync.isPausedForEntitlement, isTrue);

    blocked = false;
    final completed = <String>[];
    final sub =
        sync.operationCompletedStream.listen((op) => completed.add(op.id));
    sync.resumeAfterEntitlement();
    expect(sync.isPausedForEntitlement, isFalse);
    // resume içindeki sync'in bitmesini bekle.
    for (var i = 0; i < 50 && completed.length < 2; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(completed.length, 2);
    expect(await sync.getPendingOperations(), isEmpty);
    await sub.cancel();
  });

  test('lisans dışı hata eski davranışı korur (retry artar)', () async {
    await sync.enqueueRpc(function: 'fn_a');
    sync.registerDefaultHandler((op) async => throw Exception('timeout'));
    when(() => connectivity.isOnline).thenReturn(true);
    final result = await sync.syncPendingOperations();
    expect(result.pausedForEntitlement, isFalse);
    expect(sync.isPausedForEntitlement, isFalse);
    expect((await sync.getPendingOperations()).single.retryCount, 1);
  });
}
