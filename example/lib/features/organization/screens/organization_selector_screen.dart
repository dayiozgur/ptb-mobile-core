import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Organizasyon Servisi instance'ı
final organizationService = OrganizationService(
  supabase: Supabase.instance.client,
  cacheManager: cacheManager,
);

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
          _error = 'Tenant seçilmemiş';
          _isLoading = false;
        });
        return;
      }

      final organizations = await organizationService.getOrganizations(tenantId);

      setState(() {
        _organizations = organizations;
        _isLoading = false;
      });

      // Tek organizasyon varsa otomatik seç
      if (organizations.length == 1) {
        await _selectOrganization(organizations.first);
      }
    } catch (e) {
      Logger.error('Failed to load organizations', e);
      setState(() {
        _error = 'Organizasyonlar yüklenemedi';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectOrganization(Organization organization) async {
    final success = await organizationService.selectOrganization(organization.id);
    if (success && mounted) {
      context.go('/sites');
    } else if (mounted) {
      AppSnackbar.showError(
        context,
        message: 'Organizasyon seçilemedi',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Organizasyon Seç',
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
      return AppEmptyState(
        icon: Icons.apartment_outlined,
        title: 'Organizasyon Bulunamadı',
        message: 'Bu tenant\'ta henüz organizasyon yok.\n'
            'Yeni bir organizasyon oluşturabilirsiniz.',
        actionLabel: 'Yeni Organizasyon Oluştur',
        onAction: _showCreateOrganizationDialog,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrganizations,
      child: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          Text(
            'Devam etmek için bir organizasyon seçin',
            style: AppTypography.subheadline.copyWith(
              color: AppColors.secondaryLabel(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Organization list
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

          const SizedBox(height: AppSpacing.xl),

          // Create new organization button
          AppButton(
            label: 'Yeni Organizasyon Oluştur',
            variant: AppButtonVariant.secondary,
            icon: Icons.add,
            onPressed: _showCreateOrganizationDialog,
          ),
        ],
      ),
    );
  }

  void _showCreateOrganizationDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AppBottomSheet(
          title: 'Yeni Organizasyon',
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
                    label: 'Organizasyon Adı',
                    placeholder: 'Örn: Merkez Ofis',
                    prefixIcon: Icons.apartment,
                    validator: Validators.required('Organizasyon adı zorunludur'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: descriptionController,
                    label: 'Açıklama (Opsiyonel)',
                    placeholder: 'Organizasyon hakkında kısa bilgi',
                    prefixIcon: Icons.description,
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Oluştur',
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;

                      final tenantId = tenantService.currentTenantId;
                      final userId = authService.currentUser?.id;
                      if (tenantId == null || userId == null) return;

                      final name = nameController.text.trim();
                      final description = descriptionController.text.trim();

                      final org = await organizationService.createOrganization(
                        tenantId: tenantId,
                        name: name,
                        description: description.isNotEmpty ? description : null,
                        createdBy: userId,
                      );

                      if (context.mounted) {
                        Navigator.pop(context);

                        if (org != null) {
                          AppSnackbar.showSuccess(
                            context,
                            message: 'Organizasyon oluşturuldu',
                          );
                          _loadOrganizations();
                        } else {
                          AppSnackbar.showError(
                            context,
                            message: 'Organizasyon oluşturulamadı',
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
            // Avatar/Icon
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
                          errorBuilder: (_, __, ___) => _buildIcon(context),
                        ),
                      )
                    : _buildIcon(context),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Info
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

  Widget _buildIcon(BuildContext context) {
    return Icon(
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
        return Color(int.parse(colorString.substring(1), radix: 16) + 0xFF000000);
      }
      return AppColors.primary;
    } catch (_) {
      return AppColors.primary;
    }
  }
}
