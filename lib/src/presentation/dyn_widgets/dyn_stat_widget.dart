import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'dyn_widget_helpers.dart';

/// Stat widget görüntüleme modları.
enum DynStatMode {
  /// Büyük değer + isteğe bağlı trend oku.
  statCard,

  /// value/progressMax oranını gösteren ilerleme çubuğu.
  progress,

  /// Basit gauge (dairesel gösterge).
  gauge,
}

/// Tek-değer istatistik widget'ı (stat_card / progress / gauge).
///
/// Değer = `rows.first[valueField ?? ilkSayısalAnahtar]`. Etiket `labelField`;
/// `prefix`/`suffix`/`decimals` visualConfig'ten; trend `trendField`
/// (yeşil ↑ / kırmızı ↓). Boş satır → soluk "veri yok".
class DynStatWidget extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> visualConfig;
  final DynStatMode mode;

  const DynStatWidget(
    this.rows,
    this.visualConfig, {
    super.key,
    this.mode = DynStatMode.statCard,
  });

  /// String mod adından ('stat_card'|'progress'|'gauge') enum çözer.
  static DynStatMode modeFromString(String? value) {
    switch (value) {
      case 'progress':
        return DynStatMode.progress;
      case 'gauge':
        return DynStatMode.gauge;
      case 'stat_card':
      default:
        return DynStatMode.statCard;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textSecondary = AppColors.textSecondary(brightness);

    if (rows.isEmpty) {
      return _emptyState(textSecondary);
    }

    final row = rows.first;
    final valueField =
        DynWidgetHelpers.readString(visualConfig, 'valueField') ??
            DynWidgetHelpers.firstNumericKey(row);
    final rawValue = valueField != null ? row[valueField] : null;
    final numValue = DynWidgetHelpers.toNum(rawValue);

    final labelField = DynWidgetHelpers.readString(visualConfig, 'labelField');
    final label = labelField != null
        ? row[labelField]?.toString()
        : DynWidgetHelpers.readString(visualConfig, 'label');

    final prefix = DynWidgetHelpers.readString(visualConfig, 'prefix');
    final suffix = DynWidgetHelpers.readString(visualConfig, 'suffix');
    final decimals = DynWidgetHelpers.readInt(visualConfig, 'decimals');

    final valueText = numValue != null
        ? DynWidgetHelpers.formatNumber(
            numValue,
            decimals: decimals,
            prefix: prefix,
            suffix: suffix,
          )
        : (rawValue?.toString() ?? '—');

    switch (mode) {
      case DynStatMode.progress:
        return _buildProgress(context, numValue, valueText, label);
      case DynStatMode.gauge:
        return _buildGauge(context, numValue, valueText, label);
      case DynStatMode.statCard:
        return _buildStatCard(context, row, valueText, label);
    }
  }

  Widget _buildStatCard(
    BuildContext context,
    Map<String, dynamic> row,
    String valueText,
    String? label,
  ) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = AppColors.textPrimary(brightness);
    final textSecondary = AppColors.textSecondary(brightness);

    final trendField =
        DynWidgetHelpers.readString(visualConfig, 'trendField');
    final trend =
        trendField != null ? DynWidgetHelpers.toNum(row[trendField]) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          valueText,
          style: AppTypography.withColor(AppTypography.largeTitle, textPrimary),
        ),
        if (label != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style:
                AppTypography.withColor(AppTypography.subhead, textSecondary),
          ),
        ],
        if (trend != null && trend != 0) ...[
          const SizedBox(height: AppSpacing.sm),
          _buildTrend(trend),
        ],
      ],
    );
  }

  Widget _buildTrend(num trend) {
    final up = trend > 0;
    final color = up ? AppColors.success : AppColors.error;
    final icon = up ? Icons.arrow_upward : Icons.arrow_downward;
    final text = DynWidgetHelpers.formatNumber(trend.abs(), suffix: '%');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: AppSpacing.iconSizeSm),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          text,
          style: AppTypography.withColor(AppTypography.footnote, color),
        ),
      ],
    );
  }

  Widget _buildProgress(
    BuildContext context,
    num? numValue,
    String valueText,
    String? label,
  ) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = AppColors.textPrimary(brightness);
    final textSecondary = AppColors.textSecondary(brightness);

    final max = DynWidgetHelpers.readNum(visualConfig, 'progressMax') ?? 100;
    final value = numValue ?? 0;
    final fraction =
        max > 0 ? (value / max).clamp(0.0, 1.0).toDouble() : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label ?? '',
              style:
                  AppTypography.withColor(AppTypography.subhead, textSecondary),
            ),
            Text(
              valueText,
              style: AppTypography.withColor(
                AppTypography.headline,
                textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: AppColors.border(brightness),
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildGauge(
    BuildContext context,
    num? numValue,
    String valueText,
    String? label,
  ) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = AppColors.textPrimary(brightness);
    final textSecondary = AppColors.textSecondary(brightness);

    final max = DynWidgetHelpers.readNum(visualConfig, 'progressMax') ?? 100;
    final value = numValue ?? 0;
    final fraction =
        max > 0 ? (value / max).clamp(0.0, 1.0).toDouble() : 0.0;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: CircularProgressIndicator(
                    value: fraction,
                    strokeWidth: 8,
                    backgroundColor: AppColors.border(brightness),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                Text(
                  valueText,
                  style: AppTypography.withColor(
                    AppTypography.headline,
                    textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style:
                  AppTypography.withColor(AppTypography.footnote, textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyState(Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: Text(
          'veri yok',
          style: AppTypography.withColor(AppTypography.footnote, textSecondary),
        ),
      ),
    );
  }
}
