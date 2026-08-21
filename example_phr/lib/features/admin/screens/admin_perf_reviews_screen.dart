import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';

/// İK yönetim "Tüm Değerlendirmeler" görüntüleyici (salt-okuma, v1).
///
/// `/admin/performance/reviews` → tenant genelindeki tüm `performance_reviews`
/// satırlarını listeler: değerlendirilen adı, değerlendiren adı, dönem,
/// öz/yönetici/genel puan, durum rozeti. Dokununca detay alt-sayfası açılır.
/// Veri kaynağı [AdminPerformanceService.allReviews] (web
/// `PerformanceService.getReviews` ile birebir sözleşme).
class AdminPerfReviewsScreen extends StatefulWidget {
  const AdminPerfReviewsScreen({super.key});

  @override
  State<AdminPerfReviewsScreen> createState() => _AdminPerfReviewsScreenState();
}

class _AdminPerfReviewsScreenState extends State<AdminPerfReviewsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<AdminPerformanceReview> _reviews = [];

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
      final rows = await adminPerformanceService.allReviews();
      if (mounted) {
        setState(() {
          _reviews = rows;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('AdminPerfReviewsScreen yükleme hatası', e);
      if (mounted) {
        setState(() {
          _errorMessage = essT('common.data_load_error', 'Veriler yüklenemedi');
          _isLoading = false;
        });
      }
    }
  }

  void _openDetail(AdminPerformanceReview review) {
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
      title: essT('performance.reviews_admin.title', 'Tüm Değerlendirmeler'),
      showBackButton: true,
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
    if (_reviews.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: AppEmptyState(
                icon: Icons.assignment_outlined,
                title: essT(
                    'performance.reviews_admin.empty', 'Değerlendirme bulunamadı'),
              ),
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: _reviews.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _ReviewCard(
        review: _reviews[i],
        onTap: () => _openDetail(_reviews[i]),
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
  final AdminPerformanceReview review;
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
                    review.revieweeName ??
                        essT('performance.review.no_reviewee', 'Değerlendirilen'),
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
            const SizedBox(height: AppSpacing.xxs),
            Text(
              review.cycleName?.isNotEmpty == true
                  ? review.cycleName!
                  : essT('performance.common.unknown_cycle', 'Dönem'),
              style: AppTypography.footnote
                  .copyWith(color: AppColors.secondaryLabel(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
          ],
        ),
      ),
    );
  }
}

class _ReviewDetailSheet extends StatelessWidget {
  final AdminPerformanceReview review;

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
                    review.revieweeName ??
                        essT('performance.review.no_reviewee', 'Değerlendirilen'),
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
              label: essT('performance.common.unknown_cycle', 'Dönem'),
              value: review.cycleName ?? '-',
            ),
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
