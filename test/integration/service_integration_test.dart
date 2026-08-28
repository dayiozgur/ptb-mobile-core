import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Mock classes for integration testing
class MockSecureStorage extends Mock implements SecureStorage {}

class MockCacheManager extends Mock implements CacheManager {}

/// Integration tests for service interactions
void main() {
  group('Service Integration Tests', () {
    late MockSecureStorage mockStorage;
    late MockCacheManager mockCache;

    setUp(() {
      mockStorage = MockSecureStorage();
      mockCache = MockCacheManager();
    });

    group('Localization + Theme Integration', () {
      late LocalizationService localizationService;
      late ThemeService themeService;

      setUp(() async {
        when(() => mockStorage.read(any())).thenAnswer((_) async => null);
        when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')))
            .thenAnswer((_) async {});

        localizationService = LocalizationService(storage: mockStorage);
        themeService = ThemeService(storage: mockStorage);

        await localizationService.initialize();
        await themeService.initialize();
      });

      tearDown(() {
        localizationService.dispose();
        themeService.dispose();
      });

      test('services initialize independently', () async {
        expect(localizationService.isInitialized, true);
        expect(themeService.isInitialized, true);
      });

      test('settings persist independently', () async {
        await localizationService.setLocale(AppLocale.english);
        await themeService.setThemeMode(AppThemeMode.dark);

        // Verify storage was called for both
        verify(() => mockStorage.write(
              key: any(named: 'key'),
              value: any(named: 'value'),
            )).called(2);
      });

      test('streams emit changes independently', () async {
        final localeChanges = <AppLocale>[];
        final themeChanges = <AppThemeMode>[];

        final localeSub = localizationService.localeStream.listen(localeChanges.add);
        // API drift: themeModeStream -> settingsStream (emits ThemeSettings).
        final themeSub =
            themeService.settingsStream.listen((s) => themeChanges.add(s.mode));

        await localizationService.setLocale(AppLocale.german);
        await themeService.setThemeMode(AppThemeMode.light);

        await Future.delayed(const Duration(milliseconds: 50));

        expect(localeChanges, [AppLocale.german]);
        expect(themeChanges, [AppThemeMode.light]);

        await localeSub.cancel();
        await themeSub.cancel();
      });
    });

    group('Cache + Service Integration', () {
      // API/behavior drift: CacheManager now requires an explicit initialize()
      // (Hive-backed) before use; it no longer lazily self-initializes. We mock
      // path_provider so Hive.initFlutter() can resolve a real temp directory
      // in the pure-Dart test environment.
      late CacheManager cache;
      late Directory tempDir;

      setUp(() async {
        TestWidgetsFlutterBinding.ensureInitialized();
        tempDir = await Directory.systemTemp.createTemp('ptb_cache_it');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (methodCall) async => tempDir.path,
        );
        cache = CacheManager();
        await cache.initialize();
      });

      tearDown(() async {
        await cache.clear();
        await Hive.close();
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });

      test('cache stores and retrieves organization correctly', () async {
        final org = Organization(
          id: 'org-123',
          name: 'Test Organization',
          tenantId: 'tenant-123',
        );

        // API drift: `setTyped` was removed; store via `set(key, toJson())`.
        await cache.set('org_org-123', org.toJson());

        final retrieved = await cache.getTyped<Organization>(
          key: 'org_org-123',
          fromJson: Organization.fromJson,
        );

        expect(retrieved, isNotNull);
        expect(retrieved!.id, 'org-123');
        expect(retrieved.name, 'Test Organization');
        expect(retrieved.tenantId, 'tenant-123');
      });

      test('cache stores and retrieves site list correctly', () async {
        // API drift: Site now requires `markerId`.
        final sites = [
          Site(id: 'site-1', name: 'Site 1', organizationId: 'org-123', markerId: 'm-1'),
          Site(id: 'site-2', name: 'Site 2', organizationId: 'org-123', markerId: 'm-2'),
          Site(id: 'site-3', name: 'Site 3', organizationId: 'org-123', markerId: 'm-3'),
        ];

        await cache.setList<Site>(
          key: 'sites_org-123',
          value: sites,
          toJson: (s) => s.toJson(),
        );

        final retrieved = await cache.getList<Site>(
          key: 'sites_org-123',
          fromJson: Site.fromJson,
        );

        expect(retrieved, isNotNull);
        expect(retrieved!.length, 3);
        expect(retrieved[0].name, 'Site 1');
        expect(retrieved[1].name, 'Site 2');
        expect(retrieved[2].name, 'Site 3');
      });

      test('cache TTL expires data correctly', () async {
        await cache.set(
          'temp_data',
          {'value': 'temporary'},
          ttl: const Duration(milliseconds: 50),
        );

        // Should exist immediately
        expect(await cache.get('temp_data'), isNotNull);

        // Wait for expiration
        await Future.delayed(const Duration(milliseconds: 100));

        // Should be expired
        expect(await cache.get('temp_data'), isNull);
      });
    });

    group('Model Serialization Integration', () {
      test('full notification round-trip serialization', () {
        final original = AppNotification(
          id: 'notif-123',
          rowId: 1,
          active: true,
          title: 'Test Notification',
          description: 'This is a test',
          type: NotificationType.alert,
          priority: NotificationPriority.high,
          entityType: NotificationEntityType.unit,
          entityId: 'unit-123',
          dateTime: DateTime(2024, 1, 15, 10, 30),
          isRead: false,
          sent: true,
          platformId: 'platform-123',
          profileId: 'profile-123',
          createdAt: DateTime(2024, 1, 15, 10, 0),
          profile: NotificationProfile(
            id: 'profile-123',
            fullName: 'John Doe',
            avatarUrl: 'https://example.com/avatar.png',
          ),
        );

        final json = original.toJson();
        final restored = AppNotification.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.title, original.title);
        expect(restored.description, original.description);
        expect(restored.type, original.type);
        expect(restored.priority.value, original.priority.value);
        expect(restored.entityType, original.entityType);
        expect(restored.entityId, original.entityId);
        expect(restored.isRead, original.isRead);
        expect(restored.sent, original.sent);
      });

      test('full unit tree round-trip', () {
        final units = [
          Unit(
            id: 'floor-1',
            name: 'Floor 1',
            siteId: 'site-123',
            unitType: UnitType(
              id: 'type-floor',
              name: 'Floor',
              category: UnitCategory.floor,
            ),
          ),
          Unit(
            id: 'room-1',
            name: 'Room 101',
            parentUnitId: 'floor-1',
            siteId: 'site-123',
            unitType: UnitType(
              id: 'type-room',
              name: 'Room',
              category: UnitCategory.room,
            ),
          ),
          Unit(
            id: 'room-2',
            name: 'Room 102',
            parentUnitId: 'floor-1',
            siteId: 'site-123',
            unitType: UnitType(
              id: 'type-room',
              name: 'Room',
              category: UnitCategory.room,
            ),
          ),
        ];

        final tree = UnitTree.fromList(units);

        expect(tree.rootUnits.length, 1);
        expect(tree.rootUnits[0].name, 'Floor 1');
        expect(tree.rootUnits[0].children.length, 2);
        expect(tree.totalCount, 3);

        final room = tree.findById('room-1');
        expect(room, isNotNull);
        expect(room!.name, 'Room 101');
      });

      test('search response serialization', () {
        final response = SearchResponse(
          results: [
            const SearchResult(
              id: 'org-1',
              entityType: SearchEntityType.organization,
              title: 'Test Org',
              subtitle: 'Organization',
              score: 0.95,
            ),
            const SearchResult(
              id: 'site-1',
              entityType: SearchEntityType.site,
              title: 'Test Site',
              subtitle: 'Site',
              score: 0.85,
            ),
          ],
          totalCount: 100,
          // API drift: SearchQuery takes a single `entityType` (was
          // `entityTypes` list); SearchResponse now requires `duration` and
          // `searchedAt`.
          query: const SearchQuery(
            text: 'test',
            entityType: SearchEntityType.all,
          ),
          hasMore: true,
          duration: const Duration(milliseconds: 12),
          searchedAt: DateTime(2024, 1, 15, 10, 0),
        );

        final json = response.toJson();
        final restored = SearchResponse.fromJson(json);

        expect(restored.results.length, 2);
        expect(restored.totalCount, 100);
        expect(restored.hasMore, true);
        expect(restored.query.text, 'test');
        expect(restored.results[0].entityType, SearchEntityType.organization);
        expect(restored.results[1].entityType, SearchEntityType.site);
      });
    });

    group('Sync State Integration', () {
      // API drift: the old typed Sync* enums (SyncEntityType, SyncOperationType,
      // SyncStatus) were replaced. PendingOperation now uses a String
      // `entityType`, a `type` of PendingOperationType and a `status` of
      // PendingOperationStatus. The `.isPending`/`.canRetry` convenience getters
      // were removed, so this test now exercises status transitions and
      // JSON round-trip on the current model instead.
      test('pending operations workflow', () {
        var operation = PendingOperation(
          id: 'op-123',
          entityType: 'unit',
          entityId: 'unit-123',
          type: PendingOperationType.create,
          data: {'name': 'New Unit'},
          status: PendingOperationStatus.pending,
          createdAt: DateTime.now(),
          retryCount: 0,
        );

        expect(operation.status, PendingOperationStatus.pending);
        expect(operation.type, PendingOperationType.create);

        // Start processing
        operation = operation.copyWith(status: PendingOperationStatus.processing);
        expect(operation.status, PendingOperationStatus.processing);

        // Complete
        operation = operation.copyWith(status: PendingOperationStatus.completed);
        expect(operation.status, PendingOperationStatus.completed);

        // Round-trip serialization preserves fields
        final restored = PendingOperation.fromJson(operation.toJson());
        expect(restored.id, 'op-123');
        expect(restored.entityType, 'unit');
        expect(restored.type, PendingOperationType.create);
        expect(restored.status, PendingOperationStatus.completed);
      });

      // Removed: the `SyncState` class (initial/copyWith/canSync/hasPending) was
      // removed from the lib entirely, so the "sync state transitions" sub-test
      // no longer has an equivalent to target.

      // API drift: SyncResult no longer has success()/failure()/partial()
      // factories or isSuccess/hasFailures/totalCount getters. It now exposes
      // `success`, `message`, `processed`, `failed`.
      test('sync result scenarios', () {
        final success = SyncResult(
          success: true,
          message: 'All synced',
          processed: 10,
          failed: 0,
        );
        expect(success.success, true);
        expect(success.failed, 0);
        expect(success.processed, 10);

        final failure = SyncResult(
          success: false,
          message: 'Network error',
          processed: 0,
          failed: 10,
        );
        expect(failure.success, false);
        expect(failure.failed, 10);

        final partial = SyncResult(
          success: false,
          message: 'Some operations failed',
          processed: 7,
          failed: 3,
        );
        expect(partial.success, false);
        expect(partial.processed + partial.failed, 10);
      });
    });

    // API drift: the reporting models were reworked from computed-helper value
    // objects (totalValue / getMetric / completionRate / hasOverdue /
    // totalEntities / userActivityRate — all removed) into plain data
    // containers. DashboardMetric now takes id/title/value(String); MetricType's
    // domain-specific members (organizations/sites/units/users) were replaced by
    // count/sum/average/percentage/trend; DashboardSummary carries the counts
    // directly and requires `tenantId`; ActivityStats and EntityCountSummary
    // have different shapes. These tests now exercise construction and JSON
    // round-trip on the current models.
    group('Reporting Integration', () {
      test('dashboard summary aggregation', () {
        final summary = DashboardSummary(
          tenantId: 'tenant-123',
          metrics: [
            const DashboardMetric(
              id: 'm-org',
              title: 'Organizations',
              value: '5',
              type: MetricType.count,
              trend: TrendDirection.up,
              trendValue: 25.0,
            ),
            const DashboardMetric(
              id: 'm-site',
              title: 'Sites',
              value: '20',
              type: MetricType.count,
              trend: TrendDirection.stable,
              trendValue: 0.0,
            ),
          ],
          period: ReportPeriod.thisMonth,
          organizationCount: 5,
          siteCount: 20,
          unitCount: 100,
          activeUserCount: 50,
          generatedAt: DateTime(2024, 1, 15, 10, 0),
        );

        expect(summary.organizationCount, 5);
        expect(summary.siteCount, 20);
        expect(summary.metrics.length, 2);

        final restored = DashboardSummary.fromJson(summary.toJson());
        expect(restored.tenantId, 'tenant-123');
        expect(restored.unitCount, 100);
        expect(restored.activeUserCount, 50);
        expect(restored.metrics.first.trend, TrendDirection.up);
        expect(restored.metrics[1].trend, TrendDirection.stable);
      });

      test('activity stats calculation', () {
        final stats = ActivityStats(
          totalCount: 100,
          byType: const {'create': 60, 'update': 40},
          byEntity: const {'unit': 75, 'site': 25},
          timeSeries: const [],
          generatedAt: DateTime(2024, 1, 15, 10, 0),
        );

        expect(stats.totalCount, 100);
        expect(stats.byType['create'], 60);

        final restored = ActivityStats.fromJson(stats.toJson());
        expect(restored.totalCount, 100);
        expect(restored.byType['update'], 40);
        expect(restored.byEntity['unit'], 75);
      });

      test('entity count summary', () {
        final entitySummary = EntityCountSummary(
          total: 100,
          active: 85,
          inactive: 15,
          generatedAt: DateTime(2024, 1, 15, 10, 0),
        );

        expect(entitySummary.total, 100);
        expect(entitySummary.active + entitySummary.inactive, 100);

        final restored = EntityCountSummary.fromJson(entitySummary.toJson());
        expect(restored.total, 100);
        expect(restored.active, 85);
        expect(restored.inactive, 15);
      });
    });

    group('Date Range Integration', () {
      test('period date ranges are correct', () {
        final today = ReportPeriod.today.getDateRange();
        final now = DateTime.now();
        expect(today.start.day, now.day);
        expect(today.start.hour, 0);
        expect(today.start.minute, 0);

        final thisMonth = ReportPeriod.thisMonth.getDateRange();
        expect(thisMonth.start.day, 1);
        expect(thisMonth.start.month, now.month);

        final thisYear = ReportPeriod.thisYear.getDateRange();
        expect(thisYear.start.month, 1);
        expect(thisYear.start.day, 1);
        expect(thisYear.start.year, now.year);
      });

      test('date range operations', () {
        final january = DateRange(
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 1, 31),
        );
        final q1 = DateRange(
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 3, 31),
        );

        // API drift: `overlaps()`/`contains()` helpers and the `duration`
        // getter were removed from DateRange. `duration.inDays` is now the
        // `days` getter; the overlaps/contains checks have no current
        // equivalent, so those assertions are dropped.
        expect(january.days, 30);
        expect(q1.days, 90);
        expect(q1.previousPeriod.end, q1.start);
      });
    });
  });
}
