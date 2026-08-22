import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';
import 'admin_recruitment_candidates_screen.dart' show atsStageLabel, atsStageVariant;

/// İK yönetim "İşe Alım Hattı" görüntüleyici (salt-okuma, v1).
///
/// `/admin/recruitment/pipeline` → `job_applications` satırlarını `stage`
/// kolonuna göre kanonik hat sırasında gruplar; her aşama için başlık + sayı
/// rozeti + o aşamadaki başvuru kartları. v1: sürükle-bırak kanban DEĞİL, basit
/// gruplu liste. Veri kaynağı [AdminRecruitmentService.pipelineByStage].
class AdminRecruitmentPipelineScreen extends StatefulWidget {
  const AdminRecruitmentPipelineScreen({super.key});

  @override
  State<AdminRecruitmentPipelineScreen> createState() =>
      _AdminRecruitmentPipelineScreenState();
}

class _AdminRecruitmentPipelineScreenState
    extends State<AdminRecruitmentPipelineScreen> {
  final _ctrl = AsyncViewController();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('ats.pipeline.title', 'İşe Alım Hattı'),
      showBackButton: true,
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _ctrl.reload),
      ],
      child: AsyncView<List<PipelineStageGroup>>(
        controller: _ctrl,
        load: () => adminRecruitmentService.pipelineByStage(),
        errorFallback: essT('common.data_load_error', 'Veriler yüklenemedi'),
        isEmpty: (groups) => groups.fold<int>(0, (a, g) => a + g.count) == 0,
        emptyIcon: Icons.account_tree_outlined,
        emptyTitle: essT('ats.pipeline.empty', 'Başvuru bulunamadı'),
        builder: (context, groups) => _content(context, groups),
      ),
    );
  }

  Widget _content(BuildContext context, List<PipelineStageGroup> groups) {
    return ListView.builder(
      padding: AppSpacing.screenPadding,
      itemCount: groups.length,
      itemBuilder: (_, i) => _StageSection(group: groups[i]),
    );
  }
}

class _StageSection extends StatelessWidget {
  final PipelineStageGroup group;

  const _StageSection({required this.group});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              AppBadge(
                label: atsStageLabel(group.stage),
                variant: atsStageVariant(group.stage),
                size: AppBadgeSize.small,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${group.count}',
                style: AppTypography.footnote.copyWith(
                  color: AppColors.tertiaryLabel(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (group.applications.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              essT('ats.pipeline.stage_empty', 'Bu aşamada aday yok'),
              style: AppTypography.caption1
                  .copyWith(color: AppColors.tertiaryLabel(context)),
            ),
          )
        else
          ...group.applications.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _PipelineCard(application: a),
            ),
          ),
      ],
    );
  }
}

class _PipelineCard extends StatelessWidget {
  final JobApplicationRow application;

  const _PipelineCard({required this.application});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    application.displayName,
                    style: AppTypography.subhead
                        .copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    application.postingTitle?.isNotEmpty == true
                        ? application.postingTitle!
                        : essT('ats.application.no_posting', 'İlan yok'),
                    style: AppTypography.footnote
                        .copyWith(color: AppColors.secondaryLabel(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (application.displayDate != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                essDate(application.displayDate),
                style: AppTypography.caption1
                    .copyWith(color: AppColors.tertiaryLabel(context)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
