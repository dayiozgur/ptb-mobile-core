import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/alarm/alarm_history_model.dart';
import '../../../core/priority/priority_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Resetli alarm listesi widget'ı
///
/// alarm_histories tablosundan gelen resetli alarmları listeler.
/// Her satırda priority renk çubuğu, alarm adı, reset zamanı ve süre gösterilir.
class ResetAlarmList extends StatelessWidget {
  final List<AlarmHistory> alarms;
  final Map<String, Priority>? priorities;
  final ValueChanged<AlarmHistory>? onAlarmTap;
  final bool isLoading;
  final String? emptyMessage;

  const ResetAlarmList({
    super.key,
    required this.alarms,
    this.priorities,
    this.onAlarmTap,
    this.isLoading = false,
    this.emptyMessage,
  });

  Color _priorityColor(AlarmHistory alarm) {
    if (alarm.priorityId != null && priorities != null) {
      final priority = priorities![alarm.priorityId!];
      if (priority?.color != null) {
        final hex = priority!.color!.replaceFirst('#', '');
        if (hex.length == 6) {
          return Color(int.parse('FF$hex', radix: 16));
        }
      }
      if (priority != null) {
        if (priority.isCritical) return AppColors.error;
        if (priority.isHigh) return AppColors.warning;
      }
    }
    return AppColors.systemGray;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    if (alarms.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 32,
                color: AppColors.systemGray3,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                emptyMessage ?? 'Resetlenmiş alarm kaydı yok',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary(brightness),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: alarms.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: AppSpacing.md + 6,
        color: AppColors.divider(brightness),
      ),
      itemBuilder: (context, index) {
        final alarm = alarms[index];
        return _ResetAlarmTile(
          alarm: alarm,
          priorityColor: _priorityColor(alarm),
          priorityName: alarm.priorityId != null
              ? priorities?[alarm.priorityId!]?.label
              : null,
          brightness: brightness,
          onTap: onAlarmTap != null ? () => onAlarmTap!(alarm) : null,
        );
      },
    );
  }
}

class _ResetAlarmTile extends StatelessWidget {
  final AlarmHistory alarm;
  final Color priorityColor;
  final String? priorityName;
  final Brightness brightness;
  final VoidCallback? onTap;

  const _ResetAlarmTile({
    required this.alarm,
    required this.priorityColor,
    this.priorityName,
    required this.brightness,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yy HH:mm');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.listItemVertical,
        ),
        child: Row(
          children: [
            // Priority renk çubuğu
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: priorityColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),

            // İçerik
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          alarm.name ?? alarm.code ?? 'Alarm',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary(brightness),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (alarm.code != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.systemGray6,
                            borderRadius:
                                BorderRadius.circular(4),
                          ),
                          child: Text(
                            alarm.code!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors
                                  .textSecondary(brightness),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: [
                      Icon(
                        Icons.restart_alt,
                        size: 13,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        alarm.resetTime != null
                            ? dateFormat.format(alarm.resetTime!)
                            : '-',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              AppColors.textSecondary(brightness),
                        ),
                      ),
                      if (alarm.resetUser != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Icon(
                          Icons.person_outline,
                          size: 13,
                          color:
                              AppColors.textSecondary(brightness),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            alarm.resetUser!,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors
                                  .textSecondary(brightness),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else
                        const Spacer(),
                      // Süre badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: priorityColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          alarm.durationFormatted,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: priorityColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Alarm detay bottom sheet
///
/// Reset alarm'ın zaman çizelgesi ve detaylarını gösterir.
class AlarmDetailSheet extends StatelessWidget {
  final AlarmHistory alarm;
  final Priority? priority;

  const AlarmDetailSheet({
    super.key,
    required this.alarm,
    this.priority,
  });

  /// Bottom sheet'i göster
  static void show(
    BuildContext context, {
    required AlarmHistory alarm,
    Priority? priority,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      builder: (_) => AlarmDetailSheet(
        alarm: alarm,
        priority: priority,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin:
                        const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.systemGray4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Başlık
                Text(
                  alarm.name ?? 'Alarm',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                if (alarm.code != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Kod: ${alarm.code}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary(brightness),
                    ),
                  ),
                ],
                if (alarm.description != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    alarm.description!,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary(brightness),
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.md),

                // Durum & Priority badge
                Row(
                  children: [
                    _StatusBadge(
                      label: alarm.isResolved ? 'Reset' : 'Aktif',
                      color: alarm.isResolved
                          ? AppColors.success
                          : AppColors.error,
                    ),
                    if (priority != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      _StatusBadge(
                        label: priority!.label,
                        color: priority!.isCritical
                            ? AppColors.error
                            : priority!.isHigh
                                ? AppColors.warning
                                : AppColors.info,
                      ),
                    ],
                    const Spacer(),
                    Text(
                      alarm.durationFormatted,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(brightness),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),
                Divider(color: AppColors.divider(brightness)),
                const SizedBox(height: AppSpacing.md),

                // Zaman çizelgesi
                Text(
                  'Zaman Çizelgesi',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                _TimelineRow(
                  icon: Icons.play_arrow,
                  color: AppColors.error,
                  label: 'Başlangıç',
                  value: alarm.startTime != null
                      ? dateFormat.format(alarm.startTime!)
                      : '-',
                  brightness: brightness,
                ),
                if (alarm.arrivalStartTime != null)
                  _TimelineRow(
                    icon: Icons.directions_run,
                    color: AppColors.warning,
                    label: 'Varış',
                    value: dateFormat.format(alarm.arrivalStartTime!),
                    brightness: brightness,
                  ),
                if (alarm.localAcknowledgeTime != null)
                  _TimelineRow(
                    icon: Icons.check,
                    color: AppColors.info,
                    label: 'Onay',
                    value:
                        '${dateFormat.format(alarm.localAcknowledgeTime!)}'
                        '${alarm.localAcknowledgeUser != null ? ' (${alarm.localAcknowledgeUser})' : ''}',
                    brightness: brightness,
                  ),
                if (alarm.remoteAcknowledgeTime != null)
                  _TimelineRow(
                    icon: Icons.check_circle,
                    color: AppColors.info,
                    label: 'Uzak Onay',
                    value:
                        '${dateFormat.format(alarm.remoteAcknowledgeTime!)}'
                        '${alarm.remoteAcknowledgeUser != null ? ' (${alarm.remoteAcknowledgeUser})' : ''}',
                    brightness: brightness,
                  ),
                if (alarm.resetTime != null)
                  _TimelineRow(
                    icon: Icons.restart_alt,
                    color: AppColors.success,
                    label: 'Reset',
                    value:
                        '${dateFormat.format(alarm.resetTime!)}'
                        '${alarm.resetUser != null ? ' (${alarm.resetUser})' : ''}',
                    brightness: brightness,
                  ),
                if (alarm.endTime != null)
                  _TimelineRow(
                    icon: Icons.stop,
                    color: AppColors.systemGray,
                    label: 'Bitiş',
                    value: dateFormat.format(alarm.endTime!),
                    brightness: brightness,
                    isLast: true,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final Brightness brightness;
  final bool isLast;

  const _TimelineRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.brightness,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline dot + line
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Icon(icon, size: 18, color: color),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: AppColors.divider(brightness),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary(brightness),
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
