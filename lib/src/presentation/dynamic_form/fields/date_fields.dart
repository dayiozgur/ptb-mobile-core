import 'package:flutter/material.dart' hide FormField;

import '../../widgets/inputs/app_date_picker.dart';
import '../field_render_context.dart';
import 'field_scaffold.dart';

DateTime? _parse(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}

Widget _buildDatePicker(
  BuildContext context,
  FieldRenderContext ctx,
  AppDatePickerMode mode,
) {
  final field = ctx.field;
  return FieldScaffold(
    labelText: field.label,
    required: field.isRequired,
    helpText: field.helpText,
    errorText: ctx.errorText,
    child: AppDatePicker(
      mode: mode,
      value: _parse(ctx.value),
      placeholder: field.placeholder,
      enabled: ctx.enabled,
      onChanged: (date) => ctx.onChanged(date?.toIso8601String()),
    ),
  );
}

/// `date` → tarih seçici. Değer: ISO-8601 String.
class DateFieldWidget extends FieldWidget {
  const DateFieldWidget();

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) =>
      _buildDatePicker(context, ctx, AppDatePickerMode.date);
}

/// `datetime` → tarih + saat seçici. Değer: ISO-8601 String.
class DateTimeFieldWidget extends FieldWidget {
  const DateTimeFieldWidget();

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) =>
      _buildDatePicker(context, ctx, AppDatePickerMode.dateTime);
}
