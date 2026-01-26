import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../buttons/app_button.dart';

/// Protoolbag Error View Widget
///
/// Hata durumlarını göstermek için kullanılır.
///
/// Örnek kullanım:
/// ```dart
/// AppErrorView(
///   message: 'Something went wrong',
///   onRetry: () => fetchData(),
/// )
/// ```
class AppErrorView extends StatelessWidget {
  /// Hata başlığı
  final String? title;

  /// Hata mesajı
  final String message;

  /// İkon
  final IconData icon;

  /// İkon rengi
  final Color? iconColor;

  /// Tekrar dene callback'i (or use onAction)
  final VoidCallback? onRetry;

  /// Tekrar dene buton metni (or use actionLabel)
  final String retryButtonText;

  /// İkinci aksiyon callback'i
  final VoidCallback? onSecondaryAction;

  /// İkinci aksiyon buton metni
  final String? secondaryButtonText;

  /// Tam ekran mı?
  final bool fullScreen;

  /// Kompakt mod
  final bool compact;

  const AppErrorView({
    super.key,
    this.title,
    required this.message,
    this.icon = Icons.error_outline,
    this.iconColor,
    VoidCallback? onRetry,
    String? retryButtonText,
    this.onSecondaryAction,
    this.secondaryButtonText,
    this.fullScreen = false,
    this.compact = false,
    // Alternative parameter names (aliases)
    String? actionLabel,
    VoidCallback? onAction,
  }) : onRetry = onRetry ?? onAction,
       retryButtonText = retryButtonText ?? actionLabel ?? 'Tekrar Dene';

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final content = _buildContent(brightness);

    if (fullScreen) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: AppSpacing.screenPadding,
              child: content,
            ),
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: compact ? AppSpacing.allSm : AppSpacing.allMd,
        child: content,
      ),
    );
  }

  Widget _buildContent(Brightness brightness) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon
        Icon(
          icon,
          size: compact ? 48 : 64,
          color: iconColor ?? AppColors.error,
        ),

        SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),

        // Title
        if (title != null) ...[
          Text(
            title!,
            style: (compact ? AppTypography.headline : AppTypography.title2)
                .copyWith(
              color: AppColors.textPrimary(brightness),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
        ],

        // Message
        Text(
          message,
          style:
              (compact ? AppTypography.footnote : AppTypography.body).copyWith(
            color: AppColors.textSecondary(brightness),
          ),
          textAlign: TextAlign.center,
        ),

        // Buttons
        if (onRetry != null || onSecondaryAction != null) ...[
          SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
          if (compact)
            _buildCompactButtons()
          else
            _buildButtons(),
        ],
      ],
    );
  }

  Widget _buildButtons() {
    return Column(
      children: [
        if (onRetry != null)
          AppButton(
            label: retryButtonText,
            variant: AppButtonVariant.primary,
            onPressed: onRetry,
            isFullWidth: false,
          ),
        if (onSecondaryAction != null && secondaryButtonText != null) ...[
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: secondaryButtonText!,
            variant: AppButtonVariant.tertiary,
            onPressed: onSecondaryAction,
            isFullWidth: false,
          ),
        ],
      ],
    );
  }

  Widget _buildCompactButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onSecondaryAction != null && secondaryButtonText != null) ...[
          AppButton(
            label: secondaryButtonText!,
            variant: AppButtonVariant.tertiary,
            size: AppButtonSize.small,
            onPressed: onSecondaryAction,
            isFullWidth: false,
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        if (onRetry != null)
          AppButton(
            label: retryButtonText,
            variant: AppButtonVariant.primary,
            size: AppButtonSize.small,
            onPressed: onRetry,
            isFullWidth: false,
          ),
      ],
    );
  }
}

/// Network error view
class AppNetworkErrorView extends StatelessWidget {
  final VoidCallback? onRetry;
  final bool compact;

  const AppNetworkErrorView({
    super.key,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppErrorView(
      icon: Icons.wifi_off,
      title: 'Bağlantı Hatası',
      message: 'İnternet bağlantınızı kontrol edin ve tekrar deneyin.',
      onRetry: onRetry,
      compact: compact,
    );
  }
}

/// Server error view
class AppServerErrorView extends StatelessWidget {
  final VoidCallback? onRetry;
  final bool compact;

  const AppServerErrorView({
    super.key,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppErrorView(
      icon: Icons.cloud_off,
      title: 'Sunucu Hatası',
      message: 'Bir sorun oluştu. Lütfen daha sonra tekrar deneyin.',
      onRetry: onRetry,
      compact: compact,
    );
  }
}

/// Generic error view
class AppGenericErrorView extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;
  final bool compact;

  const AppGenericErrorView({
    super.key,
    this.message,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppErrorView(
      icon: Icons.error_outline,
      title: 'Bir Hata Oluştu',
      message: message ?? 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.',
      onRetry: onRetry,
      compact: compact,
    );
  }
}
