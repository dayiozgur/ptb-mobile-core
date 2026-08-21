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
  bool _isLoading = true;
  String? _errorMessage;
  List<Competency> _competencies = [];

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
      final rows = await adminPerformanceService.competencies();
      if (mounted) {
        setState(() {
          _competencies = rows;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('AdminCompetenciesScreen yükleme hatası', e);
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
      title: essT('competencies.title', 'Yetkinlikler'),
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
    if (_competencies.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: AppEmptyState(
                icon: Icons.workspace_premium_outlined,
                title: essT('competencies.empty', 'Yetkinlik bulunamadı'),
              ),
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: _competencies.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _CompetencyCard(competency: _competencies[i]),
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
