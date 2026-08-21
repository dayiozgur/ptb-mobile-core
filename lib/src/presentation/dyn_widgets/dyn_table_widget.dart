import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'dyn_widget_helpers.dart';

/// Dinamik veri tablosu widget'ı.
///
/// Kolonlar `visualConfig.columns` ya da satır anahtarlarından türetilir.
/// Değer tipine göre sayı/tarih biçimlendirir (tr_TR). İstemci-taraflı;
/// MVP için ~200 satırda gösterimi keser ve "+N kayıt daha" notu ekler.
/// Boş → soluk durum.
class DynDataTableWidget extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> visualConfig;

  /// Gösterilecek maksimum satır sayısı (MVP kapağı).
  static const int maxDisplayRows = 200;

  const DynDataTableWidget(
    this.rows,
    this.visualConfig, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = AppColors.textPrimary(brightness);
    final textSecondary = AppColors.textSecondary(brightness);

    if (rows.isEmpty) {
      return _emptyState(textSecondary);
    }

    final columns = _resolveColumns();
    final striped = visualConfig['striped'] != false; // varsayılan: true

    final displayRows =
        rows.length > maxDisplayRows ? rows.sublist(0, maxDisplayRows) : rows;
    final overflow = rows.length - displayRows.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 40,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 48,
            columnSpacing: AppSpacing.lg,
            headingTextStyle: AppTypography.withColor(
              AppTypography.caption1,
              textSecondary,
            ),
            dataTextStyle: AppTypography.withColor(
              AppTypography.footnote,
              textPrimary,
            ),
            columns: columns
                .map((c) => DataColumn(label: Text(_headerLabel(c))))
                .toList(),
            rows: List<DataRow>.generate(displayRows.length, (index) {
              final row = displayRows[index];
              return DataRow(
                // Satıra dokun → tam alan/değer listesini bottom-sheet'te göster.
                onSelectChanged: (_) => _showRowDetail(context, row),
                color: striped && index.isOdd
                    ? WidgetStateProperty.all(
                        AppColors.border(brightness).withValues(alpha: 0.15),
                      )
                    : null,
                cells: columns
                    .map((c) => DataCell(
                          Text(DynWidgetHelpers.formatCell(row[c])),
                        ))
                    .toList(),
              );
            }),
          ),
        ),
        if (overflow > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            '+$overflow kayıt daha',
            style: AppTypography.withColor(
              AppTypography.caption1,
              textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  List<String> _resolveColumns() {
    final configured =
        DynWidgetHelpers.readStringList(visualConfig, 'columns');
    if (configured.isNotEmpty) return configured;

    // Satır anahtarlarının birleşimi (ilk satır sırasını korur).
    final keys = <String>[];
    for (final row in rows) {
      for (final k in row.keys) {
        if (!keys.contains(k)) keys.add(k);
      }
    }
    return keys;
  }

  String _headerLabel(String column) {
    // visualConfig.columnLabels[column] varsa kullan, yoksa anahtarı.
    final labels = visualConfig['columnLabels'];
    if (labels is Map && labels[column] != null) {
      return labels[column].toString();
    }
    return column;
  }

  /// Satır detayını salt-okuma bir bottom-sheet'te (tüm alanlar) gösterir.
  void _showRowDetail(BuildContext context, Map<String, dynamic> row) {
    final brightness = Theme.of(context).brightness;
    // Tam alan listesi: satırın kendi anahtarları (kolon kısıtından bağımsız).
    final keys = row.keys.toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final b = Theme.of(ctx).brightness;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'Detay',
                    style: AppTypography.withColor(
                      AppTypography.headline,
                      AppColors.textPrimary(b),
                    ),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children:
                          keys.map((k) => _detailRow(b, k, row[k])).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(Brightness brightness, String key, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              _headerLabel(key),
              style: AppTypography.withColor(
                AppTypography.caption1,
                AppColors.textSecondary(brightness),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              DynWidgetHelpers.formatCell(value),
              style: AppTypography.withColor(
                AppTypography.footnote,
                AppColors.textPrimary(brightness),
              ),
            ),
          ),
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
