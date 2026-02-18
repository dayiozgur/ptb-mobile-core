import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/alarm/alarm_stats_model.dart';
import '../../../core/priority/priority_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Alarm priority trend chart (stacked area)
///
/// AlarmTimelineEntry verilerini priority bazli stacked area chart olarak gosterir.
/// Her priority kendi rengiyle ayri alan kaplar.
class AlarmPriorityTrendChart extends StatelessWidget {
  final List<AlarmTimelineEntry> entries;
  final Map<String, Priority> priorities;
  final double height;

  const AlarmPriorityTrendChart({
    super.key,
    required this.entries,
    required this.priorities,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    if (entries.isEmpty || entries.every((e) => e.totalCount == 0)) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Yeterli veri yok',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary(brightness),
            ),
          ),
        ),
      );
    }

    // Tum priority ID'leri topla
    final allPriorityIds = <String>{};
    for (final entry in entries) {
      allPriorityIds.addAll(entry.countByPriority.keys);
    }

    if (allPriorityIds.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Priority verisi yok',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary(brightness),
            ),
          ),
        ),
      );
    }

    // Priority'leri level'a gore sirala (yuksek oncelik uste)
    final sortedPriorityIds = allPriorityIds.toList()
      ..sort((a, b) {
        final pA = priorities[a];
        final pB = priorities[b];
        return (pA?.level ?? 99).compareTo(pB?.level ?? 99);
      });

    // Stacked area icin kumülatif Y degerlerini hesapla
    final lineBarDatas = <LineChartBarData>[];
    final cumulativeValues = List.generate(
      entries.length,
      (_) => 0.0,
    );

    // Ustten alta: her priority icin cumulative area
    for (var pIdx = sortedPriorityIds.length - 1; pIdx >= 0; pIdx--) {
      final priorityId = sortedPriorityIds[pIdx];
      final priority = priorities[priorityId];
      final color = priority?.displayColor ?? AppColors.systemGray;

      final spots = <FlSpot>[];
      for (var i = 0; i < entries.length; i++) {
        final count = entries[i].countByPriority[priorityId] ?? 0;
        cumulativeValues[i] += count;
        spots.add(FlSpot(i.toDouble(), cumulativeValues[i]));
      }

      lineBarDatas.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.25,
        preventCurveOverShooting: true,
        color: color,
        barWidth: 1.5,
        isStrokeCapRound: true,
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: color.withValues(alpha: 0.4),
        ),
      ));
    }

    // Reverse: en ustteki (en buyuk cumulative) en sonda cizikmeli
    lineBarDatas.reversed.toList();

    final maxY = cumulativeValues.reduce((a, b) => a > b ? a : b);
    final yMax = maxY > 0 ? maxY * 1.1 : 5.0;

    final timeRange = entries.length.toDouble() - 1;

    return Column(
      children: [
        // Legend
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.center,
            children: sortedPriorityIds.map((pid) {
              final p = priorities[pid];
              final color = p?.displayColor ?? AppColors.systemGray;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    p?.label ?? 'Bilinmiyor',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary(brightness),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),

        // Chart
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: yMax,
              minX: 0,
              maxX: timeRange > 0 ? timeRange : 1,
              clipData: FlClipData.all(),
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => brightness == Brightness.light
                      ? Colors.white
                      : AppColors.systemGray5,
                  tooltipRoundedRadius: AppSpacing.radiusMd,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (touchedSpots) {
                    if (touchedSpots.isEmpty) return [];
                    final index = touchedSpots.first.x.toInt();
                    if (index < 0 || index >= entries.length) return [];
                    final entry = entries[index];
                    final dateStr = DateFormat('dd/MM').format(entry.date);

                    return [
                      LineTooltipItem(
                        '$dateStr: ${entry.totalCount} alarm',
                        TextStyle(
                          color: AppColors.textPrimary(brightness),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      ...List.filled(touchedSpots.length - 1, null)
                          .map((_) => null),
                    ];
                  },
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY > 0 ? (maxY / 4).ceilToDouble().clamp(1, double.infinity) : 1,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: AppColors.divider(brightness),
                  strokeWidth: 0.5,
                  dashArray: [4, 4],
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: (timeRange / 4).clamp(1, double.infinity),
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= entries.length) {
                        return const SizedBox.shrink();
                      }
                      if (value == 0 || value >= timeRange) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          DateFormat('dd/MM').format(entries[index].date),
                          style: TextStyle(
                            color: AppColors.textSecondary(brightness),
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
                    interval: maxY > 0 ? (maxY / 4).ceilToDouble().clamp(1, double.infinity) : 1,
                    getTitlesWidget: (value, meta) {
                      if (value == meta.min || value == meta.max) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          color: AppColors.textSecondary(brightness),
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: lineBarDatas,
            ),
            duration: const Duration(milliseconds: 250),
          ),
        ),
      ],
    );
  }
}
