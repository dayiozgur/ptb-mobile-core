import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';

/// Admin "Bordro Parametreleri" (salt-okuma, v1).
///
/// `payroll_parameters` satırlarını (yıl-kapsamlı TR oran yapılandırması + global
/// varsayılan) listeler. Karta dokununca dilim/oran kırılımını alt-sayfada açar.
/// Web `PayrollParametersComponent` okuma yolunun mobil aynası.
class AdminPayrollParametersScreen extends StatefulWidget {
  const AdminPayrollParametersScreen({super.key});

  @override
  State<AdminPayrollParametersScreen> createState() =>
      _AdminPayrollParametersScreenState();
}

class _AdminPayrollParametersScreenState
    extends State<AdminPayrollParametersScreen> {
  final _ctrl = AsyncViewController();

  void _open(PayrollParameter p) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ParameterSheet(param: p),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('payroll.parameters.title', 'Bordro Parametreleri'),
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _ctrl.reload),
      ],
      child: AsyncView<List<PayrollParameter>>(
        controller: _ctrl,
        load: () => adminPayrollService.parameters(),
        errorFallback: essT('common.data_load_error', 'Veriler yüklenemedi'),
        isEmpty: (d) => d.isEmpty,
        emptyIcon: Icons.tune_outlined,
        emptyTitle: essT('payroll.parameters.empty', 'Parametre yok'),
        builder: (context, d) => _content(context, d),
      ),
    );
  }

  Widget _content(BuildContext context, List<PayrollParameter> d) {
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: d.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) =>
          _ParameterCard(param: d[i], onTap: () => _open(d[i])),
    );
  }
}

/// Bir oranı yüzde biçiminde göster (0.14 → `%14`).
String _pct(num rate) {
  final v = rate * 100;
  final s = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  return '%$s';
}

class _ParameterCard extends StatelessWidget {
  final PayrollParameter param;
  final VoidCallback onTap;

  const _ParameterCard({required this.param, required this.onTap});

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
              child: Icon(Icons.tune, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('${param.year}', style: AppTypography.headline),
                      const SizedBox(width: AppSpacing.xs),
                      AppBadge(
                        label: param.isGlobalDefault
                            ? essT('payroll.parameters.global', 'Genel')
                            : essT('payroll.parameters.tenant', 'Kuruma özel'),
                        variant: param.isGlobalDefault
                            ? AppBadgeVariant.neutral
                            : AppBadgeVariant.info,
                        size: AppBadgeSize.small,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${essT('payroll.parameters.min_wage', 'Asgari brüt')}: '
                    '${essMoney(param.minimumWageGross)}',
                    style: AppTypography.caption1
                        .copyWith(color: AppColors.tertiaryLabel(context)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.chevron_right, color: AppColors.tertiaryLabel(context)),
          ],
        ),
      ),
    );
  }
}

// ============================================
// PARAMETRE DETAY ALT-SAYFASI (salt-okuma)
// ============================================

class _ParameterSheet extends StatelessWidget {
  final PayrollParameter param;

  const _ParameterSheet({required this.param});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final maxH = MediaQuery.of(context).size.height * 0.85;

    final rates = <_Entry>[
      _Entry(essT('payroll.parameters.sgk_employee', 'SGK işçi'),
          _pct(param.sgkEmployeeRate)),
      _Entry(essT('payroll.parameters.unemp_employee', 'İşsizlik işçi'),
          _pct(param.unemploymentEmployeeRate)),
      _Entry(essT('payroll.parameters.sgk_employer', 'SGK işveren'),
          _pct(param.sgkEmployerRate)),
      _Entry(essT('payroll.parameters.unemp_employer', 'İşsizlik işveren'),
          _pct(param.unemploymentEmployerRate)),
      _Entry(essT('payroll.parameters.stamp_tax', 'Damga vergisi'),
          _pct(param.stampTaxRate)),
    ];

    final bases = <_Entry>[
      _Entry(essT('payroll.parameters.min_wage', 'Asgari brüt'),
          essMoney(param.minimumWageGross)),
      _Entry(essT('payroll.parameters.sgk_floor', 'SGK taban'),
          essMoney(param.sgkFloor)),
      _Entry(essT('payroll.parameters.sgk_ceiling', 'SGK tavan'),
          essMoney(param.sgkCeiling)),
    ];

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                color: AppColors.systemGray4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                children: [
                  Text(
                    '${param.year} — ${param.isGlobalDefault ? essT('payroll.parameters.global', 'Genel') : essT('payroll.parameters.tenant', 'Kuruma özel')}',
                    style: AppTypography.title3,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _Section(
                      title: essT('payroll.parameters.rates', 'Oranlar'),
                      entries: rates),
                  const SizedBox(height: AppSpacing.md),
                  _Section(
                      title: essT('payroll.parameters.bases', 'Matrah/Tavanlar'),
                      entries: bases),
                  if (param.incomeTaxBrackets.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      essT('payroll.parameters.tax_brackets',
                          'Gelir vergisi dilimleri'),
                      style: AppTypography.footnote.copyWith(
                        color: AppColors.secondaryLabel(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ...param.incomeTaxBrackets.map((b) => _Row(
                          entry: _Entry(
                            b.upto == null
                                ? essT('payroll.parameters.bracket_top',
                                    'Üst dilim')
                                : '≤ ${essMoney(b.upto!)}',
                            _pct(b.rate),
                          ),
                        )),
                  ],
                  if ((param.notes ?? '').isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      param.notes!,
                      style: AppTypography.caption1
                          .copyWith(color: AppColors.tertiaryLabel(context)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Entry {
  final String label;
  final String value;

  const _Entry(this.label, this.value);
}

class _Section extends StatelessWidget {
  final String title;
  final List<_Entry> entries;

  const _Section({required this.title, required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: AppTypography.footnote.copyWith(
            color: AppColors.secondaryLabel(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ...entries.map((e) => _Row(entry: e)),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final _Entry entry;

  const _Row({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              entry.label,
              style: AppTypography.subhead
                  .copyWith(color: AppColors.secondaryLabel(context)),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(entry.value, style: AppTypography.body),
        ],
      ),
    );
  }
}
