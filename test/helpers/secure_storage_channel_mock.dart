import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// flutter_secure_storage method-channel'ını in-memory bir map ile mock'lar.
///
/// Hive kutuları artık AES-256 şifreli açıldığından ([HiveEncryption]),
/// CacheManager/OfflineSyncService initialize() saf-Dart test ortamında
/// güvenli depoya (Keychain/Keystore) erişmeye çalışır. Bu mock o kanalı
/// bellekte karşılar. setUp içinde çağırın:
///
/// ```dart
/// mockFlutterSecureStorageChannel();
/// ```
Map<String, String> mockFlutterSecureStorageChannel() {
  final store = <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async {
      final args = (call.arguments as Map?)?.cast<String, dynamic>();
      final key = args?['key'] as String?;
      switch (call.method) {
        case 'read':
          return store[key];
        case 'write':
          store[key!] = args!['value'] as String;
          return null;
        case 'delete':
          store.remove(key);
          return null;
        case 'containsKey':
          return store.containsKey(key);
        case 'readAll':
          return Map<String, String>.from(store);
        case 'deleteAll':
          store.clear();
          return null;
      }
      return null;
    },
  );
  return store;
}
