import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/alarm/alarm_stats_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Alarm pie/donut chart widget
///
/// Alarm dağılımını (aktif vs reset) donut chart olarak gösterir.
/// Merkez: toplam alarm sayısı.
/// Aktif alarmlar: alarms tablosu, Reset alarmlar: alarm_histories tablosu.
class AlarmPieChart extends StatefulWidget {
  final AlarmDistribution distribution;
  final double size;

  const AlarmPieChart({
    super.key,
    required this.distribution,
    this.size = 200,
  });

  @override
  State<AlarmPieChart> createState() => _AlarmPieChartState();
}

class _AlarmPieChartState extends State<AlarmPieChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final dist = widget.distribution;

    if (dist.totalCount == 0) {
      return SizedBox(
        height: widget.size,
        child: Center(
          child: Text(
            'Alarm kaydı yok',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary(brightness),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      setState(() {
                        if (event.isInterestedForInteractions &&
                            response != null &&
                            response.touchedSection != null) {
                          _touchedIndex = response
                              .touchedSection!.touchedSectionIndex;
                        } else {
                          _touchedIndex = null;
                        }
                      });
                    },
                  ),
                  startDegreeOffset: -90,
                  sectionsSpace: 2,
                  centerSpaceRadius: widget.size * 0.3,
                  sections: _buildSections(brightness),
                ),
                swapAnimationDuration:
                    const Duration(milliseconds: 300),
              ),
              // Merkez: toplam sayı
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dist.totalCount.toString(),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                  Text(
                    'Toplam',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(brightness),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Legend
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendItem(
              color: AppColors.error,
              label: 'Aktif',
              value: dist.activeCount,
              brightness: brightness,
            ),
            const SizedBox(width: AppSpacing.lg),
            _LegendItem(
              color: AppColors.success,
              label: 'Reset',
              value: dist.resetCount,
              brightness: brightness,
            ),
            if (dist.acknowledgedCount > 0) ...[
              const SizedBox(width: AppSpacing.lg),
              _LegendItem(
                color: AppColors.info,
                label: 'Onaylı',
                value: dist.acknowledgedCount,
                brightness: brightness,
              ),
            ],
          ],
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildSections(Brightness brightness) {
    final dist = widget.distribution;
    final sections = <PieChartSectionData>[];

    void addSection(int index, int count, Color color, String label) {
      if (count <= 0) return;
      final isTouched = _touchedIndex == sections.length;
      final radius = isTouched
          ? widget.size * 0.22
          : widget.size * 0.18;

      sections.add(PieChartSectionData(
        value: count.toDouble(),
        color: color,
        radius: radius,
        title: isTouched ? '$count' : '',
        titleStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titlePositionPercentageOffset: 0.5,
      ));
    }

    addSection(0, dist.activeCount, AppColors.error, 'Aktif');
    addSection(1, dist.resetCount, AppColors.success, 'Reset');
    if (dist.acknowledgedCount > 0) {
      addSection(
          2, dist.acknowledgedCount, AppColors.info, 'Onaylı');
    }

    return sections;
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int value;
  final Brightness brightness;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
    required this.brightness,
  });

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
          '$label ($value)',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary(brightness),
          ),
        ),
      ],
    );
  }
}
