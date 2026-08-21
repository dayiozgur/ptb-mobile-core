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
  bool _isLoading = true;
  String? _errorMessage;
  List<PayrollRun> _runs = [];

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
      final rows = await adminPayrollService.runs();
      if (mounted) {
        setState(() {
          _runs = rows;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('AdminPayrollRunsScreen yükleme hatası', e);
      if (mounted) {
        setState(() {
          _errorMessage = essT('common.data_load_error', 'Veriler yüklenemedi');
          _isLoading = false;
        });
      }
    }
  }

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
    if (_runs.isEmpty) {
      return _emptyState(
        icon: Icons.event_note_outlined,
        title: essT('payroll.runs.empty', 'Bordro çalıştırması yok'),
      );
    }
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: _runs.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _RunCard(run: _runs[i], onTap: () => _open(_runs[i])),
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
  bool _isLoading = true;
  String? _errorMessage;
  List<PayrollRunPayslip> _payslips = [];

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
      final rows = await adminPayrollService.runPayslips(widget.run.id);
      if (mounted) {
        setState(() {
          _payslips = rows;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('_RunPayslipsScreen yükleme hatası', e);
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
      title: essMonthYear(widget.run.periodYear, widget.run.periodMonth),
      onBack: () => Navigator.of(context).pop(),
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
    if (_payslips.isEmpty) {
      return _emptyState(
        icon: Icons.receipt_long_outlined,
        title: essT('payroll.runs.no_payslips',
            'Bu çalıştırmada bordro satırı yok'),
      );
    }
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: _payslips.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _RunPayslipCard(payslip: _payslips[i]),
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
