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
///
/// Toggle modu:
/// - showToggle=true ise Aktif/Reset segmented control gösterilir
/// - Her mod priority bazlı donut gösterir
class AlarmPieChart extends StatefulWidget {
  final AlarmDistribution distribution;
  final Map<String, Priority>? priorities;
  final double size;
  final bool showPriorityBreakdown;
  final bool showToggle;

  const AlarmPieChart({
    super.key,
    required this.distribution,
    this.priorities,
    this.size = 200,
    this.showPriorityBreakdown = false,
    this.showToggle = false,
  });

  @override
  State<AlarmPieChart> createState() => _AlarmPieChartState();
}

class _AlarmPieChartState extends State<AlarmPieChart> {
  int? _touchedIndex;
  int _selectedMode = 0; // 0=Aktif, 1=Reset

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
        // Toggle: Aktif / Reset
        if (widget.showToggle) ...[
          _buildToggle(brightness),
          const SizedBox(height: AppSpacing.sm),
        ],

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
              // Merkez: sayı
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _centerCount.toString(),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                  Text(
                    _centerLabel,
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

  /// Toggle moduna göre merkez sayı
  int get _centerCount {
    if (!widget.showToggle) return widget.distribution.totalCount;
    return _selectedMode == 0
        ? widget.distribution.activeCount
        : widget.distribution.resetCount;
  }

  /// Toggle moduna göre merkez etiket
  String get _centerLabel {
    if (!widget.showToggle) return 'Toplam';
    return _selectedMode == 0 ? 'Aktif' : 'Reset';
  }

  /// Aktif/Reset toggle segmented control
  Widget _buildToggle(Brightness brightness) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.systemGray6,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleButton(
            label: 'Aktif',
            count: widget.distribution.activeCount,
            isSelected: _selectedMode == 0,
            color: AppColors.error,
            brightness: brightness,
            onTap: () => setState(() {
              _selectedMode = 0;
              _touchedIndex = null;
            }),
          ),
          const SizedBox(width: 4),
          _ToggleButton(
            label: 'Reset',
            count: widget.distribution.resetCount,
            isSelected: _selectedMode == 1,
            color: AppColors.success,
            brightness: brightness,
            onTap: () => setState(() {
              _selectedMode = 1;
              _touchedIndex = null;
            }),
          ),
        ],
      ),
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

    // Toggle modu aktifse priority bazlı göster
    if (widget.showToggle && widget.priorities != null) {
      final byPriority = _selectedMode == 0
          ? dist.activeByPriority
          : dist.resetByPriority;

      if (byPriority.isNotEmpty) {
        for (final entry in byPriority.entries) {
          final priority = widget.priorities![entry.key];
          final color = priority?.displayColor ?? AppColors.systemGray;
          addSection(entry.value, color);
        }
      } else {
        // Fallback: priority dağılımı yoksa tek dilim
        final count = _selectedMode == 0 ? dist.activeCount : dist.resetCount;
        final color = _selectedMode == 0 ? AppColors.error : AppColors.success;
        addSection(count, color);
      }
      return sections;
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

    // Toggle modu: priority bazlı legend
    if (widget.showToggle && widget.priorities != null) {
      final byPriority = _selectedMode == 0
          ? dist.activeByPriority
          : dist.resetByPriority;

      if (byPriority.isNotEmpty) {
        for (final entry in byPriority.entries) {
          final priority = widget.priorities![entry.key];
          final color = priority?.displayColor ?? AppColors.systemGray;
          final label = priority?.label ?? 'Bilinmeyen';
          items.add(_LegendItem(
            color: color,
            label: label,
            value: entry.value,
            brightness: brightness,
          ));
        }
      } else {
        final count = _selectedMode == 0 ? dist.activeCount : dist.resetCount;
        final color = _selectedMode == 0 ? AppColors.error : AppColors.success;
        final label = _selectedMode == 0 ? 'Aktif' : 'Reset';
        items.add(_LegendItem(
          color: color,
          label: label,
          value: count,
          brightness: brightness,
        ));
      }
      return items;
    }

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

class _ToggleButton extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final Color color;
  final Brightness brightness;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.color,
    required this.brightness,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (brightness == Brightness.light ? Colors.white : AppColors.systemGray5)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? AppColors.textPrimary(brightness)
                    : AppColors.textSecondary(brightness),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.15)
                    : AppColors.systemGray5,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? color : AppColors.textSecondary(brightness),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
