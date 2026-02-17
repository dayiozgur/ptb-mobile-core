import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Global Alarms Screen - Organization seviyesinde tum alarmlari gosterir
class GlobalAlarmsScreen extends StatefulWidget {
  const GlobalAlarmsScreen({super.key});

  @override
  State<GlobalAlarmsScreen> createState() => _GlobalAlarmsScreenState();
}

class _GlobalAlarmsScreenState extends State<GlobalAlarmsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  // Data
  List<Alarm> _activeAlarms = [];
  List<AlarmHistory> _resetAlarms = [];
  AlarmDistribution _distribution = const AlarmDistribution(
    activeCount: 0,
    resetCount: 0,
  );
  List<AlarmTimelineEntry> _timeline = [];
  Map<String, Priority> _priorityMap = {};
  Map<String, Site> _siteMap = {};

  // Filters
  int _selectedDays = 90;
  String? _selectedSiteId;
  String? _selectedPriorityId;
  String _searchQuery = '';

  // Sites for filter
  List<Site> _sites = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final tenantId = tenantService.currentTenantId;
    final orgId = organizationService.currentOrganizationId;

    if (tenantId != null) {
      alarmService.setTenant(tenantId);
    }
    if (orgId != null) {
      alarmService.setOrganization(orgId);
    }

    try {
      // Load priorities
      final priorities = await priorityService.getAll(forceRefresh: true);
      final pMap = <String, Priority>{};
      for (final p in priorities) {
        pMap[p.id] = p;
      }

      // Load sites for filter
      List<Site> sites = [];
      if (orgId != null) {
        try {
          sites = await siteService.getSites(orgId);
        } catch (_) {}
      }

      final siteMap = <String, Site>{};
      for (final site in sites) {
        siteMap[site.id] = site;
      }

      // Load alarms data
      final results = await Future.wait([
        alarmService.getAlarmDistribution(
          days: _selectedDays,
          forceRefresh: true,
        ),
        alarmService.getAlarmTimeline(
          days: _selectedDays,
          forceRefresh: true,
        ),
        alarmService.getActiveAlarms(includeVariable: true),
        alarmService.getResetAlarms(
          days: _selectedDays,
          limit: 100,
          forceRefresh: true,
        ),
      ]);

      if (mounted) {
        setState(() {
          _priorityMap = pMap;
          _siteMap = siteMap;
          _sites = sites;
          _distribution = results[0] as AlarmDistribution;
          _timeline = results[1] as List<AlarmTimelineEntry>;
          _activeAlarms = results[2] as List<Alarm>;
          _resetAlarms = results[3] as List<AlarmHistory>;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load global alarms', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Veriler yuklenirken hata olustu';
          _isLoading = false;
        });
      }
    }
  }

  List<Alarm> get _filteredActiveAlarms {
    var alarms = _activeAlarms;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      alarms = alarms.where((a) {
        return (a.name?.toLowerCase().contains(query) ?? false) ||
            (a.code?.toLowerCase().contains(query) ?? false) ||
            (a.effectiveDescription?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    if (_selectedPriorityId != null) {
      alarms = alarms.where((a) => a.priorityId == _selectedPriorityId).toList();
    }

    return alarms;
  }

  List<AlarmHistory> get _filteredResetAlarms {
    var alarms = _resetAlarms;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      alarms = alarms.where((a) {
        return (a.name?.toLowerCase().contains(query) ?? false) ||
            (a.code?.toLowerCase().contains(query) ?? false) ||
            (a.effectiveDescription?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    if (_selectedSiteId != null) {
      alarms = alarms.where((a) => a.siteId == _selectedSiteId).toList();
    }

    if (_selectedPriorityId != null) {
      alarms = alarms.where((a) => a.priorityId == _selectedPriorityId).toList();
    }

    return alarms;
  }

  void _onPeriodChanged(int days) {
    setState(() => _selectedDays = days);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Alarmlar',
      showBackButton: false,
      actions: [
        AppIconButton(
          icon: Icons.filter_list,
          onPressed: _showFilterSheet,
        ),
        AppIconButton(
          icon: Icons.refresh,
          onPressed: _loadData,
        ),
      ],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _errorMessage != null
              ? Center(
                  child: AppErrorView(
                    message: _errorMessage!,
                    onRetry: _loadData,
                  ),
                )
              : Column(
                  children: [
                    // Summary Cards
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                      child: _buildSummaryCards(),
                    ),

                    // Period Selector
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenHorizontal,
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [7, 14, 30, 60, 90, 180].map((days) {
                            final isSelected = _selectedDays == days;
                            return Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.xs),
                              child: ChoiceChip(
                                label: Text('$days gun'),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) _onPeriodChanged(days);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenHorizontal,
                      ),
                      child: AppSearchField(
                        placeholder: 'Alarm ara...',
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                        },
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Active Filters
                    if (_selectedSiteId != null || _selectedPriorityId != null)
                      _buildActiveFilters(),

                    // Tabs
                    TabBar(
                      controller: _tabController,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.secondaryLabel(context),
                      indicatorColor: AppColors.primary,
                      tabs: [
                        const Tab(text: 'Dashboard'),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Aktif'),
                              if (_filteredActiveAlarms.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                _CountBadge(
                                  count: _filteredActiveAlarms.length,
                                  color: AppColors.error,
                                ),
                              ],
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Gecmis'),
                              if (_filteredResetAlarms.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                _CountBadge(
                                  count: _filteredResetAlarms.length,
                                  color: AppColors.success,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Tab Content
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildDashboardTab(),
                          _buildActiveAlarmsTab(),
                          _buildHistoryTab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Aktif',
            value: _distribution.activeCount,
            color: AppColors.error,
            icon: Icons.warning_amber_rounded,
            onTap: () => _tabController.animateTo(1),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _SummaryCard(
            label: 'Reset',
            value: _distribution.resetCount,
            color: AppColors.success,
            icon: Icons.check_circle_outline,
            onTap: () => _tabController.animateTo(2),
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
    );
  }

  Widget _buildActiveFilters() {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.screenHorizontal,
        right: AppSpacing.screenHorizontal,
        bottom: AppSpacing.sm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (_selectedSiteId != null)
              _FilterChip(
                label: _siteMap[_selectedSiteId]?.name ?? 'Site',
                icon: Icons.location_city,
                onRemove: () {
                  setState(() => _selectedSiteId = null);
                },
              ),
            if (_selectedPriorityId != null) ...[
              const SizedBox(width: AppSpacing.xs),
              _FilterChip(
                label: _priorityMap[_selectedPriorityId]?.name ?? 'Priority',
                icon: Icons.flag,
                onRemove: () {
                  setState(() => _selectedPriorityId = null);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Distribution Chart
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

            const SizedBox(height: AppSpacing.md),

            // Timeline Chart
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

            const SizedBox(height: AppSpacing.md),

            // Alarms by Site
            if (_sites.isNotEmpty) ...[
              AppSectionHeader(title: 'Site Bazli Alarm Gecmisi'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  children: _sites.take(5).map((site) {
                    final siteResetCount = _resetAlarms
                        .where((a) => a.siteId == site.id)
                        .length;
                    return _SiteAlarmRow(
                      siteName: site.name,
                      resetCount: siteResetCount,
                    );
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveAlarmsTab() {
    final alarms = _filteredActiveAlarms;

    if (alarms.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.check_circle_outline,
          title: 'Aktif Alarm Yok',
          message: _searchQuery.isNotEmpty || _selectedPriorityId != null
              ? 'Filtrelere uygun alarm bulunamadi'
              : 'Su anda aktif alarm bulunmuyor',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: AppSpacing.screenPadding,
        itemCount: alarms.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final alarm = alarms[index];
          final priority = alarm.priorityId != null
              ? _priorityMap[alarm.priorityId!]
              : null;

          return _ActiveAlarmCard(
            alarm: alarm,
            priority: priority,
            onTap: () {
              ActiveAlarmDetailSheet.show(
                context,
                alarm: alarm,
                priority: priority,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryTab() {
    final alarms = _filteredResetAlarms;

    if (alarms.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.history,
          title: 'Alarm Gecmisi Bos',
          message: _searchQuery.isNotEmpty || _selectedSiteId != null
              ? 'Filtrelere uygun alarm bulunamadi'
              : 'Belirtilen donemde resetlenmis alarm yok',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: AppSpacing.screenPadding,
        itemCount: alarms.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final alarm = alarms[index];
          final priority = alarm.priorityId != null
              ? _priorityMap[alarm.priorityId!]
              : null;
          final site = alarm.siteId != null
              ? _siteMap[alarm.siteId!]
              : null;

          return _ResetAlarmCard(
            alarm: alarm,
            priority: priority,
            siteName: site?.name,
            onTap: () {
              AlarmDetailSheet.show(
                context,
                alarm: alarm,
                priority: priority,
              );
            },
          );
        },
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FilterSheet(
        sites: _sites,
        priorities: _priorityMap.values.toList(),
        selectedSiteId: _selectedSiteId,
        selectedPriorityId: _selectedPriorityId,
        selectedDays: _selectedDays,
        onApply: (siteId, priorityId, days) {
          setState(() {
            _selectedSiteId = siteId;
            _selectedPriorityId = priorityId;
            if (days != _selectedDays) {
              _selectedDays = days;
              _loadData();
            }
          });
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ============================================================================
// Private Widgets
// ============================================================================

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
            Icon(icon, color: color, size: 22),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(brightness),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary(brightness),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;

  const _CountBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count.toString(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onRemove;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 14,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SiteAlarmRow extends StatelessWidget {
  final String siteName;
  final int resetCount;

  const _SiteAlarmRow({
    required this.siteName,
    required this.resetCount,
  });

  @override
  Widget build(BuildContext context) {
    return AppListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.location_city,
          color: AppColors.primary,
          size: 18,
        ),
      ),
      title: siteName,
      subtitle: 'Gecmis: $resetCount',
      trailing: _CountBadge(count: resetCount, color: AppColors.success),
    );
  }
}

class _ActiveAlarmCard extends StatelessWidget {
  final Alarm alarm;
  final Priority? priority;
  final VoidCallback onTap;

  const _ActiveAlarmCard({
    required this.alarm,
    this.priority,
    required this.onTap,
  });

  Color get _priorityColor {
    if (priority != null) {
      return priority!.displayColor;
    }
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = _priorityColor;

    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: priorityColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          alarm.name ?? alarm.code ?? 'Alarm',
                          style: AppTypography.headline,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (priority != null)
                        AppBadge(
                          label: priority!.name ?? '',
                          variant: AppBadgeVariant.neutral,
                          size: AppBadgeSize.small,
                        ),
                    ],
                  ),
                  if (alarm.effectiveDescription != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      alarm.effectiveDescription!,
                      style: AppTypography.caption1.copyWith(
                        color: AppColors.secondaryLabel(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: AppColors.tertiaryLabel(context),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        alarm.durationFormatted,
                        style: AppTypography.caption2.copyWith(
                          color: AppColors.tertiaryLabel(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _ResetAlarmCard extends StatelessWidget {
  final AlarmHistory alarm;
  final Priority? priority;
  final String? siteName;
  final VoidCallback onTap;

  const _ResetAlarmCard({
    required this.alarm,
    this.priority,
    this.siteName,
    required this.onTap,
  });

  Color get _priorityColor {
    if (priority?.color != null) {
      final hex = priority!.color!.replaceFirst('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
    }
    if (priority != null) {
      if (priority!.isCritical) return AppColors.error;
      if (priority!.isHigh) return AppColors.warning;
    }
    return AppColors.systemGray;
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = _priorityColor;

    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: priorityColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          alarm.name ?? alarm.code ?? 'Alarm',
                          style: AppTypography.headline,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (priority != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: priorityColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            priority!.name ?? '',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: priorityColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (alarm.effectiveDescription != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      alarm.effectiveDescription!,
                      style: AppTypography.caption1.copyWith(
                        color: AppColors.secondaryLabel(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (siteName != null) ...[
                        Icon(
                          Icons.location_city,
                          size: 12,
                          color: AppColors.tertiaryLabel(context),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          siteName!,
                          style: AppTypography.caption2.copyWith(
                            color: AppColors.tertiaryLabel(context),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Icon(
                        Icons.timer_outlined,
                        size: 12,
                        color: AppColors.tertiaryLabel(context),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        alarm.durationFormatted,
                        style: AppTypography.caption2.copyWith(
                          color: AppColors.tertiaryLabel(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final List<Site> sites;
  final List<Priority> priorities;
  final String? selectedSiteId;
  final String? selectedPriorityId;
  final int selectedDays;
  final void Function(String? siteId, String? priorityId, int days) onApply;

  const _FilterSheet({
    required this.sites,
    required this.priorities,
    this.selectedSiteId,
    this.selectedPriorityId,
    required this.selectedDays,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _selectedSiteId;
  late String? _selectedPriorityId;
  late int _selectedDays;

  @override
  void initState() {
    super.initState();
    _selectedSiteId = widget.selectedSiteId;
    _selectedPriorityId = widget.selectedPriorityId;
    _selectedDays = widget.selectedDays;
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: 'Filtrele',
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Period selector
            Text('Donem', style: AppTypography.subheadline),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              children: [7, 14, 30, 60, 90, 180].map((days) {
                final isSelected = _selectedDays == days;
                return ChoiceChip(
                  label: Text('$days gun'),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedDays = days);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.md),

            // Site filter
            Text('Site', style: AppTypography.subheadline),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: DropdownButton<String?>(
                value: _selectedSiteId,
                isExpanded: true,
                hint: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Tum siteler'),
                ),
                underline: const SizedBox(),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Tum siteler'),
                    ),
                  ),
                  ...widget.sites.map((site) {
                    return DropdownMenuItem<String?>(
                      value: site.id,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(site.name),
                      ),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() => _selectedSiteId = value);
                },
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Priority filter
            Text('Oncelik', style: AppTypography.subheadline),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                ChoiceChip(
                  label: const Text('Tumu'),
                  selected: _selectedPriorityId == null,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedPriorityId = null);
                    }
                  },
                ),
                ...widget.priorities.map((priority) {
                  final isSelected = _selectedPriorityId == priority.id;
                  return ChoiceChip(
                    label: Text(priority.name ?? ''),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedPriorityId = selected ? priority.id : null;
                      });
                    },
                  );
                }),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // Actions
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Temizle',
                    variant: AppButtonVariant.secondary,
                    onPressed: () {
                      setState(() {
                        _selectedSiteId = null;
                        _selectedPriorityId = null;
                        _selectedDays = 90;
                      });
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'Uygula',
                    onPressed: () {
                      widget.onApply(
                        _selectedSiteId,
                        _selectedPriorityId,
                        _selectedDays,
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
