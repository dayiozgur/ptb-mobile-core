import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Protoolbag Section Header Widget
///
/// Liste bölüm başlıkları için kullanılır.
///
/// Örnek kullanım:
/// ```dart
/// AppSectionHeader(
///   title: 'Recent Items',
///   action: 'See All',
///   onActionTap: () => navigateToAll(),
/// )
/// ```
class AppSectionHeader extends StatelessWidget {
  /// Başlık
  final String title;

  /// Alt başlık
  final String? subtitle;

  /// Aksiyon metni
  final String? action;

  /// Aksiyon tıklama
  final VoidCallback? onActionTap;

  /// Aksiyon widget'ı (action yerine)
  final Widget? actionWidget;

  /// Padding
  final EdgeInsetsGeometry? padding;

  /// Sticky header
  final bool sticky;

  /// Background color (sticky için)
  final Color? backgroundColor;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.onActionTap,
    this.actionWidget,
    this.padding,
    this.sticky = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    final content = Container(
      color: sticky
          ? (backgroundColor ?? AppColors.background(brightness))
          : null,
      padding: padding ??
          const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.sm,
          ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.title3.copyWith(
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTypography.footnote.copyWith(
                      color: AppColors.textSecondary(brightness),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionWidget != null)
            actionWidget!
          else if (action != null)
            GestureDetector(
              onTap: onActionTap,
              child: Text(
                action!,
                style: AppTypography.subhead.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );

    if (sticky) {
      return SliverPersistentHeader(
        pinned: true,
        delegate: _SectionHeaderDelegate(
          child: content,
          height: subtitle != null ? 72 : 56,
        ),
      );
    }

    return content;
  }
}

class _SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _SectionHeaderDelegate({
    required this.child,
    required this.height,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(_SectionHeaderDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}

/// Basit section header
class AppSimpleSectionHeader extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry? padding;

  const AppSimpleSectionHeader({
    super.key,
    required this.title,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      width: double.infinity,
      padding: padding ??
          const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.sm,
          ),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.caption1.copyWith(
          color: AppColors.textSecondary(brightness),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Grouped list section
class AppListSection extends StatelessWidget {
  final String? header;
  final String? footer;
  final List<Widget> children;
  final EdgeInsetsGeometry? margin;
  final bool showBackground;

  const AppListSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
    this.margin,
    this.showBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Padding(
      padding: margin ?? const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md + AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Text(
                header!.toUpperCase(),
                style: AppTypography.caption1.copyWith(
                  color: AppColors.textSecondary(brightness),
                  letterSpacing: 0.5,
                ),
              ),
            ),

          // Content
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: showBackground
                ? BoxDecoration(
                    color: AppColors.surface(brightness),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  )
                : null,
            child: Column(
              children: children,
            ),
          ),

          // Footer
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md + AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Text(
                footer!,
                style: AppTypography.caption1.copyWith(
                  color: AppColors.textSecondary(brightness),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
