import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../ess_common.dart';

/// Çalışanın kendi performans değerlendirmeleri (salt-okuma v1).
///
/// `/hr/performance/my-reviews` → her satır dönem + değerlendiren + durum rozeti
/// + genel puan gösterir; dokununca detay alt-sayfası (bottom-sheet) açılır.
/// Veri kaynağı: `HrEssService.myReviews()` (web `PerformanceService.getMyReviews`
/// ile birebir sözleşme; `performance_reviews`, `staff_id`=ben).
class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  final _ctrl = AsyncViewController();

  void _openDetail(PerformanceReview review) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ReviewDetailSheet(review: review),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('hr.performance.my_reviews', 'Değerlendirmelerim'),
      showBackButton: true,
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _ctrl.reload),
      ],
      child: AsyncView<List<PerformanceReview>>(
        controller: _ctrl,
        load: () => hrEssService.myReviews(),
        errorFallback: essT('common.data_load_error', 'Veriler yüklenemedi'),
        isEmpty: (d) => d.isEmpty,
        emptyIcon: Icons.assignment_turned_in_outlined,
        emptyTitle:
            essT('hr.performance.no_reviews', 'Değerlendirme bulunamadı'),
        builder: (context, d) => _content(context, d),
      ),
    );
  }

  Widget _content(BuildContext context, List<PerformanceReview> reviews) {
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: reviews.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _ReviewCard(
        review: reviews[i],
        onTap: () => _openDetail(reviews[i]),
      ),
    );
  }
}

/// Değerlendirme durum kodu → Türkçe etiket.
String _reviewStatusLabel(String? status) {
  switch (status?.toLowerCase()) {
    case 'pending':
      return essT('performance.review_status.pending', 'Beklemede');
    case 'self_submitted':
      return essT('performance.review_status.self_submitted', 'Öz-değerlendirildi');
    case 'manager_submitted':
      return essT(
          'performance.review_status.manager_submitted', 'Yönetici değerlendirdi');
    case 'finalized':
      return essT('performance.review_status.finalized', 'Sonuçlandı');
    default:
      return essStatusLabel(status);
  }
}

/// Değerlendirme durum kodu → rozet varyantı.
AppBadgeVariant _reviewStatusVariant(String? status) {
  switch (status?.toLowerCase()) {
    case 'finalized':
      return AppBadgeVariant.success;
    case 'manager_submitted':
      return AppBadgeVariant.info;
    case 'self_submitted':
      return AppBadgeVariant.warning;
    case 'pending':
      return AppBadgeVariant.neutral;
    default:
      return essStatusVariant(status);
  }
}

/// Puanı `X/5` biçimine getirir (yoksa `—`).
String _ratingStr(num? rating) {
  if (rating == null || rating == 0) return '—';
  final v = rating == rating.roundToDouble()
      ? rating.toInt().toString()
      : rating.toString();
  return '$v/5';
}

class _ReviewCard extends StatelessWidget {
  final PerformanceReview review;
  final VoidCallback onTap;

  const _ReviewCard({required this.review, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    review.cycleName?.isNotEmpty == true
                        ? review.cycleName!
                        : essT('performance.common.unknown_cycle', 'Dönem'),
                    style: AppTypography.headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppBadge(
                  label: _reviewStatusLabel(review.status),
                  variant: _reviewStatusVariant(review.status),
                  size: AppBadgeSize.small,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.person_outline,
                    size: 14, color: AppColors.tertiaryLabel(context)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    review.reviewerName ??
                        essT('performance.review.no_reviewer', 'Atanmadı'),
                    style: AppTypography.footnote
                        .copyWith(color: AppColors.secondaryLabel(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${essT('performance.review.overall_rating', 'Genel')}: ${_ratingStr(review.overallRating)}',
                  style: AppTypography.footnote.copyWith(
                    color: AppColors.primaryLabel(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (review.displayDate != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                essDate(review.displayDate),
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

class _ReviewDetailSheet extends StatelessWidget {
  final PerformanceReview review;

  const _ReviewDetailSheet({required this.review});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.separator(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    review.cycleName?.isNotEmpty == true
                        ? review.cycleName!
                        : essT('performance.common.unknown_cycle', 'Dönem'),
                    style: AppTypography.title3,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppBadge(
                  label: _reviewStatusLabel(review.status),
                  variant: _reviewStatusVariant(review.status),
                  size: AppBadgeSize.small,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _DetailRow(
              label: essT('performance.review.col_reviewer', 'Değerlendiren'),
              value: review.reviewerName ?? '-',
            ),
            if (review.displayDate != null)
              _DetailRow(
                label: essT('performance.review.date', 'Tarih'),
                value: essDate(review.displayDate),
              ),
            const SizedBox(height: AppSpacing.sm),

            // Puanlar
            Text(
              essT('performance.review.ratings', 'Puanlar'),
              style: AppTypography.footnote
                  .copyWith(color: AppColors.secondaryLabel(context)),
            ),
            const SizedBox(height: AppSpacing.xxs),
            _DetailRow(
              label: essT('performance.review.self_rating', 'Öz değerlendirme'),
              value: _ratingStr(review.selfRating),
            ),
            _DetailRow(
              label: essT('performance.review.manager_rating', 'Yönetici'),
              value: _ratingStr(review.managerRating),
            ),
            _DetailRow(
              label: essT('performance.review.overall_rating', 'Genel'),
              value: _ratingStr(review.overallRating),
            ),

            if (review.selfComments != null &&
                review.selfComments!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                essT('performance.review.self_comments', 'Öz-değerlendirme notu'),
                style: AppTypography.footnote
                    .copyWith(color: AppColors.secondaryLabel(context)),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(review.selfComments!, style: AppTypography.body),
            ],
            if (review.managerComments != null &&
                review.managerComments!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                essT('performance.review.manager_comments', 'Yönetici notu'),
                style: AppTypography.footnote
                    .copyWith(color: AppColors.secondaryLabel(context)),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(review.managerComments!, style: AppTypography.body),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: AppTypography.footnote
                  .copyWith(color: AppColors.secondaryLabel(context)),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value,
              style: AppTypography.footnote.copyWith(
                color: AppColors.primaryLabel(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
