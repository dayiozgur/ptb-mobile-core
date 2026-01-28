import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Chart container wrapper widget
///
/// Tüm chart widget'ları için tutarlı bir kapsayıcı sağlar.
/// AppCard tabanlı, başlık/alt başlık/trailing aksiyonlu.
class ChartContainer extends StatelessWidget {
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

  const ChartContainer({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.minHeight = 200,
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
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: padding ??
                  const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
              child: _buildContent(context, brightness),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, Brightness brightness) {
    if (isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: CircularProgressIndicator.adaptive(
            valueColor: AlwaysStoppedAnimation<Color>(
              AppColors.primary,
            ),
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
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
      );
    }

    if (isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bar_chart_rounded,
                size: 32,
                color: AppColors.systemGray3,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                emptyMessage ?? 'Veri bulunamadı',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary(brightness),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return child;
  }
}

/// Dönem seçici segment kontrol
///
/// Chart'larda 7g/30g/90g dönem seçimi için kullanılır.
class ChartPeriodSelector extends StatelessWidget {
  final int selectedDays;
  final ValueChanged<int> onChanged;
  final List<int> options;

  const ChartPeriodSelector({
    super.key,
    required this.selectedDays,
    required this.onChanged,
    this.options = const [7, 30, 90],
  });

  String _label(int days) {
    if (days == 1) return '24s';
    return '${days}g';
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      decoration: BoxDecoration(
        color: brightness == Brightness.light
            ? AppColors.systemGray6
            : AppColors.surfaceElevatedDark,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((days) {
          final isSelected = days == selectedDays;
          return GestureDetector(
            onTap: () => onChanged(days),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.surface(brightness)
                    : Colors.transparent,
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusSm - 2),
                boxShadow: isSelected && brightness == Brightness.light
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                _label(days),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary(brightness),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
