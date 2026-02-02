import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Takvim Etkinlik Detay Ekranı
///
/// Seçilen etkinliğin tüm detaylarını gösterir.
class CalendarEventDetailScreen extends StatefulWidget {
  final String eventId;

  const CalendarEventDetailScreen({
    super.key,
    required this.eventId,
  });

  @override
  State<CalendarEventDetailScreen> createState() => _CalendarEventDetailScreenState();
}

class _CalendarEventDetailScreenState extends State<CalendarEventDetailScreen> {
  bool _isLoading = true;
  bool _isActionLoading = false;
  String? _errorMessage;
  CalendarEvent? _event;

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  Future<void> _loadEvent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final tenantId = tenantService.currentTenantId;
    if (tenantId != null) {
      calendarService.setTenant(tenantId);
    }

    try {
      final event = await calendarService.getById(widget.eventId);

      if (mounted) {
        setState(() {
          _event = event;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load calendar event', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Etkinlik yüklenirken hata oluştu';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _performAction(String action, Future<void> Function() actionFn) async {
    setState(() => _isActionLoading = true);

    try {
      await actionFn();
      await _loadEvent();
      if (mounted) {
        AppSnackbar.success(context, message: '$action işlemi başarılı');
      }
    } catch (e) {
      Logger.error('Action failed: $action', e);
      if (mounted) {
        AppSnackbar.error(context, message: '$action işlemi başarısız');
      }
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  void _showStatusActions() {
    if (_event == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Text(
                'Durum Değiştir',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(Theme.of(context).brightness),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_event!.status == CalendarEventStatus.scheduled) ...[
                _StatusActionTile(
                  icon: Icons.check_circle,
                  label: 'Onayla',
                  color: AppColors.success,
                  onTap: () {
                    Navigator.pop(context);
                    _performAction('Onayla', () => calendarService.confirm(widget.eventId));
                  },
                ),
              ],
              if (_event!.status == CalendarEventStatus.confirmed ||
                  _event!.status == CalendarEventStatus.scheduled) ...[
                _StatusActionTile(
                  icon: Icons.play_arrow,
                  label: 'Başlat',
                  color: AppColors.warning,
                  onTap: () {
                    Navigator.pop(context);
                    _performAction('Başlat', () => calendarService.start(widget.eventId));
                  },
                ),
              ],
              if (_event!.status == CalendarEventStatus.inProgress) ...[
                _StatusActionTile(
                  icon: Icons.task_alt,
                  label: 'Tamamla',
                  color: AppColors.success,
                  onTap: () {
                    Navigator.pop(context);
                    _performAction('Tamamla', () => calendarService.complete(widget.eventId));
                  },
                ),
              ],
              if (_event!.status.isActive) ...[
                _StatusActionTile(
                  icon: Icons.schedule,
                  label: 'Ertele',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    _showPostponeDialog();
                  },
                ),
                _StatusActionTile(
                  icon: Icons.cancel,
                  label: 'İptal Et',
                  color: AppColors.error,
                  onTap: () {
                    Navigator.pop(context);
                    _performAction('İptal Et', () => calendarService.cancel(widget.eventId));
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPostponeDialog() async {
    final newDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (newDate != null) {
      await _performAction(
        'Ertele',
        () => calendarService.postpone(widget.eventId, newDate: newDate),
      );
    }
  }

  Future<void> _deleteEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Etkinliği Sil'),
        content: const Text('Bu etkinliği silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isActionLoading = true);
      try {
        await calendarService.delete(widget.eventId);
        if (mounted) {
          AppSnackbar.success(context, message: 'Etkinlik silindi');
          context.go('/calendar');
        }
      } catch (e) {
        Logger.error('Failed to delete event', e);
        if (mounted) {
          AppSnackbar.error(context, message: 'Etkinlik silinemedi');
        }
      } finally {
        if (mounted) {
          setState(() => _isActionLoading = false);
        }
      }
    }
  }

  Color _getTypeColor(CalendarEventType type) {
    switch (type) {
      case CalendarEventType.maintenance:
        return Colors.blue;
      case CalendarEventType.meeting:
        return Colors.purple;
      case CalendarEventType.inspection:
        return Colors.orange;
      case CalendarEventType.training:
        return Colors.green;
      case CalendarEventType.deadline:
        return AppColors.error;
      case CalendarEventType.holiday:
        return Colors.pink;
      case CalendarEventType.reminder:
        return AppColors.warning;
      case CalendarEventType.task:
        return Colors.teal;
      case CalendarEventType.other:
        return AppColors.systemGray;
    }
  }

  IconData _getTypeIcon(CalendarEventType type) {
    switch (type) {
      case CalendarEventType.maintenance:
        return Icons.build_outlined;
      case CalendarEventType.meeting:
        return Icons.groups_outlined;
      case CalendarEventType.inspection:
        return Icons.search;
      case CalendarEventType.training:
        return Icons.school_outlined;
      case CalendarEventType.deadline:
        return Icons.flag_outlined;
      case CalendarEventType.holiday:
        return Icons.celebration_outlined;
      case CalendarEventType.reminder:
        return Icons.notifications_outlined;
      case CalendarEventType.task:
        return Icons.task_alt;
      case CalendarEventType.other:
        return Icons.event_outlined;
    }
  }

  Color _getStatusColor(CalendarEventStatus status) {
    switch (status) {
      case CalendarEventStatus.scheduled:
        return AppColors.info;
      case CalendarEventStatus.confirmed:
        return AppColors.success;
      case CalendarEventStatus.inProgress:
        return AppColors.warning;
      case CalendarEventStatus.completed:
        return AppColors.success;
      case CalendarEventStatus.cancelled:
        return AppColors.systemGray;
      case CalendarEventStatus.postponed:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return AppScaffold(
      title: 'Etkinlik Detayı',
      onBack: () => context.go('/calendar'),
      actions: [
        if (_event != null) ...[
          AppIconButton(
            icon: Icons.edit,
            onPressed: () => context.push('/calendar/${widget.eventId}/edit'),
          ),
          AppIconButton(
            icon: Icons.delete_outline,
            onPressed: _deleteEvent,
          ),
        ],
        AppIconButton(
          icon: Icons.refresh,
          onPressed: _loadEvent,
        ),
      ],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _errorMessage != null
              ? Center(
                  child: AppErrorView(
                    message: _errorMessage!,
                    onRetry: _loadEvent,
                  ),
                )
              : _event == null
                  ? Center(
                      child: AppEmptyState(
                        icon: Icons.event_outlined,
                        title: 'Etkinlik Bulunamadı',
                        message: 'İstenen etkinlik bulunamadı.',
                      ),
                    )
                  : _buildContent(brightness),
    );
  }

  Widget _buildContent(Brightness brightness) {
    final event = _event!;
    final typeColor = _getTypeColor(event.type);
    final statusColor = _getStatusColor(event.status);

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadEvent,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık Kartı
                _buildHeaderCard(event, typeColor, statusColor, brightness),

                const SizedBox(height: AppSpacing.lg),

                // Zaman Bilgileri
                _buildTimeSection(event, brightness),

                const SizedBox(height: AppSpacing.lg),

                // Konum ve Detaylar
                if (event.hasLocation || event.isOnlineMeeting)
                  _buildLocationSection(event, brightness),

                if (event.hasLocation || event.isOnlineMeeting)
                  const SizedBox(height: AppSpacing.lg),

                // Tekrar Bilgileri
                if (event.isRecurring) ...[
                  _buildRecurrenceSection(event, brightness),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Katılımcılar
                if (event.hasAttendees) ...[
                  _buildAttendeesSection(event, brightness),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Hatırlatıcılar
                if (event.reminders.isNotEmpty) ...[
                  _buildRemindersSection(event, brightness),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Alt boşluk
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),

        // Aksiyon butonu
        if (event.status.isActive)
          Positioned(
            left: AppSpacing.screenHorizontal,
            right: AppSpacing.screenHorizontal,
            bottom: AppSpacing.md,
            child: SafeArea(
              child: AppButton(
                label: 'Durum Değiştir',
                icon: Icons.swap_horiz,
                isLoading: _isActionLoading,
                onPressed: _showStatusActions,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeaderCard(
    CalendarEvent event,
    Color typeColor,
    Color statusColor,
    Brightness brightness,
  ) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge'ler
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        event.status.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getTypeIcon(event.type), size: 14, color: typeColor),
                      const SizedBox(width: 4),
                      Text(
                        event.type.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: typeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // Başlık
            Text(
              event.title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(brightness),
              ),
            ),

            if (event.description != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                event.description!,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary(brightness),
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSection(CalendarEvent event, Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Zaman',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(brightness),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Tarih
            _DetailRow(
              icon: Icons.calendar_today,
              label: 'Tarih',
              value: _formatDate(event.startTime),
            ),

            // Saat
            if (!event.isAllDay) ...[
              _DetailRow(
                icon: Icons.access_time,
                label: 'Başlangıç',
                value: _formatTime(event.startTime),
              ),
              if (event.endTime != null)
                _DetailRow(
                  icon: Icons.access_time,
                  label: 'Bitiş',
                  value: _formatTime(event.endTime!),
                ),
              _DetailRow(
                icon: Icons.timelapse,
                label: 'Süre',
                value: event.durationFormatted,
              ),
            ] else
              _DetailRow(
                icon: Icons.sunny,
                label: 'Süre',
                value: 'Tüm Gün',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection(CalendarEvent event, Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Konum',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(brightness),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            if (event.location != null)
              _DetailRow(
                icon: Icons.location_on,
                label: 'Adres',
                value: event.location!,
              ),

            if (event.meetingUrl != null)
              _DetailRow(
                icon: Icons.video_call,
                label: 'Online Toplantı',
                value: event.meetingUrl!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurrenceSection(CalendarEvent event, Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tekrar',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(brightness),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            _DetailRow(
              icon: Icons.repeat,
              label: 'Sıklık',
              value: event.recurrence.label,
            ),

            if (event.recurrenceInterval != null && event.recurrenceInterval! > 1)
              _DetailRow(
                icon: Icons.numbers,
                label: 'Aralık',
                value: 'Her ${event.recurrenceInterval} ${_getIntervalUnit(event.recurrence)}',
              ),

            if (event.recurrenceEndDate != null)
              _DetailRow(
                icon: Icons.event,
                label: 'Bitiş',
                value: _formatDate(event.recurrenceEndDate!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendeesSection(CalendarEvent event, Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Katılımcılar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${event.confirmedAttendeesCount}/${event.attendees.length}',
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
            ...event.attendees.map((attendee) => _AttendeeItem(attendee: attendee)),
          ],
        ),
      ),
    );
  }

  Widget _buildRemindersSection(CalendarEvent event, Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hatırlatıcılar',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(brightness),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...event.reminders.map((reminder) => _ReminderItem(reminder: reminder)),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _getIntervalUnit(RecurrenceFrequency freq) {
    switch (freq) {
      case RecurrenceFrequency.daily:
        return 'gün';
      case RecurrenceFrequency.weekly:
        return 'hafta';
      case RecurrenceFrequency.monthly:
        return 'ay';
      case RecurrenceFrequency.yearly:
        return 'yıl';
      default:
        return '';
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary(brightness)),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary(brightness),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary(brightness),
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _StatusActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: Icon(Icons.chevron_right, color: AppColors.systemGray),
      onTap: onTap,
    );
  }
}

class _AttendeeItem extends StatelessWidget {
  final EventAttendee attendee;

  const _AttendeeItem({required this.attendee});

  Color _getStatusColor() {
    switch (attendee.status) {
      case AttendeeStatus.accepted:
        return AppColors.success;
      case AttendeeStatus.declined:
        return AppColors.error;
      case AttendeeStatus.tentative:
        return AppColors.warning;
      case AttendeeStatus.pending:
        return AppColors.systemGray;
    }
  }

  IconData _getStatusIcon() {
    switch (attendee.status) {
      case AttendeeStatus.accepted:
        return Icons.check_circle;
      case AttendeeStatus.declined:
        return Icons.cancel;
      case AttendeeStatus.tentative:
        return Icons.help;
      case AttendeeStatus.pending:
        return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = _getStatusColor();

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.systemGray6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          AppAvatar(name: attendee.userName, size: AppAvatarSize.small),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      attendee.userName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary(brightness),
                      ),
                    ),
                    if (attendee.isRequired) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.star, size: 12, color: AppColors.warning),
                    ],
                  ],
                ),
                if (attendee.email != null)
                  Text(
                    attendee.email!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(brightness),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getStatusIcon(), size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  attendee.status.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderItem extends StatelessWidget {
  final EventReminder reminder;

  const _ReminderItem({required this.reminder});

  IconData _getTypeIcon() {
    switch (reminder.type) {
      case ReminderType.notification:
        return Icons.notifications_outlined;
      case ReminderType.email:
        return Icons.email_outlined;
      case ReminderType.sms:
        return Icons.sms_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.systemGray6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_getTypeIcon(), size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.type.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                Text(
                  reminder.formattedTime,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
              ],
            ),
          ),
          if (reminder.sent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 14, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    'Gönderildi',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
