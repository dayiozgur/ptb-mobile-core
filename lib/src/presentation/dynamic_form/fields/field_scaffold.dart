import 'package:flutter/material.dart' hide FormField;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Alan widget'ları için ortak dikey iskelet.
///
/// Tutarlı bir şekilde: etiket (zorunluysa `*`), alan gövdesi, yardım metni ve
/// hata metnini (error tonunda) render eder. Primitive'lerin çoğu kendi
/// etiketini çizebildiği için, tutarlı hata gösterimi (ör. [AppTextField]'ın
/// `errorText`'i yoktur) sağlamak adına etiket burada tek yerden yönetilir;
/// gövde primitive'e etiketsiz verilir.
class FieldScaffold extends StatelessWidget {
  /// Üstte gösterilecek etiket. `null` ise etiket satırı çizilmez (ör. checkbox
  /// etiketi tile başlığında gösterilir).
  final String? labelText;

  /// Zorunlu alan mı? Etiketin yanına `*` ekler.
  final bool required;

  /// Etiketin altında gösterilecek yardım metni.
  final String? helpText;

  /// Hata metni (varsa) — help metninin yerine error tonunda gösterilir.
  final String? errorText;

  /// Alan gövdesi (primitive veya ham input widget'ı).
  final Widget child;

  const FieldScaffold({
    super.key,
    required this.child,
    this.labelText,
    this.required = false,
    this.helpText,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final label = labelText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null && label.isNotEmpty) ...[
          RichText(
            text: TextSpan(
              text: label,
              style: AppTypography.subhead.copyWith(
                color: AppColors.textSecondary(brightness),
                fontWeight: FontWeight.w500,
              ),
              children: required
                  ? [
                      TextSpan(
                        text: ' *',
                        style: AppTypography.subhead.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ]
                  : const [],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        child,
        if (errorText != null && errorText!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            errorText!,
            style: AppTypography.caption1.copyWith(color: AppColors.error),
          ),
        ] else if (helpText != null && helpText!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            helpText!,
            style: AppTypography.caption1.copyWith(
              color: AppColors.textSecondary(brightness),
            ),
          ),
        ],
      ],
    );
  }
}
