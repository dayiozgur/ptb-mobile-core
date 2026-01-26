import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../utils/logger.dart';
import 'reporting_model.dart';

/// Reporting ve Analytics Servisi
///
/// Dashboard metrikleri, istatistikler ve raporlar için
/// veri toplama ve işleme servisi.
///
/// Örnek kullanım:
/// ```dart
/// final reportingService = ReportingService(
///   supabase: Supabase.instance.client,
///   cacheManager: CacheManager(),
/// );
///
/// // Dashboard özeti
/// final summary = await reportingService.getDashboardSummary(tenantId);
///
/// // Aktivite istatistikleri
/// final stats = await reportingService.getActivityStats(tenantId);
/// ```
class ReportingService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  // Cache configuration
  static const Duration _dashboardCacheDuration = Duration(minutes: 5);
  static const Duration _statsCacheDuration = Duration(minutes: 15);

  ReportingService({
    required SupabaseClient supabase,
    required CacheManager cacheManager,
  })  : _supabase = supabase,
        _cacheManager = cacheManager;

  // ============================================
  // DASHBOARD
  // ============================================

  /// Dashboard özeti getir
  Future<DashboardSummary> getDashboardSummary(
    String tenantId, {
    ReportPeriod period = ReportPeriod.thisMonth,
    bool forceRefresh = false,
  }) async {
    try {
      final cacheKey = 'dashboard_summary_${tenantId}_${period.value}';

      // Cache'den dene
      if (!forceRefresh) {
        final cached = await _cacheManager.getTyped<DashboardSummary>(
          key: cacheKey,
          fromJson: DashboardSummary.fromJson,
        );
        if (cached != null) return cached;
      }

      // Metrikleri paralel olarak getir
      final results = await Future.wait([
        _getOrganizationCount(tenantId),
        _getSiteCount(tenantId),
        _getUnitCount(tenantId),
        _getActiveUserCount(tenantId),
        _getActivityCount(tenantId, period),
        _getPendingNotificationCount(tenantId),
      ]);

      final organizationCount = results[0] as int;
      final siteCount = results[1] as int;
      final unitCount = results[2] as int;
      final activeUserCount = results[3] as int;
      final activityCount = results[4] as int;
      final pendingNotificationCount = results[5] as int;

      // Trend verilerini hesapla
      final previousPeriod = period.getDateRange().previousPeriod;
      final previousActivityCount = await _getActivityCountInRange(
        tenantId,
        previousPeriod,
      );

      final activityTrend = TrendData.calculate(
        activityCount.toDouble(),
        previousActivityCount.toDouble(),
      );

      // Dashboard metrikleri oluştur
      final metrics = [
        DashboardMetric(
          id: 'organizations',
          title: 'Organizasyonlar',
          value: organizationCount.toString(),
          type: MetricType.count,
          icon: 'business',
          color: '#2196F3',
        ),
        DashboardMetric(
          id: 'sites',
          title: 'Tesisler',
          value: siteCount.toString(),
          type: MetricType.count,
          icon: 'location_city',
          color: '#4CAF50',
        ),
        DashboardMetric(
          id: 'units',
          title: 'Üniteler',
          value: unitCount.toString(),
          type: MetricType.count,
          icon: 'widgets',
          color: '#FF9800',
        ),
        DashboardMetric(
          id: 'users',
          title: 'Aktif Kullanıcılar',
          value: activeUserCount.toString(),
          type: MetricType.count,
          icon: 'people',
          color: '#9C27B0',
        ),
        DashboardMetric(
          id: 'activities',
          title: 'Aktiviteler',
          value: activityCount.toString(),
          type: MetricType.count,
          icon: 'timeline',
          color: '#00BCD4',
          trend: activityTrend.direction,
          trendValue: activityTrend.changePercent,
          trendLabel: activityTrend.label,
        ),
        DashboardMetric(
          id: 'notifications',
          title: 'Bekleyen Bildirimler',
          value: pendingNotificationCount.toString(),
          type: MetricType.count,
          icon: 'notifications',
          color: '#F44336',
        ),
      ];

      final summary = DashboardSummary(
        tenantId: tenantId,
        metrics: metrics,
        generatedAt: DateTime.now(),
        period: period,
        organizationCount: organizationCount,
        siteCount: siteCount,
        unitCount: unitCount,
        activeUserCount: activeUserCount,
        activityCount: activityCount,
        pendingNotificationCount: pendingNotificationCount,
        activityTrend: activityTrend,
      );

      // Cache'e kaydet
      await _cacheManager.set(
        cacheKey,
        summary.toJson(),
        ttl: _dashboardCacheDuration,
      );

      Logger.debug('Dashboard summary generated for tenant: $tenantId');
      return summary;
    } catch (e) {
      Logger.error('Failed to get dashboard summary', e);
      return DashboardSummary(
        tenantId: tenantId,
        metrics: [],
        generatedAt: DateTime.now(),
        period: period,
      );
    }
  }

  // ============================================
  // ENTITY COUNTS
  // ============================================

  /// Organizasyon sayım özeti
  Future<EntityCountSummary> getOrganizationSummary(
    String tenantId, {
    bool forceRefresh = false,
  }) async {
    try {
      final cacheKey = 'org_summary_$tenantId';

      if (!forceRefresh) {
        final cached = await _cacheManager.getTyped<EntityCountSummary>(
          key: cacheKey,
          fromJson: EntityCountSummary.fromJson,
        );
        if (cached != null) return cached;
      }

      final total = await _getOrganizationCount(tenantId, activeOnly: false);
      final active = await _getOrganizationCount(tenantId, activeOnly: true);

      final summary = EntityCountSummary(
        total: total,
        active: active,
        inactive: total - active,
        generatedAt: DateTime.now(),
      );

      await _cacheManager.set(
        cacheKey,
        summary.toJson(),
        ttl: _statsCacheDuration,
      );

      return summary;
    } catch (e) {
      Logger.error('Failed to get organization summary', e);
      return EntityCountSummary(
        total: 0,
        active: 0,
        inactive: 0,
        generatedAt: DateTime.now(),
      );
    }
  }

  /// Site sayım özeti
  Future<EntityCountSummary> getSiteSummary(
    String tenantId, {
    String? organizationId,
    bool forceRefresh = false,
  }) async {
    try {
      final cacheKey = organizationId != null
          ? 'site_summary_$organizationId'
          : 'site_summary_tenant_$tenantId';

      if (!forceRefresh) {
        final cached = await _cacheManager.getTyped<EntityCountSummary>(
          key: cacheKey,
          fromJson: EntityCountSummary.fromJson,
        );
        if (cached != null) return cached;
      }

      final total = await _getSiteCount(
        tenantId,
        organizationId: organizationId,
        activeOnly: false,
      );
      final active = await _getSiteCount(
        tenantId,
        organizationId: organizationId,
        activeOnly: true,
      );

      final summary = EntityCountSummary(
        total: total,
        active: active,
        inactive: total - active,
        generatedAt: DateTime.now(),
      );

      await _cacheManager.set(
        cacheKey,
        summary.toJson(),
        ttl: _statsCacheDuration,
      );

      return summary;
    } catch (e) {
      Logger.error('Failed to get site summary', e);
      return EntityCountSummary(
        total: 0,
        active: 0,
        inactive: 0,
        generatedAt: DateTime.now(),
      );
    }
  }

  /// Unit sayım özeti
  Future<EntityCountSummary> getUnitSummary(
    String tenantId, {
    String? siteId,
    bool forceRefresh = false,
  }) async {
    try {
      final cacheKey = siteId != null
          ? 'unit_summary_$siteId'
          : 'unit_summary_tenant_$tenantId';

      if (!forceRefresh) {
        final cached = await _cacheManager.getTyped<EntityCountSummary>(
          key: cacheKey,
          fromJson: EntityCountSummary.fromJson,
        );
        if (cached != null) return cached;
      }

      final total = await _getUnitCount(
        tenantId,
        siteId: siteId,
        activeOnly: false,
      );
      final active = await _getUnitCount(
        tenantId,
        siteId: siteId,
        activeOnly: true,
      );

      final summary = EntityCountSummary(
        total: total,
        active: active,
        inactive: total - active,
        generatedAt: DateTime.now(),
      );

      await _cacheManager.set(
        cacheKey,
        summary.toJson(),
        ttl: _statsCacheDuration,
      );

      return summary;
    } catch (e) {
      Logger.error('Failed to get unit summary', e);
      return EntityCountSummary(
        total: 0,
        active: 0,
        inactive: 0,
        generatedAt: DateTime.now(),
      );
    }
  }

  // ============================================
  // ACTIVITY STATS
  // ============================================

  /// Aktivite istatistiklerini getir
  Future<ActivityStats> getActivityStats(
    String tenantId, {
    ReportPeriod period = ReportPeriod.thisMonth,
    bool forceRefresh = false,
  }) async {
    try {
      final cacheKey = 'activity_stats_${tenantId}_${period.value}';

      if (!forceRefresh) {
        final cached = await _cacheManager.getTyped<ActivityStats>(
          key: cacheKey,
          fromJson: ActivityStats.fromJson,
        );
        if (cached != null) return cached;
      }

      final dateRange = period.getDateRange();

      // Aktiviteleri getir
      final response = await _supabase
          .from('activity_logs')
          .select('action_type, entity_type, created_at')
          .eq('tenant_id', tenantId)
          .gte('created_at', dateRange.start.toIso8601String())
          .lt('created_at', dateRange.end.toIso8601String());

      final activities = response as List<dynamic>;

      // Tipe göre grupla
      final byType = <String, int>{};
      final byEntity = <String, int>{};

      for (final activity in activities) {
        final actionType = activity['action_type'] as String?;
        final entityType = activity['entity_type'] as String?;

        if (actionType != null) {
          byType[actionType] = (byType[actionType] ?? 0) + 1;
        }
        if (entityType != null) {
          byEntity[entityType] = (byEntity[entityType] ?? 0) + 1;
        }
      }

      // Zaman serisi oluştur
      final timeSeries = await _getActivityTimeSeries(tenantId, dateRange);

      final stats = ActivityStats(
        totalCount: activities.length,
        byType: byType,
        byEntity: byEntity,
        timeSeries: timeSeries,
        generatedAt: DateTime.now(),
      );

      await _cacheManager.set(
        cacheKey,
        stats.toJson(),
        ttl: _statsCacheDuration,
      );

      Logger.debug('Activity stats generated for tenant: $tenantId');
      return stats;
    } catch (e) {
      Logger.error('Failed to get activity stats', e);
      return ActivityStats(
        totalCount: 0,
        byType: {},
        byEntity: {},
        timeSeries: [],
        generatedAt: DateTime.now(),
      );
    }
  }

  Future<List<ActivityTimeSeriesData>> _getActivityTimeSeries(
    String tenantId,
    DateRange range,
  ) async {
    try {
      // Günlük gruplandırma
      final response = await _supabase.rpc(
        'get_activity_daily_counts',
        params: {
          'p_tenant_id': tenantId,
          'p_start_date': range.start.toIso8601String(),
          'p_end_date': range.end.toIso8601String(),
        },
      );

      if (response is List) {
        return response.map((item) {
          return ActivityTimeSeriesData(
            date: DateTime.parse(item['date'] as String),
            count: item['count'] as int,
          );
        }).toList();
      }

      // Fallback: Manuel hesaplama
      return _calculateTimeSeries(tenantId, range);
    } catch (e) {
      // RPC yoksa manuel hesapla
      return _calculateTimeSeries(tenantId, range);
    }
  }

  Future<List<ActivityTimeSeriesData>> _calculateTimeSeries(
    String tenantId,
    DateRange range,
  ) async {
    final result = <ActivityTimeSeriesData>[];
    var current = range.start;

    while (current.isBefore(range.end)) {
      final dayEnd = current.add(const Duration(days: 1));
      final dayRange = DateRange(start: current, end: dayEnd);

      final count = await _getActivityCountInRange(tenantId, dayRange);

      result.add(ActivityTimeSeriesData(
        date: current,
        count: count,
      ));

      current = dayEnd;
    }

    return result;
  }

  // ============================================
  // REPORTS
  // ============================================

  /// Rapor oluştur
  Future<ReportResult> generateReport(ReportRequest request) async {
    try {
      Logger.info('Generating report: ${request.type.value}');

      final dateRange = request.effectiveDateRange;
      dynamic data;
      String title;

      switch (request.type) {
        case ReportType.summary:
          title = 'Özet Rapor';
          data = await _generateSummaryReport(request, dateRange);
          break;
        case ReportType.activity:
          title = 'Aktivite Raporu';
          data = await _generateActivityReport(request, dateRange);
          break;
        case ReportType.inventory:
          title = 'Envanter Raporu';
          data = await _generateInventoryReport(request, dateRange);
          break;
        case ReportType.performance:
          title = 'Performans Raporu';
          data = await _generatePerformanceReport(request, dateRange);
          break;
        case ReportType.custom:
          title = 'Özel Rapor';
          data = await _generateCustomReport(request, dateRange);
          break;
      }

      final result = ReportResult(
        id: _generateReportId(),
        type: request.type,
        format: request.format,
        title: title,
        dateRange: dateRange,
        generatedAt: DateTime.now(),
        data: data,
        metadata: {
          'tenant_id': request.tenantId,
          'organization_id': request.organizationId,
          'site_id': request.siteId,
          'filters': request.filters,
        },
      );

      Logger.info('Report generated: ${result.id}');
      return result;
    } catch (e) {
      Logger.error('Failed to generate report', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _generateSummaryReport(
    ReportRequest request,
    DateRange range,
  ) async {
    final tenantId = request.tenantId!;

    final orgSummary = await getOrganizationSummary(tenantId);
    final siteSummary = await getSiteSummary(tenantId);
    final unitSummary = await getUnitSummary(tenantId);

    return {
      'organizations': orgSummary.toJson(),
      'sites': siteSummary.toJson(),
      'units': unitSummary.toJson(),
      'date_range': {
        'start': range.start.toIso8601String(),
        'end': range.end.toIso8601String(),
      },
    };
  }

  Future<Map<String, dynamic>> _generateActivityReport(
    ReportRequest request,
    DateRange range,
  ) async {
    final tenantId = request.tenantId!;

    // Aktiviteleri getir
    var query = _supabase
        .from('activity_logs')
        .select()
        .eq('tenant_id', tenantId)
        .gte('created_at', range.start.toIso8601String())
        .lt('created_at', range.end.toIso8601String());

    if (request.organizationId != null) {
      query = query.eq('organization_id', request.organizationId!);
    }
    if (request.siteId != null) {
      query = query.eq('site_id', request.siteId!);
    }

    final response = await query.order('created_at', ascending: false);

    return {
      'activities': response,
      'total_count': response.length,
      'date_range': {
        'start': range.start.toIso8601String(),
        'end': range.end.toIso8601String(),
      },
    };
  }

  Future<Map<String, dynamic>> _generateInventoryReport(
    ReportRequest request,
    DateRange range,
  ) async {
    final tenantId = request.tenantId!;

    // Organizasyonlar
    final orgsResponse = await _supabase
        .from('organizations')
        .select('id, name, code, active, created_at')
        .eq('tenant_id', tenantId);

    // Siteler
    final sitesResponse = await _supabase
        .from('sites')
        .select('id, name, code, organization_id, active, created_at')
        .eq('tenant_id', tenantId);

    // Üniteler
    final unitsResponse = await _supabase
        .from('units')
        .select('id, name, code, site_id, active, created_at')
        .eq('tenant_id', tenantId);

    return {
      'organizations': orgsResponse,
      'sites': sitesResponse,
      'units': unitsResponse,
      'summary': {
        'organization_count': orgsResponse.length,
        'site_count': sitesResponse.length,
        'unit_count': unitsResponse.length,
      },
    };
  }

  Future<Map<String, dynamic>> _generatePerformanceReport(
    ReportRequest request,
    DateRange range,
  ) async {
    // Performans metrikleri (aktivite bazlı)
    final stats = await getActivityStats(
      request.tenantId!,
      period: request.period,
    );

    return {
      'activity_stats': stats.toJson(),
      'period': request.period.value,
      'date_range': {
        'start': range.start.toIso8601String(),
        'end': range.end.toIso8601String(),
      },
    };
  }

  Future<Map<String, dynamic>> _generateCustomReport(
    ReportRequest request,
    DateRange range,
  ) async {
    // Özel filtreler ile rapor
    final result = <String, dynamic>{
      'filters': request.filters,
      'date_range': {
        'start': range.start.toIso8601String(),
        'end': range.end.toIso8601String(),
      },
    };

    // İstenen alanları ekle
    if (request.includeFields != null) {
      for (final field in request.includeFields!) {
        switch (field) {
          case 'organizations':
            result['organizations'] = await _getOrganizationCount(
              request.tenantId!,
            );
            break;
          case 'sites':
            result['sites'] = await _getSiteCount(request.tenantId!);
            break;
          case 'units':
            result['units'] = await _getUnitCount(request.tenantId!);
            break;
          case 'activities':
            result['activities'] = await _getActivityCount(
              request.tenantId!,
              request.period,
            );
            break;
        }
      }
    }

    return result;
  }

  // ============================================
  // PRIVATE HELPERS
  // ============================================

  Future<int> _getOrganizationCount(
    String tenantId, {
    bool activeOnly = true,
  }) async {
    try {
      var query = _supabase
          .from('organizations')
          .select()
          .eq('tenant_id', tenantId);

      if (activeOnly) {
        query = query.eq('active', true);
      }

      final response = await query.count(CountOption.exact);
      return response.count ?? 0;
    } catch (e) {
      Logger.error('Failed to get organization count', e);
      return 0;
    }
  }

  Future<int> _getSiteCount(
    String tenantId, {
    String? organizationId,
    bool activeOnly = true,
  }) async {
    try {
      var query = _supabase.from('sites').select().eq('tenant_id', tenantId);

      if (organizationId != null) {
        query = query.eq('organization_id', organizationId);
      }
      if (activeOnly) {
        query = query.eq('active', true);
      }

      final response = await query.count(CountOption.exact);
      return response.count ?? 0;
    } catch (e) {
      Logger.error('Failed to get site count', e);
      return 0;
    }
  }

  Future<int> _getUnitCount(
    String tenantId, {
    String? siteId,
    bool activeOnly = true,
  }) async {
    try {
      var query = _supabase.from('units').select().eq('tenant_id', tenantId);

      if (siteId != null) {
        query = query.eq('site_id', siteId);
      }
      if (activeOnly) {
        query = query.eq('active', true);
      }

      final response = await query.count(CountOption.exact);
      return response.count ?? 0;
    } catch (e) {
      Logger.error('Failed to get unit count', e);
      return 0;
    }
  }

  Future<int> _getActiveUserCount(String tenantId) async {
    try {
      final response = await _supabase
          .from('tenant_users')
          .select()
          .eq('tenant_id', tenantId)
          .eq('status', 'active')
          .count(CountOption.exact);

      return response.count ?? 0;
    } catch (e) {
      Logger.error('Failed to get active user count', e);
      return 0;
    }
  }

  Future<int> _getActivityCount(String tenantId, ReportPeriod period) async {
    final range = period.getDateRange();
    return _getActivityCountInRange(tenantId, range);
  }

  Future<int> _getActivityCountInRange(String tenantId, DateRange range) async {
    try {
      final response = await _supabase
          .from('activity_logs')
          .select()
          .eq('tenant_id', tenantId)
          .gte('created_at', range.start.toIso8601String())
          .lt('created_at', range.end.toIso8601String())
          .count(CountOption.exact);

      return response.count ?? 0;
    } catch (e) {
      Logger.error('Failed to get activity count', e);
      return 0;
    }
  }

  Future<int> _getPendingNotificationCount(String tenantId) async {
    try {
      // Önce kullanıcının profile_id'sini al
      final user = _supabase.auth.currentUser;
      if (user == null) return 0;

      final response = await _supabase
          .from('notifications')
          .select()
          .eq('profile_id', user.id)
          .eq('read', false)
          .count(CountOption.exact);

      return response.count ?? 0;
    } catch (e) {
      Logger.error('Failed to get pending notification count', e);
      return 0;
    }
  }

  String _generateReportId() {
    return 'report_${DateTime.now().millisecondsSinceEpoch}';
  }

  // ============================================
  // CACHE MANAGEMENT
  // ============================================

  /// Dashboard cache'ini temizle
  Future<void> clearDashboardCache(String tenantId) async {
    await _cacheManager.deleteByPrefix('dashboard_summary_$tenantId');
    Logger.debug('Dashboard cache cleared for tenant: $tenantId');
  }

  /// Tüm reporting cache'lerini temizle
  Future<void> clearAllCache(String tenantId) async {
    await Future.wait([
      _cacheManager.deleteByPrefix('dashboard_summary_$tenantId'),
      _cacheManager.deleteByPrefix('activity_stats_$tenantId'),
      _cacheManager.deleteByPrefix('org_summary_$tenantId'),
      _cacheManager.deleteByPrefix('site_summary_'),
      _cacheManager.deleteByPrefix('unit_summary_'),
    ]);
    Logger.debug('All reporting cache cleared for tenant: $tenantId');
  }
}
