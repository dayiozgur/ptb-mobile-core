import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class SiteSelectorScreen extends StatefulWidget {
  const SiteSelectorScreen({super.key});

  @override
  State<SiteSelectorScreen> createState() => _SiteSelectorScreenState();
}

class _SiteSelectorScreenState extends State<SiteSelectorScreen> {
  List<Site> _sites = [];
  bool _isLoading = true;
  String? _error;
  final Map<String, int> _siteAlarmCounts = {};

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  Future<void> _loadSites() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final organizationId = organizationService.currentOrganizationId;
      if (organizationId == null) {
        setState(() {
          _error = 'Organizasyon secilmemis';
          _isLoading = false;
        });
        return;
      }

      final sites = await siteService.getSites(organizationId);

      setState(() {
        _sites = sites;
        _isLoading = false;
      });

      _loadAlarmCounts(sites);
    } catch (e) {
      Logger.error('Failed to load sites', e);
      setState(() {
        _error = 'Siteler yuklenemedi';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAlarmCounts(List<Site> sites) async {
    for (final site in sites) {
      try {
        final count = await alarmService.getResetAlarmCountBySite(site.id);
        if (mounted && count > 0) {
          setState(() {
            _siteAlarmCounts[site.id] = count;
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _selectSite(Site site) async {
    final success = await siteService.selectSite(site.id);
    if (success && mounted) {
      context.go('/dashboard');
    } else if (mounted) {
      AppSnackbar.showError(
        context,
        message: 'Site secilemedi',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Site Sec',
      showBackButton: true,
      onBack: () => context.go('/organizations'),
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
        onAction: _loadSites,
      );
    }

    if (_sites.isEmpty) {
      return const AppEmptyState(
        icon: Icons.location_city_outlined,
        title: 'Site Bulunamadi',
        message: 'Bu organizasyonda henuz site yok.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSites,
      child: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          _buildOrganizationInfo(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Devam etmek icin bir site secin',
            style: AppTypography.subheadline.copyWith(
              color: AppColors.secondaryLabel(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          ...List.generate(_sites.length, (index) {
            final site = _sites[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < _sites.length - 1 ? AppSpacing.sm : 0,
              ),
              child: _SiteCard(
                site: site,
                alarmCount: _siteAlarmCounts[site.id] ?? 0,
                onTap: () => _selectSite(site),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOrganizationInfo() {
    final org = organizationService.currentOrganization;
    if (org == null) return const SizedBox.shrink();

    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            Icon(
              Icons.apartment,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    org.name,
                    style: AppTypography.subheadline,
                  ),
                  if (org.city != null)
                    Text(
                      org.city!,
                      style: AppTypography.caption1.copyWith(
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.go('/organizations'),
              child: const Text('Degistir'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SiteCard extends StatelessWidget {
  final Site site;
  final int alarmCount;
  final VoidCallback onTap;

  const _SiteCard({
    required this.site,
    this.alarmCount = 0,
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
                color: _getColorFromString(site.color),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: site.imagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          site.imagePath!,
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
                    site.name,
                    style: AppTypography.headline,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: [
                      if (site.floorCount != null) ...[
                        _InfoChip(
                          icon: Icons.layers,
                          label: '${site.floorCount} Kat',
                        ),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      if (site.grossAreaSqm != null) ...[
                        _InfoChip(
                          icon: Icons.square_foot,
                          label: '${site.grossAreaSqm!.toInt()} m2',
                        ),
                      ],
                    ],
                  ),
                  if (site.address != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.tertiaryLabel(context),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            site.fullAddress,
                            style: AppTypography.caption2.copyWith(
                              color: AppColors.tertiaryLabel(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (alarmCount > 0) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber, size: 14, color: AppColors.error),
                    const SizedBox(width: 4),
                    Text(
                      '$alarmCount',
                      style: AppTypography.caption2.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
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
      Icons.location_city,
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: AppColors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption2.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
