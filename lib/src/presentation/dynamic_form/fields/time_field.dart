import 'package:flutter/material.dart' hide FormField;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../field_render_context.dart';
import 'field_scaffold.dart';

/// `time_picker` → saat seçici. Değer: 'HH:mm' String.
class TimeFieldWidget extends FieldWidget {
  const TimeFieldWidget();

  TimeOfDay? _parse(dynamic value) {
    if (value is String && value.contains(':')) {
      final parts = value.split(':');
      final h = int.tryParse(parts[0]);
      final m = parts.length > 1 ? int.tryParse(parts[1]) : 0;
      if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) {
        return TimeOfDay(hour: h, minute: m);
      }
    }
    return null;
  }

  String _format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pick(BuildContext context, FieldRenderContext ctx) async {
    final result = await showTimePicker(
      context: context,
      initialTime: _parse(ctx.value) ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (result != null) {
      ctx.onChanged(_format(result));
    }
  }

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) {
    final field = ctx.field;
    final brightness = Theme.of(context).brightness;
    final selected = _parse(ctx.value);
    final display = selected != null ? _format(selected) : null;

    return FieldScaffold(
      labelText: field.label,
      required: field.isRequired,
      helpText: field.helpText,
      errorText: ctx.errorText,
      child: InkWell(
        onTap: ctx.enabled ? () => _pick(context, ctx) : null,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Container(
          height: AppSpacing.textFieldHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: brightness == Brightness.light
                ? AppColors.systemGray6
                : AppColors.surfaceElevatedDark,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: ctx.errorText != null
                ? Border.all(color: AppColors.error, width: 2)
                : null,
          ),
          child: Row(
            children: [
              Icon(
                Icons.access_time_outlined,
                color: AppColors.textSecondary(brightness),
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  display ?? field.placeholder ?? 'Saat seçin',
                  style: AppTypography.body.copyWith(
                    color: display != null
                        ? AppColors.textPrimary(brightness)
                        : AppColors.textTertiaryLight,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down,
                color: ctx.enabled
                    ? AppColors.textSecondary(brightness)
                    : AppColors.textTertiaryLight,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
