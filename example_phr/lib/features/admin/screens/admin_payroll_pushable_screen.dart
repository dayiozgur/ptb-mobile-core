import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';

/// Admin "Bordroya Bekleyenler" — bordroya itilebilir avans/masraf başvuruları.
///
/// `AdminPayrollService.getPushableSubmissions` (web `PayrollService`
/// getPushableSubmissions aynası) ile onaylı ama henüz bir `payroll_adjustments`
/// satırına dönüşmemiş başvuruları listeler. Her satır: konu/kod + başvuran +
/// tutar + statü rozeti + "Bordroya it" aksiyonu (`fn_hr_push_to_payroll`).
/// İtme = onaylama; statü rozet olarak gösterilir, kararı admin verir.
class AdminPayrollPushableScreen extends StatefulWidget {
  const AdminPayrollPushableScreen({super.key});

  @override
  State<AdminPayrollPushableScreen> createState() =>
      _AdminPayrollPushableScreenState();
}

class _AdminPayrollPushableScreenState
    extends State<AdminPayrollPushableScreen> {
  final _ctrl = AsyncViewController();
  final Set<String> _busy = {};

  /// Bir başvuruyu bordroya it (web `pushToPayroll` aynası). Onay diyaloğu →
  /// servis → başarıda oluşan ek/kesinti id'si snackbar + liste yenile. Servis
  /// hata → `null` döndürür (fırlatmaz); hata snackbar'ı gösterilir. Çift-tık
  /// guard'ı + busy-state deseni `admin_payroll_adjustments_screen` ile aynı.
  Future<void> _push(PushableSubmission sub) async {
    if (_busy.contains(sub.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            essT('payroll.pushable.push_title', 'Bordroya it')),
        content: Text(essT('payroll.pushable.push_confirm',
            'Bu başvuruyu bordro ek/kesintisine dönüştürmek istiyor musunuz?')),
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

    setState(() => _busy.add(sub.id));
    final adjId = await adminPayrollAdjustmentService.pushToPayroll(sub.id);
    if (!mounted) return;
    if (adjId != null) {
      final msg = adjId.isEmpty
          ? essT('payroll.pushable.pushed_ok', 'Bordroya itildi')
          : essT('payroll.pushable.pushed_ok_id', 'Bordroya itildi')
              .replaceFirst('{id}', adjId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.success),
      );
      _ctrl.reload();
    } else {
      setState(() => _busy.remove(sub.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(essT('payroll.pushable.push_failed', 'Bordroya itilemedi')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('payroll.pushable.title', 'Bordroya Bekleyenler'),
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _ctrl.reload),
      ],
      child: AsyncView<List<PushableSubmission>>(
        controller: _ctrl,
        load: () => adminPayrollService.getPushableSubmissions(),
        errorFallback: essT('common.data_load_error', 'Veriler yüklenemedi'),
        isEmpty: (d) => d.isEmpty,
        emptyIcon: Icons.playlist_add_check_circle_outlined,
        emptyTitle:
            essT('payroll.pushable.empty', 'Bordroya bekleyen başvuru yok'),
        builder: (context, d) => _content(context, d),
      ),
    );
  }

  Widget _content(BuildContext context, List<PushableSubmission> d) {
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: d.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _PushableCard(
        sub: d[i],
        busy: _busy.contains(d[i].id),
        onPush: () => _push(d[i]),
      ),
    );
  }
}

/// Kaynak türü etiketi (`hr_advance` avans / `hr_expense` masraf).
String _sourceLabel(PushableSubmission s) {
  switch (s.entityType) {
    case 'hr_advance':
      return essT('payroll.adjustments.source_advance', 'Avans');
    case 'hr_expense':
      return essT('payroll.adjustments.source_expense', 'Masraf');
    default:
      return s.entityType;
  }
}

class _PushableCard extends StatelessWidget {
  final PushableSubmission sub;
  final bool busy;
  final VoidCallback onPush;

  const _PushableCard({
    required this.sub,
    required this.busy,
    required this.onPush,
  });

  @override
  Widget build(BuildContext context) {
    final expense = sub.isExpense;
    final accent = expense ? AppColors.success : AppColors.warning;
    final title = (sub.subject ?? '').isNotEmpty
        ? sub.subject!
        : ((sub.code ?? '').isNotEmpty ? sub.code! : '—');

    final subtitleParts = <String>[
      _sourceLabel(sub),
      if ((sub.submitterName ?? '').isNotEmpty) sub.submitterName!,
      if ((sub.code ?? '').isNotEmpty && (sub.subject ?? '').isNotEmpty)
        sub.code!,
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
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    expense ? Icons.receipt_long : Icons.payments_outlined,
                    color: accent,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
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
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      essMoney(sub.amount),
                      style: AppTypography.headline.copyWith(color: accent),
                    ),
                    const SizedBox(height: 4),
                    AppBadge(
                      label: essStatusLabel(sub.status),
                      variant: essStatusVariant(sub.status),
                      size: AppBadgeSize.small,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      child: AppLoadingIndicator(),
                    )
                  : AppButton(
                      label: essT('payroll.pushable.push', 'Bordroya it'),
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.small,
                      icon: Icons.playlist_add_check,
                      onPressed: onPush,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
