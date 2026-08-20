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
