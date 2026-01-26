import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Icon button varyantları
enum AppIconButtonVariant {
  /// Filled - Dolgulu arka plan
  filled,

  /// Outlined - Kenarlıklı
  outlined,

  /// Ghost - Sadece ikon
  ghost,
}

/// Icon button boyutları
enum AppIconButtonSize {
  /// Small - 32px
  small,

  /// Medium - 44px (default)
  medium,

  /// Large - 56px
  large,
}

/// Protoolbag Icon Button Widget
///
/// Apple HIG uyumlu, sadece ikon içeren button komponenti.
///
/// Örnek kullanım:
/// ```dart
/// AppIconButton(
///   icon: Icons.add,
///   onPressed: () {},
/// )
/// ```
class AppIconButton extends StatelessWidget {
  /// İkon
  final IconData icon;

  /// Tıklama callback'i (null ise button disabled)
  final VoidCallback? onPressed;

  /// Button varyantı
  final AppIconButtonVariant variant;

  /// Button boyutu
  final AppIconButtonSize size;

  /// İkon rengi (null ise tema rengi)
  final Color? iconColor;

  /// Arka plan rengi (sadece filled için)
  final Color? backgroundColor;

  /// Kenarlık rengi (sadece outlined için)
  final Color? borderColor;

  /// Loading durumu
  final bool isLoading;

  /// Tooltip metni
  final String? tooltip;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.variant = AppIconButtonVariant.ghost,
    this.size = AppIconButtonSize.medium,
    this.iconColor,
    this.backgroundColor,
    this.borderColor,
    this.isLoading = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isEnabled = onPressed != null && !isLoading;

    Widget button = _buildButton(context, brightness, isEnabled);

    if (tooltip != null) {
      button = Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }

  Widget _buildButton(
    BuildContext context,
    Brightness brightness,
    bool isEnabled,
  ) {
    final buttonSize = _getButtonSize();
    final iconSize = _getIconSize();

    switch (variant) {
      case AppIconButtonVariant.filled:
        return _FilledIconButton(
          icon: icon,
          onPressed: isEnabled ? onPressed : null,
          isLoading: isLoading,
          buttonSize: buttonSize,
          iconSize: iconSize,
          iconColor: iconColor,
          backgroundColor: backgroundColor,
          brightness: brightness,
        );

      case AppIconButtonVariant.outlined:
        return _OutlinedIconButton(
          icon: icon,
          onPressed: isEnabled ? onPressed : null,
          isLoading: isLoading,
          buttonSize: buttonSize,
          iconSize: iconSize,
          iconColor: iconColor,
          borderColor: borderColor,
          brightness: brightness,
        );

      case AppIconButtonVariant.ghost:
        return _GhostIconButton(
          icon: icon,
          onPressed: isEnabled ? onPressed : null,
          isLoading: isLoading,
          buttonSize: buttonSize,
          iconSize: iconSize,
          iconColor: iconColor,
          brightness: brightness,
        );
    }
  }

  double _getButtonSize() {
    switch (size) {
      case AppIconButtonSize.small:
        return 32;
      case AppIconButtonSize.medium:
        return 44;
      case AppIconButtonSize.large:
        return 56;
    }
  }

  double _getIconSize() {
    switch (size) {
      case AppIconButtonSize.small:
        return AppSpacing.iconSizeSm;
      case AppIconButtonSize.medium:
        return 22;
      case AppIconButtonSize.large:
        return AppSpacing.iconSizeMd;
    }
  }
}

// ============================================
// FILLED ICON BUTTON
// ============================================

class _FilledIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double buttonSize;
  final double iconSize;
  final Color? iconColor;
  final Color? backgroundColor;
  final Brightness brightness;

  const _FilledIconButton({
    required this.icon,
    required this.onPressed,
    required this.isLoading,
    required this.buttonSize,
    required this.iconSize,
    this.iconColor,
    this.backgroundColor,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? AppColors.primary;
    final fgColor = iconColor ?? Colors.white;

    return SizedBox(
      width: buttonSize,
      height: buttonSize,
      child: Material(
        color: onPressed != null ? bgColor : bgColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: iconSize,
                    height: iconSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                    ),
                  )
                : Icon(
                    icon,
                    size: iconSize,
                    color: onPressed != null
                        ? fgColor
                        : fgColor.withOpacity(0.7),
                  ),
          ),
        ),
      ),
    );
  }
}

// ============================================
// OUTLINED ICON BUTTON
// ============================================

class _OutlinedIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double buttonSize;
  final double iconSize;
  final Color? iconColor;
  final Color? borderColor;
  final Brightness brightness;

  const _OutlinedIconButton({
    required this.icon,
    required this.onPressed,
    required this.isLoading,
    required this.buttonSize,
    required this.iconSize,
    this.iconColor,
    this.borderColor,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.primary;
    final border = borderColor ?? AppColors.primary;

    return SizedBox(
      width: buttonSize,
      height: buttonSize,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          side: BorderSide(
            color: onPressed != null ? border : border.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: iconSize,
                    height: iconSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  )
                : Icon(
                    icon,
                    size: iconSize,
                    color:
                        onPressed != null ? color : color.withOpacity(0.5),
                  ),
          ),
        ),
      ),
    );
  }
}

// ============================================
// GHOST ICON BUTTON
// ============================================

class _GhostIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double buttonSize;
  final double iconSize;
  final Color? iconColor;
  final Brightness brightness;

  const _GhostIconButton({
    required this.icon,
    required this.onPressed,
    required this.isLoading,
    required this.buttonSize,
    required this.iconSize,
    this.iconColor,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        iconColor ?? AppColors.textPrimary(brightness);

    return SizedBox(
      width: buttonSize,
      height: buttonSize,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: iconSize,
                    height: iconSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  )
                : Icon(
                    icon,
                    size: iconSize,
                    color:
                        onPressed != null ? color : color.withOpacity(0.5),
                  ),
          ),
        ),
      ),
    );
  }
}
