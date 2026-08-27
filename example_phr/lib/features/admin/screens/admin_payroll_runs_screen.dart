import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';

/// Admin "Bordro Çalıştırmaları" (salt-okuma, v1).
///
/// `payroll_runs` satırlarını (dönem + durum + tarih) listeler; bir çalıştırmaya
/// dokununca o run'a ait bordro satırlarını ([_RunPayslipsScreen]) açar.
/// Web `PayrollRunsComponent` okuma yolunun mobil aynası.
class AdminPayrollRunsScreen extends StatefulWidget {
  const AdminPayrollRunsScreen({super.key});

  @override
  State<AdminPayrollRunsScreen> createState() => _AdminPayrollRunsScreenState();
}

class _AdminPayrollRunsScreenState extends State<AdminPayrollRunsScreen> {
  final _ctrl = AsyncViewController();

  void _open(PayrollRun run) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _RunPayslipsScreen(run: run)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('payroll.runs.title', 'Bordro Çalıştırmaları'),
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _ctrl.reload),
      ],
      child: AsyncView<List<PayrollRun>>(
        controller: _ctrl,
        load: () => adminPayrollService.runs(),
        errorFallback: essT('common.data_load_error', 'Veriler yüklenemedi'),
        isEmpty: (runs) => runs.isEmpty,
        emptyBuilder: (_) => _emptyState(
          icon: Icons.event_note_outlined,
          title: essT('payroll.runs.empty', 'Bordro çalıştırması yok'),
        ),
        builder: (context, runs) => _content(context, runs),
      ),
    );
  }

  Widget _content(BuildContext context, List<PayrollRun> runs) {
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: runs.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _RunCard(run: runs[i], onTap: () => _open(runs[i])),
    );
  }
}

class _RunCard extends StatelessWidget {
  final PayrollRun run;
  final VoidCallback onTap;

  const _RunCard({required this.run, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.event_note, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    essMonthYear(run.periodYear, run.periodMonth),
                    style: AppTypography.headline,
                  ),
                  if ((run.label ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      run.label!,
                      style: AppTypography.caption1
                          .copyWith(color: AppColors.tertiaryLabel(context)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (run.calculatedAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${essT('payroll.runs.calculated_at', 'Hesaplandı')}: '
                      '${essDate(run.calculatedAt)}',
                      style: AppTypography.caption2
                          .copyWith(color: AppColors.tertiaryLabel(context)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppBadge(
              label: essStatusLabel(run.status),
              variant: essStatusVariant(run.status),
              size: AppBadgeSize.small,
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.chevron_right, color: AppColors.tertiaryLabel(context)),
          ],
        ),
      ),
    );
  }
}

// ============================================
// ÇALIŞTIRMA DETAYI — bordro satırları (salt-okuma)
// ============================================

class _RunPayslipsScreen extends StatefulWidget {
  final PayrollRun run;

  const _RunPayslipsScreen({required this.run});

  @override
  State<_RunPayslipsScreen> createState() => _RunPayslipsScreenState();
}

class _RunPayslipsScreenState extends State<_RunPayslipsScreen> {
  final _ctrl = AsyncViewController();

  /// "Düzeltmeleri uygula" aksiyonu çalışırken true (çift-tıklama guard'ı +
  /// AppBar'da yükleniyor göstergesi).
  bool _applying = false;

