import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/alarm/alarm_stats_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Alarm heatmap chart (7 gun x 24 saat)
///
/// CustomPaint ile 7x24 grid cizer.
/// Renk yogunlugu = alarm sayisi / maxCount.
/// Dokunma ile tooltip gosterir.
class AlarmHeatmapChart extends StatefulWidget {
  final AlarmHeatmapData data;
  final Color baseColor;
  final double height;

  const AlarmHeatmapChart({
    super.key,
    required this.data,
    this.baseColor = AppColors.error,
    this.height = 200,
  });

  @override
  State<AlarmHeatmapChart> createState() => _AlarmHeatmapChartState();
}

class _AlarmHeatmapChartState extends State<AlarmHeatmapChart> {
  int? _touchedDay;
  int? _touchedHour;

  static const _dayLabels = ['Pzt', 'Sal', 'Car', 'Per', 'Cum', 'Cmt', 'Paz'];
  static const _hourLabels = ['0', '3', '6', '9', '12', '15', '18', '21'];

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tooltip
        if (_touchedDay != null && _touchedHour != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: widget.baseColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                '${_dayLabels[_touchedDay!]} ${_touchedHour!}:00 - ${widget.data.matrix[_touchedDay!][_touchedHour!]} alarm',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.baseColor,
                ),
              ),
            ),
          ),

        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const leftPadding = 32.0;
              const topPadding = 20.0;
              final gridWidth = constraints.maxWidth - leftPadding;
              final gridHeight = widget.height - topPadding;
              final cellWidth = gridWidth / 24;
              final cellHeight = gridHeight / 7;

              return GestureDetector(
                onTapDown: (details) {
                  final dx = details.localPosition.dx - leftPadding;
                  final dy = details.localPosition.dy - topPadding;
                  if (dx < 0 || dy < 0) return;

                  final hour = (dx / cellWidth).floor().clamp(0, 23);
                  final day = (dy / cellHeight).floor().clamp(0, 6);

                  setState(() {
                    _touchedDay = day;
                    _touchedHour = hour;
                  });
                },
                onTapUp: (_) {
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted) {
                      setState(() {
                        _touchedDay = null;
                        _touchedHour = null;
                      });
                    }
                  });
                },
                child: CustomPaint(
                  size: Size(constraints.maxWidth, widget.height),
                  painter: _HeatmapPainter(
                    data: widget.data,
                    baseColor: widget.baseColor,
                    brightness: brightness,
                    leftPadding: leftPadding,
                    topPadding: topPadding,
                    dayLabels: _dayLabels,
                    hourLabels: _hourLabels,
                    touchedDay: _touchedDay,
                    touchedHour: _touchedHour,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final AlarmHeatmapData data;
  final Color baseColor;
  final Brightness brightness;
  final double leftPadding;
  final double topPadding;
  final List<String> dayLabels;
  final List<String> hourLabels;
  final int? touchedDay;
  final int? touchedHour;

  _HeatmapPainter({
    required this.data,
    required this.baseColor,
    required this.brightness,
    required this.leftPadding,
    required this.topPadding,
    required this.dayLabels,
    required this.hourLabels,
    this.touchedDay,
    this.touchedHour,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridWidth = size.width - leftPadding;
    final gridHeight = size.height - topPadding;
    final cellWidth = gridWidth / 24;
    final cellHeight = gridHeight / 7;

    final textColor = AppColors.textSecondary(brightness);
    final emptyColor = brightness == Brightness.light
        ? AppColors.systemGray6
        : AppColors.systemGray5;

    // Saat etiketleri (ust)
    for (var i = 0; i < hourLabels.length; i++) {
      final hour = int.parse(hourLabels[i]);
      final tp = TextPainter(
        text: TextSpan(
          text: hourLabels[i],
          style: TextStyle(
            color: textColor,
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(leftPadding + hour * cellWidth + (cellWidth - tp.width) / 2, 2),
      );
    }

    // Gun ve hucreleri ciz
    for (var day = 0; day < 7; day++) {
      // Gun etiketi
      final tp = TextPainter(
        text: TextSpan(
          text: dayLabels[day],
          style: TextStyle(
            color: textColor,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(0, topPadding + day * cellHeight + (cellHeight - tp.height) / 2),
      );

      for (var hour = 0; hour < 24; hour++) {
        final count = data.matrix[day][hour];
        final rect = Rect.fromLTWH(
          leftPadding + hour * cellWidth + 1,
          topPadding + day * cellHeight + 1,
          cellWidth - 2,
          cellHeight - 2,
        );

        Color cellColor;
        if (count == 0 || data.maxCount == 0) {
          cellColor = emptyColor;
        } else {
          final intensity = (count / data.maxCount).clamp(0.15, 1.0);
          cellColor = baseColor.withValues(alpha: intensity);
        }

        final isHighlighted = touchedDay == day && touchedHour == hour;
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(2));

        canvas.drawRRect(rrect, Paint()..color = cellColor);

        if (isHighlighted) {
          canvas.drawRRect(
            rrect,
            Paint()
              ..color = baseColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) {
    return data != oldDelegate.data ||
        touchedDay != oldDelegate.touchedDay ||
        touchedHour != oldDelegate.touchedHour ||
        brightness != oldDelegate.brightness;
  }
}
