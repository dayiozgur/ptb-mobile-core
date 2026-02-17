import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class SitesListScreen extends StatefulWidget {
  const SitesListScreen({super.key});

  @override
  State<SitesListScreen> createState() => _SitesListScreenState();
}

class _SitesListScreenState extends State<SitesListScreen> {
  List<Site> _sites = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
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

  List<Site> get _filteredSites {
    if (_searchQuery.isEmpty) return _sites;
    final query = _searchQuery.toLowerCase();
    return _sites.where((site) {
      return site.name.toLowerCase().contains(query) ||
          (site.address?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  void _selectSite(Site site) {
    context.push('/sites/${site.id}');
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Siteler',
      showBackButton: false,
      actions: [
        AppIconButton(
          icon: Icons.refresh,
          onPressed: _loadSites,
        ),
      ],
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

    final filteredSites = _filteredSites;

    return RefreshIndicator(
      onRefresh: _loadSites,
      child: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: AppSearchField(
              placeholder: 'Site ara...',
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),

          // Sites list
          Expanded(
            child: filteredSites.isEmpty
                ? Center(
                    child: AppEmptyState(
                      icon: Icons.search_off,
                      title: 'Sonuc Bulunamadi',
                      message: '"$_searchQuery" ile eslesen site yok',
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal,
                    ),
                    itemCount: filteredSites.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final site = filteredSites[index];
                      return _SiteCard(
                        site: site,
                        alarmCount: _siteAlarmCounts[site.id] ?? 0,
                        onTap: () => _selectSite(site),
                      );
                    },
                  ),
          ),
        ],
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
