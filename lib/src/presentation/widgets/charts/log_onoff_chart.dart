import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/iot_log/iot_log_stats_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Log On/Off step chart widget
///
/// Controller log'larındaki on_off değerlerini step chart olarak gösterir.
/// ON bölgeleri yeşil, OFF bölgeleri gri.
class LogOnOffChart extends StatelessWidget {
  final List<LogTimeSeriesEntry> entries;
  final double height;
  final Color onColor;
  final Color offColor;

  const LogOnOffChart({
    super.key,
    required this.entries,
    this.height = 120,
    this.onColor = AppColors.success,
    this.offColor = AppColors.systemGray3,
  });

  List<LogTimeSeriesEntry> get _onOffEntries =>
      entries.where((e) => e.hasOnOff).toList();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final data = _onOffEntries;

    if (data.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'On/Off verisi yok',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary(brightness),
            ),
          ),
        ),
      );
    }

    final firstTime = data.first.dateTime.millisecondsSinceEpoch;
    final lastTime = data.last.dateTime.millisecondsSinceEpoch;
    final timeRange = (lastTime - firstTime).toDouble();

    if (timeRange <= 0) {
      return SizedBox(height: height);
    }

    final spots = data.map((e) {
      final x =
          (e.dateTime.millisecondsSinceEpoch - firstTime).toDouble();
      final y = (e.onOff == 1) ? 1.0 : 0.0;
      return FlSpot(x, y);
    }).toList();

    // ON/OFF süre hesapla
    Duration onDuration = Duration.zero;
    Duration offDuration = Duration.zero;
    for (var i = 0; i < data.length - 1; i++) {
      final diff = data[i + 1].dateTime.difference(data[i].dateTime);
      if (data[i].onOff == 1) {
        onDuration += diff;
      } else {
        offDuration += diff;
      }
    }

    return Column(
      children: [
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minY: -0.1,
              maxY: 1.1,
              minX: 0,
              maxX: timeRange,
              clipData: FlClipData.all(),
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) =>
                      AppColors.surface(brightness),
                  tooltipRoundedRadius: AppSpacing.radiusSm,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final isOn = spot.y >= 0.5;
                      final entryIndex = data.indexWhere(
                        (e) =>
                            (e.dateTime.millisecondsSinceEpoch -
                                    firstTime)
                                .toDouble() ==
                            spot.x,
                      );

                      String timeStr = '';
                      if (entryIndex >= 0) {
                        timeStr = DateFormat('dd/MM HH:mm')
                            .format(data[entryIndex].dateTime);
                      }

                      return LineTooltipItem(
                        '$timeStr\n${isOn ? 'ON' : 'OFF'}',
                        TextStyle(
                          color: isOn ? onColor : offColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              gridData: FlGridData(show: false),
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
                      final ms = firstTime + value.toInt();
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
                    reservedSize: 32,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            'OFF',
                            style: TextStyle(
                              color: offColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }
                      if (value == 1) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            'ON',
                            style: TextStyle(
                              color: onColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
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
                  isCurved: false,
                  isStepLineChart: true,
                  color: onColor,
                  barWidth: 2,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        onColor.withValues(alpha: 0.2),
                        onColor.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(milliseconds: 300),
          ),
        ),

        // ON/OFF süre özeti
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _DurationBadge(
                label: 'ON',
                duration: onDuration,
                color: onColor,
                brightness: brightness,
              ),
              const SizedBox(width: AppSpacing.lg),
              _DurationBadge(
                label: 'OFF',
                duration: offDuration,
                color: offColor,
                brightness: brightness,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DurationBadge extends StatelessWidget {
  final String label;
  final Duration duration;
  final Color color;
  final Brightness brightness;

  const _DurationBadge({
    required this.label,
    required this.duration,
    required this.color,
    required this.brightness,
  });

  String _formatDuration(Duration d) {
    if (d.inDays > 0) return '${d.inDays}g ${d.inHours % 24}s';
    if (d.inHours > 0) return '${d.inHours}s ${d.inMinutes % 60}dk';
    return '${d.inMinutes}dk';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '$label: ${_formatDuration(duration)}',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary(brightness),
          ),
        ),
      ],
    );
  }
}
