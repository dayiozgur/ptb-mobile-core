import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../ess_common.dart';

/// Değerlendirme Kuyruğu — `/hr/performance/review-queue` (yönetici).
///
/// Mevcut kullanıcının değerlendirmesi gereken performans değerlendirmeleri
/// (`reviewer_staff_id = benim staff'ım`). Her satır değerlendirilen kişi +
/// dönem + durum rozeti + genel puanı gösterir; dokununca detay alt-sayfası
/// (öz/yönetici puanları, notlar, yetkinlik kırılımı) açılır.
///
/// v1 SALT-OKUMA: web'deki yönetici puanlama/sonuçlandırma akışı (managerRating
/// + overallRating yazımı) mobilde henüz YOK — yalnızca görüntüleme. Veri kaynağı:
/// `HrCalendarReviewService.reviewQueue()` (web `PerformanceService.getReviewQueue`
/// ile birebir sözleşme).
class ReviewQueueScreen extends StatefulWidget {
  const ReviewQueueScreen({super.key});

  @override
  State<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends State<ReviewQueueScreen> {
  final _ctrl = AsyncViewController();

  void _openDetail(ReviewQueueItem review) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ReviewQueueDetailSheet(review: review),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('hr.performance.review_queue', 'Değerlendirme Kuyruğu'),
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _ctrl.reload),
      ],
      child: AsyncView<List<ReviewQueueItem>>(
        controller: _ctrl,
        load: () => hrCalendarReviewService.reviewQueue(),
        errorFallback: essT('common.data_load_error', 'Veriler yüklenemedi'),
        isEmpty: (d) => d.isEmpty,
        emptyIcon: Icons.fact_check_outlined,
        emptyTitle: essT('hr.performance.review_queue_empty',
            'Değerlendirilecek kayıt yok'),
        builder: (context, d) => _content(context, d),
      ),
    );
  }

  Widget _content(BuildContext context, List<ReviewQueueItem> reviews) {
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: reviews.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _ReviewQueueCard(
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
      return essT(
          'performance.review_status.self_submitted', 'Öz-değerlendirildi');
    case 'manager_submitted':
      return essT('performance.review_status.manager_submitted',
          'Yönetici değerlendirdi');
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

class _ReviewQueueCard extends StatelessWidget {
  final ReviewQueueItem review;
  final VoidCallback onTap;

  const _ReviewQueueCard({required this.review, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = review.staffName?.isNotEmpty == true
        ? review.staffName!
        : essT('performance.review_queue.unknown_staff', 'Personel');
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
                    name,
                    style: AppTypography.headline,
                    maxLines: 1,
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
                Icon(Icons.event_note_outlined,
                    size: 14, color: AppColors.tertiaryLabel(context)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    review.cycleName?.isNotEmpty == true
                        ? review.cycleName!
                        : essT('performance.common.unknown_cycle', 'Dönem'),
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
          ],
        ),
      ),
    );
  }
}

/// Detay alt-sayfası — puanlar, notlar ve (asenkron yüklenen) yetkinlik kırılımı.
class _ReviewQueueDetailSheet extends StatefulWidget {
  final ReviewQueueItem review;

  const _ReviewQueueDetailSheet({required this.review});

  @override
  State<_ReviewQueueDetailSheet> createState() =>
      _ReviewQueueDetailSheetState();
}

class _ReviewQueueDetailSheetState extends State<_ReviewQueueDetailSheet> {
  bool _loadingComps = true;
  List<ReviewCompetencyRating> _competencies = [];

  @override
  void initState() {
    super.initState();
    _loadCompetencies();
  }

  Future<void> _loadCompetencies() async {
    try {
      final rows =
          await hrCalendarReviewService.reviewCompetencies(widget.review.id);
      if (mounted) {
        setState(() {
          _competencies = rows;
          _loadingComps = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load review competencies', e);
      if (mounted) setState(() => _loadingComps = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.review;
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
                    r.staffName?.isNotEmpty == true
                        ? r.staffName!
                        : essT('performance.review_queue.unknown_staff',
                            'Personel'),
                    style: AppTypography.title3,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppBadge(
                  label: _reviewStatusLabel(r.status),
                  variant: _reviewStatusVariant(r.status),
                  size: AppBadgeSize.small,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _DetailRow(
              label: essT('performance.review.cycle', 'Dönem'),
              value: r.cycleName ?? '-',
            ),
            if (r.displayDate != null)
              _DetailRow(
                label: essT('performance.review.date', 'Tarih'),
                value: essDate(r.displayDate),
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
              value: _ratingStr(r.selfRating),
            ),
            _DetailRow(
              label: essT('performance.review.manager_rating', 'Yönetici'),
              value: _ratingStr(r.managerRating),
            ),
            _DetailRow(
              label: essT('performance.review.overall_rating', 'Genel'),
              value: _ratingStr(r.overallRating),
            ),

            if (r.selfComments != null && r.selfComments!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                essT('performance.review.self_comments',
                    'Öz-değerlendirme notu'),
                style: AppTypography.footnote
                    .copyWith(color: AppColors.secondaryLabel(context)),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(r.selfComments!, style: AppTypography.body),
            ],
            if (r.managerComments != null && r.managerComments!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                essT('performance.review.manager_comments', 'Yönetici notu'),
                style: AppTypography.footnote
                    .copyWith(color: AppColors.secondaryLabel(context)),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(r.managerComments!, style: AppTypography.body),
            ],

            // Yetkinlikler
            const SizedBox(height: AppSpacing.md),
            Text(
              essT('performance.review_queue.competencies', 'Yetkinlikler'),
              style: AppTypography.footnote
                  .copyWith(color: AppColors.secondaryLabel(context)),
            ),
            const SizedBox(height: AppSpacing.xs),
            _buildCompetencies(context),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _buildCompetencies(BuildContext context) {
    if (_loadingComps) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Center(child: AppLoadingIndicator()),
      );
    }
    if (_competencies.isEmpty) {
      return Text(
        essT('performance.review_queue.no_competencies',
            'Yetkinlik puanı girilmemiş'),
        style: AppTypography.caption1
            .copyWith(color: AppColors.tertiaryLabel(context)),
      );
    }
    return Column(
      children: _competencies
          .map((c) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.competencyLabel,
                              style: AppTypography.subheadline),
                          if (c.comment != null && c.comment!.isNotEmpty)
                            Text(
                              c.comment!,
                              style: AppTypography.caption1.copyWith(
                                  color: AppColors.tertiaryLabel(context)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppBadge(
                      label: _ratingStr(c.rating),
                      variant: AppBadgeVariant.info,
                      size: AppBadgeSize.small,
                    ),
                  ],
                ),
              ))
          .toList(),
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
