import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';

/// Admin "Organizasyonlar" yönetim listesi (salt-okuma, v1).
///
/// Web `OrganizationService.getOrganizations` yolunu aynalar (`organizations`,
/// tenant-kapsamlı). NOT: çekirdek `/organizations` ekranı bir SEÇİCİ'dir; bu
/// ekran ise yönetim LİSTESİ (farklı amaç). Her satır: ad + kod/şehir +
/// hiyerarşi rozeti (kök / seviye).
class AdminOrganizationsScreen extends StatefulWidget {
  const AdminOrganizationsScreen({super.key});

  @override
  State<AdminOrganizationsScreen> createState() =>
      _AdminOrganizationsScreenState();
}

class _AdminOrganizationsScreenState extends State<AdminOrganizationsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<AdminOrganization> _orgs = [];

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
      final rows = await adminOrgService.organizations();
      if (mounted) {
        setState(() {
          _orgs = rows;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('AdminOrganizationsScreen yükleme hatası', e);
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
      title: essT('hr.organizations.title', 'Organizasyonlar'),
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
    if (_orgs.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: AppEmptyState(
                icon: Icons.corporate_fare_outlined,
                title: essT('hr.organizations.empty', 'Organizasyon bulunamadı'),
              ),
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: _orgs.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _OrganizationCard(org: _orgs[i]),
    );
  }
}

class _OrganizationCard extends StatelessWidget {
  final AdminOrganization org;

  const _OrganizationCard({required this.org});

  @override
  Widget build(BuildContext context) {
    final code = org.code?.trim();
    final city = org.city?.trim();

    final subtitleParts = <String>[
      if (code != null && code.isNotEmpty) code,
      if (city != null && city.isNotEmpty) city,
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
              child: Icon(Icons.corporate_fare_outlined,
                  color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    org.name?.trim().isNotEmpty == true ? org.name! : '—',
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
            AppBadge(
              label: org.isRoot
                  ? essT('hr.organizations.root', 'Kök')
                  : essT('hr.organizations.level', 'Seviye') +
                      ' ${org.hierarchyLevel ?? '-'}',
              variant:
                  org.isRoot ? AppBadgeVariant.primary : AppBadgeVariant.neutral,
              size: AppBadgeSize.small,
            ),
          ],
        ),
      ),
    );
  }
}
