import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class AlarmDashboardScreen extends StatefulWidget {
  const AlarmDashboardScreen({super.key});

  @override
  State<AlarmDashboardScreen> createState() => _AlarmDashboardScreenState();
}

class _AlarmDashboardScreenState extends State<AlarmDashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  int _selectedDays = 30;
  AlarmDistribution _distribution = const AlarmDistribution(
    activeCount: 0,
    resetCount: 0,
  );
  List<AlarmTimelineEntry> _timeline = [];
  List<Alarm> _activeAlarms = [];
  List<AlarmHistory> _resetAlarms = [];
  Map<String, Priority> _priorityMap = {};
  AlarmMttrStats _mttrStats = const AlarmMttrStats(overallMttr: Duration.zero);
  List<AlarmFrequency> _topAlarms = [];
  AlarmHeatmapData _heatmapData = AlarmHeatmapData(
    matrix: List.generate(7, (_) => List.filled(24, 0)),
    maxCount: 0,
    weekStart: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final tenantId = tenantService.currentTenantId;
    if (tenantId != null) {
      alarmService.setTenant(tenantId);
    }

    try {
      // Load priorities
      final priorities = await priorityService.getAll(forceRefresh: true);
      final pMap = <String, Priority>{};
      for (final p in priorities) {
        pMap[p.id] = p;
      }

      // Parallel loading
      final results = await Future.wait([
        alarmService.getAlarmDistribution(
          days: _selectedDays,
          forceRefresh: true,
        ),
        alarmService.getAlarmTimeline(
          days: _selectedDays,
          forceRefresh: true,
        ),
        alarmService.getActiveAlarms(),
        alarmService.getResetAlarms(
          days: _selectedDays,
          limit: 50,
          forceRefresh: true,
        ),
        alarmService.getMttrStats(
          days: _selectedDays,
          forceRefresh: true,
        ),
        alarmService.getTopAlarms(
          days: _selectedDays,
          limit: 10,
          forceRefresh: true,
        ),
        alarmService.getAlarmHeatmap(forceRefresh: true),
      ]);

      if (mounted) {
        setState(() {
          _priorityMap = pMap;
          _distribution = results[0] as AlarmDistribution;
          _timeline = results[1] as List<AlarmTimelineEntry>;
          _activeAlarms = results[2] as List<Alarm>;
          _resetAlarms = results[3] as List<AlarmHistory>;
          _mttrStats = results[4] as AlarmMttrStats;
          _topAlarms = results[5] as List<AlarmFrequency>;
          _heatmapData = results[6] as AlarmHeatmapData;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load alarm dashboard', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Veriler yuklenirken hata olustu';
          _isLoading = false;
        });
      }
    }
  }

  void _onPeriodChanged(int days) {
    setState(() => _selectedDays = days);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Alarm Yonetimi',
      onBack: () => context.go('/dashboard'),
      actions: [
        AppIconButton(
          icon: Icons.refresh,
          onPressed: _loadData,
        ),
      ],
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: AppLoadingIndicator())
            : _errorMessage != null
                ? Center(
                    child: AppErrorView(
                      message: _errorMessage!,
                      onRetry: _loadData,
                    ),
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.sm),

                        // Summary MetricCards
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenHorizontal,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: MetricCard(
                                  title: 'Aktif',
                                  value: '${_distribution.activeCount}',
                                  icon: Icons.warning_amber_rounded,
                                  color: AppColors.error,
                                  onTap: () => context.push('/alarms/active'),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: MetricCard(
                                  title: 'Reset',
                                  value: '${_distribution.resetCount}',
                                  icon: Icons.restart_alt,
                                  color: AppColors.success,
                                  onTap: () => context.push('/alarms/history'),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: MetricCard(
                                  title: 'Toplam',
                                  value: '${_distribution.totalCount}',
                                  icon: Icons.notifications_outlined,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppSpacing.md),

                        // Distribution Pie Chart
                        ChartContainer(
                          title: 'Alarm Dagilimi',
                          subtitle: 'Aktif vs Reset',
                          isEmpty: _distribution.totalCount == 0,
                          emptyMessage: 'Alarm kaydi bulunamadi',
                          child: AlarmPieChart(
                            distribution: _distribution,
                            size: 180,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Trend Bar Chart
                        ChartContainer(
                          title: 'Alarm Trendi',
                          subtitle: 'Son $_selectedDays gun',
                          trailing: ChartPeriodSelector(
                            selectedDays: _selectedDays,
                            onChanged: _onPeriodChanged,
                          ),
                          isEmpty: _timeline.every((e) => e.totalCount == 0),
                          emptyMessage: 'Bu donemde alarm kaydi yok',
                          child: AlarmBarChart(
                            entries: _timeline,
                            priorities: _priorityMap,
                            height: 180,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Priority Trend (Stacked Area)
                        ChartContainer(
                          title: 'Priority Trendi',
                          subtitle: 'Son $_selectedDays gun',
                          isEmpty: _timeline.every((e) => e.totalCount == 0),
                          emptyMessage: 'Bu donemde alarm kaydi yok',
                          child: AlarmPriorityTrendChart(
                            entries: _timeline,
                            priorities: _priorityMap,
                            height: 180,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // MTTR Card
                        ChartContainer(
                          title: 'Ortalama Cozum Suresi (MTTR)',
                          subtitle: 'Son $_selectedDays gun',
                          isEmpty: _mttrStats.totalAlarmCount == 0,
                          emptyMessage: 'Cozulmus alarm bulunamadi',
                          child: AlarmMttrCard(
                            stats: _mttrStats,
                            priorities: _priorityMap,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Top Offenders
                        ChartContainer(
                          title: 'En Sik Tekrarlayan Alarmlar',
                          subtitle: 'Son $_selectedDays gun - Top 10',
                          isEmpty: _topAlarms.isEmpty,
                          emptyMessage: 'Alarm verisi bulunamadi',
                          child: AlarmTopOffendersCard(
                            alarms: _topAlarms,
                            priorities: _priorityMap,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Heatmap
                        ChartContainer(
                          title: 'Alarm Yogunluk Haritasi',
                          subtitle: 'Haftalik gun x saat dagilimi',
                          isEmpty: _heatmapData.totalCount == 0,
                          emptyMessage: 'Bu haftada alarm kaydi yok',
                          child: AlarmHeatmapChart(
                            data: _heatmapData,
                            height: 200,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.md),

                        // Active Alarms List
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenHorizontal,
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Aktif Alarmlar',
                                style: AppTypography.title3,
                              ),
                              const Spacer(),
                              if (_activeAlarms.isNotEmpty)
                                TextButton(
                                  onPressed: () => context.push('/alarms/active'),
                                  child: Text(
                                    'Tumunu Gor',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenHorizontal,
                          ),
                          child: AppCard(
                            child: ActiveAlarmList(
                              alarms: _activeAlarms.take(5).toList(),
                              priorities: _priorityMap,
                              emptyMessage: 'Aktif alarm bulunmuyor',
                              onAlarmTap: (alarm) {
                                ActiveAlarmDetailSheet.show(
                                  context,
                                  alarm: alarm,
                                  priority: alarm.priorityId != null
                                      ? _priorityMap[alarm.priorityId!]
                                      : null,
                                );
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.md),

                        // Reset Alarms
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenHorizontal,
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Son Resetlenen Alarmlar',
                                style: AppTypography.title3,
                              ),
                              const Spacer(),
                              if (_resetAlarms.isNotEmpty)
                                TextButton(
                                  onPressed: () => context.push('/alarms/history'),
                                  child: Text(
                                    'Tumunu Gor',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenHorizontal,
                          ),
                          child: AppCard(
                            child: ResetAlarmList(
                              alarms: _resetAlarms.take(5).toList(),
                              priorities: _priorityMap,
                              emptyMessage: 'Resetlenmis alarm bulunmuyor',
                              onAlarmTap: (alarm) {
                                AlarmDetailSheet.show(
                                  context,
                                  alarm: alarm,
                                  priority: alarm.priorityId != null
                                      ? _priorityMap[alarm.priorityId!]
                                      : null,
                                );
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
      ),
    );
  }
}
