import 'package:flutter/material.dart';

import '../../../core/alarm/alarm_stats_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Site bazlı alarm sıralaması - yatay bar chart
///
/// SiteAlarmCount listesini yatay bar chart olarak gösterir.
/// Sol tarafta site adları, bar uzunluğu = alarm sayısı.
/// Her bar'ın yanında sayı etiketi gösterilir.
class AlarmSiteRankingChart extends StatelessWidget {
  final List<SiteAlarmCount> sites;
  final double height;
  final int maxItems;

  const AlarmSiteRankingChart({
    super.key,
    required this.sites,
    this.height = 300,
    this.maxItems = 10,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    if (sites.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Site alarm verisi yok',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary(brightness),
            ),
          ),
        ),
      );
    }

    final displaySites = sites.take(maxItems).toList();
    final maxCount = displaySites.first.totalCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: AppColors.error, label: 'Aktif', brightness: brightness),
              const SizedBox(width: AppSpacing.md),
              _LegendDot(color: AppColors.success, label: 'Reset', brightness: brightness),
            ],
          ),
        ),
        // Bars
        ...List.generate(displaySites.length, (index) {
          final site = displaySites[index];
          return _HorizontalBar(
            site: site,
            maxCount: maxCount,
            brightness: brightness,
          );
        }),
      ],
    );
  }
}

class _HorizontalBar extends StatelessWidget {
  final SiteAlarmCount site;
  final int maxCount;
  final Brightness brightness;

  const _HorizontalBar({
    required this.site,
    required this.maxCount,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = maxCount > 0 ? site.totalCount / maxCount : 0.0;
    final activeFraction = maxCount > 0 ? site.activeCount / maxCount : 0.0;
    final resetFraction = maxCount > 0 ? site.resetCount / maxCount : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          // Site name
          SizedBox(
            width: 100,
            child: Text(
              site.siteName,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary(brightness),
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          // Bar
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                final activeWidth = totalWidth * activeFraction;
                final resetWidth = totalWidth * resetFraction;

                return Row(
                  children: [
                    if (site.activeCount > 0)
                      Container(
                        height: 18,
                        width: activeWidth.clamp(2.0, totalWidth),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: site.resetCount == 0
                              ? BorderRadius.circular(4)
                              : const BorderRadius.horizontal(left: Radius.circular(4)),
                        ),
                      ),
                    if (site.resetCount > 0)
                      Container(
                        height: 18,
                        width: resetWidth.clamp(2.0, totalWidth - activeWidth),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: site.activeCount == 0
                              ? BorderRadius.circular(4)
                              : const BorderRadius.horizontal(right: Radius.circular(4)),
                        ),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      site.totalCount.toString(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(brightness),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final Brightness brightness;

  const _LegendDot({
    required this.color,
    required this.label,
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
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary(brightness),
          ),
        ),
      ],
    );
  }
}
