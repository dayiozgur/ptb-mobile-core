import 'package:flutter/material.dart' hide FormField;
import 'package:protoolbag_core/protoolbag_core.dart';

import '../field_render_context.dart';

/// Mobilde henüz desteklenmeyen egzotik alan tipleri için yer tutucu.
///
/// (file, image, signature, barcode, qr_scanner, gps_capture, location, rating,
/// rich_text, matrix_input, table_grid, slider_range, time_picker, daterange …)
/// Alan etiketini ve "yakında" notunu gösterir; değeri yoktur, submit'i bozmaz.
class UnsupportedFieldWidget extends FieldWidget {
  const UnsupportedFieldWidget();

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) {
    final brightness = Theme.of(context).brightness;
    final field = ctx.field;

    // i18n anahtarı varsa onu kullan; yoksa (translate anahtarı aynen döndürür)
    // Türkçe varsayılana düş.
    const key = 'field.unsupported_mobile';
    final translated = sl<LocalizationService>().translate(key);
    final note = translated == key ? 'Bu alan mobilde yakında' : translated;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: brightness == Brightness.light
            ? AppColors.systemGray6
            : AppColors.surfaceElevatedDark,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: AppColors.textSecondary(brightness),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  field.label,
                  style: AppTypography.subhead.copyWith(
                    color: AppColors.textPrimary(brightness),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  note,
                  style: AppTypography.caption1.copyWith(
                    color: AppColors.textSecondary(brightness),
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
