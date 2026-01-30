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
/// Geliştirilmiş özellikler:
/// - ON/OFF yüzde gösterimi
/// - Son durum göstergesi
/// - Geçiş sayısı bilgisi
/// - Daha iyi touch desteği
class LogOnOffChart extends StatefulWidget {
  final List<LogTimeSeriesEntry> entries;
  final double height;
  final Color onColor;
  final Color offColor;
  final bool showPercentage;
  final bool showTransitionCount;

  const LogOnOffChart({
    super.key,
    required this.entries,
    this.height = 120,
    this.onColor = AppColors.success,
    this.offColor = AppColors.systemGray3,
    this.showPercentage = true,
    this.showTransitionCount = true,
  });

  @override
  State<LogOnOffChart> createState() => _LogOnOffChartState();
}

class _LogOnOffChartState extends State<LogOnOffChart> {
  List<LogTimeSeriesEntry> get _onOffEntries =>
      widget.entries.where((e) => e.hasOnOff).toList();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final data = _onOffEntries;

    if (data.length < 2) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.toggle_off_outlined,
                size: 32,
                color: AppColors.textSecondary(brightness),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'On/Off verisi yok',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary(brightness),
                ),
              ),
              Text(
                'En az 2 veri noktası gerekli',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(brightness).withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final firstTime = data.first.dateTime.millisecondsSinceEpoch;
    final lastTime = data.last.dateTime.millisecondsSinceEpoch;
    final timeRange = (lastTime - firstTime).toDouble();

    if (timeRange <= 0) {
      return SizedBox(height: widget.height);
    }

    final spots = data.map((e) {
      final x = (e.dateTime.millisecondsSinceEpoch - firstTime).toDouble();
      final y = (e.onOff == 1) ? 1.0 : 0.0;
      return FlSpot(x, y);
    }).toList();

    // ON/OFF süre ve istatistik hesapla
    Duration onDuration = Duration.zero;
    Duration offDuration = Duration.zero;
    int transitionCount = 0;
    int? previousState;

    for (var i = 0; i < data.length - 1; i++) {
      final diff = data[i + 1].dateTime.difference(data[i].dateTime);
      if (data[i].onOff == 1) {
        onDuration += diff;
      } else {
        offDuration += diff;
      }

      // Geçiş sayısı
      if (previousState != null && previousState != data[i].onOff) {
        transitionCount++;
      }
      previousState = data[i].onOff;
    }

    // Son geçişi de say
    if (previousState != null && previousState != data.last.onOff) {
      transitionCount++;
    }

    final totalDuration = onDuration + offDuration;
    final onPercentage = totalDuration.inMilliseconds > 0
        ? (onDuration.inMilliseconds / totalDuration.inMilliseconds * 100)
        : 0.0;

    // Son durum
    final currentState = data.last.onOff == 1;

    return Column(
      children: [
        // Üst bilgi satırı: Son durum + Geçiş sayısı
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Son durum göstergesi
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: (currentState ? widget.onColor : widget.offColor)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(
                    color: currentState ? widget.onColor : widget.offColor,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: currentState ? widget.onColor : widget.offColor,
                        shape: BoxShape.circle,
                        boxShadow: currentState
                            ? [
                                BoxShadow(
                                  color: widget.onColor.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      currentState ? 'ON' : 'OFF',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: currentState ? widget.onColor : widget.offColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.showTransitionCount) ...[
                const SizedBox(width: AppSpacing.md),
                // Geçiş sayısı
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.swap_horiz,
                      size: 16,
                      color: AppColors.textSecondary(brightness),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$transitionCount geçiş',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(brightness),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Chart
        SizedBox(
          height: widget.height,
          child: LineChart(
            LineChartData(
              minY: -0.1,
              maxY: 1.1,
              minX: 0,
              maxX: timeRange,
              clipData: FlClipData.all(),
              lineTouchData: LineTouchData(
                enabled: true,
                touchSpotThreshold: 30,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => brightness == Brightness.light
                      ? Colors.white
                      : AppColors.systemGray5,
                  tooltipRoundedRadius: AppSpacing.radiusMd,
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final isOn = spot.y >= 0.5;

                      // En yakın entry'yi bul
                      int closestIndex = 0;
                      double minDiff = double.infinity;
                      for (var i = 0; i < data.length; i++) {
                        final x = (data[i].dateTime.millisecondsSinceEpoch - firstTime).toDouble();
                        final diff = (x - spot.x).abs();
                        if (diff < minDiff) {
                          minDiff = diff;
                          closestIndex = i;
                        }
                      }

                      final entry = data[closestIndex];
                      final timeStr = DateFormat('dd/MM HH:mm:ss')
                          .format(entry.dateTime);

                      return LineTooltipItem(
                        '',
                        const TextStyle(),
                        children: [
                          TextSpan(
                            text: '${isOn ? 'ON' : 'OFF'}\n',
                            style: TextStyle(
                              color: isOn ? widget.onColor : widget.offColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          TextSpan(
                            text: timeStr,
                            style: TextStyle(
                              color: AppColors.textSecondary(brightness),
                              fontWeight: FontWeight.w400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (value) {
                  if (value == 0 || value == 1) {
                    return FlLine(
                      color: AppColors.divider(brightness),
                      strokeWidth: 0.5,
                      dashArray: [4, 4],
                    );
                  }
                  return FlLine(color: Colors.transparent);
                },
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
                      final ms = firstTime + value.toInt();
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
                    reservedSize: 36,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) {
                        return Container(
                          padding: const EdgeInsets.only(right: 4),
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: widget.offColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              'OFF',
                              style: TextStyle(
                                color: widget.offColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      }
                      if (value == 1) {
                        return Container(
                          padding: const EdgeInsets.only(right: 4),
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: widget.onColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              'ON',
                              style: TextStyle(
                                color: widget.onColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
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
                  lineChartStepData: LineChartStepData(stepDirection: LineChartStepData.stepDirectionForward),
                  color: widget.onColor,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: data.length <= 30,
                    getDotPainter: (spot, percent, barData, index) {
                      final isOn = spot.y >= 0.5;
                      return FlDotCirclePainter(
                        radius: 4,
                        color: isOn ? widget.onColor : widget.offColor,
                        strokeWidth: 2,
                        strokeColor: brightness == Brightness.light
                            ? Colors.white
                            : AppColors.systemGray5,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        widget.onColor.withValues(alpha: 0.25),
                        widget.onColor.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(milliseconds: 250),
          ),
        ),

        // ON/OFF süre özeti + yüzde
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Column(
            children: [
              // Yüzde bar
              if (widget.showPercentage && totalDuration.inMilliseconds > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Column(
                    children: [
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: 8,
                          child: Row(
                            children: [
                              Expanded(
                                flex: onPercentage.round(),
                                child: Container(color: widget.onColor),
                              ),
                              Expanded(
                                flex: (100 - onPercentage).round(),
                                child: Container(color: widget.offColor.withValues(alpha: 0.3)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Yüzde değerleri
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ON: %${onPercentage.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: widget.onColor,
                            ),
                          ),
                          Text(
                            'OFF: %${(100 - onPercentage).toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: widget.offColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              // Süre badge'leri
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _DurationBadge(
                    label: 'ON',
                    duration: onDuration,
                    color: widget.onColor,
                    brightness: brightness,
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  _DurationBadge(
                    label: 'OFF',
                    duration: offDuration,
                    color: widget.offColor,
                    brightness: brightness,
                  ),
                ],
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
    if (d.inDays > 0) {
      final hours = d.inHours % 24;
      return hours > 0 ? '${d.inDays}g ${hours}s' : '${d.inDays}g';
    }
    if (d.inHours > 0) {
      final mins = d.inMinutes % 60;
      return mins > 0 ? '${d.inHours}s ${mins}dk' : '${d.inHours}s';
    }
    if (d.inMinutes > 0) {
      return '${d.inMinutes}dk';
    }
    return '${d.inSeconds}sn';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
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
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
