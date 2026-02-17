import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/iot_log/iot_log_stats_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Tek bir variable'ın zaman serisi verisi
class VariableTimeSeries {
  final String variableId;
  final String variableName;
  final String? unit;
  final Color color;
  final List<LogTimeSeriesEntry> entries;

  const VariableTimeSeries({
    required this.variableId,
    required this.variableName,
    this.unit,
    required this.color,
    required this.entries,
  });

  List<LogTimeSeriesEntry> get numericEntries =>
      entries.where((e) => e.hasNumericValue).toList();
}

/// Çoklu variable serisini aynı grafik üzerinde gösteren line chart
///
/// Her variable farklı renkte gösterilir.
/// Touch ile tooltip'te variable adı ve değer gösterilir.
class MultiLogLineChart extends StatefulWidget {
  final List<VariableTimeSeries> seriesList;
  final double height;
  final int maxDataPoints;
  final bool showLegend;

  const MultiLogLineChart({
    super.key,
    required this.seriesList,
    this.height = 240,
    this.maxDataPoints = 500,
    this.showLegend = true,
  });

  @override
  State<MultiLogLineChart> createState() => _MultiLogLineChartState();
}

class _MultiLogLineChartState extends State<MultiLogLineChart> {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    // Her seri için numeric entries'leri hazırla
    final processedSeries = <_ProcessedSeries>[];
    for (final series in widget.seriesList) {
      var entries = series.numericEntries;
      if (entries.length < 2) continue;

      // Performans için örnekleme
      if (entries.length > widget.maxDataPoints) {
        final step = entries.length ~/ widget.maxDataPoints;
        entries = List.generate(
          widget.maxDataPoints,
          (i) => entries[i * step],
        );
      }
      processedSeries.add(_ProcessedSeries(
        series: series,
        entries: entries,
      ));
    }

