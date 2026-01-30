import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Tam sayfa resetlenmiş alarm listesi ekranı
///
/// alarm_histories tablosundan gelen resetlenmiş alarmları tam ekran listeler.
/// Priorities tablosundan gelen renkleri kullanır.
/// Dönem seçimi, filtreleme, arama ve detay görüntüleme özellikleri sunar.
class ResetAlarmsScreen extends StatefulWidget {
  const ResetAlarmsScreen({super.key});

  @override
  State<ResetAlarmsScreen> createState() => _ResetAlarmsScreenState();
}

class _ResetAlarmsScreenState extends State<ResetAlarmsScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  List<AlarmHistory> _allAlarms = [];
  List<AlarmHistory> _filteredAlarms = [];
  Map<String, Priority> _priorityMap = {};

  int _selectedDays = 30;
  String? _selectedPriorityId;
  String _searchQuery = '';

  // Sıralama
  _SortOption _sortOption = _SortOption.resetTimeDesc;

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
        priorityService.getAll(),
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
          _errorMessage = 'Resetlenmiş alarmlar yüklenirken hata oluştu';
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    var filtered = List<AlarmHistory>.from(_allAlarms);

    // Priority filtresi
    if (_selectedPriorityId != null) {
      filtered = filtered
          .where((a) => a.priorityId == _selectedPriorityId)
          .toList();
    }

    // Arama filtresi
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((a) {
        final name = (a.name ?? '').toLowerCase();
        final code = (a.code ?? '').toLowerCase();
        final description = (a.description ?? '').toLowerCase();
        return name.contains(query) ||
            code.contains(query) ||
            description.contains(query);
      }).toList();
    }

    // Sıralama
    switch (_sortOption) {
      case _SortOption.resetTimeDesc:
        filtered.sort((a, b) =>
            (b.resetTime ?? b.endTime ?? DateTime(1970))
                .compareTo(a.resetTime ?? a.endTime ?? DateTime(1970)));
      case _SortOption.resetTimeAsc:
        filtered.sort((a, b) =>
            (a.resetTime ?? a.endTime ?? DateTime(1970))
                .compareTo(b.resetTime ?? b.endTime ?? DateTime(1970)));
      case _SortOption.startTimeDesc:
        filtered.sort((a, b) =>
            (b.startTime ?? DateTime(1970)).compareTo(a.startTime ?? DateTime(1970)));
      case _SortOption.startTimeAsc:
        filtered.sort((a, b) =>
            (a.startTime ?? DateTime(1970)).compareTo(b.startTime ?? DateTime(1970)));
      case _SortOption.priorityDesc:
        filtered.sort((a, b) {
          final pA = _priorityMap[a.priorityId]?.level ?? 0;
          final pB = _priorityMap[b.priorityId]?.level ?? 0;
          return pB.compareTo(pA);
        });
      case _SortOption.priorityAsc:
        filtered.sort((a, b) {
          final pA = _priorityMap[a.priorityId]?.level ?? 0;
          final pB = _priorityMap[b.priorityId]?.level ?? 0;
          return pA.compareTo(pB);
        });
      case _SortOption.durationDesc:
        filtered.sort((a, b) => (b.duration ?? Duration.zero).compareTo(a.duration ?? Duration.zero));
      case _SortOption.durationAsc:
        filtered.sort((a, b) => (a.duration ?? Duration.zero).compareTo(b.duration ?? Duration.zero));
    }

    _filteredAlarms = filtered;
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

  void _onPeriodChanged(int days) {
    setState(() => _selectedDays = days);
    _loadData();
  }

  void _showFilterSheet() {
    final brightness = Theme.of(context).brightness;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.systemGray4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Başlık
                Text(
                  'Filtreler',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Priority Filtresi
                Text(
                  'Öncelik Seviyesi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _FilterChip(
                      label: 'Tümü',
                      isSelected: _selectedPriorityId == null,
                      color: AppColors.primary,
                      onTap: () {
                        setState(() {
                          _selectedPriorityId = null;
                          _applyFilters();
                        });
                        Navigator.pop(context);
                      },
                    ),
                    ..._priorityMap.values.map((p) => _FilterChip(
                      label: p.label,
                      isSelected: _selectedPriorityId == p.id,
                      color: _getColorFromPriority(p),
                      onTap: () {
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

                // Sıralama
                Text(
                  'Sıralama',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ..._SortOption.values.map((option) => ListTile(
                  title: Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                  leading: Radio<_SortOption>(
                    value: option,
                    groupValue: _sortOption,
                    onChanged: (value) {
                      setState(() {
                        _sortOption = value!;
                        _applyFilters();
                      });
                      Navigator.pop(context);
                    },
                    activeColor: AppColors.primary,
                  ),
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    setState(() {
                      _sortOption = option;
                      _applyFilters();
                    });
                    Navigator.pop(context);
                  },
                )),

                const SizedBox(height: AppSpacing.lg),

                // Filtreleri Sıfırla
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedPriorityId = null;
                        _sortOption = _SortOption.resetTimeDesc;
                        _searchQuery = '';
                        _applyFilters();
                      });
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                    ),
                    child: const Text('Filtreleri Sıfırla'),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getColorFromPriority(Priority p) {
    if (p.color != null) {
      final hex = p.color!.replaceFirst('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
    }
    if (p.isCritical) return AppColors.error;
    if (p.isHigh) return AppColors.warning;
    return AppColors.info;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    // Aktif filtre sayısı
    int activeFilterCount = 0;
    if (_selectedPriorityId != null) activeFilterCount++;
    if (_sortOption != _SortOption.resetTimeDesc) activeFilterCount++;

    return AppScaffold(
      title: 'Alarm Geçmişi',
      onBack: () => context.go('/iot/alarms'),
      actions: [
        // Filtre butonu
        Stack(
          children: [
            AppIconButton(
              icon: Icons.filter_list,
              onPressed: _showFilterSheet,
            ),
            if (activeFilterCount > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      activeFilterCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        AppIconButton(
          icon: Icons.refresh,
          onPressed: _loadData,
        ),
      ],
      child: Column(
        children: [
          // Üst bar: Arama + Dönem seçici
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

          // Özet bilgi
          if (!_isLoading && _errorMessage == null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.restart_alt,
                          size: 16,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${_filteredAlarms.length} reset alarm',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Son $_selectedDays gün',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(brightness),
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

          // Liste
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
      return const Center(child: CircularProgressIndicator.adaptive());
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
          title: _allAlarms.isEmpty ? 'Alarm Geçmişi Yok' : 'Sonuç Bulunamadı',
          message: _allAlarms.isEmpty
              ? 'Bu dönemde resetlenmiş alarm bulunmuyor.'
              : 'Arama kriterlerinize uygun alarm bulunamadı.',
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
        return _ResetAlarmCard(
          alarm: alarm,
          priority: alarm.priorityId != null
              ? _priorityMap[alarm.priorityId!]
              : null,
          priorityColor: _getPriorityColor(alarm),
          onTap: () {
            AlarmDetailSheet.show(
              context,
              alarm: alarm,
              priority: alarm.priorityId != null
                  ? _priorityMap[alarm.priorityId!]
                  : null,
            );
          },
        );
      },
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
            // Sol renk çubuğu
            Container(
              width: 4,
              height: 70,
              decoration: BoxDecoration(
                color: priorityColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // İçerik
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık satırı
                  Row(
                    children: [
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
                      // Süre badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: priorityColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          alarm.durationFormatted,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: priorityColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xs),

                  // Kod ve Priority badge
                  Row(
                    children: [
                      if (alarm.code != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.systemGray6,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            alarm.code!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary(brightness),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      if (priority != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: priorityColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            priority!.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: priorityColor,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // Zaman bilgileri
                  Row(
                    children: [
                      // Başlangıç
                      Icon(
                        Icons.play_arrow,
                        size: 14,
                        color: AppColors.textSecondary(brightness),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        alarm.startTime != null
                            ? _formatDateTime(alarm.startTime!)
                            : '-',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(brightness),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      // Reset
                      Icon(
                        Icons.restart_alt,
                        size: 14,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        alarm.resetTime != null
                            ? _formatDateTime(alarm.resetTime!)
                            : '-',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  // Reset kullanıcısı
                  if (alarm.resetUser != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: AppColors.textSecondary(brightness),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            alarm.resetUser!,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(brightness),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.chevron_right,
              color: AppColors.systemGray,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0) {
      return 'Bugün ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Dün ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} gün önce';
    } else {
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AppColors.systemGray6,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? color : AppColors.textSecondary(Theme.of(context).brightness),
          ),
        ),
      ),
    );
  }
}

enum _SortOption {
  resetTimeDesc,
  resetTimeAsc,
  startTimeDesc,
  startTimeAsc,
  priorityDesc,
  priorityAsc,
  durationDesc,
  durationAsc;

  String get label {
    switch (this) {
      case _SortOption.resetTimeDesc:
        return 'Reset Zamanı (Yeni → Eski)';
      case _SortOption.resetTimeAsc:
        return 'Reset Zamanı (Eski → Yeni)';
      case _SortOption.startTimeDesc:
        return 'Başlangıç (Yeni → Eski)';
      case _SortOption.startTimeAsc:
        return 'Başlangıç (Eski → Yeni)';
      case _SortOption.priorityDesc:
        return 'Öncelik (Yüksek → Düşük)';
      case _SortOption.priorityAsc:
        return 'Öncelik (Düşük → Yüksek)';
      case _SortOption.durationDesc:
        return 'Süre (Uzun → Kısa)';
      case _SortOption.durationAsc:
        return 'Süre (Kısa → Uzun)';
    }
  }
}
