import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Takvim Ana Ekranı
///
/// Takvim görünümü ve etkinlik listesi sunar.
/// Aylık takvim ve günlük etkinlik listesi içerir.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  List<CalendarEvent> _events = [];
  List<CalendarEvent> _selectedDayEvents = [];

  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  // Filtreler
  CalendarEventType? _selectedType;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final tenantId = tenantService.currentTenantId;
    if (tenantId != null) {
      calendarService.setTenant(tenantId);
    }

    try {
      // Ay başı ve sonu hesapla
      final startOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
      final endOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0, 23, 59, 59);

      final events = await calendarService.getEvents(
        startDate: startOfMonth,
        endDate: endOfMonth,
        type: _selectedType,
      );

      if (mounted) {
        setState(() {
          _events = events;
          _updateSelectedDayEvents();
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load calendar events', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Etkinlikler yüklenirken hata oluştu';
          _isLoading = false;
        });
      }
    }
  }

  void _updateSelectedDayEvents() {
    _selectedDayEvents = _events.where((event) {
      return _isSameDay(event.startTime, _selectedDay);
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    return _events.where((event) => _isSameDay(event.startTime, day)).toList();
  }

  void _onDaySelected(DateTime day) {
    setState(() {
      _selectedDay = day;
      _updateSelectedDayEvents();
    });
  }

  void _onMonthChanged(DateTime month) {
    setState(() {
      _focusedMonth = month;
    });
    _loadEvents();
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

  void _showFilterSheet() {
    final brightness = Theme.of(context).brightness;

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
                'Etkinlik Tipi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(brightness),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _FilterChip(
                    label: 'Tümü',
                    isSelected: _selectedType == null,
                    color: AppColors.primary,
                    onTap: () {
                      setState(() => _selectedType = null);
                      Navigator.pop(context);
                      _loadEvents();
                    },
                  ),
                  ...CalendarEventType.values.map((type) => _FilterChip(
                        label: type.label,
                        isSelected: _selectedType == type,
                        color: _getTypeColor(type),
                        onTap: () {
                          setState(() => _selectedType = type);
                          Navigator.pop(context);
                          _loadEvents();
                        },
                      )),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return AppScaffold(
      title: 'Takvim',
      onBack: () => context.go('/home'),
      actions: [
        Stack(
          children: [
            AppIconButton(
              icon: Icons.filter_list,
              onPressed: _showFilterSheet,
            ),
            if (_selectedType != null)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        AppIconButton(
          icon: Icons.today,
          onPressed: () {
            setState(() {
              _focusedMonth = DateTime.now();
              _selectedDay = DateTime.now();
            });
            _loadEvents();
          },
        ),
        AppIconButton(
          icon: Icons.refresh,
          onPressed: _loadEvents,
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/calendar/new'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      child: Column(
        children: [
          // Takvim
          _buildCalendar(brightness),

          // Ayırıcı
          Container(
            height: 1,
            color: AppColors.separator(brightness),
          ),

          // Seçili gün başlığı
          _buildSelectedDayHeader(brightness),

          // Etkinlik listesi
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : _errorMessage != null
                    ? Center(
                        child: AppErrorView(
                          message: _errorMessage!,
                          onRetry: _loadEvents,
                        ),
                      )
                    : _buildEventsList(brightness),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(Brightness brightness) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        children: [
          // Ay seçici
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    _onMonthChanged(DateTime(_focusedMonth.year, _focusedMonth.month - 1));
                  },
                ),
                GestureDetector(
                  onTap: () => _selectMonth(),
                  child: Text(
                    _formatMonthYear(_focusedMonth),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    _onMonthChanged(DateTime(_focusedMonth.year, _focusedMonth.month + 1));
                  },
                ),
              ],
            ),
          ),

          // Haftanın günleri
          Row(
            children: ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'].map((day) {
              final isWeekend = day == 'Cmt' || day == 'Paz';
              return Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isWeekend
                            ? AppColors.textSecondary(brightness)
                            : AppColors.textPrimary(brightness),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // Günler
          _buildCalendarGrid(brightness),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(Brightness brightness) {
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);

    // Pazartesi = 1, Pazar = 7 olarak düzelt
    int firstWeekday = firstDayOfMonth.weekday;

    // Önceki ayın günlerini hesapla
    final prevMonthDays = firstWeekday - 1;
    final prevMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 0);

    List<Widget> dayWidgets = [];

    // Önceki ayın günleri
    for (int i = prevMonthDays; i > 0; i--) {
      final day = DateTime(prevMonth.year, prevMonth.month, prevMonth.day - i + 1);
      dayWidgets.add(_buildDayCell(day, brightness, isCurrentMonth: false));
    }

    // Bu ayın günleri
    for (int i = 1; i <= lastDayOfMonth.day; i++) {
      final day = DateTime(_focusedMonth.year, _focusedMonth.month, i);
      dayWidgets.add(_buildDayCell(day, brightness, isCurrentMonth: true));
    }

    // Sonraki ayın günleri (6 satırı tamamlamak için)
    final remainingDays = 42 - dayWidgets.length;
    for (int i = 1; i <= remainingDays; i++) {
      final day = DateTime(_focusedMonth.year, _focusedMonth.month + 1, i);
      dayWidgets.add(_buildDayCell(day, brightness, isCurrentMonth: false));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: dayWidgets,
    );
  }

  Widget _buildDayCell(DateTime day, Brightness brightness, {required bool isCurrentMonth}) {
    final isToday = _isSameDay(day, DateTime.now());
    final isSelected = _isSameDay(day, _selectedDay);
    final events = _getEventsForDay(day);
    final hasEvents = events.isNotEmpty;

    return GestureDetector(
      onTap: () => _onDaySelected(day),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : isToday
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : null,
          borderRadius: BorderRadius.circular(8),
          border: isToday && !isSelected
              ? Border.all(color: AppColors.primary, width: 1.5)
              : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isToday || isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? Colors.white
                      : !isCurrentMonth
                          ? AppColors.systemGray
                          : isToday
                              ? AppColors.primary
                              : AppColors.textPrimary(brightness),
                ),
              ),
            ),
            if (hasEvents)
              Positioned(
                bottom: 4,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < (events.length > 3 ? 3 : events.length); i++)
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white
                              : _getTypeColor(events[i].type),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDayHeader(Brightness brightness) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Text(
            _formatFullDate(_selectedDay),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(brightness),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _selectedDayEvents.isEmpty
                  ? AppColors.systemGray6
                  : AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_selectedDayEvents.length} etkinlik',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _selectedDayEvents.isEmpty
                    ? AppColors.textSecondary(brightness)
                    : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList(Brightness brightness) {
    if (_selectedDayEvents.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.event_available,
          title: 'Etkinlik Yok',
          message: 'Bu gün için etkinlik bulunmuyor.',
          actionLabel: 'Etkinlik Ekle',
          onAction: () => context.push('/calendar/new'),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.sm,
      ),
      itemCount: _selectedDayEvents.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final event = _selectedDayEvents[index];
        return _EventCard(
          event: event,
          typeColor: _getTypeColor(event.type),
          statusColor: _getStatusColor(event.status),
          typeIcon: _getTypeIcon(event.type),
          onTap: () => context.push('/calendar/${event.id}'),
        );
      },
    );
  }

  Future<void> _selectMonth() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _focusedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDatePickerMode: DatePickerMode.year,
    );

    if (date != null) {
      _onMonthChanged(date);
    }
  }

  String _formatMonthYear(DateTime date) {
    const months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatFullDate(DateTime date) {
    const days = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    const months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return '${date.day} ${months[date.month - 1]}, ${days[date.weekday - 1]}';
  }
}

