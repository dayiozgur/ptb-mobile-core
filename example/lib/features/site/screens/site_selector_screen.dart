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
          _error = 'Organizasyon seçilmemiş';
          _isLoading = false;
        });
        return;
      }

      final sites = await siteService.getSites(organizationId);

      setState(() {
        _sites = sites;
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Failed to load sites', e);
      setState(() {
        _error = 'Siteler yüklenemedi';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectSite(Site site) async {
    final success = await siteService.selectSite(site.id);
    if (success && mounted) {
      context.go('/home');
    } else if (mounted) {
      AppSnackbar.showError(
        context,
        message: 'Site seçilemedi',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Site Seç',
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
      return AppEmptyState(
        icon: Icons.location_city_outlined,
        title: 'Site Bulunamadı',
        message: 'Bu organizasyonda henüz site yok.\n'
            'Yeni bir site oluşturabilirsiniz.',
        actionLabel: 'Yeni Site Oluştur',
        onAction: _showCreateSiteDialog,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSites,
      child: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          // Organization info
          _buildOrganizationInfo(),
          const SizedBox(height: AppSpacing.lg),

          Text(
            'Devam etmek için bir site seçin',
            style: AppTypography.subheadline.copyWith(
              color: AppColors.secondaryLabel(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Site list
          ...List.generate(_sites.length, (index) {
            final site = _sites[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < _sites.length - 1 ? AppSpacing.sm : 0,
              ),
              child: _SiteCard(
                site: site,
                onTap: () => _selectSite(site),
              ),
            );
          }),

          const SizedBox(height: AppSpacing.xl),

          // Create new site button
          AppButton(
            label: 'Yeni Site Oluştur',
            variant: AppButtonVariant.secondary,
            icon: Icons.add,
            onPressed: _showCreateSiteDialog,
          ),
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
              child: const Text('Değiştir'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateSiteDialog() {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AppBottomSheet(
          title: 'Yeni Site',
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: nameController,
                    label: 'Site Adı',
                    placeholder: 'Örn: Merkez Bina',
                    prefixIcon: Icons.location_city,
                    validator: Validators.required('Site adı zorunludur'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: addressController,
                    label: 'Adres (Opsiyonel)',
                    placeholder: 'Site adresi',
                    prefixIcon: Icons.location_on,
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Oluştur',
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;

                      final organizationId =
                          organizationService.currentOrganizationId;
                      final tenantId = tenantService.currentTenantId;
                      final userId = authService.currentUser?.id;

                      if (organizationId == null ||
                          tenantId == null ||
                          userId == null) return;

                      final name = nameController.text.trim();
                      final address = addressController.text.trim();

                      // TODO: Marker oluşturma işlemi gerekli
                      // Şimdilik boş UUID kullanıyoruz
                      final site = await siteService.createSite(
                        organizationId: organizationId,
                        tenantId: tenantId,
                        name: name,
                        markerId: '00000000-0000-0000-0000-000000000000',
                        address: address.isNotEmpty ? address : null,
                        createdBy: userId,
                      );

                      if (context.mounted) {
                        Navigator.pop(context);

                        if (site != null) {
                          AppSnackbar.showSuccess(
                            context,
                            message: 'Site oluşturuldu',
                          );
                          _loadSites();
                        } else {
                          AppSnackbar.showError(
                            context,
                            message: 'Site oluşturulamadı',
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SiteCard extends StatelessWidget {
  final Site site;
  final VoidCallback onTap;

  const _SiteCard({
    required this.site,
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
            // Icon
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

            // Info
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
                          label: '${site.grossAreaSqm!.toInt()} m²',
                        ),
                      ],
                      if (site.energyCertificateClass != null) ...[
                        const SizedBox(width: AppSpacing.xs),
                        _InfoChip(
                          icon: Icons.eco,
                          label: site.energyCertificateClass!.value,
                          color: _getEnergyColor(site.energyCertificateClass!),
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

            // Arrow
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

  Color _getEnergyColor(EnergyCertificateClass certClass) {
    switch (certClass) {
      case EnergyCertificateClass.aPlus:
      case EnergyCertificateClass.a:
        return Colors.green;
      case EnergyCertificateClass.b:
        return Colors.lightGreen;
      case EnergyCertificateClass.c:
        return Colors.yellow.shade700;
      case EnergyCertificateClass.d:
        return Colors.orange;
      case EnergyCertificateClass.e:
      case EnergyCertificateClass.f:
        return Colors.deepOrange;
      case EnergyCertificateClass.g:
        return Colors.red;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (color ?? AppColors.primary).withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color ?? AppColors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption2.copyWith(
              color: color ?? AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
