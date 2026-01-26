/// Reporting ve Analytics modelleri
///
/// Dashboard metrikleri, raporlar ve istatistikler için
/// veri modelleri.

/// Dashboard metrik türü
enum MetricType {
  count('COUNT', 'Sayı'),
  sum('SUM', 'Toplam'),
  average('AVG', 'Ortalama'),
  percentage('PERCENTAGE', 'Yüzde'),
  trend('TREND', 'Trend');

  final String value;
  final String label;
  const MetricType(this.value, this.label);

  static MetricType? fromString(String? value) {
    if (value == null) return null;
    return MetricType.values.cast<MetricType?>().firstWhere(
          (e) => e?.value == value,
          orElse: () => null,
        );
  }
}

/// Trend yönü
enum TrendDirection {
  up('UP', 'Artış'),
  down('DOWN', 'Düşüş'),
  stable('STABLE', 'Sabit');

  final String value;
  final String label;
  const TrendDirection(this.value, this.label);

  static TrendDirection? fromString(String? value) {
    if (value == null) return null;
    return TrendDirection.values.cast<TrendDirection?>().firstWhere(
          (e) => e?.value == value,
          orElse: () => null,
        );
  }
}

/// Zaman periyodu
enum ReportPeriod {
  today('TODAY', 'Bugün'),
  yesterday('YESTERDAY', 'Dün'),
  thisWeek('THIS_WEEK', 'Bu Hafta'),
  lastWeek('LAST_WEEK', 'Geçen Hafta'),
  thisMonth('THIS_MONTH', 'Bu Ay'),
  lastMonth('LAST_MONTH', 'Geçen Ay'),
  thisQuarter('THIS_QUARTER', 'Bu Çeyrek'),
  lastQuarter('LAST_QUARTER', 'Geçen Çeyrek'),
  thisYear('THIS_YEAR', 'Bu Yıl'),
  lastYear('LAST_YEAR', 'Geçen Yıl'),
  custom('CUSTOM', 'Özel');

  final String value;
  final String label;
  const ReportPeriod(this.value, this.label);

  static ReportPeriod? fromString(String? value) {
    if (value == null) return null;
    return ReportPeriod.values.cast<ReportPeriod?>().firstWhere(
          (e) => e?.value == value,
          orElse: () => null,
        );
  }

  /// Periyodun tarih aralığını hesapla
  DateRange getDateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (this) {
      case ReportPeriod.today:
        return DateRange(
          start: today,
          end: today.add(const Duration(days: 1)),
        );
      case ReportPeriod.yesterday:
        return DateRange(
          start: today.subtract(const Duration(days: 1)),
          end: today,
        );
      case ReportPeriod.thisWeek:
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        return DateRange(
          start: weekStart,
          end: weekStart.add(const Duration(days: 7)),
        );
      case ReportPeriod.lastWeek:
        final weekStart = today.subtract(Duration(days: today.weekday + 6));
        return DateRange(
          start: weekStart,
          end: weekStart.add(const Duration(days: 7)),
        );
      case ReportPeriod.thisMonth:
        return DateRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 1),
        );
      case ReportPeriod.lastMonth:
        return DateRange(
          start: DateTime(now.year, now.month - 1, 1),
          end: DateTime(now.year, now.month, 1),
        );
      case ReportPeriod.thisQuarter:
        final quarterStart = DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1, 1);
        return DateRange(
          start: quarterStart,
          end: DateTime(quarterStart.year, quarterStart.month + 3, 1),
        );
      case ReportPeriod.lastQuarter:
        final quarterStart = DateTime(now.year, ((now.month - 1) ~/ 3) * 3 - 2, 1);
        return DateRange(
          start: quarterStart,
          end: DateTime(quarterStart.year, quarterStart.month + 3, 1),
        );
      case ReportPeriod.thisYear:
        return DateRange(
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year + 1, 1, 1),
        );
      case ReportPeriod.lastYear:
        return DateRange(
          start: DateTime(now.year - 1, 1, 1),
          end: DateTime(now.year, 1, 1),
        );
      case ReportPeriod.custom:
        return DateRange(start: today, end: today);
    }
  }
}

