import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Protoolbag Text Field Widget
///
/// Apple HIG uyumlu, özelleştirilebilir text input komponenti.
///
/// Örnek kullanım:
/// ```dart
/// AppTextField(
///   label: 'Email',
///   placeholder: 'Enter your email',
///   validator: Validators.email,
/// )
/// ```
class AppTextField extends StatefulWidget {
  /// Alan etiketi (üstte gösterilir)
  final String? label;

  /// Placeholder metni
  final String? placeholder;

  /// Yardımcı metin (altta gösterilir)
  final String? helperText;

  /// Text controller
  final TextEditingController? controller;

  /// Focus node
  final FocusNode? focusNode;

  /// Doğrulama fonksiyonu
  final String? Function(String?)? validator;

  /// Değer değiştiğinde callback
  final ValueChanged<String>? onChanged;

  /// Submit edildiğinde callback
  final ValueChanged<String>? onSubmitted;

  /// Şifre alanı mı?
  final bool obscureText;

  /// Klavye tipi
  final TextInputType? keyboardType;

  /// Input action
  final TextInputAction? textInputAction;

  /// Maksimum satır sayısı
  final int maxLines;

  /// Minimum satır sayısı
  final int? minLines;

  /// Maksimum karakter sayısı
  final int? maxLength;

  /// Sol ikon
  final IconData? prefixIcon;

  /// Sol widget (prefixIcon yerine custom widget kullanmak için)
  final Widget? prefixWidget;

  /// Sağ ikon
  final IconData? suffixIcon;

  /// Sağ widget (suffixIcon yerine custom widget kullanmak için)
  final Widget? suffixWidget;

  /// Sağ ikon tıklama callback'i
  final VoidCallback? onSuffixIconPressed;

  /// Aktif mi?
  final bool enabled;

  /// Sadece okunabilir mi?
  final bool readOnly;

  /// Auto correct
  final bool autocorrect;

  /// Input formatters
  final List<TextInputFormatter>? inputFormatters;

  /// Auto focus
  final bool autofocus;

  /// Karakter sayacı göster
  final bool showCounter;

  /// Text capitalization
  final TextCapitalization textCapitalization;

  const AppTextField({
    super.key,
    this.label,
    this.placeholder,
    this.helperText,
    this.controller,
    this.focusNode,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.prefixIcon,
    this.prefixWidget,
    this.suffixIcon,
    this.suffixWidget,
    this.onSuffixIconPressed,
    this.enabled = true,
    this.readOnly = false,
    this.autocorrect = true,
    this.inputFormatters,
    this.autofocus = false,
    this.showCounter = false,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscureText;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTypography.subhead.copyWith(
              color: AppColors.textSecondary(brightness),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],

        // Text Field
        Focus(
          onFocusChange: (hasFocus) {
            setState(() => _isFocused = hasFocus);
          },
          child: TextFormField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            validator: widget.validator,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onSubmitted,
            obscureText: _obscureText,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            textCapitalization: widget.textCapitalization,
            maxLines: widget.obscureText ? 1 : widget.maxLines,
            minLines: widget.minLines,
            maxLength: widget.maxLength,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            autocorrect: widget.autocorrect,
            inputFormatters: widget.inputFormatters,
            autofocus: widget.autofocus,
            style: AppTypography.body.copyWith(
              color: widget.enabled
                  ? AppColors.textPrimary(brightness)
                  : AppColors.textSecondary(brightness),
            ),
            decoration: InputDecoration(
              hintText: widget.placeholder,
              hintStyle: AppTypography.body.copyWith(
                color: AppColors.textTertiaryLight,
              ),
              filled: true,
              fillColor: _getFillColor(brightness),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 4,
              ),
              border: _buildBorder(brightness, false, false),
              enabledBorder: _buildBorder(brightness, false, false),
              focusedBorder: _buildBorder(brightness, true, false),
              errorBorder: _buildBorder(brightness, false, true),
              focusedErrorBorder: _buildBorder(brightness, true, true),
              disabledBorder: _buildBorder(brightness, false, false),
              prefixIcon: widget.prefixWidget ??
                  (widget.prefixIcon != null
                      ? Icon(
                          widget.prefixIcon,
                          color: _isFocused
                              ? AppColors.primary
                              : AppColors.textSecondary(brightness),
                          size: 20,
                        )
                      : null),
              suffixIcon: _buildSuffixIcon(brightness),
              counterText: widget.showCounter ? null : '',
              errorStyle: AppTypography.caption1.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ),

        // Helper Text
        if (widget.helperText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.helperText!,
            style: AppTypography.caption1.copyWith(
              color: AppColors.textSecondary(brightness),
            ),
          ),
        ],
      ],
    );
  }

  Color _getFillColor(Brightness brightness) {
    if (!widget.enabled) {
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

  Widget? _buildSuffixIcon(Brightness brightness) {
    // Password toggle
    if (widget.obscureText) {
      return IconButton(
        icon: Icon(
          _obscureText ? Icons.visibility_off : Icons.visibility,
          color: AppColors.textSecondary(brightness),
          size: 20,
        ),
        onPressed: () {
          setState(() => _obscureText = !_obscureText);
        },
      );
    }

    // Custom suffix widget
    if (widget.suffixWidget != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: widget.suffixWidget,
      );
    }

    // Custom suffix icon
    if (widget.suffixIcon != null) {
      return IconButton(
        icon: Icon(
          widget.suffixIcon,
          color: _isFocused
              ? AppColors.primary
              : AppColors.textSecondary(brightness),
          size: 20,
        ),
        onPressed: widget.onSuffixIconPressed,
      );
    }

    return null;
  }
}

/// Email için özel text field
class AppEmailField extends StatelessWidget {
  final String? label;
  final String? placeholder;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  const AppEmailField({
    super.key,
    this.label = 'Email',
    this.placeholder = 'email@example.com',
    this.controller,
    this.validator,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: label,
      placeholder: placeholder,
      controller: controller,
      validator: validator,
      onChanged: onChanged,
      enabled: enabled,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      prefixIcon: Icons.email_outlined,
    );
  }
}

/// Password için özel text field
class AppPasswordField extends StatelessWidget {
  final String? label;
  final String? placeholder;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final TextInputAction? textInputAction;

  const AppPasswordField({
    super.key,
    this.label = 'Password',
    this.placeholder = 'Enter your password',
    this.controller,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: label,
      placeholder: placeholder,
      controller: controller,
      validator: validator,
      onChanged: onChanged,
      enabled: enabled,
      obscureText: true,
      textInputAction: textInputAction ?? TextInputAction.done,
      autocorrect: false,
      prefixIcon: Icons.lock_outline,
    );
  }
}

/// Search için özel text field
class AppSearchField extends StatelessWidget {
  final String? placeholder;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool enabled;
  final bool autofocus;

  const AppSearchField({
    super.key,
    this.placeholder = 'Search...',
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.enabled = true,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      placeholder: placeholder,
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.search,
      prefixIcon: Icons.search,
      suffixIcon: controller?.text.isNotEmpty == true ? Icons.clear : null,
      onSuffixIconPressed: () {
        controller?.clear();
        onClear?.call();
        onChanged?.call('');
      },
    );
  }
}
