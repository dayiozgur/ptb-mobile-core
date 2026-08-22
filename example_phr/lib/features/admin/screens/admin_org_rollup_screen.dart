import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';

/// Admin "Organizasyon Kırılımı / Özet" — headcount rollup (salt-okuma, v1).
///
/// Canlı şemada özel rollup RPC bulunmadığından servis `staffs` sayımını
/// `organizations` ile istemcide birleştirir. Üst özet kartı (toplam org +
/// toplam personel) + organizasyon başına headcount barları.
class AdminOrgRollupScreen extends StatefulWidget {
  const AdminOrgRollupScreen({super.key});

  @override
  State<AdminOrgRollupScreen> createState() => _AdminOrgRollupScreenState();
}

class _AdminOrgRollupScreenState extends State<AdminOrgRollupScreen> {
  final _ctrl = AsyncViewController();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('hr.org_rollup.title', 'Organizasyon Kırılımı'),
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _ctrl.reload),
      ],
      child: AsyncView<List<OrgRollupRow>>(
        controller: _ctrl,
        load: () => adminOrgService.orgRollup(),
        errorFallback: essT('common.data_load_error', 'Veriler yüklenemedi'),
        isEmpty: (d) => d.isEmpty,
        emptyIcon: Icons.pie_chart_outline,
        emptyTitle: essT('hr.org_rollup.empty', 'Organizasyon bulunamadı'),
        builder: (context, d) => _content(context, d),
      ),
    );
  }

  Widget _content(BuildContext context, List<OrgRollupRow> d) {
    final maxHc = d.fold<int>(0, (m, r) => r.headcount > m ? r.headcount : m);
    final totalHc = d.fold<int>(0, (sum, r) => sum + r.headcount);
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: d.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _SummaryHeader(
            orgCount: d.length,
            totalHeadcount: totalHc,
          );
        }
        return _RollupCard(row: d[index - 1], maxHeadcount: maxHc);
      },
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final int orgCount;
  final int totalHeadcount;

  const _SummaryHeader({required this.orgCount, required this.totalHeadcount});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            Expanded(
              child: _Metric(
                label: essT('hr.org_rollup.orgs', 'Organizasyon'),
                value: '$orgCount',
                color: AppColors.primary,
              ),
            ),
            Container(
              width: 1,
              height: 36,
              color: AppColors.separator(context),
            ),
            Expanded(
              child: _Metric(
                label: essT('hr.org_rollup.headcount', 'Toplam Personel'),
                value: '$totalHeadcount',
                color: AppColors.success,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: AppTypography.title2.copyWith(color: color)),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.caption1
              .copyWith(color: AppColors.tertiaryLabel(context)),
        ),
      ],
    );
  }
}

class _RollupCard extends StatelessWidget {
  final OrgRollupRow row;
  final int maxHeadcount;

  const _RollupCard({required this.row, required this.maxHeadcount});

  @override
  Widget build(BuildContext context) {
    final ratio =
        maxHeadcount > 0 ? (row.headcount / maxHeadcount).clamp(0.0, 1.0) : 0.0;

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
                    row.organizationName?.trim().isNotEmpty == true
                        ? row.organizationName!
                        : '—',
                    style: AppTypography.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${row.headcount}',
                  style: AppTypography.headline
                      .copyWith(color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio.toDouble(),
                minHeight: 6,
                backgroundColor: AppColors.separator(context),
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
