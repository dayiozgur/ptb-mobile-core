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

  int _selectedTabIndex = 0; // 0: Aktif, 1: Resetlenmiş
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
  List<SiteAlarmCount> _siteAlarmCounts = [];
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
      // Priority'leri ve site'ları yükle
      final orgId = organizationService.currentOrganizationId;
      final prioritiesFuture = priorityService.getAll();
      final sitesFuture = orgId != null ? siteService.getSites(orgId) : Future.value(<Site>[]);
      final priorities = await prioritiesFuture;
      final sites = await sitesFuture;
      final pMap = <String, Priority>{};
      for (final p in priorities) {
        pMap[p.id] = p;
      }
      final siteNames = <String, String>{};
      for (final s in sites) {
        siteNames[s.id] = s.name;
      }

      // Paralel yükleme - forceRefresh ile cache bypass
      // Aktif alarmlar: alarms tablosundan
      // Resetlenmiş alarmlar: alarm_histories tablosundan
      final results = await Future.wait([
        alarmService.getAlarmDistribution(
          days: _selectedDays,
          forceRefresh: true,
        ),
        alarmService.getAlarmTimeline(
          days: _selectedDays,
          forceRefresh: true,
        ),
        alarmService.getActiveAlarms(), // alarms tablosu
        alarmService.getResetAlarms(    // alarm_histories tablosu
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
        alarmService.getAlarmCountsBySite(
          siteNames: siteNames,
          days: _selectedDays,
          forceRefresh: true,
        ),
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
          _siteAlarmCounts = results[7] as List<SiteAlarmCount>;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load alarm dashboard', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Veriler yüklenirken hata oluştu';
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
      title: 'Alarm Yönetimi',
      onBack: () => context.go('/iot'),
      actions: [
        AppIconButton(
          icon: Icons.refresh,
          onPressed: _loadData,
        ),
      ],
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator.adaptive())
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

                        // Bölüm 1: Özet MetricCards (tıklanabilir)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenHorizontal,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _SummaryCard(
                                  label: 'Aktif',
                                  value: _distribution.activeCount,
                                  color: AppColors.error,
                                  icon: Icons.warning_amber_rounded,
                                  onTap: () => context.go('/iot/alarms/active'),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: _SummaryCard(
                                  label: 'Reset',
                                  value: _distribution.resetCount,
                                  color: AppColors.success,
                                  icon: Icons.restart_alt,
                                  onTap: () => context.go('/iot/alarms/history'),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: _SummaryCard(
                                  label: 'Toplam',
                                  value: _distribution.totalCount,
                                  color: AppColors.primary,
                                  icon: Icons.notifications_outlined,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppSpacing.md),

                        // Bölüm 2: Alarm Dağılım Chart
                        ChartContainer(
                          title: 'Alarm Dağılımı',
                          subtitle: 'Aktif vs Reset',
                          isEmpty: _distribution.totalCount == 0,
                          emptyMessage: 'Alarm kaydı bulunamadı',
                          child: AlarmPieChart(
                            distribution: _distribution,
                            priorities: _priorityMap,
                            showToggle: true,
                            showPriorityBreakdown: true,
                            size: 180,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Bölüm 3: Alarm Trend Chart
                        ChartContainer(
                          title: 'Alarm Trendi',
                          subtitle: 'Son $_selectedDays gün',
                          trailing: ChartPeriodSelector(
                            selectedDays: _selectedDays,
                            onChanged: _onPeriodChanged,
                          ),
                          isEmpty: _timeline.every(
                              (e) => e.totalCount == 0),
                          emptyMessage:
                              'Bu dönemde alarm kaydı yok',
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
                          subtitle: 'Son $_selectedDays gün',
                          isEmpty: _timeline.every((e) => e.totalCount == 0),
                          emptyMessage: 'Bu dönemde alarm kaydı yok',
                          child: AlarmPriorityTrendChart(
                            entries: _timeline,
                            priorities: _priorityMap,
                            height: 180,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // MTTR Card
                        ChartContainer(
                          title: 'Ortalama Çözüm Süresi (MTTR)',
                          subtitle: 'Son $_selectedDays gün',
                          isEmpty: _mttrStats.totalAlarmCount == 0,
                          emptyMessage: 'Çözülmüş alarm bulunamadı',
                          child: AlarmMttrCard(
                            stats: _mttrStats,
                            priorities: _priorityMap,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Top Offenders
                        ChartContainer(
                          title: 'En Sık Tekrarlayan Alarmlar',
                          subtitle: 'Son $_selectedDays gün - Top 10',
                          isEmpty: _topAlarms.isEmpty,
                          emptyMessage: 'Alarm verisi bulunamadı',
                          child: AlarmTopOffendersCard(
                            alarms: _topAlarms,
                            priorities: _priorityMap,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Heatmap
                        ChartContainer(
                          title: 'Alarm Yoğunluk Haritası',
                          subtitle: 'Haftalık gün x saat dağılımı',
                          isEmpty: _heatmapData.totalCount == 0,
                          emptyMessage: 'Bu haftada alarm kaydı yok',
                          child: AlarmHeatmapChart(
                            data: _heatmapData,
                            height: 200,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Site Alarm Ranking
                        ChartContainer(
                          title: 'Site Alarm Sıralaması',
                          subtitle: 'Son $_selectedDays gün - Top 10',
                          isEmpty: _siteAlarmCounts.isEmpty,
                          emptyMessage: 'Site alarm verisi bulunamadı',
                          child: AlarmSiteRankingChart(
                            sites: _siteAlarmCounts,
                            height: 300,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.md),

                        // Bölüm 4: Alarm Listeleri (Tab ile)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenHorizontal,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _AlarmListTabs(
                                  selectedIndex: _selectedTabIndex,
                                  activeCount: _activeAlarms.length,
                                  resetCount: _resetAlarms.length,
                                  onTabChanged: (index) {
                                    setState(() => _selectedTabIndex = index);
                                  },
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              // Tümünü Gör butonu
                              GestureDetector(
                                onTap: () {
                                  if (_selectedTabIndex == 0) {
                                    context.go('/iot/alarms/active');
                                  } else {
                                    context.go('/iot/alarms/history');
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: AppSpacing.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Tümü',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 12,
                                        color: AppColors.primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // Tab içeriği
                        if (_selectedTabIndex == 0) ...[
                          // Aktif Alarmlar (alarms tablosu)
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
                          // Daha fazla alarm varsa göster
                          if (_activeAlarms.length > 5)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.screenHorizontal,
                              ),
                              child: TextButton(
                                onPressed: () => context.go('/iot/alarms/active'),
                                child: Text(
                                  '${_activeAlarms.length - 5} alarm daha...',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                        ] else ...[
                          // Resetlenmiş Alarmlar (alarm_histories tablosu)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.screenHorizontal,
                            ),
                            child: Text(
                              'Son $_selectedDays gün',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary(
                                  Theme.of(context).brightness,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.screenHorizontal,
                            ),
                            child: AppCard(
                              child: ResetAlarmList(
                                alarms: _resetAlarms.take(5).toList(),
                                priorities: _priorityMap,
                                emptyMessage: 'Resetlenmiş alarm bulunmuyor',
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
                          // Daha fazla alarm varsa göster
                          if (_resetAlarms.length > 5)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.screenHorizontal,
                              ),
                              child: TextButton(
                                onPressed: () => context.go('/iot/alarms/history'),
                                child: Text(
                                  '${_resetAlarms.length - 5} alarm daha...',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                        ],

                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(brightness),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 10,
                    color: AppColors.textSecondary(brightness),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Alarm listesi tab seçici widget'ı
class _AlarmListTabs extends StatelessWidget {
  final int selectedIndex;
  final int activeCount;
  final int resetCount;
  final ValueChanged<int> onTabChanged;

  const _AlarmListTabs({
    required this.selectedIndex,
    required this.activeCount,
    required this.resetCount,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.systemGray6,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: 'Aktif',
              count: activeCount,
              isSelected: selectedIndex == 0,
              color: AppColors.error,
              brightness: brightness,
              onTap: () => onTabChanged(0),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _TabButton(
              label: 'Resetlenmiş',
              count: resetCount,
              isSelected: selectedIndex == 1,
              color: AppColors.success,
              brightness: brightness,
              onTap: () => onTabChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final Color color;
  final Brightness brightness;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.color,
    required this.brightness,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (brightness == Brightness.light ? Colors.white : AppColors.systemGray5)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? AppColors.textPrimary(brightness)
                    : AppColors.textSecondary(brightness),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.15)
                    : AppColors.systemGray5,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? color : AppColors.textSecondary(brightness),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
