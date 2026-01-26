import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../buttons/app_button.dart';

/// Protoolbag Bottom Sheet Widget
///
/// Modal bottom sheet içeriği olarak doğrudan kullanılabilir.
///
/// Örnek kullanım:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   builder: (context) => AppBottomSheet(
///     title: 'Select Option',
///     child: ListView(...),
///   ),
/// );
/// ```
class AppBottomSheet extends StatelessWidget {
  /// Başlık
  final String? title;

  /// İçerik widget'ı
  final Widget child;

  /// Drag handle göster
  final bool showDragHandle;

  /// Maksimum yükseklik
  final double? maxHeight;

  /// İçerik padding'i
  final EdgeInsetsGeometry? padding;

  /// Aksiyon butonları
  final List<Widget>? actions;

  const AppBottomSheet({
    super.key,
    this.title,
    required this.child,
    this.showDragHandle = true,
    this.maxHeight,
    this.padding,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return _BottomSheetContent(
      title: title,
      showDragHandle: showDragHandle,
      maxHeight: maxHeight,
      padding: padding,
      actions: actions,
      child: child,
    );
  }
}

/// AppBottomSheet static metodları
class AppBottomSheetHelper {
  AppBottomSheetHelper._();

  /// Bottom sheet göster
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool isDismissible = true,
    bool enableDrag = true,
    bool showDragHandle = true,
    bool isScrollControlled = true,
    bool useSafeArea = true,
    double? maxHeight,
    EdgeInsetsGeometry? padding,
    List<Widget>? actions,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      backgroundColor: Colors.transparent,
      builder: (context) => _BottomSheetContent(
        title: title,
        showDragHandle: showDragHandle,
        maxHeight: maxHeight,
        padding: padding,
        actions: actions,
        child: child,
      ),
    );
  }

  /// Confirmation bottom sheet
  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    String? message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) {
    return show<bool>(
      context: context,
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Text(
                message,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary(
                    Theme.of(context).brightness,
                  ),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: cancelText,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: confirmText,
                  variant: isDestructive
                      ? AppButtonVariant.destructive
                      : AppButtonVariant.primary,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Options list bottom sheet
  static Future<T?> showOptions<T>({
    required BuildContext context,
    required List<AppBottomSheetOption<T>> options,
    String? title,
    T? selectedValue,
  }) {
    return show<T>(
      context: context,
      title: title,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            _OptionItem<T>(
              option: option,
              isSelected: option.value == selectedValue,
              onTap: () => Navigator.of(context).pop(option.value),
            ),
        ],
      ),
    );
  }

  /// Actions bottom sheet (iOS style action sheet)
  static Future<int?> showActions({
    required BuildContext context,
    required List<AppBottomSheetAction> actions,
    String? title,
    String? message,
    String cancelText = 'Cancel',
  }) {
    return show<int>(
      context: context,
      showDragHandle: false,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          if (title != null || message != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.systemGray6,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSpacing.radiusLg),
                ),
              ),
              child: Column(
                children: [
                  if (title != null)
                    Text(
                      title,
                      style: AppTypography.footnote.copyWith(
                        color: AppColors.textSecondary(
                          Theme.of(context).brightness,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  if (message != null) ...[
                    if (title != null) const SizedBox(height: 4),
                    Text(
                      message,
                      style: AppTypography.caption1.copyWith(
                        color: AppColors.textSecondary(
                          Theme.of(context).brightness,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),

          // Actions
          for (int i = 0; i < actions.length; i++) ...[
            if (i > 0 || title != null || message != null)
              Divider(
                height: 0.5,
                thickness: 0.5,
                color: AppColors.divider(Theme.of(context).brightness),
              ),
            _ActionItem(
              action: actions[i],
              onTap: () => Navigator.of(context).pop(i),
            ),
          ],

          // Cancel
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface(Theme.of(context).brightness),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    cancelText,
                    style: AppTypography.headline.copyWith(
                      color: AppColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomSheetContent extends StatelessWidget {
  final String? title;
  final Widget child;
  final bool showDragHandle;
  final double? maxHeight;
  final EdgeInsetsGeometry? padding;
  final List<Widget>? actions;

  const _BottomSheetContent({
    this.title,
    required this.child,
    required this.showDragHandle,
    this.maxHeight,
    this.padding,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final mediaQuery = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: maxHeight ?? mediaQuery.size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          if (showDragHandle)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.systemGray4,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),

          // Title
          if (title != null)
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
                    child: Text(
                      title!,
                      style: AppTypography.headline.copyWith(
                        color: AppColors.textPrimary(brightness),
                      ),
                    ),
                  ),
                  // Close button
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(
                      Icons.close,
                      color: AppColors.textSecondary(brightness),
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: padding ?? AppSpacing.cardInsets,
              child: child,
            ),
          ),

          // Actions
          if (actions != null && actions!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  for (int i = 0; i < actions!.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.sm),
                    Expanded(child: actions![i]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Bottom sheet option
class AppBottomSheetOption<T> {
  final T value;
  final String label;
  final IconData? icon;
  final String? subtitle;
  final bool enabled;

  const AppBottomSheetOption({
    required this.value,
    required this.label,
    this.icon,
    this.subtitle,
    this.enabled = true,
  });
}

class _OptionItem<T> extends StatelessWidget {
  final AppBottomSheetOption<T> option;
  final bool isSelected;
  final VoidCallback? onTap;

  const _OptionItem({
    required this.option,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: option.enabled ? onTap : null,
        child: Padding(
          padding: AppSpacing.listItemPadding,
          child: Row(
            children: [
              if (option.icon != null) ...[
                Icon(
                  option.icon,
                  size: 24,
                  color: option.enabled
                      ? AppColors.textPrimary(brightness)
                      : AppColors.textSecondary(brightness),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: AppTypography.body.copyWith(
                        color: option.enabled
                            ? AppColors.textPrimary(brightness)
                            : AppColors.textSecondary(brightness),
                      ),
                    ),
                    if (option.subtitle != null)
                      Text(
                        option.subtitle!,
                        style: AppTypography.caption1.copyWith(
                          color: AppColors.textSecondary(brightness),
                        ),
                      ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check,
                  size: 20,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet action
class AppBottomSheetAction {
  final String label;
  final IconData? icon;
  final bool isDestructive;

  const AppBottomSheetAction({
    required this.label,
    this.icon,
    this.isDestructive = false,
  });
}

class _ActionItem extends StatelessWidget {
  final AppBottomSheetAction action;
  final VoidCallback? onTap;

  const _ActionItem({
    required this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = action.isDestructive
        ? AppColors.error
        : AppColors.primary;

    return Material(
      color: AppColors.surface(brightness),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (action.icon != null) ...[
                Icon(action.icon, color: color, size: 20),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                action.label,
                style: AppTypography.body.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
