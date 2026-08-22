import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';

/// İK yönetim "Yetkinlikler" görüntüleyici (salt-okuma, v1).
///
/// `/admin/competencies` → aktif `competencies` satırlarını listeler (tenant'a
/// ait + global şablonlar): ad, kategori/açıklama, kod, aktif. Veri kaynağı
/// [AdminPerformanceService.competencies] (web `CompetencyService.list` ile
/// aynı okuma sözleşmesi).
class AdminCompetenciesScreen extends StatefulWidget {
  const AdminCompetenciesScreen({super.key});

  @override
  State<AdminCompetenciesScreen> createState() =>
      _AdminCompetenciesScreenState();
}

class _AdminCompetenciesScreenState extends State<AdminCompetenciesScreen> {
  final _ctrl = AsyncViewController();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('competencies.title', 'Yetkinlikler'),
      showBackButton: true,
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _ctrl.reload),
      ],
      child: AsyncView<List<Competency>>(
        controller: _ctrl,
        load: () => adminPerformanceService.competencies(),
        errorFallback: essT('common.data_load_error', 'Veriler yüklenemedi'),
        isEmpty: (d) => d.isEmpty,
        emptyIcon: Icons.workspace_premium_outlined,
        emptyTitle: essT('competencies.empty', 'Yetkinlik bulunamadı'),
        builder: (context, d) => _content(context, d),
      ),
    );
  }

  Widget _content(BuildContext context, List<Competency> d) {
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: d.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _CompetencyCard(competency: d[i]),
    );
  }
}

class _CompetencyCard extends StatelessWidget {
  final Competency competency;

  const _CompetencyCard({required this.competency});

  @override
  Widget build(BuildContext context) {
    final name = competency.name?.isNotEmpty == true
        ? competency.name!
        : (competency.code ?? essT('competencies.unnamed', 'Yetkinlik'));
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
                    name,
                    style: AppTypography.headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (competency.isGlobal)
                  AppBadge(
                    label: essT('competencies.global', 'Genel'),
                    variant: AppBadgeVariant.info,
                    size: AppBadgeSize.small,
                  )
                else
                  AppBadge(
                    label: essT(
                        competency.active ? 'common.active' : 'common.inactive',
                        competency.active ? 'Aktif' : 'Pasif'),
                    variant: competency.active
                        ? AppBadgeVariant.success
                        : AppBadgeVariant.neutral,
                    size: AppBadgeSize.small,
                  ),
              ],
            ),
            if (competency.category != null &&
                competency.category!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Icon(Icons.category_outlined,
                      size: 14, color: AppColors.tertiaryLabel(context)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      competency.category!,
                      style: AppTypography.footnote
                          .copyWith(color: AppColors.secondaryLabel(context)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (competency.description != null &&
                competency.description!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                competency.description!,
                style: AppTypography.caption1
                    .copyWith(color: AppColors.tertiaryLabel(context)),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
