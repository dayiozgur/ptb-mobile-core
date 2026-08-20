import 'package:flutter/material.dart' hide FormField;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../field_render_context.dart';
import 'field_scaffold.dart';

/// `rating` → dokunulabilir yıldız satırı. Değer: num (1..max).
///
/// Yıldız sayısı `field.options.items` doluysa onun uzunluğu, aksi halde
/// `field.validation.max` ya da varsayılan 5. Seçili yıldıza tekrar dokunmak
/// puanı temizler.
class RatingFieldWidget extends FieldWidget {
  const RatingFieldWidget();

  int _maxStars(FieldRenderContext ctx) {
    final items = ctx.field.options.items;
    if (items.isNotEmpty) return items.length;
    final validationMax = ctx.field.validation.max;
    if (validationMax != null && validationMax >= 1) return validationMax.round();
    return 5;
  }

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) {
    final field = ctx.field;
    final max = _maxStars(ctx);
    final current = (ctx.value is num) ? (ctx.value as num).round() : 0;

    return FieldScaffold(
      labelText: field.label,
      required: field.isRequired,
      helpText: field.helpText,
      errorText: ctx.errorText,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= max; i++)
            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs / 2),
              constraints: const BoxConstraints(),
              iconSize: 32,
              icon: Icon(
                i <= current ? Icons.star_rounded : Icons.star_border_rounded,
                color: i <= current
                    ? AppColors.warning
                    : AppColors.textTertiaryLight,
              ),
              onPressed: ctx.enabled
                  ? () => ctx.onChanged(i == current ? null : i)
                  : null,
            ),
        ],
      ),
    );
  }
}
