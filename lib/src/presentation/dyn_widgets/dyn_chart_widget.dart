import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'dyn_widget_helpers.dart';

/// fl_chart tabanlı dinamik grafik widget'ı.
///
/// Desteklenen [chartKind]:
/// - `bar_chart` / `horizontal_bar` / `stacked_bar` → BarChart
/// - `line_chart` / `area_chart` → LineChart (area = dolgulu)
/// - `pie_chart` / `donut_chart` → PieChart (donut = centerSpaceRadius>0)
///
/// `labelField` = x/kategori (verilmezse ilk metin kolonu). `valueFields[]` =
/// seriler (verilmezse sayısal kolonlar). `colors[]` visualConfig'ten ya da
/// varsayılan 10-renk paletinden. Bilinmeyen kind → soluk placeholder.
class DynChartWidget extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> visualConfig;
  final String chartKind;

  /// Grafik yüksekliği.
  final double height;

  const DynChartWidget(
    this.rows,
    this.visualConfig, {
    required this.chartKind,
    this.height = 220,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textSecondary = AppColors.textSecondary(brightness);

    if (rows.isEmpty) {
      return _placeholder('veri yok', textSecondary);
    }

    switch (chartKind) {
      case 'bar_chart':
      case 'horizontal_bar':
      case 'stacked_bar':
        return _buildBarChart(context);
      case 'line_chart':
      case 'area_chart':
        return _buildLineChart(context);
      case 'pie_chart':
      case 'donut_chart':
        return _buildPieChart(context);
      default:
        return _placeholder('Desteklenmeyen grafik: $chartKind', textSecondary);
    }
  }

  // ============================================
  // FIELD RESOLUTION
  // ============================================

  String _resolveLabelField() {
    return DynWidgetHelpers.readString(visualConfig, 'labelField') ??
        DynWidgetHelpers.firstStringKey(rows.first) ??
        rows.first.keys.first;
  }

  List<String> _resolveValueFields(String labelField) {
    final configured =
        DynWidgetHelpers.readStringList(visualConfig, 'valueFields');
    if (configured.isNotEmpty) return configured;

    // Sayısal kolonlar (label hariç).
    final fields = <String>[];
    for (final entry in rows.first.entries) {
      if (entry.key == labelField) continue;
      if (DynWidgetHelpers.toNum(entry.value) != null &&
          entry.value is! bool) {
        fields.add(entry.key);
      }
    }
    return fields;
  }

  double _maxYAcross(List<String> valueFields, {bool stacked = false}) {
    var maxY = 0.0;
    for (final row in rows) {
      if (stacked) {
        var sum = 0.0;
        for (final f in valueFields) {
          sum += DynWidgetHelpers.toNum(row[f])?.toDouble() ?? 0;
        }
        if (sum > maxY) maxY = sum;
      } else {
        for (final f in valueFields) {
          final v = DynWidgetHelpers.toNum(row[f])?.toDouble() ?? 0;
          if (v > maxY) maxY = v;
        }
      }
    }
    // Üstte biraz boşluk; sıfırsa 1'e sabitle.
    return maxY <= 0 ? 1 : maxY * 1.15;
  }

  // ============================================
  // BAR
  // ============================================

  Widget _buildBarChart(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textSecondary = AppColors.textSecondary(brightness);
    final palette = DynWidgetHelpers.resolveColors(visualConfig);

    final labelField = _resolveLabelField();
    final valueFields = _resolveValueFields(labelField);
    if (valueFields.isEmpty) {
      return _placeholder('Sayısal seri bulunamadı', textSecondary);
    }

    final stacked = chartKind == 'stacked_bar';
    final maxY = _maxYAcross(valueFields, stacked: stacked);

    final groups = <BarChartGroupData>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (stacked) {
        var runningTop = 0.0;
        final stackItems = <BarChartRodStackItem>[];
        for (var s = 0; s < valueFields.length; s++) {
          final v =
              DynWidgetHelpers.toNum(row[valueFields[s]])?.toDouble() ?? 0;
          if (v <= 0) continue;
          stackItems.add(BarChartRodStackItem(
            runningTop,
            runningTop + v,
            palette[s % palette.length],
          ));
          runningTop += v;
        }
        groups.add(BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: runningTop,
              rodStackItems: stackItems,
              width: 14,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ));
      } else {
        final rods = <BarChartRodData>[];
        for (var s = 0; s < valueFields.length; s++) {
          final v =
              DynWidgetHelpers.toNum(row[valueFields[s]])?.toDouble() ?? 0;
          rods.add(BarChartRodData(
            toY: v,
            color: palette[s % palette.length],
            width: valueFields.length > 1 ? 8 : 14,
            borderRadius: BorderRadius.circular(2),
          ));
        }
        groups.add(BarChartGroupData(x: i, barRods: rods));
      }
    }

    return _chartFrame(
      context: context,
      valueFields: valueFields,
      palette: palette,
      chart: BarChart(
        BarChartData(
          maxY: maxY,
          minY: 0,
          barGroups: groups,
          gridData: _gridData(brightness),
          borderData: FlBorderData(show: false),
          titlesData: _titles(
            brightness: brightness,
            maxY: maxY,
            categoryLabelAt: (i) => _categoryLabel(i, labelField),
          ),
          barTouchData: BarTouchData(
            enabled: true,
            // Varsayılan fl_chart tooltip'i lacivert zemin + okunaksız metin
            // veriyordu → yüzey zemini + textPrimary ile okunur hale getir.
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.surface(brightness),
              tooltipRoundedRadius: AppSpacing.radiusSm,
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final label = _categoryLabel(group.x.toInt(), labelField);
                final val = rod.toY;
                final valStr = val == val.roundToDouble()
                    ? val.toInt().toString()
                    : val.toStringAsFixed(1);
                return BarTooltipItem(
                  '$label\n$valStr',
                  TextStyle(
                    color: AppColors.textPrimary(brightness),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // LINE / AREA
  // ============================================

  Widget _buildLineChart(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textSecondary = AppColors.textSecondary(brightness);
    final palette = DynWidgetHelpers.resolveColors(visualConfig);

    final labelField = _resolveLabelField();
    final valueFields = _resolveValueFields(labelField);
    if (valueFields.isEmpty) {
      return _placeholder('Sayısal seri bulunamadı', textSecondary);
    }

    final area = chartKind == 'area_chart';
    final maxY = _maxYAcross(valueFields);

    final bars = <LineChartBarData>[];
    for (var s = 0; s < valueFields.length; s++) {
      final color = palette[s % palette.length];
      final spots = <FlSpot>[];
      for (var i = 0; i < rows.length; i++) {
        final v =
            DynWidgetHelpers.toNum(rows[i][valueFields[s]])?.toDouble() ?? 0;
        spots.add(FlSpot(i.toDouble(), v));
      }
      bars.add(LineChartBarData(
        spots: spots,
        color: color,
        barWidth: 2.5,
        isCurved: true,
        preventCurveOverShooting: true,
        dotData: FlDotData(show: rows.length <= 12),
        belowBarData: BarAreaData(
          show: area,
          color: color.withValues(alpha: 0.15),
        ),
      ));
    }

    return _chartFrame(
      context: context,
      valueFields: valueFields,
      palette: palette,
      chart: LineChart(
        LineChartData(
          maxY: maxY,
          minY: 0,
          minX: 0,
          maxX: (rows.length - 1).clamp(0, double.maxFinite).toDouble(),
          lineBarsData: bars,
          gridData: _gridData(brightness),
          borderData: FlBorderData(show: false),
          titlesData: _titles(
            brightness: brightness,
            maxY: maxY,
            categoryLabelAt: (i) => _categoryLabel(i, labelField),
          ),
          lineTouchData: const LineTouchData(enabled: true),
        ),
      ),
    );
  }

  // ============================================
  // PIE / DONUT
  // ============================================

  Widget _buildPieChart(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textSecondary = AppColors.textSecondary(brightness);
    final palette = DynWidgetHelpers.resolveColors(visualConfig);

    final labelField = _resolveLabelField();
    final valueFields = _resolveValueFields(labelField);
    final valueField = valueFields.isNotEmpty
        ? valueFields.first
        : DynWidgetHelpers.firstNumericKey(rows.first);
    if (valueField == null) {
      return _placeholder('Sayısal alan bulunamadı', textSecondary);
    }

    final donut = chartKind == 'donut_chart';
    final total = rows.fold<double>(
      0,
      (sum, r) => sum + (DynWidgetHelpers.toNum(r[valueField])?.toDouble() ?? 0),
    );

    final sections = <PieChartSectionData>[];
    final legendLabels = <String>[];
    for (var i = 0; i < rows.length; i++) {
      final v = DynWidgetHelpers.toNum(rows[i][valueField])?.toDouble() ?? 0;
      if (v <= 0) continue;
      final pct = total > 0 ? (v / total * 100) : 0;
      sections.add(PieChartSectionData(
        value: v,
        color: palette[i % palette.length],
        radius: donut ? 44 : 56,
        title: '${pct.toStringAsFixed(0)}%',
        titleStyle: AppTypography.withColor(
          AppTypography.caption2,
          Colors.white,
        ),
      ));
      legendLabels.add(rows[i][labelField]?.toString() ?? '—');
    }

    if (sections.isEmpty) {
      return _placeholder('veri yok', textSecondary);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: donut ? 40 : 0,
              sectionsSpace: 2,
              pieTouchData: PieTouchData(enabled: true),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _legend(legendLabels, palette, brightness),
      ],
    );
  }

  // ============================================
  // SHARED CHROME
  // ============================================

  Widget _chartFrame({
    required BuildContext context,
    required List<String> valueFields,
    required List<Color> palette,
    required Widget chart,
  }) {
    final brightness = Theme.of(context).brightness;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: height, child: chart),
        if (valueFields.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          _legend(valueFields, palette, brightness),
        ],
      ],
    );
  }

  Widget _legend(
    List<String> labels,
    List<Color> palette,
    Brightness brightness,
  ) {
    final textSecondary = AppColors.textSecondary(brightness);
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < labels.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: palette[i % palette.length],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                labels[i],
                style: AppTypography.withColor(
                  AppTypography.caption1,
                  textSecondary,
                ),
              ),
            ],
          ),
      ],
    );
  }

  FlGridData _gridData(Brightness brightness) {
    return FlGridData(
      show: true,
      drawVerticalLine: false,
      getDrawingHorizontalLine: (value) => FlLine(
        color: AppColors.border(brightness).withValues(alpha: 0.4),
        strokeWidth: 0.5,
      ),
    );
  }

  FlTitlesData _titles({
    required Brightness brightness,
    required double maxY,
    required String Function(int index) categoryLabelAt,
  }) {
    final textSecondary = AppColors.textSecondary(brightness);
    final style = AppTypography.withColor(AppTypography.caption2, textSecondary);

    return FlTitlesData(
      show: true,
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          interval: maxY > 0 ? maxY / 4 : null,
          getTitlesWidget: (value, meta) => Text(
            DynWidgetHelpers.formatNumber(value),
            style: style,
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          getTitlesWidget: (value, meta) {
            final i = value.round();
            if (i < 0 || i >= rows.length) return const SizedBox.shrink();
            // Çok kategori varsa etiketleri seyrekleştir.
            final step = (rows.length / 6).ceil();
            if (rows.length > 8 && i % step != 0) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                categoryLabelAt(i),
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
      ),
    );
  }

  String _categoryLabel(int index, String labelField) {
    if (index < 0 || index >= rows.length) return '';
    final raw = rows[index][labelField];
    final date = DynWidgetHelpers.tryDate(raw);
    if (date != null) {
      return '${date.day.toString().padLeft(2, '0')}.'
          '${date.month.toString().padLeft(2, '0')}';
    }
    return raw?.toString() ?? '';
  }

  Widget _placeholder(String message, Color textSecondary) {
    return SizedBox(
      height: height,
      child: Center(
        child: Text(
          message,
          style: AppTypography.withColor(AppTypography.footnote, textSecondary),
        ),
      ),
    );
  }
}
