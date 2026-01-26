import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Protoolbag Tab Bar Widget
///
/// Apple HIG uyumlu, özelleştirilebilir tab bar komponenti.
///
/// Örnek kullanım:
/// ```dart
/// AppTabBar(
///   tabs: ['All', 'Active', 'Completed'],
///   selectedIndex: 0,
///   onTabChanged: (index) => setState(() => _selectedIndex = index),
/// )
/// ```
class AppTabBar extends StatelessWidget {
  /// Tab etiketleri
  final List<String> tabs;

  /// Seçili index
  final int selectedIndex;

  /// Tab değiştiğinde
  final ValueChanged<int>? onTabChanged;

  /// Scrollable
  final bool isScrollable;

  /// Padding
  final EdgeInsetsGeometry? padding;

  const AppTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    this.onTabChanged,
    this.isScrollable = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    if (isScrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding ??
            const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            for (int i = 0; i < tabs.length; i++) ...[
              _TabItem(
                label: tabs[i],
                isSelected: i == selectedIndex,
                onTap: () => onTabChanged?.call(i),
                brightness: brightness,
              ),
              if (i < tabs.length - 1) const SizedBox(width: AppSpacing.xs),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Row(
        children: [
          for (int i = 0; i < tabs.length; i++)
            Expanded(
              child: _TabItem(
                label: tabs[i],
                isSelected: i == selectedIndex,
                onTap: () => onTabChanged?.call(i),
                brightness: brightness,
              ),
            ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final Brightness brightness;

  const _TabItem({
    required this.label,
    required this.isSelected,
    this.onTap,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.subhead.copyWith(
            color: isSelected
                ? AppColors.primary
                : AppColors.textSecondary(brightness),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Segmented Control Style Tab Bar
class AppSegmentedControl extends StatelessWidget {
  /// Segment etiketleri
  final List<String> segments;

  /// Seçili index
  final int selectedIndex;

  /// Segment değiştiğinde
  final ValueChanged<int>? onSegmentChanged;

  /// Padding
  final EdgeInsetsGeometry? padding;

  const AppSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    this.onSegmentChanged,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      margin: padding,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: brightness == Brightness.light
            ? AppColors.systemGray6
            : AppColors.surfaceElevatedDark,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < segments.length; i++)
            Expanded(
              child: _SegmentItem(
                label: segments[i],
                isSelected: i == selectedIndex,
                onTap: () => onSegmentChanged?.call(i),
                brightness: brightness,
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final Brightness brightness;

  const _SegmentItem({
    required this.label,
    required this.isSelected,
    this.onTap,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.surface(brightness)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppTypography.subhead.copyWith(
            color: isSelected
                ? AppColors.textPrimary(brightness)
                : AppColors.textSecondary(brightness),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Bottom Navigation Bar
class AppBottomNavigationBar extends StatelessWidget {
  /// Navigation itemları
  final List<AppBottomNavItem> items;

  /// Seçili index
  final int currentIndex;

  /// Item tıklandığında
  final ValueChanged<int>? onTap;

  /// Background color
  final Color? backgroundColor;

  /// Show labels
  final bool showLabels;

  const AppBottomNavigationBar({
    super.key,
    required this.items,
    required this.currentIndex,
    this.onTap,
    this.backgroundColor,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface(brightness),
        border: Border(
          top: BorderSide(
            color: AppColors.divider(brightness),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (int i = 0; i < items.length; i++)
                Expanded(
                  child: _BottomNavItem(
                    item: items[i],
                    isSelected: i == currentIndex,
                    onTap: () => onTap?.call(i),
                    showLabel: showLabels,
                    brightness: brightness,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom navigation item
class AppBottomNavItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final int? badgeCount;
  final bool showBadge;

  const AppBottomNavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    this.badgeCount,
    this.showBadge = false,
  });
}

class _BottomNavItem extends StatelessWidget {
  final AppBottomNavItem item;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool showLabel;
  final Brightness brightness;

  const _BottomNavItem({
    required this.item,
    required this.isSelected,
    this.onTap,
    required this.showLabel,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? AppColors.primary
        : AppColors.textSecondary(brightness);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? (item.activeIcon ?? item.icon) : item.icon,
                  color: color,
                  size: 24,
                ),
                if (item.showBadge || (item.badgeCount ?? 0) > 0)
                  Positioned(
                    top: -4,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: item.badgeCount != null
                          ? Text(
                              item.badgeCount! > 99
                                  ? '99+'
                                  : '${item.badgeCount}',
                              style: AppTypography.caption2.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
              ],
            ),
            if (showLabel) ...[
              const SizedBox(height: 2),
              Text(
                item.label,
                style: AppTypography.caption2.copyWith(
                  color: color,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
