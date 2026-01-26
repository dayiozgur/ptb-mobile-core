import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Button varyantları
enum AppButtonVariant {
  /// Primary - Ana aksiyon butonu (mavi arka plan)
  primary,

  /// Secondary - İkincil aksiyon butonu (outline)
  secondary,

  /// Tertiary - Üçüncül aksiyon butonu (sadece text)
  tertiary,

  /// Destructive - Silme/tehlikeli işlem butonu (kırmızı)
  destructive,

  /// Success - Başarılı işlem butonu (yeşil)
  success,
}

/// Button boyutları
enum AppButtonSize {
  /// Small - 32px yükseklik
  small,

  /// Medium - 44px yükseklik (default)
  medium,

  /// Large - 52px yükseklik
  large,
}

/// Protoolbag Button Widget
///
/// Apple HIG uyumlu, özelleştirilebilir button komponenti.
///
/// Örnek kullanım:
/// ```dart
/// AppButton(
///   label: 'Continue',
///   variant: AppButtonVariant.primary,
///   onPressed: () {},
/// )
/// ```
class AppButton extends StatelessWidget {
  /// Button metni
  final String label;

  /// Tıklama callback'i (null ise button disabled)
  final VoidCallback? onPressed;

  /// Button varyantı
  final AppButtonVariant variant;

  /// Button boyutu
  final AppButtonSize size;

  /// Loading durumu
  final bool isLoading;

  /// Full width mi?
  final bool isFullWidth;

  /// Sol ikon
  final IconData? icon;

  /// Sağ ikon
  final IconData? trailingIcon;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.isFullWidth = true,
    this.icon,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isEnabled = onPressed != null && !isLoading;

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: _getHeight(),
      child: _buildButton(context, brightness, isEnabled),
    );
  }

  Widget _buildButton(
    BuildContext context,
    Brightness brightness,
    bool isEnabled,
  ) {
    switch (variant) {
      case AppButtonVariant.primary:
        return _PrimaryButton(
          label: label,
          onPressed: isEnabled ? onPressed : null,
          isLoading: isLoading,
          size: size,
          icon: icon,
          trailingIcon: trailingIcon,
        );

      case AppButtonVariant.secondary:
        return _SecondaryButton(
          label: label,
          onPressed: isEnabled ? onPressed : null,
          isLoading: isLoading,
          size: size,
          icon: icon,
          trailingIcon: trailingIcon,
        );

      case AppButtonVariant.tertiary:
        return _TertiaryButton(
          label: label,
          onPressed: isEnabled ? onPressed : null,
          isLoading: isLoading,
          size: size,
          icon: icon,
          trailingIcon: trailingIcon,
        );

      case AppButtonVariant.destructive:
        return _DestructiveButton(
          label: label,
          onPressed: isEnabled ? onPressed : null,
          isLoading: isLoading,
          size: size,
          icon: icon,
          trailingIcon: trailingIcon,
        );

      case AppButtonVariant.success:
        return _SuccessButton(
          label: label,
          onPressed: isEnabled ? onPressed : null,
          isLoading: isLoading,
          size: size,
          icon: icon,
          trailingIcon: trailingIcon,
        );
    }
  }

  double _getHeight() {
    switch (size) {
      case AppButtonSize.small:
        return AppSpacing.buttonHeightSm;
      case AppButtonSize.medium:
        return AppSpacing.buttonHeightMd;
      case AppButtonSize.large:
        return AppSpacing.buttonHeightLg;
    }
  }
}

// ============================================
// PRIMARY BUTTON
// ============================================

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;

  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    required this.isLoading,
    required this.size,
    this.icon,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
        disabledForegroundColor: Colors.white.withOpacity(0.7),
        elevation: 0,
        padding: _getPadding(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
      ),
      child: _ButtonContent(
        label: label,
        isLoading: isLoading,
        size: size,
        icon: icon,
        trailingIcon: trailingIcon,
        color: Colors.white,
      ),
    );
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case AppButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.sm);
      case AppButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.md);
      case AppButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.lg);
    }
  }
}

