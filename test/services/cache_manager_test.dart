import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

void main() {
  // API/behavior drift: CacheManager is now Hive-backed and requires an
  // explicit initialize() before use (it no longer lazily self-initializes).
  // We mock path_provider so Hive.initFlutter() can resolve a real temp
  // directory in the pure-Dart test environment, then close Hive in tearDown.
  late CacheManager cacheManager;
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('ptb_cache_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => tempDir.path,
    );
    cacheManager = CacheManager();
    await cacheManager.initialize();
  });

  tearDown(() async {
    await cacheManager.clear();
    await Hive.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('CacheManager - Basic Operations', () {
    test('set and get string value', () async {
      await cacheManager.set('test_key', 'test_value');
      final result = await cacheManager.get('test_key');

      expect(result, 'test_value');
    });

    test('set and get map value', () async {
      final data = {'name': 'Test', 'value': 123};
      await cacheManager.set('map_key', data);
      final result = await cacheManager.get('map_key');

      expect(result, isA<Map>());
      expect(result['name'], 'Test');
      expect(result['value'], 123);
    });

    test('get returns null for non-existent key', () async {
      final result = await cacheManager.get('non_existent');
      expect(result, isNull);
    });

    test('has returns true for existing key', () async {
      await cacheManager.set('existing_key', 'value');

      expect(await cacheManager.has('existing_key'), true);
      expect(await cacheManager.has('non_existent_key'), false);
    });

    test('delete removes key', () async {
      await cacheManager.set('delete_test', 'value');
      expect(await cacheManager.has('delete_test'), true);

      await cacheManager.delete('delete_test');
      expect(await cacheManager.has('delete_test'), false);
    });

    test('clear removes all keys', () async {
      await cacheManager.set('key1', 'value1');
      await cacheManager.set('key2', 'value2');
      await cacheManager.set('key3', 'value3');

      await cacheManager.clear();

      expect(await cacheManager.has('key1'), false);
      expect(await cacheManager.has('key2'), false);
      expect(await cacheManager.has('key3'), false);
    });
  });

  group('CacheManager - Typed Operations', () {
    test('set + getTyped works with model', () async {
      // API drift: `setTyped` was removed; store via `set(key, toJson())` and
      // read back with `getTyped`. `Tenant.slug`/`ownerId` were also removed.
      final tenant = Tenant(
        id: 'tenant-123',
        name: 'Test Tenant',
      );

      await cacheManager.set('tenant', tenant.toJson());

      final result = await cacheManager.getTyped<Tenant>(
        key: 'tenant',
        fromJson: Tenant.fromJson,
      );

      expect(result, isNotNull);
      expect(result!.id, 'tenant-123');
      expect(result.name, 'Test Tenant');
    });

    test('getTyped returns null for non-existent key', () async {
      final result = await cacheManager.getTyped<Tenant>(
        key: 'non_existent',
        fromJson: Tenant.fromJson,
      );

      expect(result, isNull);
    });
  });

  group('CacheManager - List Operations', () {
    test('setList and getList works correctly', () async {
      final organizations = [
        Organization(
          id: 'org-1',
          name: 'Org 1',
          tenantId: 'tenant-1',
        ),
        Organization(
          id: 'org-2',
          name: 'Org 2',
          tenantId: 'tenant-1',
        ),
      ];

      await cacheManager.setList<Organization>(
        key: 'organizations',
        value: organizations,
        toJson: (o) => o.toJson(),
      );

      final result = await cacheManager.getList<Organization>(
        key: 'organizations',
        fromJson: Organization.fromJson,
      );

      expect(result, isNotNull);
      expect(result!.length, 2);
      expect(result[0].name, 'Org 1');
      expect(result[1].name, 'Org 2');
    });

    test('getList returns null for non-existent key', () async {
      final result = await cacheManager.getList<Organization>(
        key: 'non_existent',
        fromJson: Organization.fromJson,
      );

      expect(result, isNull);
    });
  });

  group('CacheManager - TTL', () {
    test('expired cache returns null', () async {
      await cacheManager.set(
        'short_lived',
        'value',
        ttl: const Duration(milliseconds: 50),
      );

      expect(await cacheManager.get('short_lived'), 'value');

      // Wait for expiration
      await Future.delayed(const Duration(milliseconds: 100));

      expect(await cacheManager.get('short_lived'), isNull);
    });

    test('non-expired cache returns value', () async {
      await cacheManager.set(
        'long_lived',
        'value',
        ttl: const Duration(hours: 1),
      );

      await Future.delayed(const Duration(milliseconds: 50));

      expect(await cacheManager.get('long_lived'), 'value');
    });
  });

  group('CacheManager - Error Handling', () {
    test('getTyped handles invalid JSON gracefully', () async {
      // Set invalid data directly (a plain string, not a JSON object)
      await cacheManager.set('invalid', 'not a json');

      final result = await cacheManager.getTyped<Tenant>(
        key: 'invalid',
        fromJson: Tenant.fromJson,
      );

      // Should return null or handle gracefully
      expect(result, isNull);
    });
  });
}
