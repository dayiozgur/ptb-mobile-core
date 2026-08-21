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
  bool _isLoading = true;
  String? _errorMessage;
  List<PayrollSalary> _salaries = [];

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
      final rows = await adminPayrollService.salaries();
      if (mounted) {
        setState(() {
          _salaries = rows;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('AdminPayrollSalariesScreen yükleme hatası', e);
      if (mounted) {
        setState(() {
          _errorMessage = essT('common.data_load_error', 'Veriler yüklenemedi');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('payroll.salaries.title', 'Maaş Tanımları'),
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _load),
      ],
      child: RefreshIndicator(
        onRefresh: _load,
        child: _buildContent(),
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
    if (_salaries.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: AppEmptyState(
                icon: Icons.payments_outlined,
                title: essT('payroll.salaries.empty', 'Maaş tanımı yok'),
              ),
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: _salaries.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _SalaryCard(salary: _salaries[i]),
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
