import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Loading indicator boyutları
enum AppLoadingSize {
  /// Small - 16px
  small,

  /// Medium - 24px
  medium,

  /// Large - 40px
  large,
}

/// Protoolbag Loading Indicator Widget
///
/// Apple HIG uyumlu loading göstergesi.
///
/// Örnek kullanım:
/// ```dart
/// AppLoadingIndicator(
///   size: AppLoadingSize.medium,
///   message: 'Loading...',
/// )
/// ```
class AppLoadingIndicator extends StatelessWidget {
  /// Boyut
  final AppLoadingSize size;

  /// Renk
  final Color? color;

  /// Mesaj (opsiyonel)
  final String? message;

  /// Centered (tam ekran ortada)
  final bool centered;

  const AppLoadingIndicator({
    super.key,
    this.size = AppLoadingSize.medium,
    this.color,
    this.message,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    final indicator = _buildIndicator(context);

    if (centered) {
      return Center(child: indicator);
    }

    return indicator;
  }

  Widget _buildIndicator(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final indicatorColor = color ?? AppColors.primary;

    if (message != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _getSize(),
            height: _getSize(),
            child: CircularProgressIndicator(
              strokeWidth: _getStrokeWidth(),
              valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message!,
            style: AppTypography.subhead.copyWith(
              color: AppColors.textSecondary(brightness),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return SizedBox(
      width: _getSize(),
      height: _getSize(),
      child: CircularProgressIndicator(
        strokeWidth: _getStrokeWidth(),
        valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
      ),
    );
  }

  double _getSize() {
    switch (size) {
      case AppLoadingSize.small:
        return 16;
      case AppLoadingSize.medium:
        return 24;
      case AppLoadingSize.large:
        return 40;
    }
  }

  double _getStrokeWidth() {
    switch (size) {
      case AppLoadingSize.small:
        return 2;
      case AppLoadingSize.medium:
        return 2.5;
      case AppLoadingSize.large:
        return 3;
    }
  }
}

/// Full screen loading overlay
class AppLoadingOverlay extends StatelessWidget {
  /// Mesaj
  final String? message;

  /// Arka plan rengi
  final Color? backgroundColor;

  const AppLoadingOverlay({
    super.key,
    this.message,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface(Theme.of(context).brightness),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: AppLoadingIndicator(
            size: AppLoadingSize.large,
            message: message,
          ),
        ),
      ),
    );
  }

  /// Loading overlay göster
  static void show(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => PopScope(
        canPop: false,
        child: AppLoadingOverlay(
          message: message,
          backgroundColor: Colors.transparent,
        ),
      ),
    );
  }

  /// Loading overlay kapat
  static void hide(BuildContext context) {
    Navigator.of(context).pop();
  }
}

/// Shimmer loading effect için placeholder
class AppShimmerLoading extends StatefulWidget {
  /// Genişlik
  final double? width;

  /// Yükseklik
  final double height;

  /// Köşe yarıçapı
  final double borderRadius;

  const AppShimmerLoading({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 4,
  });

  @override
  State<AppShimmerLoading> createState() => _AppShimmerLoadingState();
}

class _AppShimmerLoadingState extends State<AppShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final baseColor = brightness == Brightness.light
        ? AppColors.systemGray5
        : AppColors.surfaceElevatedDark;
    final highlightColor = brightness == Brightness.light
        ? AppColors.systemGray6
        : AppColors.surfaceDark;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// List item shimmer
class AppListItemShimmer extends StatelessWidget {
  /// Avatar göster
  final bool showAvatar;

  /// Subtitle göster
  final bool showSubtitle;

  /// Trailing göster
  final bool showTrailing;

  const AppListItemShimmer({
    super.key,
    this.showAvatar = true,
    this.showSubtitle = true,
    this.showTrailing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.listItemPadding,
      child: Row(
        children: [
          if (showAvatar) ...[
            const AppShimmerLoading(
              width: 44,
              height: 44,
              borderRadius: 22,
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppShimmerLoading(width: 150, height: 16),
                if (showSubtitle) ...[
                  const SizedBox(height: AppSpacing.xs),
                  const AppShimmerLoading(width: 100, height: 12),
                ],
              ],
            ),
          ),
          if (showTrailing) ...[
            const SizedBox(width: AppSpacing.md),
            const AppShimmerLoading(width: 60, height: 16),
          ],
        ],
      ),
    );
  }
}
