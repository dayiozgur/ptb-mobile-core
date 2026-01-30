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
  final bool showMinMaxIndicators;
  final bool startFromZero;

  const LogChartConfig({
    this.lineColor = AppColors.primary,
    this.gradientColor,
    this.showDots = false,
    this.showArea = true,
    this.enableTouch = true,
    this.lineWidth = 2.0,
    this.yAxisLabel,
    this.valueUnit,
    this.showMinMaxIndicators = true,
    this.startFromZero = false,
  });
}

/// Log line chart widget
///
/// Controller log value'larını zaman serisi olarak gösterir.
/// logs tablosundaki value alanı double parse edilmiş şekilde.
/// Smooth bezier curve, gradient dolgu, tooltip desteği.
/// Geliştirilmiş özellikler:
/// - Min/max değer göstergeleri
/// - Daha iyi touch hassasiyeti
/// - Performans için otomatik veri örnekleme
/// - Akıllı Y ekseni aralıkları
class LogLineChart extends StatefulWidget {
  final List<LogTimeSeriesEntry> entries;
  final LogChartConfig config;
  final double height;

  /// Maximum number of data points to display (performance optimization)
  final int maxDataPoints;

  const LogLineChart({
    super.key,
    required this.entries,
    this.config = const LogChartConfig(),
    this.height = 200,
    this.maxDataPoints = 500,
  });

  @override
  State<LogLineChart> createState() => _LogLineChartState();
}

class _LogLineChartState extends State<LogLineChart> {
  int? _touchedIndex;

