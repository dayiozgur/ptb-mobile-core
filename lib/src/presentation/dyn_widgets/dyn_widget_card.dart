import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../widgets/cards/app_card.dart';

/// Dinamik report/page widget'ları için ortak kart iskeleti.
///
/// Başlık/alt başlık header'ı, yükleniyor spinner'ı, hata + tekrar-dene durumu
/// ve isteğe bağlı footer ("N kayıt") sağlar. Report/page viewer'lar her
/// widget'ı bu kartla sarar.
class DynWidgetCard extends StatelessWidget {
  /// Kart başlığı.
  final String? title;

  /// Kart alt başlığı.
  final String? subtitle;

  /// İçerik (widget gövdesi). [loading]/[error] baskındır.
  final Widget? child;

  /// Yükleniyor durumu — spinner gösterir.
  final bool loading;

  /// Hata mesajı — gösterildiğinde [onRetry] ile tekrar-dene sunar.
  final String? error;

  /// Tekrar-dene callback'i (hata durumunda).
  final VoidCallback? onRetry;

  /// İsteğe bağlı footer (ör. "128 kayıt").
  final String? footer;

  const DynWidgetCard({
    super.key,
    this.title,
    this.subtitle,
    this.child,
    this.loading = false,
    this.error,
    this.onRetry,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = AppColors.textPrimary(brightness);
    final textSecondary = AppColors.textSecondary(brightness);

    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null || subtitle != null) ...[
            _buildHeader(textPrimary, textSecondary),
            const SizedBox(height: AppSpacing.md),
          ],
          _buildBody(context, textSecondary),
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              footer!,
              style: AppTypography.withColor(
                AppTypography.caption1,
                textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(Color textPrimary, Color textSecondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null)
          Text(
            title!,
            style: AppTypography.withColor(AppTypography.headline, textPrimary),
          ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle!,
            style: AppTypography.withColor(
              AppTypography.footnote,
              textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBody(BuildContext context, Color textSecondary) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: AppSpacing.iconSizeLg,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: AppTypography.withColor(
                AppTypography.footnote,
                textSecondary,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: AppSpacing.iconSizeSm),
                label: const Text('Tekrar dene'),
              ),
            ],
          ],
        ),
      );
    }

    return child ?? const SizedBox.shrink();
  }
}
