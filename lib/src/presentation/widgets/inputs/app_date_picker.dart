import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Date picker modu
enum AppDatePickerMode {
  /// Sadece tarih
  date,

  /// Sadece saat
  time,

  /// Tarih ve saat
  dateTime,
}

/// Protoolbag Date Picker Widget
///
/// Apple HIG uyumlu tarih/saat seçici komponenti.
///
/// Örnek kullanım:
/// ```dart
/// AppDatePicker(
///   label: 'Birth Date',
///   value: selectedDate,
///   onChanged: (date) => setState(() => selectedDate = date),
/// )
/// ```
class AppDatePicker extends StatelessWidget {
  /// Alan etiketi
  final String? label;

  /// Placeholder metni
  final String? placeholder;

  /// Yardımcı metin
  final String? helperText;

  /// Seçili değer
  final DateTime? value;

  /// Değer değiştiğinde callback
  final ValueChanged<DateTime?>? onChanged;

  /// Picker modu
  final AppDatePickerMode mode;

  /// Minimum tarih
  final DateTime? minDate;

  /// Maksimum tarih
  final DateTime? maxDate;

  /// Tarih formatı
  final String? dateFormat;

  /// Sol ikon
  final IconData? prefixIcon;

  /// Aktif mi?
  final bool enabled;

  /// Hata mesajı
  final String? errorText;

  const AppDatePicker({
    super.key,
    this.label,
    this.placeholder,
    this.helperText,
    this.value,
    this.onChanged,
    this.mode = AppDatePickerMode.date,
    this.minDate,
    this.maxDate,
    this.dateFormat,
    this.prefixIcon,
    this.enabled = true,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        if (label != null) ...[
          Text(
            label!,
            style: AppTypography.subhead.copyWith(
              color: AppColors.textSecondary(brightness),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],

        // Date Picker Field
        InkWell(
          onTap: enabled ? () => _showPicker(context) : null,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: Container(
            height: AppSpacing.textFieldHeight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: _getFillColor(brightness),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: hasError
                  ? Border.all(color: AppColors.error, width: 2)
                  : null,
            ),
            child: Row(
              children: [
                // Prefix icon
                if (prefixIcon != null) ...[
                  Icon(
                    prefixIcon,
                    color: AppColors.textSecondary(brightness),
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ] else ...[
                  Icon(
                    _getDefaultIcon(),
                    color: AppColors.textSecondary(brightness),
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],

                // Value or placeholder
                Expanded(
                  child: Text(
                    value != null ? _formatValue(value!) : placeholder ?? '',
                    style: AppTypography.body.copyWith(
                      color: value != null
                          ? AppColors.textPrimary(brightness)
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                ),

                // Trailing icon
                Icon(
                  Icons.keyboard_arrow_down,
                  color: enabled
                      ? AppColors.textSecondary(brightness)
                      : AppColors.textTertiaryLight,
                  size: 20,
                ),
              ],
            ),
          ),
        ),

        // Error text
        if (errorText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            errorText!,
            style: AppTypography.caption1.copyWith(
              color: AppColors.error,
            ),
          ),
        ],

        // Helper Text
        if (helperText != null && errorText == null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            helperText!,
            style: AppTypography.caption1.copyWith(
              color: AppColors.textSecondary(brightness),
            ),
          ),
        ],
      ],
    );
  }

  Color _getFillColor(Brightness brightness) {
    if (!enabled) {
      return brightness == Brightness.light
          ? AppColors.systemGray6
          : AppColors.surfaceDark;
    }
    return brightness == Brightness.light
        ? AppColors.systemGray6
        : AppColors.surfaceElevatedDark;
  }

  IconData _getDefaultIcon() {
    switch (mode) {
      case AppDatePickerMode.date:
        return Icons.calendar_today_outlined;
      case AppDatePickerMode.time:
        return Icons.access_time_outlined;
      case AppDatePickerMode.dateTime:
        return Icons.event_outlined;
    }
  }

  String _formatValue(DateTime date) {
    if (dateFormat != null) {
      return DateFormat(dateFormat).format(date);
    }

    switch (mode) {
      case AppDatePickerMode.date:
        return DateFormat('dd/MM/yyyy').format(date);
      case AppDatePickerMode.time:
        return DateFormat('HH:mm').format(date);
      case AppDatePickerMode.dateTime:
        return DateFormat('dd/MM/yyyy HH:mm').format(date);
    }
  }

  Future<void> _showPicker(BuildContext context) async {
    switch (mode) {
      case AppDatePickerMode.date:
        await _showDatePicker(context);
        break;
      case AppDatePickerMode.time:
        await _showTimePicker(context);
        break;
      case AppDatePickerMode.dateTime:
        await _showDateTimePicker(context);
        break;
    }
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = value ?? now;

    final result = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: minDate ?? DateTime(1900),
      lastDate: maxDate ?? DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                  surface: AppColors.surface(Theme.of(context).brightness),
                ),
          ),
          child: child!,
        );
      },
    );

    if (result != null) {
      onChanged?.call(result);
    }
  }

  Future<void> _showTimePicker(BuildContext context) async {
    final now = DateTime.now();
    final initialTime =
        value != null ? TimeOfDay.fromDateTime(value!) : TimeOfDay.now();

    final result = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                  surface: AppColors.surface(Theme.of(context).brightness),
                ),
          ),
          child: child!,
        );
      },
    );

    if (result != null) {
      final date = value ?? now;
      final newDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        result.hour,
        result.minute,
      );
      onChanged?.call(newDateTime);
    }
  }

  Future<void> _showDateTimePicker(BuildContext context) async {
    // First show date picker
    final now = DateTime.now();
    final initialDate = value ?? now;

    final dateResult = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: minDate ?? DateTime(1900),
      lastDate: maxDate ?? DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                  surface: AppColors.surface(Theme.of(context).brightness),
                ),
          ),
          child: child!,
        );
      },
    );

    if (dateResult == null) return;

    // Then show time picker
    if (!context.mounted) return;

    final initialTime =
        value != null ? TimeOfDay.fromDateTime(value!) : TimeOfDay.now();

    final timeResult = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                  surface: AppColors.surface(Theme.of(context).brightness),
                ),
          ),
          child: child!,
        );
      },
    );

    if (timeResult != null) {
      final newDateTime = DateTime(
        dateResult.year,
        dateResult.month,
        dateResult.day,
        timeResult.hour,
        timeResult.minute,
      );
      onChanged?.call(newDateTime);
    }
  }
}

