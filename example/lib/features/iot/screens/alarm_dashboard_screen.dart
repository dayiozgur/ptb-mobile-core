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
  List<AlarmHistory> _resetAlarms = [];
  Map<String, Priority> _priorityMap = {};

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
      // Priority'leri yükle
      final priorities = await priorityService.getAll();
      final pMap = <String, Priority>{};
      for (final p in priorities) {
        pMap[p.id] = p;
      }

      // Paralel yükleme
      final results = await Future.wait([
        alarmService.getAlarmDistribution(days: _selectedDays),
        alarmService.getAlarmTimeline(days: _selectedDays),
        alarmService.getResetAlarms(days: _selectedDays, limit: 20),
      ]);

      if (mounted) {
        setState(() {
          _priorityMap = pMap;
          _distribution = results[0] as AlarmDistribution;
          _timeline = results[1] as List<AlarmTimelineEntry>;
          _resetAlarms = results[2] as List<AlarmHistory>;
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

                        // Bölüm 1: Özet MetricCards
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
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: _SummaryCard(
                                  label: 'Reset',
                                  value: _distribution.resetCount,
                                  color: AppColors.success,
                                  icon: Icons.restart_alt,
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

                        const SizedBox(height: AppSpacing.md),

                        // Bölüm 4: Resetli Alarm Listesi
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenHorizontal,
                          ),
                          child: AppSectionHeader(
                            title: 'Resetlenmiş Alarmlar',
                            subtitle:
                                'alarm_histories - Son $_selectedDays gün',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenHorizontal,
                          ),
                          child: AppCard(
                            child: ResetAlarmList(
                              alarms: _resetAlarms,
                              priorities: _priorityMap,
                              onAlarmTap: (alarm) {
                                AlarmDetailSheet.show(
                                  context,
                                  alarm: alarm,
                                  priority: alarm.priorityId != null
                                      ? _priorityMap[
                                          alarm.priorityId!]
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

class _SummaryCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return AppCard(
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
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(brightness),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