class _EventCard extends StatelessWidget {
  final CalendarEvent event;
  final Color typeColor;
  final Color statusColor;
  final IconData typeIcon;
  final VoidCallback onTap;

  const _EventCard({
    required this.event,
    required this.typeColor,
    required this.statusColor,
    required this.typeIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sol renk çubuğu
            Container(
              width: 4,
              height: 60,
              decoration: BoxDecoration(
                color: typeColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // İçerik
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Saat ve tip
                  Row(
                    children: [
                      if (!event.isAllDay) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time, size: 12, color: typeColor),
                              const SizedBox(width: 4),
                              Text(
                                _formatTime(event.startTime),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: typeColor,
                                ),
                              ),
                              if (event.endTime != null) ...[
                                Text(
                                  ' - ${_formatTime(event.endTime!)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: typeColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ] else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Tüm Gün',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: typeColor,
                            ),
                          ),
                        ),
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          event.status.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xs),

                  // Başlık
                  Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(brightness),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (event.description != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      event.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary(brightness),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xs),

                  // Alt bilgiler
                  Row(
                    children: [
                      Icon(typeIcon, size: 14, color: typeColor),
                      const SizedBox(width: 4),
                      Text(
                        event.type.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(brightness),
                        ),
                      ),
                      if (event.isRecurring) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Icon(Icons.repeat, size: 14, color: AppColors.textSecondary(brightness)),
                        const SizedBox(width: 4),
                        Text(
                          event.recurrence.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(brightness),
                          ),
                        ),
                      ],
                      if (event.hasAttendees) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Icon(Icons.people_outline, size: 14, color: AppColors.textSecondary(brightness)),
                        const SizedBox(width: 4),
                        Text(
                          '${event.attendees.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(brightness),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.chevron_right, color: AppColors.systemGray),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AppColors.systemGray6,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? color
                : AppColors.textSecondary(Theme.of(context).brightness),
          ),
        ),
      ),
    );
  }
}
