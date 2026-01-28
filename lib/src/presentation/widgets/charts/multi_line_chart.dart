import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/iot_log/iot_log_stats_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Multi-variable line chart widget
///
/// Birden fazla variable'ın log verilerini aynı chart üzerinde
/// farklı renklerle overlay olarak gösterir.
class MultiLineChart extends StatefulWidget {
  /// Variable adı → zaman serisi verileri
  final Map<String, List<LogTimeSeriesEntry>> dataSeries;
  final double height;
  final bool showLegend;

  const MultiLineChart({
    super.key,
    required this.dataSeries,
    this.height = 220,
    this.showLegend = true,
  });

  @override
  State<MultiLineChart> createState() => _MultiLineChartState();
}

class _MultiLineChartState extends State<MultiLineChart> {
  final Set<String> _hiddenSeries = {};

  static const _lineColors = [
    AppColors.primary,
    AppColors.error,
    AppColors.success,
    AppColors.warning,
    AppColors.secondary,
    AppColors.accent,
  ];

  Color _colorForIndex(int index) =>
      _lineColors[index % _lineColors.length];

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final seriesKeys = widget.dataSeries.keys.toList();

    if (seriesKeys.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            'Veri bulunamadı',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary(brightness),
            ),
          ),
        ),
      );
    }

    // Visible seriler
    final visibleSeries = <String, List<LogTimeSeriesEntry>>{};
    for (final key in seriesKeys) {
      if (!_hiddenSeries.contains(key)) {
        final numericEntries = widget.dataSeries[key]!
            .where((e) => e.hasNumericValue)
            .toList();
        if (numericEntries.length >= 2) {
          visibleSeries[key] = numericEntries;
        }
      }
    }

    if (visibleSeries.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            'Gösterilecek veri yok',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary(brightness),
            ),
          ),
        ),
      );
    }

    // Global min/max hesapla
    double globalMinY = double.infinity;
    double globalMaxY = double.negativeInfinity;
    int globalMinTime = 0x7FFFFFFFFFFFFFFF;
    int globalMaxTime = 0;

    for (final entries in visibleSeries.values) {
      for (final entry in entries) {
        if (entry.value! < globalMinY) globalMinY = entry.value!;
        if (entry.value! > globalMaxY) globalMaxY = entry.value!;
        final ms = entry.dateTime.millisecondsSinceEpoch;
        if (ms < globalMinTime) globalMinTime = ms;
        if (ms > globalMaxTime) globalMaxTime = ms;
      }
    }

    final yPadding = (globalMaxY - globalMinY) * 0.1;
    final yMin = globalMinY - yPadding;
    final yMax = globalMaxY + yPadding;
    final timeRange = (globalMaxTime - globalMinTime).toDouble();

    if (timeRange <= 0) {
      return SizedBox(height: widget.height);
    }

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: LineChart(
            LineChartData(
              minY: yMin,
              maxY: yMax,
              minX: 0,
              maxX: timeRange,
              clipData: FlClipData.all(),
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) =>
                      AppColors.surface(brightness),
                  tooltipRoundedRadius: AppSpacing.radiusSm,
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final seriesIndex = spot.barIndex;
                      final visibleKeys =
                          visibleSeries.keys.toList();
                      final name = seriesIndex < visibleKeys.length
                          ? visibleKeys[seriesIndex]
                          : '';

                      return LineTooltipItem(
                        '$name\n${spot.y.toStringAsFixed(1)}',
                        TextStyle(
                          color: _colorForIndex(
                              seriesKeys.indexOf(
                                  seriesIndex < visibleKeys.length
                                      ? visibleKeys[seriesIndex]
                                      : seriesKeys.first)),
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
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
                    interval: timeRange / 4,
                    getTitlesWidget: (value, meta) {
                      if (value == 0 || value >= timeRange) {
                        return const SizedBox.shrink();
                      }
                      final ms = globalMinTime + value.toInt();
                      final dt =
                          DateTime.fromMillisecondsSinceEpoch(ms.toInt());
                      final format = timeRange >
                              const Duration(days: 3)
                                  .inMilliseconds
                          ? DateFormat('dd/MM')
                          : DateFormat('HH:mm');
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          format.format(dt),
                          style: TextStyle(
                            color: AppColors
                                .textSecondary(brightness),
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
                    reservedSize: 42,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          _formatValue(value),
                          style: TextStyle(
                            color: AppColors
                                .textSecondary(brightness),
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: visibleSeries.entries.map((mapEntry) {
                final seriesName = mapEntry.key;
                final entries = mapEntry.value;
                final colorIndex =
                    seriesKeys.indexOf(seriesName);
                final color = _colorForIndex(colorIndex);

                return LineChartBarData(
                  spots: entries.map((e) {
                    final x =
                        (e.dateTime.millisecondsSinceEpoch -
                                globalMinTime)
                            .toDouble();
                    return FlSpot(x, e.value!);
                  }).toList(),
                  isCurved: true,
                  curveSmoothness: 0.3,
                  preventCurveOverShooting: true,
                  color: color,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(show: false),
                );
              }).toList(),
            ),
            duration: const Duration(milliseconds: 300),
          ),
        ),

        // Legend with toggle
        if (widget.showLegend && seriesKeys.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              alignment: WrapAlignment.center,
              children: seriesKeys.asMap().entries.map((e) {
                final name = e.value;
                final color = _colorForIndex(e.key);
                final isHidden = _hiddenSeries.contains(name);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isHidden) {
                        _hiddenSeries.remove(name);
                      } else {
                        // En az 1 seri görünür kalmalı
                        if (_hiddenSeries.length <
                            seriesKeys.length - 1) {
                          _hiddenSeries.add(name);
                        }
                      }
                    });
                  },
                  child: Opacity(
                    opacity: isHidden ? 0.4 : 1.0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 16,
                          height: 3,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                AppColors.textSecondary(brightness),
                            decoration: isHidden
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  String _formatValue(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}
