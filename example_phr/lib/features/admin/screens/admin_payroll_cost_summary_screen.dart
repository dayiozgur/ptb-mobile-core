import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';

/// Admin "Maliyet Özeti" (salt-okuma, v1).
///
/// Sunucu-taraflı boyutsal RPC `fn_payroll_cost_rollup` ile bordro-maliyet
/// dökümü: toplam brüt / net / işveren maliyeti + kova başına kişi sayısı.
/// Boyut değiştirilebilir: aylık | departman. Aralık web ekranıyla aynı
/// (yılbaşı → bugün). Web `PayrollCostSummaryComponent` aynası.
class AdminPayrollCostSummaryScreen extends StatefulWidget {
  const AdminPayrollCostSummaryScreen({super.key});

  @override
  State<AdminPayrollCostSummaryScreen> createState() =>
      _AdminPayrollCostSummaryScreenState();
}

class _AdminPayrollCostSummaryScreenState
    extends State<AdminPayrollCostSummaryScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  // 0 = aylık, 1 = departman.
  int _dimIndex = 0;
  PayrollCostSummary? _summary;

  String get _dimension => _dimIndex == 0 ? 'month' : 'department';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final summary =
          await adminPayrollService.costSummary(dimension: _dimension);
      if (mounted) {
        setState(() {
          _summary = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('AdminPayrollCostSummaryScreen yükleme hatası', e);
      if (mounted) {
        setState(() {
          _errorMessage = essT('common.data_load_error', 'Veriler yüklenemedi');
          _isLoading = false;
        });
      }
    }
  }

  void _onDimChanged(int i) {
    if (_dimIndex == i) return;
    setState(() => _dimIndex = i);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('payroll.cost.title', 'Maliyet Özeti'),
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _load),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: AppSegmentedControl(
              segments: [
                essT('payroll.cost.by_month', 'Aylık'),
                essT('payroll.cost.by_department', 'Departman'),
              ],
              selectedIndex: _dimIndex,
              onSegmentChanged: _onDimChanged,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: AppLoadingIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: AppErrorView(message: _errorMessage!, onRetry: _load),
      );
    }
    final summary = _summary;
    final rows = summary?.rows ?? const <PayrollCostRow>[];

    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        if (summary != null) ...[
          _RangeLabel(summary: summary),
          const SizedBox(height: AppSpacing.sm),
          _TotalsGrid(summary: summary),
          const SizedBox(height: AppSpacing.md),
        ],
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxl),
            child: Center(
              child: AppEmptyState(
                icon: Icons.query_stats_outlined,
                title: essT('payroll.cost.empty', 'Bu aralıkta veri yok'),
              ),
            ),
          )
        else
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _CostRowCard(row: r, dimension: _dimension),
              )),
      ],
    );
  }
}

class _RangeLabel extends StatelessWidget {
  final PayrollCostSummary summary;

  const _RangeLabel({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Text(
      '${summary.fromDate} → ${summary.toDate}',
      style: AppTypography.caption1
          .copyWith(color: AppColors.tertiaryLabel(context)),
    );
  }
}

class _TotalsGrid extends StatelessWidget {
  final PayrollCostSummary summary;

  const _TotalsGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _TotalTile(
                label: essT('payroll.cost.total_gross', 'Toplam brüt'),
                value: essMoney(summary.totalGross),
                color: AppColors.tertiaryLabel(context),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _TotalTile(
                label: essT('payroll.cost.total_net', 'Toplam net'),
                value: essMoney(summary.totalNet),
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _TotalTile(
                label: essT('payroll.cost.total_employer_cost',
                    'İşveren maliyeti'),
                value: essMoney(summary.totalEmployerCost),
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _TotalTile(
                label: essT('payroll.cost.headcount', 'Kişi'),
                value: '${summary.headcount}',
                color: AppColors.tertiaryLabel(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TotalTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TotalTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.caption2
                  .copyWith(color: AppColors.secondaryLabel(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: AppTypography.title3.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _CostRowCard extends StatelessWidget {
  final PayrollCostRow row;
  final String dimension;

  const _CostRowCard({required this.row, required this.dimension});

  /// Kova başlığı: aylık boyutta 'YYYY-MM' → 'Ay Yıl'; departmanda etiket
  /// (yoksa "Atanmamış").
  String _bucketTitle() {
    if (dimension == 'month') {
      final parts = row.key.split('-');
      if (parts.length >= 2) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (y != null && m != null) return essMonthYear(y, m);
      }
      return row.key;
    }
    final label = (row.label ?? '').trim();
    if (label.isNotEmpty) return label;
    return essT('payroll.cost.unassigned', 'Atanmamış');
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _bucketTitle(),
                    style: AppTypography.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppBadge(
                  label: '${row.headcount} '
                      '${essT('payroll.cost.headcount', 'Kişi')}',
                  variant: AppBadgeVariant.neutral,
                  size: AppBadgeSize.small,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _amountRow(
              context,
              essT('payroll.cost.total_gross', 'Toplam brüt'),
              essMoney(row.totalGross),
              AppColors.tertiaryLabel(context),
            ),
            _amountRow(
              context,
              essT('payroll.cost.total_net', 'Toplam net'),
              essMoney(row.totalNet),
              AppColors.success,
            ),
            _amountRow(
              context,
              essT('payroll.cost.total_employer_cost', 'İşveren maliyeti'),
              essMoney(row.totalEmployerCost),
              AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountRow(
      BuildContext context, String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.caption1
                  .copyWith(color: AppColors.secondaryLabel(context)),
            ),
          ),
          Text(
            value,
            style: AppTypography.subhead.copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }
}
