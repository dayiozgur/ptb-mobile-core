import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Protoolbag Progress Bar Widget
///
/// İlerleme gösterimi için progress bar komponenti.
///
/// Örnek kullanım:
/// ```dart
/// AppProgressBar(
///   value: 0.75,
///   label: 'Upload Progress',
///   showPercentage: true,
/// )
/// ```
class AppProgressBar extends StatelessWidget {
  /// İlerleme değeri (0.0 - 1.0)
  final double value;

  /// Etiket
  final String? label;

  /// Yüzde göster
  final bool showPercentage;

  /// Renk
  final Color? color;

  /// Arka plan rengi
  final Color? backgroundColor;

  /// Yükseklik
  final double height;

  /// Köşe yarıçapı
  final double? borderRadius;

  /// Animasyonlu
  final bool animated;

  const AppProgressBar({
    super.key,
    required this.value,
    this.label,
    this.showPercentage = false,
    this.color,
    this.backgroundColor,
    this.height = 4,
    this.borderRadius,
    this.animated = true,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final progressColor = color ?? AppColors.primary;
    final trackColor = backgroundColor ?? AppColors.systemGray5;
    final radius = borderRadius ?? (height / 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label and percentage
        if (label != null || showPercentage)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (label != null)
                  Text(
                    label!,
                    style: AppTypography.subhead.copyWith(
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                if (showPercentage)
                  Text(
                    '${(value * 100).toInt()}%',
                    style: AppTypography.subhead.copyWith(
                      color: AppColors.textSecondary(brightness),
                    ),
                  ),
              ],
            ),
          ),

        // Progress bar
        Container(
          height: height,
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  AnimatedContainer(
                    duration: animated
                        ? const Duration(milliseconds: 300)
                        : Duration.zero,
                    curve: Curves.easeInOut,
                    width: constraints.maxWidth * value.clamp(0.0, 1.0),
                    height: height,
                    decoration: BoxDecoration(
                      color: progressColor,
                      borderRadius: BorderRadius.circular(radius),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Circular progress indicator
class AppCircularProgress extends StatelessWidget {
  /// İlerleme değeri (0.0 - 1.0)
  final double value;

  /// Boyut
  final double size;

  /// Çizgi kalınlığı
  final double strokeWidth;

  /// Renk
  final Color? color;

  /// Arka plan rengi
  final Color? backgroundColor;

  /// Merkez widget'ı
  final Widget? center;

  /// Yüzde göster
  final bool showPercentage;

  const AppCircularProgress({
    super.key,
    required this.value,
    this.size = 64,
    this.strokeWidth = 4,
    this.color,
    this.backgroundColor,
    this.center,
    this.showPercentage = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final progressColor = color ?? AppColors.primary;
    final trackColor = backgroundColor ?? AppColors.systemGray5;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background circle
          CircularProgressIndicator(
            value: 1,
            strokeWidth: strokeWidth,
            valueColor: AlwaysStoppedAnimation<Color>(trackColor),
            backgroundColor: Colors.transparent,
          ),

          // Progress
          CircularProgressIndicator(
            value: value.clamp(0.0, 1.0),
            strokeWidth: strokeWidth,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            backgroundColor: Colors.transparent,
            strokeCap: StrokeCap.round,
          ),

          // Center content
          if (center != null || showPercentage)
            Center(
              child: center ??
                  Text(
                    '${(value * 100).toInt()}%',
                    style: AppTypography.headline.copyWith(
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
            ),
        ],
      ),
    );
  }
}

/// Multi-segment progress bar
class AppSegmentedProgress extends StatelessWidget {
  /// Segment değerleri (toplam 1.0 olmalı)
  final List<AppProgressSegment> segments;

  /// Yükseklik
  final double height;

  /// Köşe yarıçapı
  final double? borderRadius;

  /// Segment arası boşluk
  final double spacing;

  const AppSegmentedProgress({
    super.key,
    required this.segments,
    this.height = 8,
    this.borderRadius,
    this.spacing = 2,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? (height / 2);

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Row(
          children: [
            for (int i = 0; i < segments.length; i++) ...[
              Expanded(
                flex: (segments[i].value * 100).toInt(),
                child: Container(
                  color: segments[i].color,
                ),
              ),
              if (i < segments.length - 1 && spacing > 0)
                SizedBox(width: spacing),
            ],
          ],
        ),
      ),
    );
  }
}

/// Progress segment
class AppProgressSegment {
  final double value;
  final Color color;
  final String? label;

  const AppProgressSegment({
    required this.value,
    required this.color,
    this.label,
  });
}

/// Step progress (adım göstergesi)
class AppStepProgress extends StatelessWidget {
  /// Toplam adım sayısı
  final int totalSteps;

  /// Mevcut adım (1'den başlar)
  final int currentStep;

  /// Adım isimleri
  final List<String>? stepLabels;

  /// Renk
  final Color? activeColor;

  /// Pasif renk
  final Color? inactiveColor;

  const AppStepProgress({
    super.key,
    required this.totalSteps,
    required this.currentStep,
    this.stepLabels,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final active = activeColor ?? AppColors.primary;
    final inactive = inactiveColor ?? AppColors.systemGray4;

    return Column(
      children: [
        // Steps
        Row(
          children: [
            for (int i = 1; i <= totalSteps; i++) ...[
              // Step circle
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= currentStep ? active : inactive,
                ),
                child: Center(
                  child: i < currentStep
                      ? const Icon(
                          Icons.check,
                          size: 14,
                          color: Colors.white,
                        )
                      : Text(
                          '$i',
                          style: AppTypography.caption2.copyWith(
                            color: i <= currentStep
                                ? Colors.white
                                : AppColors.textSecondary(brightness),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              // Connector line
              if (i < totalSteps)
                Expanded(
                  child: Container(
                    height: 2,
                    color: i < currentStep ? active : inactive,
                  ),
                ),
            ],
          ],
        ),

        // Labels
        if (stepLabels != null && stepLabels!.length == totalSteps) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (int i = 0; i < stepLabels!.length; i++)
                Expanded(
                  child: Text(
                    stepLabels![i],
                    style: AppTypography.caption1.copyWith(
                      color: i < currentStep
                          ? active
                          : AppColors.textSecondary(brightness),
                    ),
                    textAlign: i == 0
                        ? TextAlign.left
                        : i == stepLabels!.length - 1
                            ? TextAlign.right
                            : TextAlign.center,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
