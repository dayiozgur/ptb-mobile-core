import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';

/// İK yönetim "İş İlanları" görüntüleyici (salt-okuma, v1).
///
/// `/admin/recruitment/postings` → tenant'ın `job_postings` satırlarını listeler:
/// başlık, departman, durum rozeti, açık pozisyon + başvuru sayısı, tarih.
/// Veri kaynağı [AdminRecruitmentService.postings] (web `AtsService.getPostings`
/// ile birebir sözleşme).
class AdminRecruitmentPostingsScreen extends StatefulWidget {
  const AdminRecruitmentPostingsScreen({super.key});

  @override
  State<AdminRecruitmentPostingsScreen> createState() =>
      _AdminRecruitmentPostingsScreenState();
}

class _AdminRecruitmentPostingsScreenState
    extends State<AdminRecruitmentPostingsScreen> {
  final _ctrl = AsyncViewController();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('ats.postings.title', 'İş İlanları'),
      showBackButton: true,
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _ctrl.reload),
      ],
      child: AsyncView<List<JobPostingRow>>(
        controller: _ctrl,
        load: () => adminRecruitmentService.postings(),
        errorFallback: essT('common.data_load_error', 'Veriler yüklenemedi'),
        isEmpty: (postings) => postings.isEmpty,
        emptyIcon: Icons.work_outline,
        emptyTitle: essT('ats.postings.empty', 'İlan bulunamadı'),
        builder: (context, postings) => _content(context, postings),
      ),
    );
  }

  Widget _content(BuildContext context, List<JobPostingRow> postings) {
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: postings.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _PostingCard(posting: postings[i]),
    );
  }
}

/// İlan durum kodu → Türkçe etiket.
String _postingStatusLabel(String? status) {
  switch (status?.toLowerCase()) {
    case 'draft':
      return essT('ats.posting_status.draft', 'Taslak');
    case 'open':
      return essT('ats.posting_status.open', 'Açık');
    case 'on_hold':
      return essT('ats.posting_status.on_hold', 'Beklemede');
    case 'closed':
      return essT('ats.posting_status.closed', 'Kapalı');
    default:
      return essStatusLabel(status);
  }
}

/// İlan durum kodu → rozet varyantı.
AppBadgeVariant _postingStatusVariant(String? status) {
  switch (status?.toLowerCase()) {
    case 'open':
      return AppBadgeVariant.success;
    case 'on_hold':
      return AppBadgeVariant.warning;
    case 'closed':
      return AppBadgeVariant.neutral;
    case 'draft':
      return AppBadgeVariant.info;
    default:
      return essStatusVariant(status);
  }
}

class _PostingCard extends StatelessWidget {
  final JobPostingRow posting;

  const _PostingCard({required this.posting});

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
                    posting.title,
                    style: AppTypography.headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppBadge(
                  label: _postingStatusLabel(posting.status),
                  variant: _postingStatusVariant(posting.status),
                  size: AppBadgeSize.small,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              posting.departmentName?.isNotEmpty == true
                  ? posting.departmentName!
                  : essT('ats.posting.no_department', 'Departman yok'),
              style: AppTypography.footnote
                  .copyWith(color: AppColors.secondaryLabel(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.people_outline,
                    size: 14, color: AppColors.tertiaryLabel(context)),
                const SizedBox(width: 4),
                Text(
                  '${posting.applicantCount} ${essT('ats.posting.applicants', 'başvuru')}',
                  style: AppTypography.footnote
                      .copyWith(color: AppColors.secondaryLabel(context)),
                ),
                const SizedBox(width: AppSpacing.md),
                Icon(Icons.badge_outlined,
                    size: 14, color: AppColors.tertiaryLabel(context)),
                const SizedBox(width: 4),
                Text(
                  '${posting.openings} ${essT('ats.posting.openings', 'açık pozisyon')}',
                  style: AppTypography.footnote
                      .copyWith(color: AppColors.secondaryLabel(context)),
                ),
                const Spacer(),
                if (posting.createdAt != null)
                  Text(
                    essDate(posting.createdAt),
                    style: AppTypography.caption1
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
