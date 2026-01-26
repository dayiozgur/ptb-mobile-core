import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Snackbar varyantları
enum AppSnackbarVariant {
  /// Default - Nötr
  info,

  /// Success - Yeşil
  success,

  /// Warning - Turuncu
  warning,

  /// Error - Kırmızı
  error,
}

/// Protoolbag Snackbar Helper
///
/// Bildirim mesajları göstermek için kullanılır.
///
/// Örnek kullanım:
/// ```dart
/// AppSnackbar.show(
///   context,
///   message: 'Changes saved successfully',
///   variant: AppSnackbarVariant.success,
/// );
/// ```
class AppSnackbar {
  AppSnackbar._();

  /// Snackbar göster
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
    BuildContext context, {
    required String message,
    AppSnackbarVariant variant = AppSnackbarVariant.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
    bool showCloseIcon = false,
    VoidCallback? onClosed,
  }) {
    final snackBar = SnackBar(
      content: _SnackbarContent(
        message: message,
        variant: variant,
      ),
      backgroundColor: _getBackgroundColor(variant),
      duration: duration,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      action: actionLabel != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: Colors.white,
              onPressed: onAction ?? () {},
            )
          : null,
      showCloseIcon: showCloseIcon,
      closeIconColor: Colors.white.withOpacity(0.7),
    );

    return ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Success snackbar
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> success(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return show(
      context,
      message: message,
      variant: AppSnackbarVariant.success,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Error snackbar
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> error(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return show(
      context,
      message: message,
      variant: AppSnackbarVariant.error,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Warning snackbar
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> warning(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return show(
      context,
      message: message,
      variant: AppSnackbarVariant.warning,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Info snackbar
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> info(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return show(
      context,
      message: message,
      variant: AppSnackbarVariant.info,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Tüm snackbar'ları kapat
  static void hideAll(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  /// Mevcut snackbar'ı kapat
  static void hide(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  static Color _getBackgroundColor(AppSnackbarVariant variant) {
    switch (variant) {
      case AppSnackbarVariant.success:
        return AppColors.success;
      case AppSnackbarVariant.warning:
        return AppColors.warning;
      case AppSnackbarVariant.error:
        return AppColors.error;
      case AppSnackbarVariant.info:
        return const Color(0xFF323232);
    }
  }
}

class _SnackbarContent extends StatelessWidget {
  final String message;
  final AppSnackbarVariant variant;

  const _SnackbarContent({
    required this.message,
    required this.variant,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          _getIcon(),
          color: Colors.white,
          size: 20,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: AppTypography.subhead.copyWith(
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  IconData _getIcon() {
    switch (variant) {
      case AppSnackbarVariant.success:
        return Icons.check_circle;
      case AppSnackbarVariant.warning:
        return Icons.warning_amber;
      case AppSnackbarVariant.error:
        return Icons.error;
      case AppSnackbarVariant.info:
        return Icons.info_outline;
    }
  }
}

/// Toast benzeri kısa mesajlar için
class AppToast {
  AppToast._();

  /// Kısa toast göster
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        onDismiss: () => entry.remove(),
        duration: duration,
      ),
    );

    overlay.insert(entry);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;
  final Duration duration;

  const _ToastWidget({
    required this.message,
    required this.onDismiss,
    required this.duration,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 100,
      left: 0,
      right: 0,
      child: Center(
        child: FadeTransition(
          opacity: _animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.5),
              end: Offset.zero,
            ).animate(_animation),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: brightness == Brightness.light
                    ? AppColors.textPrimaryLight.withOpacity(0.9)
                    : AppColors.surfaceElevatedDark,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                widget.message,
                style: AppTypography.subhead.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