// ============================================
// SECONDARY BUTTON
// ============================================

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;

  const _SecondaryButton({
    required this.label,
    required this.onPressed,
    required this.isLoading,
    required this.size,
    this.icon,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        disabledForegroundColor: AppColors.primary.withOpacity(0.5),
        side: BorderSide(
          color: onPressed != null
              ? AppColors.primary
              : AppColors.primary.withOpacity(0.5),
        ),
        elevation: 0,
        padding: _getPadding(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
      ),
      child: _ButtonContent(
        label: label,
        isLoading: isLoading,
        size: size,
        icon: icon,
        trailingIcon: trailingIcon,
        color: AppColors.primary,
      ),
    );
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case AppButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.sm);
      case AppButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.md);
      case AppButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.lg);
    }
  }
}

// ============================================
// TERTIARY BUTTON
// ============================================

class _TertiaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;

  const _TertiaryButton({
    required this.label,
    required this.onPressed,
    required this.isLoading,
    required this.size,
    this.icon,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        disabledForegroundColor: AppColors.primary.withOpacity(0.5),
        padding: _getPadding(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
      ),
      child: _ButtonContent(
        label: label,
        isLoading: isLoading,
        size: size,
        icon: icon,
        trailingIcon: trailingIcon,
        color: AppColors.primary,
      ),
    );
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case AppButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.xs);
      case AppButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.sm);
      case AppButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.md);
    }
  }
}

// ============================================
// DESTRUCTIVE BUTTON
// ============================================

class _DestructiveButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;

  const _DestructiveButton({
    required this.label,
    required this.onPressed,
    required this.isLoading,
    required this.size,
    this.icon,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.error,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.error.withOpacity(0.5),
        disabledForegroundColor: Colors.white.withOpacity(0.7),
        elevation: 0,
        padding: _getPadding(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
      ),
      child: _ButtonContent(
        label: label,
        isLoading: isLoading,
        size: size,
        icon: icon,
        trailingIcon: trailingIcon,
        color: Colors.white,
      ),
    );
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case AppButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.sm);
      case AppButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.md);
      case AppButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.lg);
    }
  }
}

// ============================================
// SUCCESS BUTTON
// ============================================

class _SuccessButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;

  const _SuccessButton({
    required this.label,
    required this.onPressed,
    required this.isLoading,
    required this.size,
    this.icon,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.success.withOpacity(0.5),
        disabledForegroundColor: Colors.white.withOpacity(0.7),
        elevation: 0,
        padding: _getPadding(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
      ),
      child: _ButtonContent(
        label: label,
        isLoading: isLoading,
        size: size,
        icon: icon,
        trailingIcon: trailingIcon,
        color: Colors.white,
      ),
    );
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case AppButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.sm);
      case AppButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.md);
      case AppButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.lg);
    }
  }
}

// ============================================
// BUTTON CONTENT
// ============================================

class _ButtonContent extends StatelessWidget {
  final String label;
  final bool isLoading;
  final AppButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final Color color;

  const _ButtonContent({
    required this.label,
    required this.isLoading,
    required this.size,
    required this.color,
    this.icon,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        width: _getIconSize(),
        height: _getIconSize(),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: _getIconSize(), color: color),
          SizedBox(width: AppSpacing.iconTextSpacing),
        ],
        Text(label, style: _getTextStyle()),
        if (trailingIcon != null) ...[
          SizedBox(width: AppSpacing.iconTextSpacing),
          Icon(trailingIcon, size: _getIconSize(), color: color),
        ],
      ],
    );
  }

  double _getIconSize() {
    switch (size) {
      case AppButtonSize.small:
        return AppSpacing.iconSizeSm;
      case AppButtonSize.medium:
        return 20;
      case AppButtonSize.large:
        return AppSpacing.iconSizeMd;
    }
  }

  TextStyle _getTextStyle() {
    switch (size) {
      case AppButtonSize.small:
        return AppTypography.buttonSmall;
      case AppButtonSize.medium:
        return AppTypography.buttonMedium;
      case AppButtonSize.large:
        return AppTypography.buttonLarge;
    }
  }
}
