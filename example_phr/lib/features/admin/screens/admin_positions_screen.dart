import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';

/// Admin "Pozisyonlar" görüntüleyici (salt-okuma, v1).
///
/// Web `PositionService` list yolunu aynalar (`positions`, tenant-kapsamlı).
/// Her satır: ad + kod + kademe rozeti.
class AdminPositionsScreen extends StatefulWidget {
  const AdminPositionsScreen({super.key});

  @override
  State<AdminPositionsScreen> createState() => _AdminPositionsScreenState();
}

class _AdminPositionsScreenState extends State<AdminPositionsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<AdminPosition> _positions = [];

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
      final rows = await adminOrgService.positions();
      if (mounted) {
        setState(() {
          _positions = rows;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('AdminPositionsScreen yükleme hatası', e);
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
      title: essT('hr.positions.title', 'Pozisyonlar'),
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
    if (_positions.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: AppEmptyState(
                icon: Icons.badge_outlined,
                title: essT('hr.positions.empty', 'Pozisyon bulunamadı'),
              ),
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: _positions.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _PositionCard(position: _positions[i]),
    );
  }
}

class _PositionCard extends StatelessWidget {
  final AdminPosition position;

  const _PositionCard({required this.position});

  @override
  Widget build(BuildContext context) {
    final code = position.code?.trim();
    final desc = position.description?.trim();

    final subtitleParts = <String>[
      if (code != null && code.isNotEmpty) code,
      if (desc != null && desc.isNotEmpty) desc,
    ];

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
              child: Icon(Icons.badge_outlined, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    position.name?.trim().isNotEmpty == true
                        ? position.name!
                        : '—',
                    style: AppTypography.headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitleParts.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitleParts.join(' · '),
                      style: AppTypography.caption1.copyWith(
                        color: AppColors.secondaryLabel(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (position.level != null)
              AppBadge(
                label: essT('hr.positions.level', 'Kademe') +
                    ' ${position.level}',
                variant: AppBadgeVariant.neutral,
                size: AppBadgeSize.small,
              ),
          ],
        ),
      ),
    );
  }
}
