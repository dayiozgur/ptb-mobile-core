import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/alarm/alarm_stats_model.dart';
import '../../../core/priority/priority_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// MTTR (Mean Time To Resolve) istatistik kartı
///
/// Genel MTTR değeri + priority bazlı breakdown + haftalık trend çizgisi gösterir.
class AlarmMttrCard extends StatelessWidget {
  final AlarmMttrStats stats;
  final Map<String, Priority>? priorities;

  const AlarmMttrCard({
    super.key,
    required this.stats,
    this.priorities,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ana MTTR değeri
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              stats.overallMttrFormatted,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(brightness),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Ort. Cozum Suresi',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary(brightness),
                ),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                '${stats.totalAlarmCount} alarm',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.md),

        // Priority bazlı MTTR breakdown
        if (stats.mttrByPriority.isNotEmpty) ...[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: stats.mttrByPriority.entries.map((entry) {
              final priority = priorities?[entry.key];
              final color = priority?.displayColor ?? AppColors.systemGray;
              final label = priority?.label ?? 'Bilinmiyor';
              final mttrStr = AlarmMttrStats.formatDuration(entry.value);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mttrStr,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // Haftalık MTTR trend çizgisi
        if (stats.trend.length >= 2)
          SizedBox(
            height: 80,
            child: _buildTrendChart(brightness),
          ),
      ],
    );
  }

  Widget _buildTrendChart(Brightness brightness) {
    final spots = <FlSpot>[];
    for (var i = 0; i < stats.trend.length; i++) {
      spots.add(FlSpot(i.toDouble(), stats.trend[i].avgMttr.inMinutes.toDouble()));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        clipData: FlClipData.all(),
        lineTouchData: LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.primary,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.2),
                  AppColors.primary.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
