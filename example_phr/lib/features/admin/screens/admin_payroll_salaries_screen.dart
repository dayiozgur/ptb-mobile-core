import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';

/// Admin "Maaş Tanımları" (salt-okuma, v1).
///
/// `payroll_salaries` satırlarını (personel + brüt aylık + para birimi + aktif)
/// listeler. HASSAS: brüt rakam yalnız RLS/grants ile yetkilendirilen admin'e
/// döner. Web `PayrollSalariesComponent` okuma yolunun mobil aynası.
class AdminPayrollSalariesScreen extends StatefulWidget {
  const AdminPayrollSalariesScreen({super.key});

  @override
  State<AdminPayrollSalariesScreen> createState() =>
      _AdminPayrollSalariesScreenState();
}

class _AdminPayrollSalariesScreenState
    extends State<AdminPayrollSalariesScreen> {
  final _ctrl = AsyncViewController();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('payroll.salaries.title', 'Maaş Tanımları'),
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _ctrl.reload),
      ],
      child: AsyncView<List<PayrollSalary>>(
        controller: _ctrl,
        load: () => adminPayrollService.salaries(),
        errorFallback: essT('common.data_load_error', 'Veriler yüklenemedi'),
        isEmpty: (salaries) => salaries.isEmpty,
        emptyIcon: Icons.payments_outlined,
        emptyTitle: essT('payroll.salaries.empty', 'Maaş tanımı yok'),
        builder: (context, salaries) => _content(context, salaries),
      ),
    );
  }

  Widget _content(BuildContext context, List<PayrollSalary> salaries) {
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: salaries.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _SalaryCard(salary: salaries[i]),
    );
  }
}

class _SalaryCard extends StatelessWidget {
  final PayrollSalary salary;

  const _SalaryCard({required this.salary});

  @override
  Widget build(BuildContext context) {
    final name = (salary.staffName ?? '').isEmpty ? '—' : salary.staffName!;
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            AppAvatar(name: name),
            const SizedBox(width: AppSpacing.md),
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
                  Row(
                    children: [
                      Text(
                        essT('payroll.salaries.gross_monthly', 'Aylık brüt'),
                        style: AppTypography.caption1.copyWith(
                            color: AppColors.tertiaryLabel(context)),
                      ),
                      if (!salary.active) ...[
                        const SizedBox(width: AppSpacing.xs),
                        AppBadge(
                          label: essT('common.passive', 'Pasif'),
                          variant: AppBadgeVariant.neutral,
                          size: AppBadgeSize.small,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Text(
              essMoney(salary.grossMonthly),
              style: AppTypography.headline.copyWith(
                color: salary.active
                    ? AppColors.primary
                    : AppColors.tertiaryLabel(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
