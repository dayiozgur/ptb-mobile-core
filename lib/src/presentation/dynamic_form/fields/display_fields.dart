import 'package:flutter/material.dart' hide FormField;
import 'package:protoolbag_core/protoolbag_core.dart';

import '../field_render_context.dart';

/// `heading` → bölüm başlığı. Değeri yoktur (display-only).
class HeadingFieldWidget extends FieldWidget {
  const HeadingFieldWidget();

  @override
  bool get isDisplayOnly => true;

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) {
    final brightness = Theme.of(context).brightness;
    final field = ctx.field;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            field.label,
            style: AppTypography.headline.copyWith(
              color: AppColors.textPrimary(brightness),
            ),
          ),
          if (field.helpText != null && field.helpText!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              field.helpText!,
              style: AppTypography.subhead.copyWith(
                color: AppColors.textSecondary(brightness),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// `divider` → yatay ayraç. Değeri yoktur (display-only).
class DividerFieldWidget extends FieldWidget {
  const DividerFieldWidget();

  @override
  bool get isDisplayOnly => true;

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: AppColors.divider(brightness),
      ),
    );
  }
}
