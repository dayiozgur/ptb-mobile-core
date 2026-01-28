import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/iot_log/iot_log_stats_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Log line chart konfigürasyonu
class LogChartConfig {
  final Color lineColor;
  final Color? gradientColor;
  final bool showDots;
  final bool showArea;
  final bool enableTouch;
  final double lineWidth;
  final String? yAxisLabel;
  final String? valueUnit;

  const LogChartConfig({
    this.lineColor = AppColors.primary,
    this.gradientColor,
    this.showDots = false,
    this.showArea = true,
    this.enableTouch = true,
    this.lineWidth = 2.0,
    this.yAxisLabel,
    this.valueUnit,
  });
}

/// Log line chart widget
///
/// Controller log value'larını zaman serisi olarak gösterir.
/// logs tablosundaki value alanı double parse edilmiş şekilde.
/// Smooth bezier curve, gradient dolgu, tooltip desteği.
class LogLineChart extends StatefulWidget {
  final List<LogTimeSeriesEntry> entries;
  final LogChartConfig config;
  final double height;

  const LogLineChart({
    super.key,
    required this.entries,
    this.config = const LogChartConfig(),
    this.height = 200,
  });

  @override
  State<LogLineChart> createState() => _LogLineChartState();
}

class _LogLineChartState extends State<LogLineChart> {
  /// Numerik değerlere sahip entry'ler
  List<LogTimeSeriesEntry> get _numericEntries =>
      widget.entries.where((e) => e.hasNumericValue).toList();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final entries = _numericEntries;

    if (entries.length < 2) {
      return SizedBox(
        height: widget.height,
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

    final values = entries.map((e) => e.value!).toList();
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final padding = (maxVal - minVal) * 0.1;
    final yMin = minVal - padding;
    final yMax = maxVal + padding;

    final firstTime = entries.first.dateTime.millisecondsSinceEpoch;
    final lastTime = entries.last.dateTime.millisecondsSinceEpoch;
    final timeRange = (lastTime - firstTime).toDouble();

    final spots = entries.map((e) {
      final x =
          (e.dateTime.millisecondsSinceEpoch - firstTime).toDouble();
      return FlSpot(x, e.value!);
    }).toList();

    return SizedBox(
      height: widget.height,
      child: LineChart(
        LineChartData(
          minY: yMin,
          maxY: yMax,
          minX: 0,
          maxX: timeRange,
          clipData: FlClipData.all(),
          lineTouchData: LineTouchData(
            enabled: widget.config.enableTouch,
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
                  final entryIndex = entries.indexWhere(
                    (e) =>
                        (e.dateTime.millisecondsSinceEpoch -
                                firstTime)
                            .toDouble() ==
                        spot.x,
                  );

                  String timeStr = '';
                  if (entryIndex >= 0) {
                    timeStr = DateFormat('dd/MM HH:mm')
                        .format(entries[entryIndex].dateTime);
                  }

                  final unit = widget.config.valueUnit ?? '';
                  final valueStr =
                      spot.y.toStringAsFixed(1);

                  return LineTooltipItem(
                    '$timeStr\n$valueStr$unit',
                    TextStyle(
                      color: AppColors.textPrimary(brightness),
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  );
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
            getTouchedSpotIndicator: (barData, spotIndexes) {
              return spotIndexes.map((index) {
                return TouchedSpotIndicatorData(
                  FlLine(
                    color: widget.config.lineColor.withValues(alpha: 0.4),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                  FlDotData(
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                      radius: 4,
                      color: widget.config.lineColor,
                      strokeWidth: 2,
                      strokeColor: AppColors.surface(brightness),
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
                  final ms = (firstTime + value.toInt());
                  final dt =
                      DateTime.fromMillisecondsSinceEpoch(ms.toInt());

                  // İlk ve son etiket kontrolü
                  if (value == 0 || value >= timeRange) {
                    return const SizedBox.shrink();
                  }

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
                reservedSize: 42,
                interval: _calculateYInterval(yMin, yMax),
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      _formatValue(value),
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
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              preventCurveOverShooting: true,
              color: widget.config.lineColor,
              barWidth: widget.config.lineWidth,
              isStrokeCapRound: true,
              dotData: FlDotData(show: widget.config.showDots),
              belowBarData: widget.config.showArea
                  ? BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          (widget.config.gradientColor ??
                                  widget.config.lineColor)
                              .withValues(alpha: 0.3),
                          (widget.config.gradientColor ??
                                  widget.config.lineColor)
                              .withValues(alpha: 0.0),
                        ],
                      ),
                    )
                  : BarAreaData(show: false),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 300),
      ),
    );
  }

  double _calculateYInterval(double min, double max) {
    final range = max - min;
    if (range <= 0) return 1;
    if (range <= 5) return 1;
    if (range <= 20) return 5;
    if (range <= 100) return 20;
    if (range <= 500) return 100;
    return (range / 5).roundToDouble();
  }

  String _formatValue(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}
