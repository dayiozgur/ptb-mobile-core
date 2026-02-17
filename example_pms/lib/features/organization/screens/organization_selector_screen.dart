import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class OrganizationSelectorScreen extends StatefulWidget {
  const OrganizationSelectorScreen({super.key});

  @override
  State<OrganizationSelectorScreen> createState() =>
      _OrganizationSelectorScreenState();
}

class _OrganizationSelectorScreenState
    extends State<OrganizationSelectorScreen> {
  List<Organization> _organizations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkRestoredOrganization();
  }

  Future<void> _checkRestoredOrganization() async {
    final currentOrg = organizationService.currentOrganization;
    if (currentOrg != null && currentOrg.active) {
      if (mounted) {
        context.go('/main');
        return;
      }
    }
    _loadOrganizations();
  }

  Future<void> _loadOrganizations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tenantId = tenantService.currentTenantId;
      if (tenantId == null) {
        setState(() {
          _error = 'Tenant secilmemis';
          _isLoading = false;
        });
        return;
      }

      final organizations =
          await organizationService.getOrganizations(tenantId);

      setState(() {
        _organizations = organizations;
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Failed to load organizations', e);
      setState(() {
        _error = 'Organizasyonlar yuklenemedi';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectOrganization(Organization organization) async {
    final success =
        await organizationService.selectOrganization(organization.id);
    if (success && mounted) {
      context.go('/main');
    } else if (mounted) {
      AppSnackbar.showError(
        context,
        message: 'Organizasyon secilemedi',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Organizasyon Sec',
      showBackButton: true,
      onBack: () => context.go('/tenant-select'),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: AppLoadingIndicator());
    }

    if (_error != null) {
      return AppErrorView(
        title: 'Hata',
        message: _error!,
        actionLabel: 'Tekrar Dene',
        onAction: _loadOrganizations,
      );
    }

    if (_organizations.isEmpty) {
      return const AppEmptyState(
        icon: Icons.apartment_outlined,
        title: 'Organizasyon Bulunamadi',
        message: 'Bu tenant\'ta henuz organizasyon yok.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrganizations,
      child: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          Text(
            'Devam etmek icin bir organizasyon secin',
            style: AppTypography.subheadline.copyWith(
              color: AppColors.secondaryLabel(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          ...List.generate(_organizations.length, (index) {
            final org = _organizations[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < _organizations.length - 1 ? AppSpacing.sm : 0,
              ),
              child: _OrganizationCard(
                organization: org,
                onTap: () => _selectOrganization(org),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _OrganizationCard extends StatelessWidget {
  final Organization organization;
  final VoidCallback onTap;

  const _OrganizationCard({
    required this.organization,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getColorFromString(organization.color),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: organization.imagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          organization.imagePath!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildIcon(),
                        ),
                      )
                    : _buildIcon(),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    organization.name,
                    style: AppTypography.headline,
                  ),
                  if (organization.description != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      organization.description!,
                      style: AppTypography.caption1.copyWith(
                        color: AppColors.secondaryLabel(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (organization.city != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.tertiaryLabel(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          organization.city!,
                          style: AppTypography.caption2.copyWith(
                            color: AppColors.tertiaryLabel(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.tertiaryLabel(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return const Icon(
      Icons.apartment,
      color: Colors.white,
      size: 24,
    );
  }

  Color _getColorFromString(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return AppColors.primary;
    }

    try {
      if (colorString.startsWith('#')) {
        return Color(
            int.parse(colorString.substring(1), radix: 16) + 0xFF000000);
      }
      return AppColors.primary;
    } catch (_) {
      return AppColors.primary;
    }
  }
}
