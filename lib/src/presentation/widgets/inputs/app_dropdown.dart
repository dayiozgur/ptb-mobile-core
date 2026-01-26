import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Dropdown item modeli
class AppDropdownItem<T> {
  /// Değer
  final T value;

  /// Görüntülenecek metin
  final String label;

  /// İkon (opsiyonel)
  final IconData? icon;

  /// Aktif mi?
  final bool enabled;

  const AppDropdownItem({
    required this.value,
    required this.label,
    this.icon,
    this.enabled = true,
  });
}

/// Protoolbag Dropdown Widget
///
/// Apple HIG uyumlu, özelleştirilebilir dropdown komponenti.
///
/// Örnek kullanım:
/// ```dart
/// AppDropdown<String>(
///   label: 'Country',
///   items: [
///     AppDropdownItem(value: 'tr', label: 'Turkey'),
///     AppDropdownItem(value: 'us', label: 'United States'),
///   ],
///   value: selectedCountry,
///   onChanged: (value) => setState(() => selectedCountry = value),
/// )
/// ```
class AppDropdown<T> extends StatelessWidget {
  /// Alan etiketi
  final String? label;

  /// Placeholder metni
  final String? placeholder;

  /// Yardımcı metin
  final String? helperText;

  /// Dropdown itemları
  final List<AppDropdownItem<T>> items;

  /// Seçili değer
  final T? value;

  /// Değer değiştiğinde callback
  final ValueChanged<T?>? onChanged;

  /// Doğrulama fonksiyonu
  final String? Function(T?)? validator;

  /// Sol ikon
  final IconData? prefixIcon;

  /// Aktif mi?
  final bool enabled;

  /// Hata mesajı
  final String? errorText;

  const AppDropdown({
    super.key,
    this.label,
    this.placeholder,
    this.helperText,
    required this.items,
    this.value,
    this.onChanged,
    this.validator,
    this.prefixIcon,
    this.enabled = true,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        if (label != null) ...[
          Text(
            label!,
            style: AppTypography.subhead.copyWith(
              color: AppColors.textSecondary(brightness),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],

        // Dropdown
        DropdownButtonFormField<T>(
          value: value,
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item.value,
              enabled: item.enabled,
              child: Row(
                children: [
                  if (item.icon != null) ...[
                    Icon(
                      item.icon,
                      size: 20,
                      color: item.enabled
                          ? AppColors.textPrimary(brightness)
                          : AppColors.textSecondary(brightness),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(
                    item.label,
                    style: AppTypography.body.copyWith(
                      color: item.enabled
                          ? AppColors.textPrimary(brightness)
                          : AppColors.textSecondary(brightness),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: enabled ? onChanged : null,
          validator: validator,
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: AppTypography.body.copyWith(
              color: AppColors.textTertiaryLight,
            ),
            filled: true,
            fillColor: _getFillColor(brightness),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 4,
            ),
            border: _buildBorder(brightness, false, hasError),
            enabledBorder: _buildBorder(brightness, false, hasError),
            focusedBorder: _buildBorder(brightness, true, hasError),
            errorBorder: _buildBorder(brightness, false, true),
            focusedErrorBorder: _buildBorder(brightness, true, true),
            disabledBorder: _buildBorder(brightness, false, false),
            prefixIcon: prefixIcon != null
                ? Icon(
                    prefixIcon,
                    color: AppColors.textSecondary(brightness),
                    size: 20,
                  )
                : null,
            errorText: errorText,
            errorStyle: AppTypography.caption1.copyWith(
              color: AppColors.error,
            ),
          ),
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: enabled
                ? AppColors.textSecondary(brightness)
                : AppColors.textTertiaryLight,
          ),
          dropdownColor: AppColors.surface(brightness),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          style: AppTypography.body.copyWith(
            color: enabled
                ? AppColors.textPrimary(brightness)
                : AppColors.textSecondary(brightness),
          ),
        ),

        // Helper Text
        if (helperText != null && errorText == null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            helperText!,
            style: AppTypography.caption1.copyWith(
              color: AppColors.textSecondary(brightness),
            ),
          ),
        ],
      ],
    );
  }

  Color _getFillColor(Brightness brightness) {
    if (!enabled) {
      return brightness == Brightness.light
          ? AppColors.systemGray6
          : AppColors.surfaceDark;
    }
    return brightness == Brightness.light
        ? AppColors.systemGray6
        : AppColors.surfaceElevatedDark;
  }

  OutlineInputBorder _buildBorder(
    Brightness brightness,
    bool isFocused,
    bool isError,
  ) {
    Color borderColor;

    if (isError) {
      borderColor = AppColors.error;
    } else if (isFocused) {
      borderColor = AppColors.primary;
    } else {
      borderColor = Colors.transparent;
    }

    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      borderSide: BorderSide(
        color: borderColor,
        width: isFocused || isError ? 2 : 0,
      ),
    );
  }
}

/// Basit string dropdown
class AppSimpleDropdown extends StatelessWidget {
  final String? label;
  final String? placeholder;
  final List<String> items;
  final String? value;
  final ValueChanged<String?>? onChanged;
  final bool enabled;

  const AppSimpleDropdown({
    super.key,
    this.label,
    this.placeholder,
    required this.items,
    this.value,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppDropdown<String>(
      label: label,
      placeholder: placeholder,
      items: items
          .map((item) => AppDropdownItem(value: item, label: item))
          .toList(),
      value: value,
      onChanged: onChanged,
      enabled: enabled,
    );
  }
}
