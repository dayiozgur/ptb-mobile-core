import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';

/// PHR yönetim "Teşvikler (SGK/Ar-Ge)" görüntüleyici (salt-okuma, v1).
///
/// `/admin/tesvik` → tenant genelindeki teşvik tahakkuk kayıtlarını
/// (`tesvik_accruals`) listeler: personel, teşvik kalemi (regime + rule_code),
/// dönem, teşvik tutarı, durum rozeti. Veri kaynağı
/// [AdminTesvikKvkkService.tesvikRecords] (web `TesvikService.getAccruals`
/// okuma sözleşmesiyle birebir).
class AdminTesvikScreen extends StatefulWidget {
  const AdminTesvikScreen({super.key});

  @override
  State<AdminTesvikScreen> createState() => _AdminTesvikScreenState();
}

class _AdminTesvikScreenState extends State<AdminTesvikScreen> {
  final _ctrl = AsyncViewController();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('tesvik.title', 'Teşvikler (SGK/Ar-Ge)'),
      showBackButton: true,
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _ctrl.reload),
      ],
      child: AsyncView<List<TesvikAccrualRow>>(
        controller: _ctrl,
        load: () => adminTesvikKvkkService.tesvikRecords(),
        errorFallback: essT('common.data_load_error', 'Veriler yüklenemedi'),
        isEmpty: (rows) => rows.isEmpty,
        emptyIcon: Icons.savings_outlined,
        emptyTitle: essT('tesvik.empty', 'Teşvik kaydı bulunamadı'),
        builder: (context, rows) => _content(context, rows),
      ),
    );
  }

  Widget _content(BuildContext context, List<TesvikAccrualRow> rows) {
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _TesvikCard(row: rows[i]),
    );
  }
}

/// `rule_code` → kısa Türkçe etiket.
String tesvikRuleCodeLabel(String code) {
  switch (code) {
    case 'arge_indirimi':
      return essT('tesvik.rule.arge_indirimi', 'Ar-Ge İndirimi');
    case 'sgk_isveren':
      return essT('tesvik.rule.sgk_isveren', 'SGK İşveren');
    case 'gv_stopaj':
      return essT('tesvik.rule.gv_stopaj', 'GV Stopaj');
    case 'damga_vergisi':
      return essT('tesvik.rule.damga_vergisi', 'Damga Vergisi');
    case 'gv_istisna':
      return essT('tesvik.rule.gv_istisna', 'GV İstisna');
    case 'kdv_istisna':
      return essT('tesvik.rule.kdv_istisna', 'KDV İstisna');
    default:
      return code;
  }
}

/// `regime` → kısa etiket.
String tesvikRegimeLabel(String regime) {
  switch (regime) {
    case '5746':
      return essT('tesvik.regime.5746', 'Ar-Ge Merkezi (5746)');
    case '4691':
      return essT('tesvik.regime.4691', 'Teknopark (4691)');
    default:
      return regime;
  }
}

/// `title_category` → Türkçe etiket.
String tesvikTitleCategoryLabel(String? cat) {
  switch (cat) {
    case 'arge_personeli':
      return essT('tesvik.title_cat.arge_personeli', 'Ar-Ge Personeli');
    case 'teknisyen':
      return essT('tesvik.title_cat.teknisyen', 'Teknisyen');
    case 'destek':
      return essT('tesvik.title_cat.destek', 'Destek');
    default:
      return cat ?? '-';
  }
}

/// Tahakkuk durumu → rozet varyantı.
AppBadgeVariant tesvikStatusVariant(String status) {
  switch (status) {
    case 'finalized':
    case 'approved':
      return AppBadgeVariant.success;
    case 'draft':
      return AppBadgeVariant.warning;
    default:
      return AppBadgeVariant.neutral;
  }
}

/// Tahakkuk durumu → Türkçe etiket.
String tesvikStatusLabel(String status) {
  switch (status) {
    case 'finalized':
      return essT('tesvik.status.finalized', 'Kesinleşti');
    case 'approved':
      return essT('tesvik.status.approved', 'Onaylandı');
    case 'draft':
      return essT('tesvik.status.draft', 'Taslak');
    default:
      return status;
  }
}

class _TesvikCard extends StatelessWidget {
  final TesvikAccrualRow row;

  const _TesvikCard({required this.row});

  @override
  Widget build(BuildContext context) {
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
                    row.staffName ??
                        essT('tesvik.no_staff', 'Personel'),
                    style: AppTypography.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppBadge(
                  label: tesvikStatusLabel(row.status),
                  variant: tesvikStatusVariant(row.status),
                  size: AppBadgeSize.small,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${tesvikRuleCodeLabel(row.ruleCode)} · ${tesvikRegimeLabel(row.regime)}',
              style: AppTypography.footnote
                  .copyWith(color: AppColors.secondaryLabel(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.event_outlined,
                    size: 14, color: AppColors.tertiaryLabel(context)),
                const SizedBox(width: 4),
                Text(
                  row.periodLabel,
                  style: AppTypography.footnote
                      .copyWith(color: AppColors.secondaryLabel(context)),
                ),
                const SizedBox(width: AppSpacing.md),
                Icon(Icons.schedule,
                    size: 14, color: AppColors.tertiaryLabel(context)),
                const SizedBox(width: 4),
                Text(
                  essDuration((row.argeHours * 60).round()),
                  style: AppTypography.footnote
                      .copyWith(color: AppColors.secondaryLabel(context)),
                ),
                const Spacer(),
                Text(
                  essMoney(row.incentiveAmount),
                  style: AppTypography.headline
                      .copyWith(color: AppColors.success),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
