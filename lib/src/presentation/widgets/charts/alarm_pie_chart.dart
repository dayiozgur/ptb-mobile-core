import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/alarm/alarm_stats_model.dart';
import '../../../core/priority/priority_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Alarm pie/donut chart widget
///
/// Alarm dağılımını (aktif vs reset) donut chart olarak gösterir.
/// Merkez: toplam alarm sayısı.
/// Aktif alarmlar: alarms tablosu, Reset alarmlar: alarm_histories tablosu.
///
/// Priority bazlı renklendirme:
/// - priorities parametresi verilirse, aktif alarmlar priority rengine göre gösterilir
/// - verilmezse varsayılan renkler kullanılır (aktif=error, reset=success)
class AlarmPieChart extends StatefulWidget {
  final AlarmDistribution distribution;
  final Map<String, Priority>? priorities;
  final double size;
  final bool showPriorityBreakdown;

  const AlarmPieChart({
    super.key,
    required this.distribution,
    this.priorities,
    this.size = 200,
    this.showPriorityBreakdown = false,
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
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.xs,
          children: _buildPriorityLegend(brightness),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildSections(Brightness brightness) {
    final dist = widget.distribution;
    final sections = <PieChartSectionData>[];

    void addSection(int count, Color color) {
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
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titlePositionPercentageOffset: 0.5,
      ));
    }

    // Priority breakdown gösterilecekse ve priority dağılımı varsa
    if (widget.showPriorityBreakdown &&
        dist.hasPriorityDistribution &&
        widget.priorities != null) {
      // Aktif alarmlar priority bazında
      for (final entry in dist.activeByPriority.entries) {
        final priority = widget.priorities![entry.key];
        final color = priority?.displayColor ?? AppColors.error;
        addSection(entry.value, color);
      }
      // Reset alarmlar (gri tonlarında)
      addSection(dist.resetCount, AppColors.success);
    } else {
      // Varsayılan davranış: Aktif vs Reset
      addSection(dist.activeCount, AppColors.error);
      addSection(dist.resetCount, AppColors.success);
      if (dist.acknowledgedCount > 0) {
        addSection(dist.acknowledgedCount, AppColors.info);
      }
    }

    return sections;
  }

  /// Priority bazlı legend öğeleri oluştur
  List<Widget> _buildPriorityLegend(Brightness brightness) {
    final dist = widget.distribution;
    final items = <Widget>[];

    if (widget.showPriorityBreakdown &&
        dist.hasPriorityDistribution &&
        widget.priorities != null) {
      // Aktif alarmlar priority bazında
      for (final entry in dist.activeByPriority.entries) {
        final priority = widget.priorities![entry.key];
        final color = priority?.displayColor ?? AppColors.error;
        final label = priority?.label ?? 'Bilinmeyen';
        items.add(_LegendItem(
          color: color,
          label: label,
          value: entry.value,
          brightness: brightness,
        ));
      }
      // Reset alarmlar
      if (dist.resetCount > 0) {
        items.add(_LegendItem(
          color: AppColors.success,
          label: 'Reset',
          value: dist.resetCount,
          brightness: brightness,
        ));
      }
    } else {
      // Varsayılan legend
      items.add(_LegendItem(
        color: AppColors.error,
        label: 'Aktif',
        value: dist.activeCount,
        brightness: brightness,
      ));
      items.add(_LegendItem(
        color: AppColors.success,
        label: 'Reset',
        value: dist.resetCount,
        brightness: brightness,
      ));
      if (dist.acknowledgedCount > 0) {
        items.add(_LegendItem(
          color: AppColors.info,
          label: 'Onaylı',
          value: dist.acknowledgedCount,
          brightness: brightness,
        ));
      }
    }

    return items;
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
