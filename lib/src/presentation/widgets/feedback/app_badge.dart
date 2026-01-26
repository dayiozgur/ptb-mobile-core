import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Badge varyantları
enum AppBadgeVariant {
  /// Primary - Mavi
  primary,

  /// Success - Yeşil
  success,

  /// Warning - Turuncu
  warning,

  /// Error - Kırmızı
  error,

  /// Info - Açık mavi
  info,

  /// Neutral - Gri
  neutral,
}

/// Badge boyutları
enum AppBadgeSize {
  /// Small - Küçük (nokta veya tek rakam)
  small,

  /// Medium - Orta (varsayılan)
  medium,

  /// Large - Büyük
  large,
}

/// Protoolbag Badge Widget
///
/// Bildirim sayısı, durum göstergesi vb. için kullanılır.
///
/// Örnek kullanım:
/// ```dart
/// AppBadge(
///   label: '5',
///   variant: AppBadgeVariant.error,
/// )
/// ```
class AppBadge extends StatelessWidget {
  /// Badge metni (boş ise dot gösterilir)
  final String? label;

  /// Varyant
  final AppBadgeVariant variant;

  /// Boyut
  final AppBadgeSize size;

  /// İkon (label yerine)
  final IconData? icon;

  /// Sadece nokta göster
  final bool dot;

  const AppBadge({
    super.key,
    this.label,
    this.variant = AppBadgeVariant.primary,
    this.size = AppBadgeSize.medium,
    this.icon,
    this.dot = false,
  });

  @override
  Widget build(BuildContext context) {
    if (dot || (label == null && icon == null)) {
      return _buildDot();
    }

    return Container(
      constraints: BoxConstraints(
        minWidth: _getMinSize(),
        minHeight: _getHeight(),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: _getPadding(),
      ),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Center(
        child: icon != null
            ? Icon(
                icon,
                size: _getIconSize(),
                color: _getTextColor(),
              )
            : Text(
                _formatLabel(label!),
                style: _getTextStyle().copyWith(
                  color: _getTextColor(),
                ),
              ),
      ),
    );
  }

  Widget _buildDot() {
    final dotSize = size == AppBadgeSize.small
        ? 6.0
        : size == AppBadgeSize.medium
            ? 8.0
            : 10.0;

    return Container(
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        shape: BoxShape.circle,
      ),
    );
  }

  double _getMinSize() {
    switch (size) {
      case AppBadgeSize.small:
        return 16;
      case AppBadgeSize.medium:
        return 20;
      case AppBadgeSize.large:
        return 24;
    }
  }

  double _getHeight() {
    switch (size) {
      case AppBadgeSize.small:
        return 16;
      case AppBadgeSize.medium:
        return 20;
      case AppBadgeSize.large:
        return 24;
    }
  }

  double _getPadding() {
    switch (size) {
      case AppBadgeSize.small:
        return 4;
      case AppBadgeSize.medium:
        return 6;
      case AppBadgeSize.large:
        return 8;
    }
  }

  double _getIconSize() {
    switch (size) {
      case AppBadgeSize.small:
        return 10;
      case AppBadgeSize.medium:
        return 12;
      case AppBadgeSize.large:
        return 14;
    }
  }

  TextStyle _getTextStyle() {
    switch (size) {
      case AppBadgeSize.small:
        return AppTypography.caption2.copyWith(fontWeight: FontWeight.w600);
      case AppBadgeSize.medium:
        return AppTypography.caption1.copyWith(fontWeight: FontWeight.w600);
      case AppBadgeSize.large:
        return AppTypography.footnote.copyWith(fontWeight: FontWeight.w600);
    }
  }

  String _formatLabel(String value) {
    final number = int.tryParse(value);
    if (number != null && number > 99) {
      return '99+';
    }
    return value;
  }

  Color _getBackgroundColor() {
    switch (variant) {
      case AppBadgeVariant.primary:
        return AppColors.primary;
      case AppBadgeVariant.success:
        return AppColors.success;
      case AppBadgeVariant.warning:
        return AppColors.warning;
      case AppBadgeVariant.error:
        return AppColors.error;
      case AppBadgeVariant.info:
        return AppColors.info;
      case AppBadgeVariant.neutral:
        return AppColors.systemGray;
    }
  }

  Color _getTextColor() {
    return Colors.white;
  }
}

/// Badge ile sarılmış widget
class AppBadgeWrapper extends StatelessWidget {
  /// İçerik widget'ı
  final Widget child;

  /// Badge metni
  final String? badgeLabel;

  /// Badge varyantı
  final AppBadgeVariant badgeVariant;

  /// Badge boyutu
  final AppBadgeSize badgeSize;

  /// Badge pozisyonu
  final AlignmentGeometry badgeAlignment;

  /// Badge görünür mü?
  final bool showBadge;

  /// Sadece dot göster
  final bool dot;

  /// Badge offset
  final Offset badgeOffset;

  const AppBadgeWrapper({
    super.key,
    required this.child,
    this.badgeLabel,
    this.badgeVariant = AppBadgeVariant.error,
    this.badgeSize = AppBadgeSize.small,
    this.badgeAlignment = Alignment.topRight,
    this.showBadge = true,
    this.dot = false,
    this.badgeOffset = const Offset(-2, 2),
  });

  @override
  Widget build(BuildContext context) {
    if (!showBadge) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: badgeOffset.dy,
          right: badgeOffset.dx,
          child: AppBadge(
            label: badgeLabel,
            variant: badgeVariant,
            size: badgeSize,
            dot: dot,
          ),
        ),
      ],
    );
  }
}

/// Status badge (durum göstergesi)
class AppStatusBadge extends StatelessWidget {
  /// Durum metni
  final String label;

  /// Durum aktif mi?
  final bool isActive;

  /// Özel renk
  final Color? activeColor;

  const AppStatusBadge({
    super.key,
    required this.label,
    this.isActive = true,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = isActive
        ? (activeColor ?? AppColors.success)
        : AppColors.textSecondary(brightness);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.caption1.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
