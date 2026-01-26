import 'package:flutter_test/flutter_test.dart';
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
        final themeSub = themeService.themeModeStream.listen(themeChanges.add);

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
      test('cache stores and retrieves organization correctly', () async {
        final cache = CacheManager();
        final org = Organization(
          id: 'org-123',
          name: 'Test Organization',
          tenantId: 'tenant-123',
        );

        await cache.setTyped<Organization>(
          key: 'org_org-123',
          value: org,
          toJson: (o) => o.toJson(),
        );

        final retrieved = await cache.getTyped<Organization>(
          key: 'org_org-123',
          fromJson: Organization.fromJson,
        );

        expect(retrieved, isNotNull);
        expect(retrieved!.id, 'org-123');
        expect(retrieved.name, 'Test Organization');
        expect(retrieved.tenantId, 'tenant-123');

        await cache.clear();
      });

      test('cache stores and retrieves site list correctly', () async {
        final cache = CacheManager();
        final sites = [
          Site(id: 'site-1', name: 'Site 1', organizationId: 'org-123'),
          Site(id: 'site-2', name: 'Site 2', organizationId: 'org-123'),
          Site(id: 'site-3', name: 'Site 3', organizationId: 'org-123'),
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

        await cache.clear();
      });

      test('cache TTL expires data correctly', () async {
        final cache = CacheManager();

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

        await cache.clear();
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
            SearchResult(
              id: 'org-1',
              entityType: SearchEntityType.organization,
              title: 'Test Org',
              subtitle: 'Organization',
              score: 0.95,
            ),
            SearchResult(
              id: 'site-1',
              entityType: SearchEntityType.site,
              title: 'Test Site',
              subtitle: 'Site',
              score: 0.85,
            ),
          ],
          totalCount: 100,
          query: SearchQuery(
            text: 'test',
            entityTypes: [SearchEntityType.all],
          ),
          hasMore: true,
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
      test('pending operations workflow', () {
        // Create operation
        var operation = PendingOperation(
          id: 'op-123',
          entityType: SyncEntityType.unit,
          entityId: 'unit-123',
          operationType: SyncOperationType.create,
          data: {'name': 'New Unit'},
          status: SyncStatus.pending,
          createdAt: DateTime.now(),
          retryCount: 0,
        );

        expect(operation.isPending, true);
        expect(operation.canRetry, true);

        // Start syncing
        operation = operation.copyWith(status: SyncStatus.syncing);
        expect(operation.status.isSyncing, true);

        // Complete
        operation = operation.copyWith(status: SyncStatus.completed);
        expect(operation.status.isCompleted, true);
      });

      test('sync state transitions', () {
        var state = SyncState.initial();
        expect(state.isOnline, false);
        expect(state.canSync, false);

        // Go online with pending operations
        state = state.copyWith(isOnline: true, pendingCount: 5);
        expect(state.canSync, true);

        // Start syncing
        state = state.copyWith(isSyncing: true);
        expect(state.canSync, false);

        // Complete sync
        state = state.copyWith(
          isSyncing: false,
          pendingCount: 0,
          lastSyncAt: DateTime.now(),
        );
        expect(state.canSync, false); // No pending
        expect(state.hasPending, false);
      });

      test('sync result scenarios', () {
        // Full success
        final success = SyncResult.success(syncedCount: 10);
        expect(success.isSuccess, true);
        expect(success.hasFailures, false);
        expect(success.totalCount, 10);

        // Full failure
        final failure = SyncResult.failure(error: 'Network error', failedCount: 10);
        expect(failure.isSuccess, false);
        expect(failure.hasFailures, true);

        // Partial success
        final partial = SyncResult.partial(
          syncedCount: 7,
          failedCount: 3,
          error: 'Some operations failed',
        );
        expect(partial.isSuccess, false);
        expect(partial.hasFailures, true);
        expect(partial.totalCount, 10);
      });
    });

    group('Reporting Integration', () {
      test('dashboard summary aggregation', () {
        final summary = DashboardSummary(
          metrics: [
            DashboardMetric(
              type: MetricType.organizations,
              value: 5,
              previousValue: 4,
              trend: TrendDirection.up,
              changePercent: 25.0,
            ),
            DashboardMetric(
              type: MetricType.sites,
              value: 20,
              previousValue: 20,
              trend: TrendDirection.stable,
              changePercent: 0.0,
            ),
            DashboardMetric(
              type: MetricType.units,
              value: 100,
              previousValue: 110,
              trend: TrendDirection.down,
              changePercent: -9.1,
            ),
            DashboardMetric(
              type: MetricType.users,
              value: 50,
              previousValue: 45,
              trend: TrendDirection.up,
              changePercent: 11.1,
            ),
          ],
          period: ReportPeriod.thisMonth,
          generatedAt: DateTime.now(),
        );

        expect(summary.totalValue, 175); // 5 + 20 + 100 + 50
        expect(summary.getMetric(MetricType.organizations)?.value, 5);
        expect(summary.getMetric(MetricType.sites)?.trend, TrendDirection.stable);
        expect(summary.getMetric(MetricType.units)?.trend.isNegative, true);
      });

      test('activity stats calculation', () {
        final stats = ActivityStats(
          totalActivities: 100,
          completedActivities: 75,
          pendingActivities: 20,
          overdueActivities: 5,
          period: ReportPeriod.thisWeek,
        );

        expect(stats.completionRate, 75.0);
        expect(stats.hasOverdue, true);

        final noOverdueStats = ActivityStats(
          totalActivities: 100,
          completedActivities: 80,
          pendingActivities: 20,
          overdueActivities: 0,
          period: ReportPeriod.thisWeek,
        );

        expect(noOverdueStats.hasOverdue, false);
      });

      test('entity count summary', () {
        final entitySummary = EntityCountSummary(
          organizationCount: 5,
          siteCount: 25,
          unitCount: 150,
          userCount: 100,
          activeUserCount: 85,
        );

        expect(entitySummary.totalEntities, 280); // 5 + 25 + 150 + 100
        expect(entitySummary.userActivityRate, 85.0);
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
        final february = DateRange(
          start: DateTime(2024, 2, 1),
          end: DateTime(2024, 2, 29),
        );
        final q1 = DateRange(
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 3, 31),
        );

        expect(january.overlaps(february), false);
        expect(january.overlaps(q1), true);
        expect(q1.contains(DateTime(2024, 2, 15)), true);
        expect(january.duration.inDays, 30);
      });
    });
  });
}
