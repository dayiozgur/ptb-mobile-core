import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

void main() {
  // API drift: the reporting models were reworked from computed-helper value
  // objects into plain data containers.
  // - MetricType's domain-specific members (organizations/sites/units/users)
  //   were replaced by count/sum/average/percentage/trend; enum `value`s are now
  //   UPPERCASE codes and `fromValue` became nullable `fromString`.
  // - DashboardMetric now takes id/title/value(String) (no previousValue/
  //   changePercent/formattedValue/formattedChange).
  // - DashboardSummary requires `tenantId` and carries the entity counts
  //   directly (getMetric/totalValue removed).
  // - ActivityStats is now {totalCount, byType, byEntity, timeSeries,
  //   generatedAt} (completionRate/hasOverdue removed).
  // - EntityCountSummary is now {total, active, inactive, generatedAt}
  //   (totalEntities/userActivityRate removed).
  // - DateRange exposes `days`/`previousPeriod` (duration/contains/overlaps/
  //   toJson removed).
  // - ReportType is summary/activity/inventory/performance/custom; ReportFormat
  //   only exposes value/label (extension/mimeType removed).
  // - ReportResult is {id, type, format, title, dateRange, generatedAt, data}
  //   (request/isSuccess/error removed); ReportRequest.toJson uses snake_case.
  group('MetricType', () {
    test('has correct values', () {
      expect(MetricType.count.value, 'COUNT');
      expect(MetricType.sum.value, 'SUM');
      expect(MetricType.average.value, 'AVG');
      expect(MetricType.percentage.value, 'PERCENTAGE');
      expect(MetricType.trend.value, 'TREND');
    });

    test('has correct labels', () {
      expect(MetricType.count.label, 'Sayı');
      expect(MetricType.sum.label, 'Toplam');
      expect(MetricType.average.label, 'Ortalama');
    });

    test('fromString returns correct type', () {
      expect(MetricType.fromString('COUNT'), MetricType.count);
      expect(MetricType.fromString('SUM'), MetricType.sum);
      expect(MetricType.fromString('invalid'), isNull);
      expect(MetricType.fromString(null), isNull);
    });
  });

  group('TrendDirection', () {
    test('has correct values', () {
      expect(TrendDirection.up.value, 'UP');
      expect(TrendDirection.down.value, 'DOWN');
      expect(TrendDirection.stable.value, 'STABLE');
    });

    test('fromString returns correct type', () {
      expect(TrendDirection.fromString('UP'), TrendDirection.up);
      expect(TrendDirection.fromString('DOWN'), TrendDirection.down);
      expect(TrendDirection.fromString('invalid'), isNull);
    });
  });

  group('ReportPeriod', () {
    test('has correct values', () {
      expect(ReportPeriod.today.value, 'TODAY');
      expect(ReportPeriod.thisWeek.value, 'THIS_WEEK');
      expect(ReportPeriod.thisMonth.value, 'THIS_MONTH');
      expect(ReportPeriod.thisYear.value, 'THIS_YEAR');
      expect(ReportPeriod.custom.value, 'CUSTOM');
    });

    test('has correct labels', () {
      expect(ReportPeriod.today.label, 'Bugün');
      expect(ReportPeriod.thisWeek.label, 'Bu Hafta');
      expect(ReportPeriod.thisMonth.label, 'Bu Ay');
      expect(ReportPeriod.thisYear.label, 'Bu Yıl');
      expect(ReportPeriod.custom.label, 'Özel');
    });

    test('getDateRange returns correct range for today', () {
      final range = ReportPeriod.today.getDateRange();
      final now = DateTime.now();

      expect(range.start.year, now.year);
      expect(range.start.month, now.month);
      expect(range.start.day, now.day);
      expect(range.start.hour, 0);
      expect(range.start.minute, 0);
    });

    test('getDateRange returns correct range for thisWeek', () {
      final range = ReportPeriod.thisWeek.getDateRange();

      // Start should be Monday of current week
      expect(range.start.weekday, DateTime.monday);
      expect(range.end.isAfter(range.start), true);
    });

    test('getDateRange returns correct range for thisMonth', () {
      final range = ReportPeriod.thisMonth.getDateRange();
      final now = DateTime.now();

      expect(range.start.year, now.year);
      expect(range.start.month, now.month);
      expect(range.start.day, 1);
    });

    test('getDateRange returns correct range for thisYear', () {
      final range = ReportPeriod.thisYear.getDateRange();
      final now = DateTime.now();

      expect(range.start.year, now.year);
      expect(range.start.month, 1);
      expect(range.start.day, 1);
    });
  });

  group('DateRange', () {
    test('creates correctly', () {
      final start = DateTime(2024, 1, 1);
      final end = DateTime(2024, 1, 31);
      final range = DateRange(start: start, end: end);

      expect(range.start, start);
      expect(range.end, end);
    });

    test('days returns correct value', () {
      final range = DateRange(
        start: DateTime(2024, 1, 1),
        end: DateTime(2024, 1, 11),
      );

      expect(range.days, 10);
    });

    test('previousPeriod returns adjacent earlier range', () {
      final range = DateRange(
        start: DateTime(2024, 1, 11),
        end: DateTime(2024, 1, 21),
      );

      final previous = range.previousPeriod;

      expect(previous.end, range.start);
      expect(previous.start, DateTime(2024, 1, 1));
    });
  });

  group('DashboardMetric', () {
    test('creates correctly', () {
      const metric = DashboardMetric(
        id: 'm-1',
        title: 'Organizations',
        value: '100',
        type: MetricType.count,
        trend: TrendDirection.up,
        trendValue: 25.0,
      );

      expect(metric.id, 'm-1');
      expect(metric.title, 'Organizations');
      expect(metric.value, '100');
      expect(metric.type, MetricType.count);
      expect(metric.trend, TrendDirection.up);
      expect(metric.trendValue, 25.0);
    });

    test('round-trips through JSON', () {
      const metric = DashboardMetric(
        id: 'm-users',
        title: 'Users',
        value: '500',
        type: MetricType.count,
        trend: TrendDirection.up,
        trendValue: 11.1,
      );

      final restored = DashboardMetric.fromJson(metric.toJson());

      expect(restored.id, 'm-users');
      expect(restored.title, 'Users');
      expect(restored.value, '500');
      expect(restored.type, MetricType.count);
      expect(restored.trend, TrendDirection.up);
      expect(restored.trendValue, 11.1);
    });
  });

  group('DashboardSummary', () {
    test('creates correctly', () {
      final summary = DashboardSummary(
        tenantId: 'tenant-123',
        metrics: const [
          DashboardMetric(id: 'm-1', title: 'Orgs', value: '10'),
          DashboardMetric(id: 'm-2', title: 'Sites', value: '50'),
        ],
        period: ReportPeriod.thisMonth,
        organizationCount: 10,
        siteCount: 50,
        generatedAt: DateTime.now(),
      );

      expect(summary.tenantId, 'tenant-123');
      expect(summary.metrics.length, 2);
      expect(summary.period, ReportPeriod.thisMonth);
      expect(summary.organizationCount, 10);
      expect(summary.siteCount, 50);
    });

    test('round-trips through JSON', () {
      final summary = DashboardSummary(
        tenantId: 'tenant-123',
        metrics: const [
          DashboardMetric(
            id: 'm-org',
            title: 'Organizations',
            value: '5',
            trend: TrendDirection.up,
          ),
        ],
        period: ReportPeriod.thisMonth,
        organizationCount: 5,
        siteCount: 20,
        unitCount: 100,
        activeUserCount: 50,
        generatedAt: DateTime(2024, 1, 15, 10, 0),
      );

      final restored = DashboardSummary.fromJson(summary.toJson());

      expect(restored.tenantId, 'tenant-123');
      expect(restored.unitCount, 100);
      expect(restored.activeUserCount, 50);
      expect(restored.metrics.first.trend, TrendDirection.up);
    });
  });

  group('ActivityStats', () {
    test('creates correctly', () {
      final stats = ActivityStats(
        totalCount: 100,
        byType: const {'create': 60, 'update': 40},
        byEntity: const {'unit': 75, 'site': 25},
        timeSeries: const [],
        generatedAt: DateTime.now(),
      );

      expect(stats.totalCount, 100);
      expect(stats.byType['create'], 60);
      expect(stats.byEntity['unit'], 75);
    });

    test('round-trips through JSON', () {
      final stats = ActivityStats(
        totalCount: 100,
        byType: const {'create': 60, 'update': 40},
        byEntity: const {'unit': 75, 'site': 25},
        timeSeries: const [],
        generatedAt: DateTime(2024, 1, 15, 10, 0),
      );

      final restored = ActivityStats.fromJson(stats.toJson());

      expect(restored.totalCount, 100);
      expect(restored.byType['update'], 40);
      expect(restored.byEntity['site'], 25);
    });
  });

  group('EntityCountSummary', () {
    test('creates correctly', () {
      final summary = EntityCountSummary(
        total: 100,
        active: 85,
        inactive: 15,
        generatedAt: DateTime.now(),
      );

      expect(summary.total, 100);
      expect(summary.active, 85);
      expect(summary.inactive, 15);
      expect(summary.active + summary.inactive, 100);
    });

    test('round-trips through JSON', () {
      final summary = EntityCountSummary(
        total: 100,
        active: 85,
        inactive: 15,
        generatedAt: DateTime(2024, 1, 15, 10, 0),
      );

      final restored = EntityCountSummary.fromJson(summary.toJson());

      expect(restored.total, 100);
      expect(restored.active, 85);
      expect(restored.inactive, 15);
    });
  });

  group('ReportType', () {
    test('has correct values', () {
      expect(ReportType.summary.value, 'SUMMARY');
      expect(ReportType.activity.value, 'ACTIVITY');
      expect(ReportType.inventory.value, 'INVENTORY');
      expect(ReportType.performance.value, 'PERFORMANCE');
      expect(ReportType.custom.value, 'CUSTOM');
    });

    test('has correct labels', () {
      expect(ReportType.summary.label, 'Özet Rapor');
      expect(ReportType.activity.label, 'Aktivite Raporu');
      expect(ReportType.custom.label, 'Özel Rapor');
    });
  });

  group('ReportFormat', () {
    test('has correct values', () {
      expect(ReportFormat.json.value, 'JSON');
      expect(ReportFormat.csv.value, 'CSV');
      expect(ReportFormat.pdf.value, 'PDF');
      expect(ReportFormat.excel.value, 'EXCEL');
    });

    test('has correct labels', () {
      expect(ReportFormat.json.label, 'JSON');
      expect(ReportFormat.csv.label, 'CSV');
      expect(ReportFormat.pdf.label, 'PDF');
      expect(ReportFormat.excel.label, 'Excel');
    });
  });

  group('ReportRequest', () {
    test('creates correctly', () {
      const request = ReportRequest(
        type: ReportType.summary,
        period: ReportPeriod.thisMonth,
        format: ReportFormat.pdf,
        tenantId: 'tenant-123',
      );

      expect(request.type, ReportType.summary);
      expect(request.period, ReportPeriod.thisMonth);
      expect(request.format, ReportFormat.pdf);
      expect(request.tenantId, 'tenant-123');
    });

    test('toJson serializes correctly', () {
      const request = ReportRequest(
        type: ReportType.activity,
        period: ReportPeriod.thisWeek,
        format: ReportFormat.csv,
        tenantId: 'tenant-123',
        organizationId: 'org-123',
      );

      final json = request.toJson();

      expect(json['type'], 'ACTIVITY');
      expect(json['period'], 'THIS_WEEK');
      expect(json['format'], 'CSV');
      expect(json['tenant_id'], 'tenant-123');
      expect(json['organization_id'], 'org-123');
    });
  });

  group('ReportResult', () {
    test('creates correctly', () {
      final result = ReportResult(
        id: 'report-1',
        type: ReportType.summary,
        format: ReportFormat.json,
        title: 'Monthly Summary',
        dateRange: DateRange(
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 1, 31),
        ),
        generatedAt: DateTime.now(),
        data: {'metrics': []},
      );

      expect(result.id, 'report-1');
      expect(result.type, ReportType.summary);
      expect(result.data, isA<Map>());
    });

    test('round-trips through JSON', () {
      final result = ReportResult(
        id: 'report-1',
        type: ReportType.summary,
        format: ReportFormat.json,
        title: 'Monthly Summary',
        dateRange: DateRange(
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 1, 31),
        ),
        generatedAt: DateTime(2024, 1, 15, 10, 0),
        data: {'value': 'x'},
      );

      final restored = ReportResult.fromJson(result.toJson());

      expect(restored.id, 'report-1');
      expect(restored.type, ReportType.summary);
      expect(restored.format, ReportFormat.json);
      expect(restored.title, 'Monthly Summary');
    });
  });
}