  /// Bekleyen bordro ek/kesintilerini bu çalıştırmanın bordrosuna işle
  /// (`fn_payroll_apply_adjustments`, web `PayrollService.applyAdjustments`
  /// aynası). Onay diyaloğu → servis → "N düzeltme uygulandı" snackbar + liste
  /// yenile. Servis hata → `null` döndürür (fırlatmaz); hata snackbar'ı gösterilir.
  /// Aksiyon-deseni `admin_payroll_adjustments_screen.dart` iptal akışıyla aynı.
  Future<void> _applyAdjustments() async {
    if (_applying) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(essT(
            'payroll.runs.apply_adjustments_title', 'Düzeltmeleri uygula')),
        content: Text(essT('payroll.runs.apply_adjustments_confirm',
            'Bu çalıştırma için bekleyen bordro ek/kesintilerini uygulamak istiyor musunuz?')),
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

    setState(() => _applying = true);
    final count =
        await adminPayrollAdjustmentService.applyAdjustments(widget.run.id);
    if (!mounted) return;
    setState(() => _applying = false);

    final outcome = payrollApplyOutcome(
      count,
      successTemplate: essT(
          'payroll.runs.adjustments_applied', '{n} düzeltme uygulandı'),
      errorText:
          essT('payroll.runs.apply_adjustments_failed', 'Düzeltmeler uygulanamadı'),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(outcome.message),
        backgroundColor: outcome.ok ? AppColors.success : AppColors.error,
      ),
    );
    if (outcome.ok) _ctrl.reload();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essMonthYear(widget.run.periodYear, widget.run.periodMonth),
      onBack: () => Navigator.of(context).pop(),
      actions: [
        AppIconButton(
          icon: Icons.playlist_add_check,
          isLoading: _applying,
          tooltip: essT('payroll.runs.apply_adjustments_title',
              'Düzeltmeleri uygula'),
          onPressed: _applyAdjustments,
        ),
        AppIconButton(icon: Icons.refresh, onPressed: _ctrl.reload),
      ],
      child: AsyncView<List<PayrollRunPayslip>>(
        controller: _ctrl,
        load: () => adminPayrollService.runPayslips(widget.run.id),
        errorFallback: essT('common.data_load_error', 'Veriler yüklenemedi'),
        isEmpty: (payslips) => payslips.isEmpty,
        emptyBuilder: (_) => _emptyState(
          icon: Icons.receipt_long_outlined,
          title: essT('payroll.runs.no_payslips',
              'Bu çalıştırmada bordro satırı yok'),
        ),
        builder: (context, payslips) => _content(context, payslips),
      ),
    );
  }

  Widget _content(BuildContext context, List<PayrollRunPayslip> payslips) {
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: payslips.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _RunPayslipCard(payslip: payslips[i]),
    );
  }
}

class _RunPayslipCard extends StatelessWidget {
  final PayrollRunPayslip payslip;

  const _RunPayslipCard({required this.payslip});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            AppAvatar(name: payslip.staffName ?? '—'),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (payslip.staffName ?? '').isEmpty ? '—' : payslip.staffName!,
                    style: AppTypography.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${essT('payroll.gross', 'Brüt')}: '
                    '${essMoney(payslip.grossSalary)}',
                    style: AppTypography.caption1
                        .copyWith(color: AppColors.tertiaryLabel(context)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  essMoney(payslip.netPayable),
                  style:
                      AppTypography.headline.copyWith(color: AppColors.success),
                ),
                const SizedBox(height: 2),
                Text(
                  essT('payroll.net_payable', 'Net ödenecek'),
                  style: AppTypography.caption2
                      .copyWith(color: AppColors.tertiaryLabel(context)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// `applyAdjustments` dönüşünü (işlenen adet; `null` = servis hatası)
/// kullanıcı mesajına çevirir. Saf/test-edilebilir — çeviri şablonları dışarıdan
/// verilir (çeviri runtime'ına bağımlı değil). `null` → hata; aksi halde
/// [successTemplate] içindeki `{n}` işaretçisi adetle değiştirilir.
({bool ok, String message}) payrollApplyOutcome(
  int? count, {
  required String successTemplate,
  required String errorText,
}) {
  if (count == null) return (ok: false, message: errorText);
  return (ok: true, message: successTemplate.replaceFirst('{n}', '$count'));
}

/// Kaydırılabilir boş-durum (RefreshIndicator ile uyumlu).
Widget _emptyState({required IconData icon, required String title}) {
  return LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(
          child: AppEmptyState(icon: icon, title: title),
        ),
      ),
    ),
  );
}
