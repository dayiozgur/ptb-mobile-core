import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

void main() {
  group('MetricType', () {
    test('has correct values', () {
      expect(MetricType.organizations.value, 'organizations');
      expect(MetricType.sites.value, 'sites');
      expect(MetricType.units.value, 'units');
      expect(MetricType.users.value, 'users');
      expect(MetricType.activities.value, 'activities');
    });

    test('has correct labels', () {
      expect(MetricType.organizations.label, 'Organizasyonlar');
      expect(MetricType.sites.label, 'Sahalar');
      expect(MetricType.units.label, 'Alanlar');
      expect(MetricType.users.label, 'Kullanıcılar');
      expect(MetricType.activities.label, 'Aktiviteler');
    });

    test('fromValue returns correct type', () {
      expect(MetricType.fromValue('organizations'), MetricType.organizations);
      expect(MetricType.fromValue('sites'), MetricType.sites);
      expect(MetricType.fromValue('invalid'), MetricType.organizations);
    });
  });

  group('TrendDirection', () {
    test('has correct values', () {
      expect(TrendDirection.up.value, 'up');
      expect(TrendDirection.down.value, 'down');
      expect(TrendDirection.stable.value, 'stable');
    });

    test('isPositive returns correct value', () {
      expect(TrendDirection.up.isPositive, true);
      expect(TrendDirection.down.isPositive, false);
      expect(TrendDirection.stable.isPositive, false);
    });

    test('isNegative returns correct value', () {
      expect(TrendDirection.up.isNegative, false);
      expect(TrendDirection.down.isNegative, true);
      expect(TrendDirection.stable.isNegative, false);
    });
  });

  group('ReportPeriod', () {
    test('has correct values', () {
      expect(ReportPeriod.today.value, 'today');
      expect(ReportPeriod.thisWeek.value, 'this_week');
      expect(ReportPeriod.thisMonth.value, 'this_month');
      expect(ReportPeriod.thisYear.value, 'this_year');
      expect(ReportPeriod.custom.value, 'custom');
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
      final now = DateTime.now();

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

    test('duration returns correct value', () {
      final range = DateRange(
        start: DateTime(2024, 1, 1),
        end: DateTime(2024, 1, 11),
      );

      expect(range.duration.inDays, 10);
    });

    test('contains returns correct value', () {
      final range = DateRange(
        start: DateTime(2024, 1, 1),
        end: DateTime(2024, 1, 31),
      );

      expect(range.contains(DateTime(2024, 1, 15)), true);
      expect(range.contains(DateTime(2024, 2, 1)), false);
      expect(range.contains(DateTime(2023, 12, 31)), false);
    });

    test('overlaps returns correct value', () {
      final range1 = DateRange(
        start: DateTime(2024, 1, 1),
        end: DateTime(2024, 1, 31),
      );
      final range2 = DateRange(
        start: DateTime(2024, 1, 15),
        end: DateTime(2024, 2, 15),
      );
      final range3 = DateRange(
        start: DateTime(2024, 3, 1),
        end: DateTime(2024, 3, 31),
      );

      expect(range1.overlaps(range2), true);
      expect(range1.overlaps(range3), false);
    });

    test('toJson serializes correctly', () {
      final range = DateRange(
        start: DateTime(2024, 1, 1),
        end: DateTime(2024, 1, 31),
      );

      final json = range.toJson();

      expect(json['start'], isA<String>());
      expect(json['end'], isA<String>());
    });
  });

  group('DashboardMetric', () {
    test('creates correctly', () {
      final metric = DashboardMetric(
        type: MetricType.organizations,
        value: 100,
        previousValue: 80,
        trend: TrendDirection.up,
        changePercent: 25.0,
      );

      expect(metric.type, MetricType.organizations);
      expect(metric.value, 100);
      expect(metric.previousValue, 80);
      expect(metric.trend, TrendDirection.up);
      expect(metric.changePercent, 25.0);
    });

    test('formattedValue returns correct string', () {
      final metric = DashboardMetric(
        type: MetricType.sites,
        value: 1234,
      );

      expect(metric.formattedValue, '1,234');
    });

    test('formattedChange returns correct string', () {
      final positiveMetric = DashboardMetric(
        type: MetricType.units,
        value: 100,
        trend: TrendDirection.up,
        changePercent: 15.5,
      );
      expect(positiveMetric.formattedChange, '+15.5%');

      final negativeMetric = DashboardMetric(
        type: MetricType.units,
        value: 100,
        trend: TrendDirection.down,
        changePercent: 10.0,
      );
      expect(negativeMetric.formattedChange, '-10.0%');

      final stableMetric = DashboardMetric(
        type: MetricType.units,
        value: 100,
        trend: TrendDirection.stable,
        changePercent: 0.0,
      );
      expect(stableMetric.formattedChange, '0.0%');
    });

    test('fromJson parses correctly', () {
      final json = {
        'type': 'users',
        'value': 500,
        'previousValue': 450,
        'trend': 'up',
        'changePercent': 11.1,
      };

      final metric = DashboardMetric.fromJson(json);

      expect(metric.type, MetricType.users);
      expect(metric.value, 500);
      expect(metric.previousValue, 450);
      expect(metric.trend, TrendDirection.up);
      expect(metric.changePercent, 11.1);
    });
  });

  group('DashboardSummary', () {
    test('creates correctly', () {
      final metrics = [
        DashboardMetric(type: MetricType.organizations, value: 10),
        DashboardMetric(type: MetricType.sites, value: 50),
      ];

      final summary = DashboardSummary(
        metrics: metrics,
        period: ReportPeriod.thisMonth,
        generatedAt: DateTime.now(),
      );

      expect(summary.metrics.length, 2);
      expect(summary.period, ReportPeriod.thisMonth);
    });

    test('getMetric returns correct metric', () {
      final summary = DashboardSummary(
        metrics: [
          DashboardMetric(type: MetricType.organizations, value: 10),
          DashboardMetric(type: MetricType.sites, value: 50),
        ],
        period: ReportPeriod.thisMonth,
        generatedAt: DateTime.now(),
      );

      expect(summary.getMetric(MetricType.organizations)?.value, 10);
      expect(summary.getMetric(MetricType.sites)?.value, 50);
      expect(summary.getMetric(MetricType.users), isNull);
    });

    test('totalValue returns sum of all metric values', () {
      final summary = DashboardSummary(
        metrics: [
          DashboardMetric(type: MetricType.organizations, value: 10),
          DashboardMetric(type: MetricType.sites, value: 50),
          DashboardMetric(type: MetricType.units, value: 40),
        ],
        period: ReportPeriod.thisMonth,
        generatedAt: DateTime.now(),
      );

      expect(summary.totalValue, 100);
    });
  });

  group('ActivityStats', () {
    test('creates correctly', () {
      final stats = ActivityStats(
        totalActivities: 100,
        completedActivities: 80,
        pendingActivities: 15,
        overdueActivities: 5,
        period: ReportPeriod.thisWeek,
      );

      expect(stats.totalActivities, 100);
      expect(stats.completedActivities, 80);
      expect(stats.pendingActivities, 15);
      expect(stats.overdueActivities, 5);
    });

    test('completionRate calculates correctly', () {
      final stats = ActivityStats(
        totalActivities: 100,
        completedActivities: 75,
        pendingActivities: 20,
        overdueActivities: 5,
        period: ReportPeriod.thisWeek,
      );

      expect(stats.completionRate, 75.0);
    });

    test('completionRate returns 0 when no activities', () {
      final stats = ActivityStats(
        totalActivities: 0,
        completedActivities: 0,
        pendingActivities: 0,
        overdueActivities: 0,
        period: ReportPeriod.thisWeek,
      );

      expect(stats.completionRate, 0.0);
    });

    test('hasOverdue returns correct value', () {
      final withOverdue = ActivityStats(
        totalActivities: 100,
        completedActivities: 80,
        pendingActivities: 10,
        overdueActivities: 10,
        period: ReportPeriod.thisWeek,
      );
      expect(withOverdue.hasOverdue, true);

      final withoutOverdue = ActivityStats(
        totalActivities: 100,
        completedActivities: 80,
        pendingActivities: 20,
        overdueActivities: 0,
        period: ReportPeriod.thisWeek,
      );
      expect(withoutOverdue.hasOverdue, false);
    });
  });

  group('EntityCountSummary', () {
    test('creates correctly', () {
      final summary = EntityCountSummary(
        organizationCount: 5,
        siteCount: 20,
        unitCount: 100,
        userCount: 50,
        activeUserCount: 45,
      );

      expect(summary.organizationCount, 5);
      expect(summary.siteCount, 20);
      expect(summary.unitCount, 100);
      expect(summary.userCount, 50);
      expect(summary.activeUserCount, 45);
    });

    test('totalEntities calculates correctly', () {
      final summary = EntityCountSummary(
        organizationCount: 5,
        siteCount: 20,
        unitCount: 100,
        userCount: 50,
        activeUserCount: 45,
      );

      expect(summary.totalEntities, 175); // 5 + 20 + 100 + 50
    });

    test('userActivityRate calculates correctly', () {
      final summary = EntityCountSummary(
        organizationCount: 5,
        siteCount: 20,
        unitCount: 100,
        userCount: 100,
        activeUserCount: 75,
      );

      expect(summary.userActivityRate, 75.0);
    });

    test('userActivityRate returns 0 when no users', () {
      final summary = EntityCountSummary(
        organizationCount: 5,
        siteCount: 20,
        unitCount: 100,
        userCount: 0,
        activeUserCount: 0,
      );

      expect(summary.userActivityRate, 0.0);
    });
  });

  group('ReportType', () {
    test('has correct values', () {
      expect(ReportType.dashboard.value, 'dashboard');
      expect(ReportType.activity.value, 'activity');
      expect(ReportType.entitySummary.value, 'entity_summary');
      expect(ReportType.trend.value, 'trend');
      expect(ReportType.custom.value, 'custom');
    });

    test('has correct labels', () {
      expect(ReportType.dashboard.label, 'Dashboard');
      expect(ReportType.activity.label, 'Aktivite Raporu');
      expect(ReportType.entitySummary.label, 'Varlık Özeti');
      expect(ReportType.trend.label, 'Trend Analizi');
      expect(ReportType.custom.label, 'Özel Rapor');
    });
  });

  group('ReportFormat', () {
    test('has correct values', () {
      expect(ReportFormat.json.value, 'json');
      expect(ReportFormat.csv.value, 'csv');
      expect(ReportFormat.pdf.value, 'pdf');
      expect(ReportFormat.excel.value, 'excel');
    });

    test('has correct extensions', () {
      expect(ReportFormat.json.extension, 'json');
      expect(ReportFormat.csv.extension, 'csv');
      expect(ReportFormat.pdf.extension, 'pdf');
      expect(ReportFormat.excel.extension, 'xlsx');
    });

    test('has correct mime types', () {
      expect(ReportFormat.json.mimeType, 'application/json');
      expect(ReportFormat.csv.mimeType, 'text/csv');
      expect(ReportFormat.pdf.mimeType, 'application/pdf');
      expect(ReportFormat.excel.mimeType,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    });
  });

  group('ReportRequest', () {
    test('creates correctly', () {
      final request = ReportRequest(
        type: ReportType.dashboard,
        period: ReportPeriod.thisMonth,
        format: ReportFormat.pdf,
        tenantId: 'tenant-123',
      );

      expect(request.type, ReportType.dashboard);
      expect(request.period, ReportPeriod.thisMonth);
      expect(request.format, ReportFormat.pdf);
      expect(request.tenantId, 'tenant-123');
    });

    test('toJson serializes correctly', () {
      final request = ReportRequest(
        type: ReportType.activity,
        period: ReportPeriod.thisWeek,
        format: ReportFormat.csv,
        tenantId: 'tenant-123',
        organizationId: 'org-123',
      );

      final json = request.toJson();

      expect(json['type'], 'activity');
      expect(json['period'], 'this_week');
      expect(json['format'], 'csv');
      expect(json['tenantId'], 'tenant-123');
      expect(json['organizationId'], 'org-123');
    });
  });

  group('ReportResult', () {
    test('creates correctly', () {
      final result = ReportResult(
        request: ReportRequest(
          type: ReportType.dashboard,
          period: ReportPeriod.thisMonth,
          format: ReportFormat.json,
          tenantId: 'tenant-123',
        ),
        data: {'metrics': []},
        generatedAt: DateTime.now(),
      );

      expect(result.request.type, ReportType.dashboard);
      expect(result.data, isA<Map>());
      expect(result.isSuccess, true);
    });

    test('isSuccess returns correct value', () {
      final successResult = ReportResult(
        request: ReportRequest(
          type: ReportType.dashboard,
          period: ReportPeriod.thisMonth,
          format: ReportFormat.json,
          tenantId: 'tenant-123',
        ),
        data: {'data': 'value'},
        generatedAt: DateTime.now(),
      );
      expect(successResult.isSuccess, true);

      final failResult = ReportResult(
        request: ReportRequest(
          type: ReportType.dashboard,
          period: ReportPeriod.thisMonth,
          format: ReportFormat.json,
          tenantId: 'tenant-123',
        ),
        data: null,
        generatedAt: DateTime.now(),
        error: 'Failed to generate report',
      );
      expect(failResult.isSuccess, false);
    });
  });
}
