import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Protoolbag List Tile Widget
///
/// Apple HIG uyumlu, özelleştirilebilir list item komponenti.
///
/// Örnek kullanım:
/// ```dart
/// AppListTile(
///   title: 'John Doe',
///   subtitle: 'john@example.com',
///   leading: AppAvatar(name: 'John Doe'),
///   onTap: () => navigateToDetail(),
/// )
/// ```
class AppListTile extends StatelessWidget {
  /// Başlık
  final String title;

  /// Alt başlık
  final String? subtitle;

  /// Sol widget (ikon, avatar vb.)
  final Widget? leading;

  /// Sağ widget
  final Widget? trailing;

  /// Tıklama callback'i
  final VoidCallback? onTap;

  /// Uzun basma callback'i
  final VoidCallback? onLongPress;

  /// Chevron (ok) göster
  final bool showChevron;

  /// Divider göster
  final bool showDivider;

  /// Divider indent (sol boşluk)
  final double? dividerIndent;

  /// Dense mod
  final bool dense;

  /// Aktif mi?
  final bool enabled;

  /// Padding
  final EdgeInsetsGeometry? padding;

  /// Background color
  final Color? backgroundColor;

  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.showChevron = false,
    this.showDivider = true,
    this.dividerIndent,
    this.dense = false,
    this.enabled = true,
    this.padding,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: backgroundColor ?? Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            onLongPress: enabled ? onLongPress : null,
            child: Padding(
              padding: padding ??
                  EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: dense ? AppSpacing.sm : AppSpacing.sm + 4,
                  ),
              child: Row(
                children: [
                  // Leading
                  if (leading != null) ...[
                    leading!,
                    SizedBox(width: dense ? AppSpacing.sm : AppSpacing.md),
                  ],

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: (dense
                                  ? AppTypography.subhead
                                  : AppTypography.body)
                              .copyWith(
                            color: enabled
                                ? AppColors.textPrimary(brightness)
                                : AppColors.textSecondary(brightness),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: (dense
                                    ? AppTypography.caption1
                                    : AppTypography.subhead)
                                .copyWith(
                              color: AppColors.textSecondary(brightness),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Trailing
                  if (trailing != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    trailing!,
                  ],

                  // Chevron
                  if (showChevron) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: AppColors.textTertiaryLight,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Divider
        if (showDivider)
          Divider(
            height: 0.5,
            thickness: 0.5,
            indent: dividerIndent ??
                (leading != null ? AppSpacing.md + 44 + AppSpacing.md : AppSpacing.md),
            color: AppColors.divider(brightness),
          ),
      ],
    );
  }
}

/// Değer gösterme için list tile
class AppValueListTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool showDivider;

  const AppValueListTile({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
    this.showChevron = false,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return AppListTile(
      title: label,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary(brightness),
            ),
          ),
        ],
      ),
      onTap: onTap,
      showChevron: showChevron,
      showDivider: showDivider,
    );
  }
}

/// Switch ile list tile
class AppSwitchListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool showDivider;
  final bool enabled;

  const AppSwitchListTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.showDivider = true,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppListTile(
      title: title,
      subtitle: subtitle,
      enabled: enabled,
      trailing: Switch.adaptive(
        value: value,
        onChanged: enabled ? onChanged : null,
        activeColor: AppColors.success,
      ),
      onTap: enabled ? () => onChanged?.call(!value) : null,
      showDivider: showDivider,
    );
  }
}

/// Checkbox ile list tile
class AppCheckboxListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool?>? onChanged;
  final bool showDivider;
  final bool enabled;

  const AppCheckboxListTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.showDivider = true,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppListTile(
      title: title,
      subtitle: subtitle,
      enabled: enabled,
      leading: Checkbox(
        value: value,
        onChanged: enabled ? onChanged : null,
        activeColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      onTap: enabled ? () => onChanged?.call(!value) : null,
      showDivider: showDivider,
      dividerIndent: AppSpacing.md,
    );
  }
}

/// Radio ile list tile
class AppRadioListTile<T> extends StatelessWidget {
  final String title;
  final String? subtitle;
  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;
  final bool showDivider;
  final bool enabled;

  const AppRadioListTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.groupValue,
    this.onChanged,
    this.showDivider = true,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppListTile(
      title: title,
      subtitle: subtitle,
      enabled: enabled,
      trailing: Radio<T>(
        value: value,
        groupValue: groupValue,
        onChanged: enabled ? onChanged : null,
        activeColor: AppColors.primary,
      ),
      onTap: enabled ? () => onChanged?.call(value) : null,
      showDivider: showDivider,
    );
  }
}
