import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart' hide TimeOfDay;

/// Takvim Etkinlik Form Ekranı
///
/// Yeni etkinlik oluşturma ve mevcut etkinlikleri düzenleme formu.
class CalendarEventFormScreen extends StatefulWidget {
  final String? eventId;

  const CalendarEventFormScreen({
    super.key,
    this.eventId,
  });

  bool get isEditing => eventId != null;

  @override
  State<CalendarEventFormScreen> createState() => _CalendarEventFormScreenState();
}

class _CalendarEventFormScreenState extends State<CalendarEventFormScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  // Form fields
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _meetingUrlController = TextEditingController();

  CalendarEventType _selectedType = CalendarEventType.other;
  RecurrenceFrequency _selectedRecurrence = RecurrenceFrequency.none;

  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  DateTime? _endDate;
  TimeOfDay? _endTime;
  bool _isAllDay = false;

  CalendarEvent? _existingEvent;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadExistingEvent();
    } else {
      // Varsayılan bitiş saati (1 saat sonra)
      final now = TimeOfDay.now();
      _endTime = TimeOfDay(hour: (now.hour + 1) % 24, minute: now.minute);
      _endDate = _startDate;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _meetingUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingEvent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final tenantId = tenantService.currentTenantId;
    if (tenantId != null) {
      calendarService.setTenant(tenantId);
    }

    try {
      final event = await calendarService.getById(widget.eventId!);

      if (event != null && mounted) {
        setState(() {
          _existingEvent = event;
          _titleController.text = event.title;
          _descriptionController.text = event.description ?? '';
          _locationController.text = event.location ?? '';
          _meetingUrlController.text = event.meetingUrl ?? '';
          _selectedType = event.type;
          _selectedRecurrence = event.recurrence;
          _startDate = event.startTime;
          _startTime = TimeOfDay.fromDateTime(event.startTime);
          _isAllDay = event.isAllDay;

          if (event.endTime != null) {
            _endDate = event.endTime;
            _endTime = TimeOfDay.fromDateTime(event.endTime!);
          }

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

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final tenantId = tenantService.currentTenantId;
      if (tenantId == null) {
        throw Exception('Tenant seçili değil');
      }

      // Başlangıç tarihi ve saati birleştir
      final startDateTime = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _isAllDay ? 0 : _startTime.hour,
        _isAllDay ? 0 : _startTime.minute,
      );

      // Bitiş tarihi ve saati birleştir
      DateTime? endDateTime;
      if (_endDate != null && _endTime != null && !_isAllDay) {
        endDateTime = DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
          _endTime!.hour,
          _endTime!.minute,
        );
      }

      if (widget.isEditing && _existingEvent != null) {
        // Güncelleme
        await calendarService.update(
          widget.eventId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          type: _selectedType,
          startTime: startDateTime,
          endTime: endDateTime,
          isAllDay: _isAllDay,
          location: _locationController.text.trim().isNotEmpty
              ? _locationController.text.trim()
              : null,
          meetingUrl: _meetingUrlController.text.trim().isNotEmpty
              ? _meetingUrlController.text.trim()
              : null,
          recurrence: _selectedRecurrence,
        );

        if (mounted) {
          AppSnackbar.success(context, message: 'Etkinlik güncellendi');
          context.go('/calendar/${widget.eventId}');
        }
      } else {
        // Yeni oluştur
        final event = await calendarService.create(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          type: _selectedType,
          startTime: startDateTime,
          endTime: endDateTime,
          isAllDay: _isAllDay,
          location: _locationController.text.trim().isNotEmpty
              ? _locationController.text.trim()
              : null,
          meetingUrl: _meetingUrlController.text.trim().isNotEmpty
              ? _meetingUrlController.text.trim()
              : null,
          recurrence: _selectedRecurrence,
        );

        if (mounted) {
          AppSnackbar.success(context, message: 'Etkinlik oluşturuldu');
          context.go('/calendar/${event.id}');
        }
      }
    } catch (e) {
      Logger.error('Failed to save calendar event', e);
      if (mounted) {
        AppSnackbar.error(context, message: 'Etkinlik kaydedilemedi');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );

    if (date != null) {
      setState(() {
        _startDate = date;
        // Bitiş tarihi başlangıçtan önce olamaz
        if (_endDate != null && _endDate!.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _selectStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );

    if (time != null) {
      setState(() => _startTime = time);
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );

    if (date != null) {
      setState(() => _endDate = date);
    }
  }

  Future<void> _selectEndTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _endTime ?? TimeOfDay(hour: (_startTime.hour + 1) % 24, minute: _startTime.minute),
    );

    if (time != null) {
      setState(() => _endTime = time);
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

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return AppScaffold(
      title: widget.isEditing ? 'Etkinliği Düzenle' : 'Yeni Etkinlik',
      onBack: () => widget.isEditing
          ? context.go('/calendar/${widget.eventId}')
          : context.go('/calendar'),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _errorMessage != null
              ? Center(
                  child: AppErrorView(
                    message: _errorMessage!,
                    onRetry: _loadExistingEvent,
                  ),
                )
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: AppSpacing.screenPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Temel Bilgiler
                        _buildSectionHeader('Temel Bilgiler', brightness),
                        const SizedBox(height: AppSpacing.sm),
                        _buildBasicInfoSection(brightness),

                        const SizedBox(height: AppSpacing.lg),

                        // Etkinlik Tipi
                        _buildSectionHeader('Etkinlik Tipi', brightness),
                        const SizedBox(height: AppSpacing.sm),
                        _buildTypeSection(brightness),

                        const SizedBox(height: AppSpacing.lg),

                        // Tarih ve Saat
                        _buildSectionHeader('Tarih ve Saat', brightness),
                        const SizedBox(height: AppSpacing.sm),
                        _buildDateTimeSection(brightness),

                        const SizedBox(height: AppSpacing.lg),

                        // Konum
                        _buildSectionHeader('Konum', brightness),
                        const SizedBox(height: AppSpacing.sm),
                        _buildLocationSection(brightness),

                        const SizedBox(height: AppSpacing.lg),

                        // Tekrar
                        _buildSectionHeader('Tekrar', brightness),
                        const SizedBox(height: AppSpacing.sm),
                        _buildRecurrenceSection(brightness),

                        const SizedBox(height: AppSpacing.xl),

                        // Kaydet butonu
                        AppButton(
                          label: widget.isEditing ? 'Güncelle' : 'Oluştur',
                          icon: widget.isEditing ? Icons.save : Icons.add,
                          isLoading: _isSaving,
                          onPressed: _saveEvent,
                        ),

                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildSectionHeader(String title, Brightness brightness) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary(brightness),
      ),
    );
  }

  Widget _buildBasicInfoSection(Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          children: [
            // Başlık
            AppTextField(
              controller: _titleController,
              label: 'Etkinlik Başlığı',
              placeholder: 'Örn: Haftalık toplantı',
              prefixIcon: Icons.title,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Başlık zorunludur';
                }
                if (value.trim().length < 3) {
                  return 'Başlık en az 3 karakter olmalıdır';
                }
                return null;
              },
            ),

            const SizedBox(height: AppSpacing.md),

            // Açıklama
            AppTextField(
              controller: _descriptionController,
              label: 'Açıklama',
              placeholder: 'Etkinlik detaylarını açıklayın...',
              prefixIcon: Icons.description_outlined,
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSection(Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: CalendarEventType.values.map((type) {
            final isSelected = _selectedType == type;
            final color = _getTypeColor(type);

            return GestureDetector(
              onTap: () => setState(() => _selectedType = type),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getTypeIcon(type),
                      size: 16,
                      color: isSelected ? color : AppColors.textSecondary(brightness),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      type.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? color : AppColors.textSecondary(brightness),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDateTimeSection(Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          children: [
            // Tüm gün toggle
            SwitchListTile(
              title: Text(
                'Tüm Gün',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary(brightness),
                ),
              ),
              value: _isAllDay,
              onChanged: (value) => setState(() => _isAllDay = value),
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: AppSpacing.md),

            // Başlangıç tarihi
            InkWell(
              onTap: _selectStartDate,
              borderRadius: BorderRadius.circular(8),
              child: _DateTimeSelector(
                icon: Icons.calendar_today,
                label: 'Başlangıç Tarihi',
                value: _formatDate(_startDate),
              ),
            ),

            if (!_isAllDay) ...[
              const SizedBox(height: AppSpacing.sm),

              // Başlangıç saati
              InkWell(
                onTap: _selectStartTime,
                borderRadius: BorderRadius.circular(8),
                child: _DateTimeSelector(
                  icon: Icons.access_time,
                  label: 'Başlangıç Saati',
                  value: _formatTime(_startTime),
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Bitiş tarihi
              InkWell(
                onTap: _selectEndDate,
                borderRadius: BorderRadius.circular(8),
                child: _DateTimeSelector(
                  icon: Icons.calendar_today,
                  label: 'Bitiş Tarihi',
                  value: _endDate != null ? _formatDate(_endDate!) : 'Seçin',
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Bitiş saati
              InkWell(
                onTap: _selectEndTime,
                borderRadius: BorderRadius.circular(8),
                child: _DateTimeSelector(
                  icon: Icons.access_time,
                  label: 'Bitiş Saati',
                  value: _endTime != null ? _formatTime(_endTime!) : 'Seçin',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection(Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          children: [
            // Fiziksel konum
            AppTextField(
              controller: _locationController,
              label: 'Konum',
              placeholder: 'Toplantı odası, adres vb.',
              prefixIcon: Icons.location_on_outlined,
            ),

            const SizedBox(height: AppSpacing.md),

            // Online toplantı linki
            AppTextField(
              controller: _meetingUrlController,
              label: 'Toplantı Linki',
              placeholder: 'https://meet.google.com/...',
              prefixIcon: Icons.video_call_outlined,
              keyboardType: TextInputType.url,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurrenceSection(Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tekrar Sıklığı',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(brightness),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: RecurrenceFrequency.values.map((freq) {
                final isSelected = _selectedRecurrence == freq;

                return GestureDetector(
                  onTap: () => setState(() => _selectedRecurrence = freq),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.systemGray6,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      freq.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary(brightness),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _DateTimeSelector extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DateTimeSelector({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.systemGray6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary(brightness)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.systemGray),
        ],
      ),
    );
  }
}
