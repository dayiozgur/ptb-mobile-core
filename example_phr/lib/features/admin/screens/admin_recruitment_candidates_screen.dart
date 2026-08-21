import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';

/// İK yönetim "Adaylar" görüntüleyici (salt-okuma, v1).
///
/// `/admin/recruitment/candidates` → tenant'ın `job_applications` satırlarını
/// listeler: aday adı, başvurulan ilan başlığı, hat aşaması rozeti, başvuru
/// tarihi. (Aday adı `job_candidates` embed'inden çözülür — ayrı `candidates`
/// tablosu yoktur.) Veri kaynağı [AdminRecruitmentService.applications] (web
/// `AtsService.getApplications` ile birebir sözleşme).
class AdminRecruitmentCandidatesScreen extends StatefulWidget {
  const AdminRecruitmentCandidatesScreen({super.key});

  @override
  State<AdminRecruitmentCandidatesScreen> createState() =>
      _AdminRecruitmentCandidatesScreenState();
}

class _AdminRecruitmentCandidatesScreenState
    extends State<AdminRecruitmentCandidatesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<JobApplicationRow> _applications = [];

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
      final rows = await adminRecruitmentService.applications();
      if (mounted) {
        setState(() {
          _applications = rows;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('AdminRecruitmentCandidatesScreen yükleme hatası', e);
      if (mounted) {
        setState(() {
          _errorMessage = essT('common.data_load_error', 'Veriler yüklenemedi');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('ats.candidates.title', 'Adaylar'),
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
    if (_applications.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: AppEmptyState(
                icon: Icons.people_outline,
                title: essT('ats.candidates.empty', 'Aday bulunamadı'),
              ),
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: _applications.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _ApplicationCard(application: _applications[i]),
    );
  }
}

/// Hat aşaması kodu → Türkçe etiket.
String atsStageLabel(String? stage) {
  switch (stage?.toLowerCase()) {
    case 'applied':
      return essT('ats.stage.applied', 'Başvurdu');
    case 'screening':
      return essT('ats.stage.screening', 'Ön Eleme');
    case 'interview':
      return essT('ats.stage.interview', 'Mülakat');
    case 'offer':
      return essT('ats.stage.offer', 'Teklif');
    case 'hired':
      return essT('ats.stage.hired', 'İşe Alındı');
    case 'rejected':
      return essT('ats.stage.rejected', 'Reddedildi');
    default:
      return essStatusLabel(stage);
  }
}

/// Hat aşaması kodu → rozet varyantı.
AppBadgeVariant atsStageVariant(String? stage) {
  switch (stage?.toLowerCase()) {
    case 'hired':
      return AppBadgeVariant.success;
    case 'rejected':
      return AppBadgeVariant.error;
    case 'offer':
      return AppBadgeVariant.info;
    case 'interview':
    case 'screening':
      return AppBadgeVariant.warning;
    case 'applied':
      return AppBadgeVariant.neutral;
    default:
      return essStatusVariant(stage);
  }
}

class _ApplicationCard extends StatelessWidget {
  final JobApplicationRow application;

  const _ApplicationCard({required this.application});

  @override
  Widget build(BuildContext context) {
    return AppCard(
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
              child: Icon(Icons.person_outline, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    application.displayName,
                    style: AppTypography.headline,
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
                  if (application.displayDate != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      essDate(application.displayDate),
                      style: AppTypography.caption1
                          .copyWith(color: AppColors.tertiaryLabel(context)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppBadge(
              label: atsStageLabel(application.stage),
              variant: atsStageVariant(application.stage),
              size: AppBadgeSize.small,
            ),
          ],
        ),
      ),
    );
  }
}
