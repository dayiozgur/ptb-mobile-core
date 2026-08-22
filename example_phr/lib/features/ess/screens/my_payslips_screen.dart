import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../ess_common.dart';
import 'payslip_detail_screen.dart';

/// Çalışanın bordro (maaş pusulası) listesi.
///
/// Her satır dönem (YYYY/Ay) + net ödenecek tutarı gösterir; dokununca
/// [PayslipDetailScreen] kırılımı açar.
class MyPayslipsScreen extends StatefulWidget {
  const MyPayslipsScreen({super.key});

  @override
  State<MyPayslipsScreen> createState() => _MyPayslipsScreenState();
}

class _MyPayslipsScreenState extends State<MyPayslipsScreen> {
  final _ctrl = AsyncViewController();

  void _open(Payslip p) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PayslipDetailScreen(payslip: p)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('hr.payroll.my_payslips', 'Maaş Pusulalarım'),
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _ctrl.reload),
      ],
      child: AsyncView<List<Payslip>>(
        controller: _ctrl,
        load: () => hrEssService.myPayslips(),
        errorFallback: essT('common.data_load_error', 'Veriler yüklenemedi'),
        isEmpty: (d) => d.isEmpty,
        emptyIcon: Icons.receipt_long_outlined,
        emptyTitle: essT('hr.payroll.no_payslips', 'Bordro bulunamadı'),
        builder: (context, d) => _content(context, d),
      ),
    );
  }

  Widget _content(BuildContext context, List<Payslip> payslips) {
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: payslips.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _PayslipCard(
        payslip: payslips[i],
        onTap: () => _open(payslips[i]),
      ),
    );
  }
}

class _PayslipCard extends StatelessWidget {
  final Payslip payslip;
  final VoidCallback onTap;

  const _PayslipCard({required this.payslip, required this.onTap});

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
              child: Icon(Icons.receipt_long, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    essMonthYear(payslip.periodYear, payslip.periodMonth),
                    style: AppTypography.headline,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    essT('hr.payroll.net_payable', 'Net ödenecek'),
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
                  style: AppTypography.headline
                      .copyWith(color: AppColors.success),
                ),
                const SizedBox(height: 2),
                Icon(Icons.chevron_right,
                    color: AppColors.tertiaryLabel(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
