import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';

/// Card varyantları
enum AppCardVariant {
  /// Elevated - Gölgeli card
  elevated,

  /// Outlined - Kenarlıklı card
  outlined,

  /// Filled - Dolgulu card (gölgesiz)
  filled,
}

/// Protoolbag Card Widget
///
/// Apple HIG uyumlu, özelleştirilebilir card komponenti.
///
/// Örnek kullanım:
/// ```dart
/// AppCard(
///   child: Text('Hello World'),
///   onTap: () {},
/// )
/// ```
class AppCard extends StatelessWidget {
  /// Card içeriği
  final Widget child;

  /// Tıklama callback'i
  final VoidCallback? onTap;

  /// Uzun basma callback'i
  final VoidCallback? onLongPress;

  /// Card varyantı
  final AppCardVariant variant;

  /// İç padding
  final EdgeInsetsGeometry? padding;

  /// Dış margin
  final EdgeInsetsGeometry? margin;

  /// Arka plan rengi
  final Color? backgroundColor;

  /// Kenarlık rengi (sadece outlined için)
  final Color? borderColor;

  /// Köşe yarıçapı
  final double? borderRadius;

  /// Gölge göster (sadece elevated için)
  final bool showShadow;

  /// Genişlik
  final double? width;

  /// Yükseklik
  final double? height;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.variant = AppCardVariant.elevated,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.showShadow = true,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(
          borderRadius ?? AppSpacing.radiusMd,
        ),
        border: _getBorder(brightness),
        boxShadow: _getShadow(brightness),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(
          borderRadius ?? AppSpacing.radiusMd,
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(
            borderRadius ?? AppSpacing.radiusMd,
          ),
          child: Padding(
            padding: padding ?? AppSpacing.cardInsets,
            child: child,
          ),
        ),
      ),
    );
  }

  Border? _getBorder(Brightness brightness) {
    if (variant == AppCardVariant.outlined) {
      return Border.all(
        color: borderColor ?? AppColors.border(brightness),
        width: 1,
      );
    }
    return null;
  }

  List<BoxShadow>? _getShadow(Brightness brightness) {
    if (variant == AppCardVariant.elevated && showShadow) {
      return AppShadows.card(brightness);
    }
    return null;
  }
}

/// Header ile card
class AppCardWithHeader extends StatelessWidget {
  /// Header başlığı
  final String title;

  /// Header alt başlığı
  final String? subtitle;

  /// Header sağ aksiyonu
  final Widget? action;

  /// Card içeriği
  final Widget child;

  /// Tıklama callback'i
  final VoidCallback? onTap;

  /// Card varyantı
  final AppCardVariant variant;

  /// Dış margin
  final EdgeInsetsGeometry? margin;

  const AppCardWithHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    required this.child,
    this.onTap,
    this.variant = AppCardVariant.elevated,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return AppCard(
      variant: variant,
      margin: margin,
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(brightness),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary(brightness),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (action != null) action!,
              ],
            ),
          ),

          // Divider
          Divider(
            height: 1,
            thickness: 0.5,
            color: AppColors.divider(brightness),
          ),

          // Content
          Padding(
            padding: AppSpacing.cardInsets,
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Tıklanabilir list card
class AppListCard extends StatelessWidget {
  /// Liste öğeleri
  final List<Widget> children;

  /// Card varyantı
  final AppCardVariant variant;

  /// Dış margin
  final EdgeInsetsGeometry? margin;

  /// Divider göster
  final bool showDivider;

  const AppListCard({
    super.key,
    required this.children,
    this.variant = AppCardVariant.elevated,
    this.margin,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return AppCard(
      variant: variant,
      margin: margin,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (showDivider && i < children.length - 1)
              Divider(
                height: 1,
                thickness: 0.5,
                indent: AppSpacing.md,
                color: AppColors.divider(brightness),
              ),
          ],
        ],
      ),
    );
  }
}
