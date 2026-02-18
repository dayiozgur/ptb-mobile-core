import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/alarm/alarm_stats_model.dart';
import '../../../core/priority/priority_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// En sik tekrarlayan alarmlar listesi (Top N)
///
/// Siralanmis liste: rank, alarm adi, tekrar sayisi badge, son olusma, priority rengi.
class AlarmTopOffendersCard extends StatelessWidget {
  final List<AlarmFrequency> alarms;
  final Map<String, Priority>? priorities;

  const AlarmTopOffendersCard({
    super.key,
    required this.alarms,
    this.priorities,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    if (alarms.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'Alarm verisi bulunamadi',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary(brightness),
            ),
          ),
        ),
      );
    }

    return Column(
      children: alarms.asMap().entries.map((entry) {
        final index = entry.key;
        final alarm = entry.value;
        final priorityId = alarm.priorityId;
        final Priority? priority;
        if (priorityId != null && priorities != null) {
          priority = priorities![priorityId];
        } else {
          priority = null;
        }
        final priorityColor = priority?.displayColor ?? AppColors.systemGray;

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: index < alarms.length - 1
                ? Border(
                    bottom: BorderSide(
                      color: AppColors.divider(brightness),
                      width: 0.5,
                    ),
                  )
                : null,
          ),
          child: Row(
            children: [
              // Rank
              SizedBox(
                width: 24,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: index < 3
                        ? AppColors.error
                        : AppColors.textSecondary(brightness),
                  ),
                ),
              ),

              // Priority renk indicator
              Container(
                width: 4,
                height: 32,
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Alarm bilgileri
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alarm.alarmName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(brightness),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Son: ${DateFormat('dd/MM HH:mm').format(alarm.lastOccurrence)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary(brightness),
                      ),
                    ),
                  ],
                ),
              ),

              // Count badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (index < 3 ? AppColors.error : AppColors.warning)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${alarm.count}x',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: index < 3 ? AppColors.error : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