  /// Numerik değerlere sahip entry'ler
  List<LogTimeSeriesEntry> get _numericEntries {
    final entries = widget.entries.where((e) => e.hasNumericValue).toList();

    // Performans için örnekleme
    if (entries.length > widget.maxDataPoints) {
      final step = entries.length ~/ widget.maxDataPoints;
      return List.generate(
        widget.maxDataPoints,
        (i) => entries[i * step],
      );
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final entries = _numericEntries;

    if (entries.length < 2) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.show_chart,
                size: 32,
                color: AppColors.textSecondary(brightness),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Yeterli veri yok',
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

    final values = entries.map((e) => e.value!).toList();
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);

    // Daha iyi Y aralığı hesaplaması
    final range = maxVal - minVal;
    final padding = range > 0 ? range * 0.15 : 1.0;

    // startFromZero seçeneği varsa veya min değer 0'a yakınsa
    final yMin = widget.config.startFromZero || (minVal >= 0 && minVal < padding)
        ? 0.0
        : minVal - padding;
    final yMax = maxVal + padding;

    final firstTime = entries.first.dateTime.millisecondsSinceEpoch;
    final lastTime = entries.last.dateTime.millisecondsSinceEpoch;
    final timeRange = (lastTime - firstTime).toDouble();

    // Min/max indekslerini bul
    int minIndex = 0;
    int maxIndex = 0;
    for (var i = 0; i < values.length; i++) {
      if (values[i] == minVal) minIndex = i;
      if (values[i] == maxVal) maxIndex = i;
    }

    final spots = entries.asMap().entries.map((e) {
      final i = e.key;
      final entry = e.value;
      final x = (entry.dateTime.millisecondsSinceEpoch - firstTime).toDouble();
      return FlSpot(x, entry.value!);
    }).toList();

    return Column(
      children: [
        // Min/Max göstergeleri
        if (widget.config.showMinMaxIndicators && range > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _MinMaxBadge(
                  label: 'Min',
                  value: minVal,
                  color: AppColors.info,
                  unit: widget.config.valueUnit,
                  brightness: brightness,
                ),
                const SizedBox(width: AppSpacing.lg),
                _MinMaxBadge(
                  label: 'Max',
                  value: maxVal,
                  color: AppColors.error,
                  unit: widget.config.valueUnit,
                  brightness: brightness,
                ),
              ],
            ),
          ),

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
                enabled: widget.config.enableTouch,
                touchSpotThreshold: 20, // Daha büyük touch alanı
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
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      // En yakın entry'yi bul
                      int closestIndex = 0;
                      double minDiff = double.infinity;
                      for (var i = 0; i < entries.length; i++) {
                        final x = (entries[i].dateTime.millisecondsSinceEpoch - firstTime).toDouble();
                        final diff = (x - spot.x).abs();
                        if (diff < minDiff) {
                          minDiff = diff;
                          closestIndex = i;
                        }
                      }

                      final entry = entries[closestIndex];
                      final timeStr = DateFormat('dd/MM HH:mm:ss')
                          .format(entry.dateTime);

                      final unit = widget.config.valueUnit ?? '';
                      final valueStr = _formatValuePrecise(spot.y);

                      return LineTooltipItem(
                        '',
                        const TextStyle(),
                        children: [
                          TextSpan(
                            text: '$valueStr$unit\n',
                            style: TextStyle(
                              color: widget.config.lineColor,
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
                handleBuiltInTouches: true,
                touchCallback: (event, response) {
                  if (event.isInterestedForInteractions &&
                      response != null &&
                      response.lineBarSpots != null &&
                      response.lineBarSpots!.isNotEmpty) {
                    setState(() {
                      _touchedIndex = response.lineBarSpots!.first.spotIndex;
                    });
                  } else {
                    setState(() {
                      _touchedIndex = null;
                    });
                  }
                },
                getTouchedSpotIndicator: (barData, spotIndexes) {
                  return spotIndexes.map((index) {
                    return TouchedSpotIndicatorData(
                      FlLine(
                        color: widget.config.lineColor.withValues(alpha: 0.5),
                        strokeWidth: 1.5,
                        dashArray: [4, 4],
                      ),
                      FlDotData(
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                          radius: 6,
                          color: widget.config.lineColor,
                          strokeWidth: 3,
                          strokeColor: brightness == Brightness.light
                              ? Colors.white
                              : AppColors.systemGray5,
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
                      final dt = DateTime.fromMillisecondsSinceEpoch(ms.toInt());

                      // İlk ve son etiket kontrolü
                      if (value == 0 || value >= timeRange) {
                        return const SizedBox.shrink();
                      }

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
                      // İlk ve son değerleri atla (kenar çizgilerinde)
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
                  curveSmoothness: 0.25,
                  preventCurveOverShooting: true,
                  color: widget.config.lineColor,
                  barWidth: widget.config.lineWidth,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: widget.config.showDots || entries.length <= 20,
                    getDotPainter: (spot, percent, barData, index) {
                      // Min/max noktalarını vurgula
                      final isMin = index == minIndex;
                      final isMax = index == maxIndex;
                      final isTouched = index == _touchedIndex;

                      if (isMin || isMax || isTouched) {
                        return FlDotCirclePainter(
                          radius: isMin || isMax ? 5 : 4,
                          color: isMin
                              ? AppColors.info
                              : isMax
                                  ? AppColors.error
                                  : widget.config.lineColor,
                          strokeWidth: 2,
                          strokeColor: brightness == Brightness.light
                              ? Colors.white
                              : AppColors.systemGray5,
                        );
                      }

                      return FlDotCirclePainter(
                        radius: 3,
                        color: widget.config.lineColor,
                        strokeWidth: 0,
                        strokeColor: Colors.transparent,
                      );
                    },
                  ),
                  belowBarData: widget.config.showArea
                      ? BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              (widget.config.gradientColor ?? widget.config.lineColor)
                                  .withValues(alpha: 0.25),
                              (widget.config.gradientColor ?? widget.config.lineColor)
                                  .withValues(alpha: 0.02),
                            ],
                          ),
                        )
                      : BarAreaData(show: false),
                ),
              ],
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

    // Daha güzel aralıklar için
    if (range <= 1) return 0.2;
    if (range <= 5) return 1;
    if (range <= 10) return 2;
    if (range <= 25) return 5;
    if (range <= 50) return 10;
    if (range <= 100) return 20;
    if (range <= 250) return 50;
    if (range <= 500) return 100;
    if (range <= 1000) return 200;

    // Büyük değerler için yaklaşık 5 çizgi
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

  String _formatValuePrecise(double value) {
    if (value.abs() >= 10000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    if (value.abs() < 1) {
      return value.toStringAsFixed(3);
    }
    return value.toStringAsFixed(2);
  }
}

class _MinMaxBadge extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final String? unit;
  final Brightness brightness;

  const _MinMaxBadge({
    required this.label,
    required this.value,
    required this.color,
    this.unit,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    String formattedValue;
    if (value.abs() >= 1000) {
      formattedValue = '${(value / 1000).toStringAsFixed(1)}k';
    } else if (value == value.roundToDouble()) {
      formattedValue = value.toInt().toString();
    } else {
      formattedValue = value.toStringAsFixed(1);
    }

    return Row(
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
        const SizedBox(width: 4),
        Text(
          '$label: $formattedValue${unit ?? ''}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary(brightness),
          ),
        ),
      ],
    );
  }
}
