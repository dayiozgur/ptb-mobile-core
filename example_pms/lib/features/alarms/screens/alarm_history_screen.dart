import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class AlarmHistoryScreen extends StatefulWidget {
  const AlarmHistoryScreen({super.key});

  @override
  State<AlarmHistoryScreen> createState() => _AlarmHistoryScreenState();
}

class _AlarmHistoryScreenState extends State<AlarmHistoryScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  List<AlarmHistory> _allAlarms = [];
  List<AlarmHistory> _filteredAlarms = [];
  Map<String, Priority> _priorityMap = {};

  int _selectedDays = 30;
  String? _selectedPriorityId;
  String _searchQuery = '';

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
      final results = await Future.wait([
        priorityService.getAll(forceRefresh: true),
        alarmService.getResetAlarms(
          days: _selectedDays,
          limit: 200,
          forceRefresh: true,
        ),
      ]);

      final priorities = results[0] as List<Priority>;
      final alarms = results[1] as List<AlarmHistory>;

      final pMap = <String, Priority>{};
      for (final p in priorities) {
        pMap[p.id] = p;
      }

      if (mounted) {
        setState(() {
          _priorityMap = pMap;
          _allAlarms = alarms;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load reset alarms', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Alarm gecmisi yuklenirken hata olustu';
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    var filtered = List<AlarmHistory>.from(_allAlarms);

    if (_selectedPriorityId != null) {
      filtered = filtered.where((a) => a.priorityId == _selectedPriorityId).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((a) {
        final name = (a.name ?? '').toLowerCase();
        final code = (a.code ?? '').toLowerCase();
        return name.contains(query) || code.contains(query);
      }).toList();
    }

    // Sort by reset time desc
    filtered.sort((a, b) =>
        (b.resetTime ?? b.endTime ?? DateTime(1970))
            .compareTo(a.resetTime ?? a.endTime ?? DateTime(1970)));

    _filteredAlarms = filtered;
  }

  void _onPeriodChanged(int days) {
    setState(() => _selectedDays = days);
    _loadData();
  }

  Color _getPriorityColor(AlarmHistory alarm) {
    if (alarm.priorityId != null && _priorityMap.containsKey(alarm.priorityId)) {
      final priority = _priorityMap[alarm.priorityId!]!;
      if (priority.color != null) {
        final hex = priority.color!.replaceFirst('#', '');
        if (hex.length == 6) {
          return Color(int.parse('FF$hex', radix: 16));
        }
      }
      if (priority.isCritical) return AppColors.error;
      if (priority.isHigh) return AppColors.warning;
    }
    return AppColors.systemGray;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return AppScaffold(
      title: 'Alarm Gecmisi',
      onBack: () => context.go('/alarms'),
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
      child: Column(
        children: [
          // Search + Period selector
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: Row(
              children: [
                Expanded(
                  child: AppSearchBar(
                    placeholder: 'Alarm ara...',
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _applyFilters();
                      });
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                ChartPeriodSelector(
                  selectedDays: _selectedDays,
                  onChanged: _onPeriodChanged,
                  options: const [7, 30, 90],
                ),
              ],
            ),
          ),

          // Summary
          if (!_isLoading && _errorMessage == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.restart_alt, size: 16, color: AppColors.success),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${_filteredAlarms.length} reset alarm',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Son $_selectedDays gun',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary(brightness)),
                  ),
                ],
              ),
            ),

          const SizedBox(height: AppSpacing.sm),

          // List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: _buildContent(brightness),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Brightness brightness) {
    if (_isLoading) {
      return const Center(child: AppLoadingIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: AppErrorView(
          message: _errorMessage!,
          onRetry: _loadData,
        ),
      );
    }

    if (_filteredAlarms.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.history,
          title: _allAlarms.isEmpty ? 'Alarm Gecmisi Yok' : 'Sonuc Bulunamadi',
          message: _allAlarms.isEmpty
              ? 'Bu donemde resetlenmis alarm bulunmuyor.'
              : 'Arama kriterlerinize uygun alarm bulunamadi.',
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.sm,
      ),
      itemCount: _filteredAlarms.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final alarm = _filteredAlarms[index];
        final priority = alarm.priorityId != null ? _priorityMap[alarm.priorityId!] : null;
        final priorityColor = _getPriorityColor(alarm);

        return _ResetAlarmCard(
          alarm: alarm,
          priority: priority,
          priorityColor: priorityColor,
          onTap: () {
            AlarmDetailSheet.show(
              context,
              alarm: alarm,
              priority: priority,
            );
          },
        );
      },
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => AppBottomSheet(
        title: 'Filtreler',
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Oncelik Seviyesi', style: AppTypography.subheadline),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  FilterChip(
                    label: const Text('Tumu'),
                    selected: _selectedPriorityId == null,
                    onSelected: (_) {
                      setState(() {
                        _selectedPriorityId = null;
                        _applyFilters();
                      });
                      Navigator.pop(context);
                    },
                  ),
                  ..._priorityMap.values.map((p) => FilterChip(
                    label: Text(p.label),
                    selected: _selectedPriorityId == p.id,
                    onSelected: (_) {
                      setState(() {
                        _selectedPriorityId = p.id;
                        _applyFilters();
                      });
                      Navigator.pop(context);
                    },
                  )),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResetAlarmCard extends StatelessWidget {
  final AlarmHistory alarm;
  final Priority? priority;
  final Color priorityColor;
  final VoidCallback onTap;

  const _ResetAlarmCard({
    required this.alarm,
    this.priority,
    required this.priorityColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 70,
              decoration: BoxDecoration(
                color: priorityColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          alarm.name ?? alarm.code ?? 'Alarm',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary(brightness)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: priorityColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          alarm.durationFormatted,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: priorityColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      if (alarm.code != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.segmentedBackground(context),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(alarm.code!, style: TextStyle(fontSize: 11, color: AppColors.textSecondary(brightness))),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      if (priority != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: priorityColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(priority!.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: priorityColor)),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Icon(Icons.play_arrow, size: 14, color: AppColors.textSecondary(brightness)),
                      const SizedBox(width: 2),
                      Text(
                        alarm.startTime != null ? _formatDateTime(alarm.startTime!) : '-',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary(brightness)),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Icon(Icons.restart_alt, size: 14, color: AppColors.success),
                      const SizedBox(width: 2),
                      Text(
                        alarm.resetTime != null ? _formatDateTime(alarm.resetTime!) : '-',
                        style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.chevron_right, color: AppColors.systemGray),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return 'Bugun ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Dun ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} gun once';
    } else {
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }
}
