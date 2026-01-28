import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/alarm/alarm_stats_model.dart';
import '../../../core/priority/priority_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Alarm bar chart widget
///
/// alarm_histories tablosundan gelen AlarmTimelineEntry verilerini
/// günlük stacked bar chart olarak gösterir.
/// Son 7/30/90 gün desteklenir.
class AlarmBarChart extends StatefulWidget {
  final List<AlarmTimelineEntry> entries;
  final Map<String, Priority>? priorities;
  final double height;

  const AlarmBarChart({
    super.key,
    required this.entries,
    this.priorities,
    this.height = 200,
  });

  @override
  State<AlarmBarChart> createState() => _AlarmBarChartState();
}

class _AlarmBarChartState extends State<AlarmBarChart> {
  int? _touchedIndex;

  /// Priority renklerini belirle
  Color _priorityColor(String priorityId, int index) {
    final priority = widget.priorities?[priorityId];
    if (priority?.color != null) {
      final hex = priority!.color!.replaceFirst('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
    }

    // Fallback renkleri
    const fallbackColors = [
      AppColors.error,
      AppColors.warning,
      AppColors.info,
      AppColors.success,
      AppColors.secondary,
    ];
    return fallbackColors[index % fallbackColors.length];
  }

  /// Tüm benzersiz priority ID'leri
  List<String> get _allPriorityIds {
    final ids = <String>{};
    for (final entry in widget.entries) {
      ids.addAll(entry.countByPriority.keys);
    }
    return ids.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return SizedBox(height: widget.height);
    }

    final brightness = Theme.of(context).brightness;
    final maxValue = widget.entries.fold<int>(
        0, (max, e) => e.totalCount > max ? e.totalCount : max);
    final priorityIds = _allPriorityIds;

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (maxValue + 1).toDouble(),
              minY: 0,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) =>
                      AppColors.surface(brightness),
                  tooltipRoundedRadius: AppSpacing.radiusSm,
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final entry = widget.entries[group.x.toInt()];
                    final dateStr =
                        DateFormat('dd MMM').format(entry.date);
                    return BarTooltipItem(
                      '$dateStr\n${entry.totalCount} alarm',
                      TextStyle(
                        color: AppColors.textPrimary(brightness),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
                touchCallback: (event, response) {
                  setState(() {
                    if (event.isInterestedForInteractions &&
                        response != null &&
                        response.spot != null) {
                      _touchedIndex =
                          response.spot!.touchedBarGroupIndex;
                    } else {
                      _touchedIndex = null;
                    }
                  });
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= widget.entries.length) {
                        return const SizedBox.shrink();
                      }

                      // Etiket aralığını belirle
                      final totalEntries = widget.entries.length;
                      final interval = totalEntries <= 7
                          ? 1
                          : totalEntries <= 30
                              ? 5
                              : 10;

                      if (index % interval != 0 &&
                          index != totalEntries - 1) {
                        return const SizedBox.shrink();
                      }

                      final date = widget.entries[index].date;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          DateFormat('dd/MM').format(date),
                          style: TextStyle(
                            color:
                                AppColors.textSecondary(brightness),
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: maxValue > 4
                        ? (maxValue / 4).ceilToDouble()
                        : 1,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            color:
                                AppColors.textSecondary(brightness),
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxValue > 4
                    ? (maxValue / 4).ceilToDouble()
                    : 1,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: AppColors.divider(brightness),
                  strokeWidth: 0.5,
                  dashArray: [4, 4],
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: widget.entries.asMap().entries.map((mapEntry) {
                final i = mapEntry.key;
                final entry = mapEntry.value;
                final isTouched = _touchedIndex == i;

                // Stacked bar rod sections
                final sections = <BarChartRodStackItem>[];
                var cumulative = 0.0;

                if (priorityIds.isNotEmpty) {
                  for (var j = 0; j < priorityIds.length; j++) {
                    final pid = priorityIds[j];
                    final count =
                        (entry.countByPriority[pid] ?? 0).toDouble();
                    if (count > 0) {
                      sections.add(BarChartRodStackItem(
                        cumulative,
                        cumulative + count,
                        _priorityColor(pid, j).withValues(
                          alpha: isTouched ? 1.0 : 0.85,
                        ),
                      ));
                      cumulative += count;
                    }
                  }
                }

                // Fallback: tek renk bar
                if (sections.isEmpty && entry.totalCount > 0) {
                  sections.add(BarChartRodStackItem(
                    0,
                    entry.totalCount.toDouble(),
                    AppColors.primary.withValues(
                      alpha: isTouched ? 1.0 : 0.85,
                    ),
                  ));
                }

                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: entry.totalCount.toDouble(),
                      width: widget.entries.length <= 7
                          ? 20
                          : widget.entries.length <= 30
                              ? 8
                              : 4,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(3),
                        topRight: Radius.circular(3),
                      ),
                      rodStackItems: sections,
                    ),
                  ],
                );
              }).toList(),
            ),
            swapAnimationDuration: const Duration(milliseconds: 300),
          ),
        ),

        // Legend
        if (priorityIds.isNotEmpty && widget.priorities != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              alignment: WrapAlignment.center,
              children: priorityIds.asMap().entries.map((e) {
                final pid = e.value;
                final priority = widget.priorities?[pid];
                final label = priority?.label ?? pid;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _priorityColor(pid, e.key),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary(brightness),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