/// Date range picker
class AppDateRangePicker extends StatelessWidget {
  final String? label;
  final String? placeholder;
  final DateTimeRange? value;
  final ValueChanged<DateTimeRange?>? onChanged;
  final DateTime? minDate;
  final DateTime? maxDate;
  final String? dateFormat;
  final bool enabled;
  final String? errorText;

  const AppDateRangePicker({
    super.key,
    this.label,
    this.placeholder,
    this.value,
    this.onChanged,
    this.minDate,
    this.maxDate,
    this.dateFormat,
    this.enabled = true,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTypography.subhead.copyWith(
              color: AppColors.textSecondary(brightness),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        InkWell(
          onTap: enabled ? () => _showPicker(context) : null,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: Container(
            height: AppSpacing.textFieldHeight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: brightness == Brightness.light
                  ? AppColors.systemGray6
                  : AppColors.surfaceElevatedDark,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: hasError
                  ? Border.all(color: AppColors.error, width: 2)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.date_range_outlined,
                  color: AppColors.textSecondary(brightness),
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    value != null ? _formatRange(value!) : placeholder ?? '',
                    style: AppTypography.body.copyWith(
                      color: value != null
                          ? AppColors.textPrimary(brightness)
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary(brightness),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            errorText!,
            style: AppTypography.caption1.copyWith(
              color: AppColors.error,
            ),
          ),
        ],
      ],
    );
  }

  String _formatRange(DateTimeRange range) {
    final format = DateFormat(dateFormat ?? 'dd/MM/yyyy');
    return '${format.format(range.start)} - ${format.format(range.end)}';
  }

  Future<void> _showPicker(BuildContext context) async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: minDate ?? DateTime(1900),
      lastDate: maxDate ?? DateTime(2100),
      initialDateRange: value,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                  surface: AppColors.surface(Theme.of(context).brightness),
                ),
          ),
          child: child!,
        );
      },
    );

    if (result != null) {
      onChanged?.call(result);
    }
  }
}
