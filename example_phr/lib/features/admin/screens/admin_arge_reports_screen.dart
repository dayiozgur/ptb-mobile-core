import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';

/// PHR yönetim "Ar-Ge Raporları" görüntüleyici (salt-okuma, v1).
///
/// `/admin/arge-reports` → Ar-Ge Puantaj İcmal: Ar-Ge personelinin
/// (`staffs.is_arge_personnel`) aylık `puantaj_sheets` Ar-Ge / toplam saat
/// icmalini listeler (personel, dönem, Ar-Ge saati / toplam saat + oran
/// çubuğu). Veri kaynağı [AdminTesvikKvkkService.argeReports] (web
/// `dr_data_sources 'arge-puantaj-summary'` içeriğiyle birebir).
class AdminArgeReportsScreen extends StatefulWidget {
  const AdminArgeReportsScreen({super.key});

  @override
  State<AdminArgeReportsScreen> createState() => _AdminArgeReportsScreenState();
}

class _AdminArgeReportsScreenState extends State<AdminArgeReportsScreen> {
  final _ctrl = AsyncViewController();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('arge_report.title', 'Ar-Ge Raporları'),
      showBackButton: true,
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _ctrl.reload),
      ],
      child: AsyncView<List<ArgeReportRow>>(
        controller: _ctrl,
        load: () => adminTesvikKvkkService.argeReports(),
        errorFallback: essT('common.data_load_error', 'Veriler yüklenemedi'),
        isEmpty: (d) => d.isEmpty,
        emptyIcon: Icons.science_outlined,
        emptyTitle: essT('arge_report.empty', 'Ar-Ge kaydı bulunamadı'),
        builder: (context, d) => _content(context, d),
      ),
    );
  }

  Widget _content(BuildContext context, List<ArgeReportRow> d) {
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: d.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _ArgeCard(row: d[i]),
    );
  }
}

class _ArgeCard extends StatelessWidget {
  final ArgeReportRow row;

  const _ArgeCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final ratio = row.argeRatio;
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
                    row.staffName ?? essT('arge_report.no_staff', 'Personel'),
                    style: AppTypography.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  row.periodLabel,
                  style: AppTypography.footnote
                      .copyWith(color: AppColors.secondaryLabel(context)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.science_outlined,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  '${essT('arge_report.arge_hours', 'Ar-Ge')}: ${essDuration((row.argeHours * 60).round())}',
                  style: AppTypography.footnote.copyWith(
                    color: AppColors.primaryLabel(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${essT('arge_report.total_hours', 'Toplam')}: ${essDuration((row.totalHours * 60).round())}',
                  style: AppTypography.footnote
                      .copyWith(color: AppColors.secondaryLabel(context)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: AppColors.separator(context),
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(ratio * 100).round()}% ${essT('arge_report.arge_ratio', 'Ar-Ge oranı')}',
              style: AppTypography.caption1
                  .copyWith(color: AppColors.tertiaryLabel(context)),
            ),
          ],
        ),
      ),
    );
  }
}
