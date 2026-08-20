import 'package:flutter/material.dart' hide FormField;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../field_render_context.dart';
import 'managed_text_field.dart';

const _numberKeyboard = TextInputType.numberWithOptions(decimal: true);

String _displayNum(dynamic value) => value?.toString() ?? '';

/// Ham metni [num]'a çevirir (boş/geçersiz → null).
num? _toNum(String raw) => num.tryParse(raw.trim().replaceAll(',', '.'));

Widget _affix(BuildContext context, String text) {
  final brightness = Theme.of(context).brightness;
  return Text(
    text,
    style: AppTypography.body.copyWith(
      color: AppColors.textSecondary(brightness),
    ),
  );
}

/// `number` → sayısal klavye. Değer: num.
class NumberFieldWidget extends FieldWidget {
  const NumberFieldWidget();

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) {
    return ManagedTextField(
      ctx: ctx,
      keyboardType: _numberKeyboard,
      transform: _toNum,
      display: _displayNum,
    );
  }
}

/// `currency` → sayısal klavye + para birimi öneki. Değer: num.
class CurrencyFieldWidget extends FieldWidget {
  const CurrencyFieldWidget();

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) {
    return ManagedTextField(
      ctx: ctx,
      keyboardType: _numberKeyboard,
      prefixWidget: _affix(context, '₺'),
      transform: _toNum,
      display: _displayNum,
    );
  }
}

/// `percentage` → sayısal klavye + `%` soneki. Değer: num.
class PercentageFieldWidget extends FieldWidget {
  const PercentageFieldWidget();

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) {
    return ManagedTextField(
      ctx: ctx,
      keyboardType: _numberKeyboard,
      suffixWidget: _affix(context, '%'),
      transform: _toNum,
      display: _displayNum,
    );
  }
}
