import 'package:flutter/material.dart' hide FormField;
import 'package:protoolbag_core/protoolbag_core.dart';

import '../ess_common.dart';

/// Tek bir bordronun kırılımı — brüt, SGK, gelir vergisi, net + gün sayıları.
class PayslipDetailScreen extends StatelessWidget {
  final Payslip payslip;

  const PayslipDetailScreen({super.key, required this.payslip});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essMonthYear(payslip.periodYear, payslip.periodMonth),
      onBack: () => Navigator.of(context).pop(),
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Öne çıkan: net ödenecek
            AppCard(
              variant: AppCardVariant.filled,
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    Text(
                      essT('hr.payroll.net_payable', 'Net ödenecek'),
                      style: AppTypography.subhead
                          .copyWith(color: AppColors.secondaryLabel(context)),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      essMoney(payslip.netPayable),
                      style: AppTypography.largeTitle
                          .copyWith(color: AppColors.success),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Kazanç / kesinti kırılımı
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    _row(context, essT('hr.payroll.gross', 'Brüt maaş'),
                        essMoney(payslip.grossSalary)),
                    _divider(context),
                    _row(
                      context,
                      essT('hr.payroll.sgk', 'SGK işçi payı'),
                      '- ${essMoney(payslip.sgkEmployee)}',
                      valueColor: AppColors.error,
                    ),
                    _divider(context),
                    _row(
                      context,
                      essT('hr.payroll.income_tax', 'Gelir vergisi'),
                      '- ${essMoney(payslip.incomeTax)}',
                      valueColor: AppColors.error,
                    ),
                    _divider(context),
                    _row(context, essT('hr.payroll.net', 'Net maaş'),
                        essMoney(payslip.netSalary)),
                    _divider(context),
                    _row(
                      context,
                      essT('hr.payroll.net_payable', 'Net ödenecek'),
                      essMoney(payslip.netPayable),
                      emphasize: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Gün bilgileri
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    title: essT('hr.payroll.worked_days', 'Çalışılan gün'),
                    value: _fmtNum(payslip.workedDays),
                    icon: Icons.work_outline,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: MetricCard(
                    title: essT('hr.payroll.absent_days', 'Devamsız gün'),
                    value: _fmtNum(payslip.absentDays),
                    icon: Icons.event_busy_outlined,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
            if (payslip.overtimeMinutes > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Padding(
                  padding: AppSpacing.cardInsets,
                  child: _row(
                    context,
                    essT('hr.payroll.overtime', 'Fazla mesai'),
                    essDuration(payslip.overtimeMinutes.toInt()),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
    bool emphasize = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: emphasize
                  ? AppTypography.headline
                  : AppTypography.body.copyWith(
                      color: AppColors.secondaryLabel(context),
                    ),
            ),
          ),
          Text(
            value,
            style: (emphasize ? AppTypography.headline : AppTypography.body)
                .copyWith(
              color: valueColor ??
                  (emphasize
                      ? AppColors.primary
                      : AppColors.primaryLabel(context)),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) =>
      Divider(height: 1, color: AppColors.separator(context));

  String _fmtNum(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
