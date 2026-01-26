import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Chip varyantları
enum AppChipVariant {
  /// Filled - Dolgulu
  filled,

  /// Outlined - Kenarlıklı
  outlined,

  /// Tonal - Yarı saydam arka plan
  tonal,
}

/// Protoolbag Chip Widget
///
/// Etiket, filtre, seçim gösterimi için chip komponenti.
///
/// Örnek kullanım:
/// ```dart
/// AppChip(
///   label: 'Active',
///   variant: AppChipVariant.tonal,
///   color: AppColors.success,
/// )
/// ```
class AppChip extends StatelessWidget {
  /// Chip metni
  final String label;

  /// Varyant
  final AppChipVariant variant;

  /// Renk
  final Color? color;

  /// Sol ikon
  final IconData? icon;

  /// Seçili mi?
  final bool selected;

  /// Tıklama callback'i
  final VoidCallback? onTap;

  /// Silme callback'i
  final VoidCallback? onDelete;

  /// Küçük boyut
  final bool small;

  const AppChip({
    super.key,
    required this.label,
    this.variant = AppChipVariant.tonal,
    this.color,
    this.icon,
    this.selected = false,
    this.onTap,
    this.onDelete,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final chipColor = color ?? AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: small ? AppSpacing.sm : AppSpacing.sm + 4,
          vertical: small ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: _getBackgroundColor(chipColor, brightness),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: variant == AppChipVariant.outlined
              ? Border.all(color: chipColor, width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: small ? 14 : 16,
                color: _getForegroundColor(chipColor, brightness),
              ),
              SizedBox(width: small ? 4 : 6),
            ],
            Text(
              label,
              style: (small ? AppTypography.caption1 : AppTypography.subhead)
                  .copyWith(
                color: _getForegroundColor(chipColor, brightness),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (onDelete != null) ...[
              SizedBox(width: small ? 4 : 6),
              GestureDetector(
                onTap: onDelete,
                child: Icon(
                  Icons.close,
                  size: small ? 14 : 16,
                  color: _getForegroundColor(chipColor, brightness),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor(Color chipColor, Brightness brightness) {
    switch (variant) {
      case AppChipVariant.filled:
        return selected ? chipColor : chipColor.withOpacity(0.8);
      case AppChipVariant.outlined:
        return selected ? chipColor.withOpacity(0.1) : Colors.transparent;
      case AppChipVariant.tonal:
        return chipColor.withOpacity(selected ? 0.2 : 0.1);
    }
  }

  Color _getForegroundColor(Color chipColor, Brightness brightness) {
    switch (variant) {
      case AppChipVariant.filled:
        return Colors.white;
      case AppChipVariant.outlined:
      case AppChipVariant.tonal:
        return chipColor;
    }
  }
}

/// Choice chips group
class AppChoiceChips<T> extends StatelessWidget {
  /// Seçenekler
  final List<AppChoiceChipItem<T>> items;

  /// Seçili değer
  final T? selectedValue;

  /// Değer değiştiğinde
  final ValueChanged<T>? onSelected;

  /// Scrollable
  final bool scrollable;

  /// Padding
  final EdgeInsetsGeometry? padding;

  /// Spacing
  final double spacing;

  const AppChoiceChips({
    super.key,
    required this.items,
    this.selectedValue,
    this.onSelected,
    this.scrollable = false,
    this.padding,
    this.spacing = AppSpacing.sm,
  });

  @override
  Widget build(BuildContext context) {
    final chips = items.map((item) {
      final isSelected = item.value == selectedValue;
      return AppChip(
        label: item.label,
        icon: item.icon,
        variant: AppChipVariant.tonal,
        color: item.color,
        selected: isSelected,
        onTap: () => onSelected?.call(item.value),
      );
    }).toList();

    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Row(
          children: [
            for (int i = 0; i < chips.length; i++) ...[
              chips[i],
              if (i < chips.length - 1) SizedBox(width: spacing),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: chips,
      ),
    );
  }
}

/// Choice chip item
class AppChoiceChipItem<T> {
  final T value;
  final String label;
  final IconData? icon;
  final Color? color;

  const AppChoiceChipItem({
    required this.value,
    required this.label,
    this.icon,
    this.color,
  });
}

/// Filter chips group
class AppFilterChips extends StatelessWidget {
  /// Filtreler
  final List<AppFilterChipItem> items;

  /// Scrollable
  final bool scrollable;

  /// Padding
  final EdgeInsetsGeometry? padding;

  /// Spacing
  final double spacing;

  const AppFilterChips({
    super.key,
    required this.items,
    this.scrollable = false,
    this.padding,
    this.spacing = AppSpacing.sm,
  });

  @override
  Widget build(BuildContext context) {
    final chips = items.map((item) {
      return AppChip(
        label: item.label,
        icon: item.icon,
        variant: AppChipVariant.tonal,
        color: item.color,
        selected: item.selected,
        onTap: () => item.onChanged?.call(!item.selected),
      );
    }).toList();

    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Row(
          children: [
            for (int i = 0; i < chips.length; i++) ...[
              chips[i],
              if (i < chips.length - 1) SizedBox(width: spacing),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: chips,
      ),
    );
  }
}

/// Filter chip item
class AppFilterChipItem {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool selected;
  final ValueChanged<bool>? onChanged;

  const AppFilterChipItem({
    required this.label,
    this.icon,
    this.color,
    this.selected = false,
    this.onChanged,
  });
}

/// Tag chip (sadece gösterim)
class AppTag extends StatelessWidget {
  final String label;
  final Color? color;
  final bool small;

  const AppTag({
    super.key,
    required this.label,
    this.color,
    this.small = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppChip(
      label: label,
      variant: AppChipVariant.tonal,
      color: color,
      small: small,
    );
  }
}