    if (processedSeries.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.show_chart, size: 32, color: AppColors.textSecondary(brightness)),
              const SizedBox(height: AppSpacing.sm),
              Text('Yeterli veri yok', style: TextStyle(fontSize: 14, color: AppColors.textSecondary(brightness))),
            ],
          ),
        ),
      );
    }

    // Global zaman aralığını hesapla (tüm seriler üzerinden)
    int globalFirstTime = processedSeries.first.entries.first.dateTime.millisecondsSinceEpoch;
    int globalLastTime = processedSeries.first.entries.last.dateTime.millisecondsSinceEpoch;
    double globalMinY = double.infinity;
    double globalMaxY = double.negativeInfinity;

    for (final ps in processedSeries) {
      final ft = ps.entries.first.dateTime.millisecondsSinceEpoch;
      final lt = ps.entries.last.dateTime.millisecondsSinceEpoch;
      if (ft < globalFirstTime) globalFirstTime = ft;
      if (lt > globalLastTime) globalLastTime = lt;

      for (final e in ps.entries) {
        if (e.value! < globalMinY) globalMinY = e.value!;
        if (e.value! > globalMaxY) globalMaxY = e.value!;
      }
    }

    final timeRange = (globalLastTime - globalFirstTime).toDouble();
    if (timeRange <= 0) {
      return SizedBox(height: widget.height);
    }

    final range = globalMaxY - globalMinY;
    final padding = range > 0 ? range * 0.15 : 1.0;
    final yMin = (globalMinY >= 0 && globalMinY < padding) ? 0.0 : globalMinY - padding;
    final yMax = globalMaxY + padding;

    // Line bar data oluştur
    final lineBars = <LineChartBarData>[];
    for (final ps in processedSeries) {
      final spots = ps.entries.map((e) {
        final x = (e.dateTime.millisecondsSinceEpoch - globalFirstTime).toDouble();
        return FlSpot(x, e.value!);
      }).toList();

      lineBars.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.25,
        preventCurveOverShooting: true,
        color: ps.series.color,
        barWidth: 2.0,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: ps.entries.length <= 20,
          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
            radius: 3,
            color: ps.series.color,
            strokeWidth: 0,
            strokeColor: Colors.transparent,
          ),
        ),
        belowBarData: BarAreaData(
          show: processedSeries.length == 1,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ps.series.color.withValues(alpha: 0.2),
              ps.series.color.withValues(alpha: 0.02),
            ],
          ),
        ),
      ));
    }

    return Column(
      children: [
        // Legend
        if (widget.showLegend && processedSeries.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              alignment: WrapAlignment.center,
              children: processedSeries.map((ps) {
                final unit = ps.series.unit;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 3,
                      decoration: BoxDecoration(
                        color: ps.series.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unit != null && unit.isNotEmpty
                          ? '${ps.series.variableName} ($unit)'
                          : ps.series.variableName,
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
                touchSpotThreshold: 20,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => brightness == Brightness.light
                      ? Colors.white
                      : AppColors.systemGray5,
                  tooltipRoundedRadius: AppSpacing.radiusMd,
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  tooltipMargin: 12,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  maxContentWidth: 200,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final seriesIndex = spot.barIndex;
                      if (seriesIndex >= processedSeries.length) {
                        return null;
                      }
                      final ps = processedSeries[seriesIndex];

                      // En yakın entry'yi bul
                      int closestIndex = 0;
                      double minDiff = double.infinity;
                      for (var i = 0; i < ps.entries.length; i++) {
                        final x = (ps.entries[i].dateTime.millisecondsSinceEpoch - globalFirstTime).toDouble();
                        final diff = (x - spot.x).abs();
                        if (diff < minDiff) {
                          minDiff = diff;
                          closestIndex = i;
                        }
                      }

                      final entry = ps.entries[closestIndex];
                      final timeStr = DateFormat('dd/MM HH:mm').format(entry.dateTime);
                      final unit = ps.series.unit ?? '';
                      final valueStr = _formatValue(spot.y);

                      return LineTooltipItem(
                        '',
                        const TextStyle(),
                        children: [
                          TextSpan(
                            text: '${ps.series.variableName}\n',
                            style: TextStyle(
                              color: ps.series.color,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          TextSpan(
                            text: '$valueStr $unit\n',
                            style: TextStyle(
                              color: ps.series.color,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          TextSpan(
                            text: timeStr,
                            style: TextStyle(
                              color: AppColors.textSecondary(brightness),
                              fontWeight: FontWeight.w400,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                ),
                handleBuiltInTouches: true,
                getTouchedSpotIndicator: (barData, spotIndexes) {
                  return spotIndexes.map((index) {
                    return TouchedSpotIndicatorData(
                      FlLine(
                        color: barData.color?.withValues(alpha: 0.5) ?? AppColors.primary.withValues(alpha: 0.5),
                        strokeWidth: 1.5,
                        dashArray: [4, 4],
                      ),
                      FlDotData(
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 5,
                          color: barData.color ?? AppColors.primary,
                          strokeWidth: 2.5,
                          strokeColor: brightness == Brightness.light ? Colors.white : AppColors.systemGray5,
                        ),
                      ),
                    );
                  }).toList();
                },
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: _calculateYInterval(yMin, yMax),
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
                      final ms = (globalFirstTime + value.toInt());
                      final dt = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
                      final format = timeRange > const Duration(days: 3).inMilliseconds
                          ? DateFormat('dd/MM')
                          : timeRange > const Duration(hours: 12).inMilliseconds
                              ? DateFormat('dd HH:mm')
                              : DateFormat('HH:mm');
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          format.format(dt),
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
                    reservedSize: 48,
                    interval: _calculateYInterval(yMin, yMax),
                    getTitlesWidget: (value, meta) {
                      if (value == meta.min || value == meta.max) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          _formatValue(value),
                          style: TextStyle(
                            color: AppColors.textSecondary(brightness),
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      );
                    },
                  ),
                ),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: lineBars,
            ),
            duration: const Duration(milliseconds: 250),
          ),
        ),
      ],
    );
  }

  double _calculateYInterval(double min, double max) {
    final range = max - min;
    if (range <= 0) return 1;
    if (range <= 1) return 0.2;
    if (range <= 5) return 1;
    if (range <= 10) return 2;
    if (range <= 25) return 5;
    if (range <= 50) return 10;
    if (range <= 100) return 20;
    if (range <= 250) return 50;
    if (range <= 500) return 100;
    if (range <= 1000) return 200;
    return (range / 5).roundToDouble();
  }

  String _formatValue(double value) {
    if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class _ProcessedSeries {
  final VariableTimeSeries series;
  final List<LogTimeSeriesEntry> entries;

  _ProcessedSeries({required this.series, required this.entries});
}