/// Tarih aralığı
class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange({
    required this.start,
    required this.end,
  });

  /// Gün sayısı
  int get days => end.difference(start).inDays;

  /// Önceki periyod (karşılaştırma için)
  DateRange get previousPeriod {
    final duration = end.difference(start);
    return DateRange(
      start: start.subtract(duration),
      end: start,
    );
  }

  @override
  String toString() => 'DateRange($start - $end)';
}

/// Dashboard metriği
class DashboardMetric {
  final String id;
  final String title;
  final String value;
  final MetricType type;
  final String? subtitle;
  final String? icon;
  final String? color;
  final TrendDirection? trend;
  final double? trendValue;
  final String? trendLabel;
  final DateTime? updatedAt;

  const DashboardMetric({
    required this.id,
    required this.title,
    required this.value,
    this.type = MetricType.count,
    this.subtitle,
    this.icon,
    this.color,
    this.trend,
    this.trendValue,
    this.trendLabel,
    this.updatedAt,
  });

  factory DashboardMetric.fromJson(Map<String, dynamic> json) {
    return DashboardMetric(
      id: json['id'] as String,
      title: json['title'] as String,
      value: json['value'] as String,
      type: MetricType.fromString(json['type'] as String?) ?? MetricType.count,
      subtitle: json['subtitle'] as String?,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      trend: TrendDirection.fromString(json['trend'] as String?),
      trendValue: (json['trend_value'] as num?)?.toDouble(),
      trendLabel: json['trend_label'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'value': value,
        'type': type.value,
        'subtitle': subtitle,
        'icon': icon,
        'color': color,
        'trend': trend?.value,
        'trend_value': trendValue,
        'trend_label': trendLabel,
        'updated_at': updatedAt?.toIso8601String(),
      };
}

/// Dashboard özeti
class DashboardSummary {
  final String tenantId;
  final List<DashboardMetric> metrics;
  final DateTime generatedAt;
  final ReportPeriod period;

  // Ana metrikler
  final int organizationCount;
  final int siteCount;
  final int unitCount;
  final int activeUserCount;
  final int activityCount;
  final int pendingNotificationCount;

  // Trend verileri
  final TrendData? organizationTrend;
  final TrendData? siteTrend;
  final TrendData? unitTrend;
  final TrendData? activityTrend;

  const DashboardSummary({
    required this.tenantId,
    required this.metrics,
    required this.generatedAt,
    this.period = ReportPeriod.thisMonth,
    this.organizationCount = 0,
    this.siteCount = 0,
    this.unitCount = 0,
    this.activeUserCount = 0,
    this.activityCount = 0,
    this.pendingNotificationCount = 0,
    this.organizationTrend,
    this.siteTrend,
    this.unitTrend,
    this.activityTrend,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      tenantId: json['tenant_id'] as String,
      metrics: (json['metrics'] as List<dynamic>?)
              ?.map((e) => DashboardMetric.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      generatedAt: DateTime.parse(json['generated_at'] as String),
      period: ReportPeriod.fromString(json['period'] as String?) ??
          ReportPeriod.thisMonth,
      organizationCount: json['organization_count'] as int? ?? 0,
      siteCount: json['site_count'] as int? ?? 0,
      unitCount: json['unit_count'] as int? ?? 0,
      activeUserCount: json['active_user_count'] as int? ?? 0,
      activityCount: json['activity_count'] as int? ?? 0,
      pendingNotificationCount: json['pending_notification_count'] as int? ?? 0,
      organizationTrend: json['organization_trend'] != null
          ? TrendData.fromJson(json['organization_trend'] as Map<String, dynamic>)
          : null,
      siteTrend: json['site_trend'] != null
          ? TrendData.fromJson(json['site_trend'] as Map<String, dynamic>)
          : null,
      unitTrend: json['unit_trend'] != null
          ? TrendData.fromJson(json['unit_trend'] as Map<String, dynamic>)
          : null,
      activityTrend: json['activity_trend'] != null
          ? TrendData.fromJson(json['activity_trend'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'tenant_id': tenantId,
        'metrics': metrics.map((m) => m.toJson()).toList(),
        'generated_at': generatedAt.toIso8601String(),
        'period': period.value,
        'organization_count': organizationCount,
        'site_count': siteCount,
        'unit_count': unitCount,
        'active_user_count': activeUserCount,
        'activity_count': activityCount,
        'pending_notification_count': pendingNotificationCount,
        'organization_trend': organizationTrend?.toJson(),
        'site_trend': siteTrend?.toJson(),
        'unit_trend': unitTrend?.toJson(),
        'activity_trend': activityTrend?.toJson(),
      };
}

/// Trend verisi
class TrendData {
  final double currentValue;
  final double previousValue;
  final TrendDirection direction;
  final double changePercent;
  final String? label;

  const TrendData({
    required this.currentValue,
    required this.previousValue,
    required this.direction,
    required this.changePercent,
    this.label,
  });

  factory TrendData.fromJson(Map<String, dynamic> json) {
    return TrendData(
      currentValue: (json['current_value'] as num).toDouble(),
      previousValue: (json['previous_value'] as num).toDouble(),
      direction: TrendDirection.fromString(json['direction'] as String?) ??
          TrendDirection.stable,
      changePercent: (json['change_percent'] as num).toDouble(),
      label: json['label'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'current_value': currentValue,
        'previous_value': previousValue,
        'direction': direction.value,
        'change_percent': changePercent,
        'label': label,
      };

  factory TrendData.calculate(double current, double previous) {
    final change = previous > 0 ? ((current - previous) / previous) * 100 : 0.0;
    final direction = change > 1
        ? TrendDirection.up
        : change < -1
            ? TrendDirection.down
            : TrendDirection.stable;

    return TrendData(
      currentValue: current,
      previousValue: previous,
      direction: direction,
      changePercent: change.abs(),
      label: '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%',
    );
  }
}

/// Aktivite istatistiği
class ActivityStats {
  final int totalCount;
  final Map<String, int> byType;
  final Map<String, int> byEntity;
  final List<ActivityTimeSeriesData> timeSeries;
  final DateTime generatedAt;

  const ActivityStats({
    required this.totalCount,
    required this.byType,
    required this.byEntity,
    required this.timeSeries,
    required this.generatedAt,
  });

  factory ActivityStats.fromJson(Map<String, dynamic> json) {
    return ActivityStats(
      totalCount: json['total_count'] as int,
      byType: Map<String, int>.from(json['by_type'] as Map? ?? {}),
      byEntity: Map<String, int>.from(json['by_entity'] as Map? ?? {}),
      timeSeries: (json['time_series'] as List<dynamic>?)
              ?.map((e) =>
                  ActivityTimeSeriesData.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      generatedAt: DateTime.parse(json['generated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'total_count': totalCount,
        'by_type': byType,
        'by_entity': byEntity,
        'time_series': timeSeries.map((t) => t.toJson()).toList(),
        'generated_at': generatedAt.toIso8601String(),
      };
}

/// Aktivite zaman serisi verisi
class ActivityTimeSeriesData {
  final DateTime date;
  final int count;
  final String? label;

  const ActivityTimeSeriesData({
    required this.date,
    required this.count,
    this.label,
  });

  factory ActivityTimeSeriesData.fromJson(Map<String, dynamic> json) {
    return ActivityTimeSeriesData(
      date: DateTime.parse(json['date'] as String),
      count: json['count'] as int,
      label: json['label'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'count': count,
        'label': label,
      };
}

/// Entity sayım özeti
class EntityCountSummary {
  final int total;
  final int active;
  final int inactive;
  final TrendData? trend;
  final DateTime generatedAt;

  const EntityCountSummary({
    required this.total,
    required this.active,
    required this.inactive,
    this.trend,
    required this.generatedAt,
  });

  factory EntityCountSummary.fromJson(Map<String, dynamic> json) {
    return EntityCountSummary(
      total: json['total'] as int,
      active: json['active'] as int,
      inactive: json['inactive'] as int,
      trend: json['trend'] != null
          ? TrendData.fromJson(json['trend'] as Map<String, dynamic>)
          : null,
      generatedAt: DateTime.parse(json['generated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'total': total,
        'active': active,
        'inactive': inactive,
        'trend': trend?.toJson(),
        'generated_at': generatedAt.toIso8601String(),
      };
}

/// Rapor türü
enum ReportType {
  summary('SUMMARY', 'Özet Rapor'),
  activity('ACTIVITY', 'Aktivite Raporu'),
  inventory('INVENTORY', 'Envanter Raporu'),
  performance('PERFORMANCE', 'Performans Raporu'),
  custom('CUSTOM', 'Özel Rapor');

  final String value;
  final String label;
  const ReportType(this.value, this.label);

  static ReportType? fromString(String? value) {
    if (value == null) return null;
    return ReportType.values.cast<ReportType?>().firstWhere(
          (e) => e?.value == value,
          orElse: () => null,
        );
  }
}

/// Rapor formatı
enum ReportFormat {
  json('JSON', 'JSON'),
  csv('CSV', 'CSV'),
  pdf('PDF', 'PDF'),
  excel('EXCEL', 'Excel');

  final String value;
  final String label;
  const ReportFormat(this.value, this.label);

  static ReportFormat? fromString(String? value) {
    if (value == null) return null;
    return ReportFormat.values.cast<ReportFormat?>().firstWhere(
          (e) => e?.value == value,
          orElse: () => null,
        );
  }
}

/// Rapor isteği
class ReportRequest {
  final ReportType type;
  final ReportPeriod period;
  final DateRange? customDateRange;
  final String? tenantId;
  final String? organizationId;
  final String? siteId;
  final ReportFormat format;
  final Map<String, dynamic>? filters;
  final List<String>? includeFields;

  const ReportRequest({
    required this.type,
    this.period = ReportPeriod.thisMonth,
    this.customDateRange,
    this.tenantId,
    this.organizationId,
    this.siteId,
    this.format = ReportFormat.json,
    this.filters,
    this.includeFields,
  });

  DateRange get effectiveDateRange =>
      period == ReportPeriod.custom && customDateRange != null
          ? customDateRange!
          : period.getDateRange();

  Map<String, dynamic> toJson() => {
        'type': type.value,
        'period': period.value,
        'custom_date_range': customDateRange != null
            ? {
                'start': customDateRange!.start.toIso8601String(),
                'end': customDateRange!.end.toIso8601String(),
              }
            : null,
        'tenant_id': tenantId,
        'organization_id': organizationId,
        'site_id': siteId,
        'format': format.value,
        'filters': filters,
        'include_fields': includeFields,
      };
}

/// Rapor sonucu
class ReportResult {
  final String id;
  final ReportType type;
  final ReportFormat format;
  final String title;
  final DateRange dateRange;
  final DateTime generatedAt;
  final dynamic data;
  final String? downloadUrl;
  final Map<String, dynamic>? metadata;

  const ReportResult({
    required this.id,
    required this.type,
    required this.format,
    required this.title,
    required this.dateRange,
    required this.generatedAt,
    this.data,
    this.downloadUrl,
    this.metadata,
  });

  factory ReportResult.fromJson(Map<String, dynamic> json) {
    return ReportResult(
      id: json['id'] as String,
      type: ReportType.fromString(json['type'] as String?) ?? ReportType.summary,
      format:
          ReportFormat.fromString(json['format'] as String?) ?? ReportFormat.json,
      title: json['title'] as String,
      dateRange: DateRange(
        start: DateTime.parse(json['date_range']['start'] as String),
        end: DateTime.parse(json['date_range']['end'] as String),
      ),
      generatedAt: DateTime.parse(json['generated_at'] as String),
      data: json['data'],
      downloadUrl: json['download_url'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.value,
        'format': format.value,
        'title': title,
        'date_range': {
          'start': dateRange.start.toIso8601String(),
          'end': dateRange.end.toIso8601String(),
        },
        'generated_at': generatedAt.toIso8601String(),
        'data': data,
        'download_url': downloadUrl,
        'metadata': metadata,
      };
}
