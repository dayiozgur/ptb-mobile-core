import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/alarm/alarm_model.dart';
import '../../../core/priority/priority_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Aktif alarm listesi widget'ı
///
/// alarms tablosundan gelen aktif alarmları listeler.
/// alarms tablosu sadece aktif alarmları içerir (backend senkronizasyonu).
/// Her satırda priority renk çubuğu, alarm adı, başlangıç zamanı ve süre gösterilir.
class ActiveAlarmList extends StatelessWidget {
  final List<Alarm> alarms;
  final Map<String, Priority>? priorities;
  final ValueChanged<Alarm>? onAlarmTap;
  final bool isLoading;
  final String? emptyMessage;
  final bool showAcknowledgeStatus;

  const ActiveAlarmList({
    super.key,
    required this.alarms,
    this.priorities,
    this.onAlarmTap,
    this.isLoading = false,
    this.emptyMessage,
    this.showAcknowledgeStatus = true,
  });

  Color _priorityColor(Alarm alarm) {
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
    return AppColors.error;
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
                color: AppColors.success,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                emptyMessage ?? 'Aktif alarm yok',
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
        return _ActiveAlarmTile(
          alarm: alarm,
          priorityColor: _priorityColor(alarm),
          priorityName: (alarm.priorityId != null && priorities != null)
              ? priorities![alarm.priorityId!]?.label
              : null,
          brightness: brightness,
          showAcknowledgeStatus: showAcknowledgeStatus,
          onTap: onAlarmTap != null ? () => onAlarmTap!(alarm) : null,
        );
      },
    );
  }
}

class _ActiveAlarmTile extends StatelessWidget {
  final Alarm alarm;
  final Color priorityColor;
  final String? priorityName;
  final Brightness brightness;
  final bool showAcknowledgeStatus;
  final VoidCallback? onTap;

  const _ActiveAlarmTile({
    required this.alarm,
    required this.priorityColor,
    this.priorityName,
    required this.brightness,
    this.showAcknowledgeStatus = true,
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
            // Priority renk çubuğu + pulsing indicator
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: priorityColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Aktif alarm göstergesi
                Positioned(
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: priorityColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: priorityColor.withValues(alpha: 0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.sm),

            // İçerik
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Onay durumu ikonu
                      if (showAcknowledgeStatus && alarm.isAcknowledged) ...[
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: AppColors.info,
                        ),
                        const SizedBox(width: 4),
                      ],
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
                      if (alarm.code != null && alarm.name != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.systemGray6,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            alarm.code!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary(brightness),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 13,
                        color: priorityColor,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        alarm.startTime != null
                            ? dateFormat.format(alarm.startTime!)
                            : '-',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(brightness),
                        ),
                      ),
                      const Spacer(),
                      // Süre badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: priorityColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 11,
                              color: priorityColor,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              alarm.durationFormatted,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: priorityColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Chevron
            const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.tertiaryLabel(brightness),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aktif alarm detay bottom sheet
///
/// Aktif alarm'ın zaman çizelgesi ve detaylarını gösterir.
class ActiveAlarmDetailSheet extends StatelessWidget {
  final Alarm alarm;
  final Priority? priority;
  final VoidCallback? onAcknowledge;

  const ActiveAlarmDetailSheet({
    super.key,
    required this.alarm,
    this.priority,
    this.onAcknowledge,
  });

  /// Bottom sheet'i göster
  static void show(
    BuildContext context, {
    required Alarm alarm,
    Priority? priority,
    VoidCallback? onAcknowledge,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      builder: (_) => ActiveAlarmDetailSheet(
        alarm: alarm,
        priority: priority,
        onAcknowledge: onAcknowledge,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');

    Color priorityColor = AppColors.error;
    if (priority != null) {
      if (priority!.color != null) {
        final hex = priority!.color!.replaceFirst('#', '');
        if (hex.length == 6) {
          priorityColor = Color(int.parse('FF$hex', radix: 16));
        }
      } else if (priority!.isCritical) {
        priorityColor = AppColors.error;
      } else if (priority!.isHigh) {
        priorityColor = AppColors.warning;
      }
    }

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
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.systemGray4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Aktif alarm banner
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(
                      color: priorityColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: priorityColor,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'AKTİF ALARM',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: priorityColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),

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
                      label: 'Aktif',
                      color: AppColors.error,
                    ),
                    if (alarm.isAcknowledged) ...[
                      const SizedBox(width: AppSpacing.sm),
                      _StatusBadge(
                        label: 'Onaylandı',
                        color: AppColors.info,
                      ),
                    ],
                    if (priority != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      _StatusBadge(
                        label: priority!.label,
                        color: priorityColor,
                      ),
                    ],
                    const Spacer(),
                    Text(
                      alarm.durationFormatted,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: priorityColor,
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
                    label: 'Yerel Onay',
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
                _TimelineRow(
                  icon: Icons.timer,
                  color: AppColors.systemGray,
                  label: 'Devam Ediyor',
                  value: 'Alarm hala aktif',
                  brightness: brightness,
                  isLast: true,
                ),

                // Onay butonu
                if (onAcknowledge != null && !alarm.isAcknowledged) ...[
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onAcknowledge,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Alarmı Onayla'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.md),
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
