import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Metric trend yönü
enum MetricTrend {
  /// Yukarı (pozitif)
  up,

  /// Aşağı (negatif)
  down,

  /// Nötr
  neutral,
}

/// Protoolbag Metric Card Widget
///
/// Dashboard ve istatistik gösterimi için metrik kartı.
///
/// Örnek kullanım:
/// ```dart
/// MetricCard(
///   title: 'Total Revenue',
///   value: '\$12,450',
///   trend: MetricTrend.up,
///   trendValue: '+12%',
///   icon: Icons.attach_money,
/// )
/// ```
class MetricCard extends StatelessWidget {
  /// Başlık
  final String title;

  /// Değer
  final String value;

  /// Alt başlık/açıklama
  final String? subtitle;

  /// İkon
  final IconData? icon;

  /// Ana renk (ikon ve arka plan için kullanılır)
  final Color? color;

  /// İkon rengi (color'dan bağımsız özelleştirme için)
  final Color? iconColor;

  /// İkon arka plan rengi (color'dan bağımsız özelleştirme için)
  final Color? iconBackgroundColor;

  /// Trend yönü
  final MetricTrend? trend;

  /// Trend değeri (örn: +12%)
  final String? trendValue;

  /// Tıklama callback'i
  final VoidCallback? onTap;

  /// Genişlik
  final double? width;

  /// Dış margin
  final EdgeInsetsGeometry? margin;

  /// Kompakt mod
  final bool compact;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.color,
    this.iconColor,
    this.iconBackgroundColor,
    this.trend,
    this.trendValue,
    this.onTap,
    this.width,
    this.margin,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      width: width,
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: AppShadows.card(brightness),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Padding(
            padding: compact ? AppSpacing.allSm : AppSpacing.cardInsets,
            child: compact ? _buildCompactContent(brightness) : _buildContent(brightness),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Brightness brightness) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header (icon + title)
        Row(
          children: [
            if (icon != null) ...[
              _buildIcon(brightness),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Text(
                title,
                style: AppTypography.subhead.copyWith(
                  color: AppColors.textSecondary(brightness),
                ),
              ),
            ),
            if (trend != null && trendValue != null) _buildTrend(brightness),
          ],
        ),

        const SizedBox(height: AppSpacing.sm),

        // Value
        Text(
          value,
          style: AppTypography.title1.copyWith(
            color: AppColors.textPrimary(brightness),
          ),
        ),

        // Subtitle
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle!,
            style: AppTypography.caption1.copyWith(
              color: AppColors.textSecondary(brightness),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompactContent(Brightness brightness) {
    return Row(
      children: [
        if (icon != null) ...[
          _buildIcon(brightness, small: true),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppTypography.caption1.copyWith(
                  color: AppColors.textSecondary(brightness),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTypography.headline.copyWith(
                  color: AppColors.textPrimary(brightness),
                ),
              ),
            ],
          ),
        ),
        if (trend != null && trendValue != null) _buildTrend(brightness),
      ],
    );
  }

  Widget _buildIcon(Brightness brightness, {bool small = false}) {
    final accentColor = iconColor ?? color ?? AppColors.primary;
    final bgColor = iconBackgroundColor ?? accentColor.withValues(alpha: 0.1);
    final fgColor = accentColor;
    final size = small ? 32.0 : 40.0;
    final iconSize = small ? 16.0 : 20.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: fgColor,
      ),
    );
  }

  Widget _buildTrend(Brightness brightness) {
    final color = _getTrendColor();
    final iconData = _getTrendIcon();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconData,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            trendValue!,
            style: AppTypography.caption2.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getTrendColor() {
    switch (trend) {
      case MetricTrend.up:
        return AppColors.success;
      case MetricTrend.down:
        return AppColors.error;
      case MetricTrend.neutral:
      case null:
        return AppColors.systemGray;
    }
  }

  IconData _getTrendIcon() {
    switch (trend) {
      case MetricTrend.up:
        return Icons.trending_up;
      case MetricTrend.down:
        return Icons.trending_down;
      case MetricTrend.neutral:
      case null:
        return Icons.trending_flat;
    }
  }
}

/// Metric card grid
class MetricCardGrid extends StatelessWidget {
  /// Metric kartları
  final List<MetricCard> cards;

  /// Sütun sayısı
  final int crossAxisCount;

  /// Yatay boşluk
  final double mainAxisSpacing;

  /// Dikey boşluk
  final double crossAxisSpacing;

  /// Child aspect ratio
  final double childAspectRatio;

  const MetricCardGrid({
    super.key,
    required this.cards,
    this.crossAxisCount = 2,
    this.mainAxisSpacing = AppSpacing.md,
    this.crossAxisSpacing = AppSpacing.md,
    this.childAspectRatio = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      childAspectRatio: childAspectRatio,
      children: cards,
    );
  }
}

/// Horizontal scrollable metric cards
class MetricCardRow extends StatelessWidget {
  /// Metric kartları
  final List<MetricCard> cards;

  /// Kart genişliği
  final double cardWidth;

  /// Kartlar arası boşluk
  final double spacing;

  /// Padding
  final EdgeInsetsGeometry? padding;

  const MetricCardRow({
    super.key,
    required this.cards,
    this.cardWidth = 160,
    this.spacing = AppSpacing.md,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            SizedBox(
              width: cardWidth,
              child: cards[i],
            ),
            if (i < cards.length - 1) SizedBox(width: spacing),
          ],
        ],
      ),
    );
  }
}
