import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class ActiveAlarmsScreen extends StatefulWidget {
  const ActiveAlarmsScreen({super.key});

  @override
  State<ActiveAlarmsScreen> createState() => _ActiveAlarmsScreenState();
}

class _ActiveAlarmsScreenState extends State<ActiveAlarmsScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  List<Alarm> _allAlarms = [];
  List<Alarm> _filteredAlarms = [];
  Map<String, Priority> _priorityMap = {};

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
        alarmService.getActiveAlarms(includeVariable: true),
      ]);

      final priorities = results[0] as List<Priority>;
      final alarms = results[1] as List<Alarm>;

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
      Logger.error('Failed to load active alarms', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Aktif alarmlar yuklenirken hata olustu';
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    var filtered = List<Alarm>.from(_allAlarms);

    if (_selectedPriorityId != null) {
      filtered = filtered.where((a) => a.priorityId == _selectedPriorityId).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((a) {
        final name = (a.name ?? '').toLowerCase();
        final code = (a.code ?? '').toLowerCase();
        final description = (a.description ?? '').toLowerCase();
        return name.contains(query) || code.contains(query) || description.contains(query);
      }).toList();
    }

    // Sort by start time descending
    filtered.sort((a, b) =>
        (b.startTime ?? DateTime(1970)).compareTo(a.startTime ?? DateTime(1970)));

    _filteredAlarms = filtered;
  }

  Color _getPriorityColor(Alarm alarm) {
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
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return AppScaffold(
      title: 'Aktif Alarmlar',
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
          // Search bar
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
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

          // Summary badge
          if (!_isLoading && _errorMessage == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.error),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${_filteredAlarms.length} aktif alarm',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (_searchQuery.isNotEmpty || _selectedPriorityId != null)
                    Text(
                      'Toplam: ${_allAlarms.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(brightness),
                      ),
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
          icon: Icons.check_circle_outline,
          title: _allAlarms.isEmpty ? 'Aktif Alarm Yok' : 'Sonuc Bulunamadi',
          message: _allAlarms.isEmpty
              ? 'Su anda aktif alarm bulunmuyor.'
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

        return _AlarmCard(
          alarm: alarm,
          priority: priority,
          priorityColor: priorityColor,
          onTap: () {
            ActiveAlarmDetailSheet.show(
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
              if (_selectedPriorityId != null)
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    label: 'Filtreleri Sifirla',
                    variant: AppButtonVariant.secondary,
                    onPressed: () {
                      setState(() {
                        _selectedPriorityId = null;
                        _searchQuery = '';
                        _applyFilters();
                      });
                      Navigator.pop(context);
                    },
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlarmCard extends StatelessWidget {
  final Alarm alarm;
  final Priority? priority;
  final Color priorityColor;
  final VoidCallback onTap;

  const _AlarmCard({
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
            // Priority indicator
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: priorityColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: priorityColor.withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  width: 4,
                  height: 50,
                  decoration: BoxDecoration(
                    color: priorityColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (alarm.isAcknowledged) ...[
                        Icon(Icons.check_circle, size: 16, color: AppColors.info),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      Expanded(
                        child: Text(
                          alarm.name ?? alarm.code ?? 'Alarm',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(brightness),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                          child: Text(
                            alarm.code!,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary(brightness)),
                          ),
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
                          child: Text(
                            priority!.label,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: priorityColor),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: AppColors.textSecondary(brightness)),
                      const SizedBox(width: 4),
                      Text(
                        alarm.startTime != null ? _formatDateTime(alarm.startTime!) : '-',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary(brightness)),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: priorityColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer_outlined, size: 14, color: priorityColor),
                            const SizedBox(width: 4),
                            Text(
                              alarm.durationFormatted,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: priorityColor),
                            ),
                          ],
                        ),
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
    } else {
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }
}
