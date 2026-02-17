import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Map container wrapper widget
///
/// ChartContainer pattern'ini takip eder.
/// Başlık, alt başlık, trailing aksiyonlu kapsayıcı.
/// Loading/error/empty state yönetimi sağlar.
class MapContainer extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final double minHeight;
  final EdgeInsetsGeometry? padding;
  final bool isLoading;
  final String? errorMessage;
  final String? emptyMessage;
  final bool isEmpty;

  const MapContainer({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.minHeight = 300,
    this.padding,
    this.isLoading = false,
    this.errorMessage,
    this.emptyMessage,
    this.isEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: brightness == Brightness.light
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                        const SizedBox(height: AppSpacing.xxs),
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
                if (trailing != null) trailing!,
              ],
            ),
          ),

          // Content
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(AppSpacing.radiusMd),
              bottomRight: Radius.circular(AppSpacing.radiusMd),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Padding(
                padding: padding ?? EdgeInsets.zero,
                child: _buildContent(context, brightness),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, Brightness brightness) {
    if (isLoading) {
      return SizedBox(
        height: minHeight,
        child: Center(
          child: CircularProgressIndicator.adaptive(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return SizedBox(
        height: minHeight,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 32,
                  color: AppColors.error,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (isEmpty) {
      return SizedBox(
        height: minHeight,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.map_outlined,
                  size: 32,
                  color: AppColors.systemGray3,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  emptyMessage ?? 'Konum verisi bulunamadı',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return child;
  }
}
