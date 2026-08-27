import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';

/// Admin "Bordro Ek/Kesintileri" (salt-okuma, v1).
///
/// `payroll_adjustments` satırlarını (personel + tür + tutar + dönem + durum)
/// listeler. `addition` = ek (yeşil), `deduction` = kesinti (kırmızı).
/// Web `PayrollAdjustmentsComponent` okuma yolunun mobil aynası.
class AdminPayrollAdjustmentsScreen extends StatefulWidget {
  const AdminPayrollAdjustmentsScreen({super.key});

  @override
  State<AdminPayrollAdjustmentsScreen> createState() =>
      _AdminPayrollAdjustmentsScreenState();
}

class _AdminPayrollAdjustmentsScreenState
    extends State<AdminPayrollAdjustmentsScreen> {
  final _ctrl = AsyncViewController();
  final Set<String> _busy = {};

  /// Bekleyen bir ek/kesintiyi iptal et (web `cancelAdjustment` aynası). Onay
  /// diyaloğu → servis → başarıda liste yenile. Servis hata → `false` döndürür
  /// (fırlatmaz); kullanıcıya hata snackbar'ı gösterilir.
  Future<void> _cancel(PayrollAdjustment adj) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            Text(essT('payroll.adjustments.cancel_title', 'Ek/kesintiyi iptal et')),
        content: Text(essT('payroll.adjustments.cancel_confirm',
            'Bu bekleyen ek/kesintiyi iptal etmek istiyor musunuz?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(essT('common.cancel', 'Vazgeç')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(essT('common.confirm', 'Onayla')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy.add(adj.id));
    final ok = await adminPayrollAdjustmentService.cancelAdjustment(adj.id);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              essT('payroll.adjustments.cancelled_ok', 'Ek/kesinti iptal edildi')),
          backgroundColor: AppColors.success,
        ),
      );
      _ctrl.reload();
    } else {
      setState(() => _busy.remove(adj.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              essT('payroll.adjustments.cancel_failed', 'İptal başarısız')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('payroll.adjustments.title', 'Bordro Ek/Kesintileri'),
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _ctrl.reload),
      ],
      child: AsyncView<List<PayrollAdjustment>>(
        controller: _ctrl,
        load: () => adminPayrollService.adjustments(),
        errorFallback: essT('common.data_load_error', 'Veriler yüklenemedi'),
        isEmpty: (d) => d.isEmpty,
        emptyIcon: Icons.swap_vert_outlined,
        emptyTitle: essT('payroll.adjustments.empty', 'Ek/kesinti yok'),
        builder: (context, d) => _content(context, d),
      ),
    );
  }

  Widget _content(BuildContext context, List<PayrollAdjustment> d) {
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: d.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _AdjustmentCard(
        adj: d[i],
        busy: _busy.contains(d[i].id),
        onCancel: () => _cancel(d[i]),
      ),
    );
  }
}

/// Ek/kesinti türü etiketi.
String _kindLabel(PayrollAdjustment a) {
  return a.isDeduction
      ? essT('payroll.adjustments.deduction', 'Kesinti')
      : essT('payroll.adjustments.addition', 'Ek');
}

/// Kaynak türü etiketi (`advance` avans / `expense` masraf).
String _sourceLabel(PayrollAdjustment a) {
  switch (a.sourceType) {
    case 'advance':
      return essT('payroll.adjustments.source_advance', 'Avans');
    case 'expense':
      return essT('payroll.adjustments.source_expense', 'Masraf');
    default:
      return a.sourceType;
  }
}

class _AdjustmentCard extends StatelessWidget {
  final PayrollAdjustment adj;
  final bool busy;
  final VoidCallback onCancel;

  const _AdjustmentCard({
    required this.adj,
    required this.busy,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final deduction = adj.isDeduction;
    final isPending = adj.status == 'pending';
    final amountColor = deduction ? AppColors.error : AppColors.success;
    final sign = deduction ? '-' : '+';
    final name = (adj.staffName ?? '').isEmpty ? '—' : adj.staffName!;

    final subtitleParts = <String>[
      _sourceLabel(adj),
      if (adj.periodYear != null && adj.periodMonth != null)
        essMonthYear(adj.periodYear, adj.periodMonth),
    ];

    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: amountColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                deduction ? Icons.trending_down : Icons.trending_up,
                color: amountColor,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTypography.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitleParts.join(' · '),
                    style: AppTypography.caption1
                        .copyWith(color: AppColors.tertiaryLabel(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((adj.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      adj.description!,
                      style: AppTypography.caption2
                          .copyWith(color: AppColors.tertiaryLabel(context)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$sign${essMoney(adj.amount)}',
                  style: AppTypography.headline.copyWith(color: amountColor),
                ),
                const SizedBox(height: 4),
                AppBadge(
                  label: _kindLabel(adj),
                  variant: deduction
                      ? AppBadgeVariant.error
                      : AppBadgeVariant.success,
                  size: AppBadgeSize.small,
                ),
                const SizedBox(height: 4),
                AppBadge(
                  label: essStatusLabel(adj.status),
                  variant: essStatusVariant(adj.status),
                  size: AppBadgeSize.small,
                ),
              ],
            ),
          ],
            ),
            if (isPending) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                        child: AppLoadingIndicator(),
                      )
                    : AppButton(
                        label: essT('payroll.adjustments.cancel', 'İptal et'),
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.small,
                        icon: Icons.close,
                        onPressed: onCancel,
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
