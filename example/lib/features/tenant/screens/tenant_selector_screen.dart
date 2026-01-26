import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class TenantSelectorScreen extends StatefulWidget {
  const TenantSelectorScreen({super.key});

  @override
  State<TenantSelectorScreen> createState() => _TenantSelectorScreenState();
}

class _TenantSelectorScreenState extends State<TenantSelectorScreen> {
  List<Tenant> _tenants = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTenants();
  }

  Future<void> _loadTenants() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = authService.currentUser?.id;
      if (userId == null) {
        setState(() {
          _error = 'Kullanıcı oturumu bulunamadı';
          _isLoading = false;
        });
        return;
      }

      final tenants = await tenantService.getUserTenants(userId);

      setState(() {
        _tenants = tenants;
        _isLoading = false;
      });

      // Tek tenant varsa otomatik seç
      if (tenants.length == 1) {
        await _selectTenant(tenants.first);
      }
    } catch (e) {
      Logger.error('Failed to load tenants', e);
      setState(() {
        _error = 'Organizasyonlar yüklenemedi';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectTenant(Tenant tenant) async {
    final success = await tenantService.selectTenant(tenant.id);
    if (success && mounted) {
      context.go('/home');
    } else if (mounted) {
      AppSnackbar.showError(
        context,
        message: 'Organizasyon seçilemedi',
      );
    }
  }

  Future<void> _handleLogout() async {
    await authService.signOut();
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Organizasyon Seç',
      showBackButton: false,
      actions: [
        AppIconButton(
          icon: Icons.logout,
          onPressed: _handleLogout,
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
        onAction: _loadTenants,
      );
    }

    if (_tenants.isEmpty) {
      return AppEmptyState(
        icon: Icons.business_outlined,
        title: 'Organizasyon Bulunamadı',
        message: 'Henüz bir organizasyona dahil değilsiniz.\n'
            'Yeni bir organizasyon oluşturabilir veya '
            'mevcut bir organizasyona davet bekleyebilirsiniz.',
        actionLabel: 'Yeni Organizasyon Oluştur',
        onAction: _showCreateTenantDialog,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTenants,
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

          // Tenant list
          ...List.generate(_tenants.length, (index) {
            final tenant = _tenants[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < _tenants.length - 1 ? AppSpacing.sm : 0,
              ),
              child: _TenantCard(
                tenant: tenant,
                onTap: () => _selectTenant(tenant),
              ),
            );
          }),

          const SizedBox(height: AppSpacing.xl),

          // Create new tenant button
          AppButton(
            label: 'Yeni Organizasyon Oluştur',
            variant: AppButtonVariant.secondary,
            icon: Icons.add,
            onPressed: _showCreateTenantDialog,
          ),
        ],
      ),
    );
  }

  void _showCreateTenantDialog() {
    final nameController = TextEditingController();
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
                    placeholder: 'Örn: Şirketim A.Ş.',
                    prefixIcon: Icons.business,
                    validator: Validators.required('Organizasyon adı zorunludur'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Oluştur',
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;

                      final userId = authService.currentUser?.id;
                      if (userId == null) return;

                      final name = nameController.text.trim();
                      final slug = name
                          .toLowerCase()
                          .replaceAll(RegExp(r'[^a-z0-9]'), '-')
                          .replaceAll(RegExp(r'-+'), '-');

                      final tenant = await tenantService.createTenant(
                        name: name,
                        slug: slug,
                        ownerId: userId,
                      );

                      if (context.mounted) {
                        Navigator.pop(context);

                        if (tenant != null) {
                          AppSnackbar.showSuccess(
                            context,
                            message: 'Organizasyon oluşturuldu',
                          );
                          _loadTenants();
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

class _TenantCard extends StatelessWidget {
  final Tenant tenant;
  final VoidCallback onTap;

  const _TenantCard({
    required this.tenant,
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
            // Avatar/Logo
            AppAvatar(
              imageUrl: tenant.logoUrl,
              name: tenant.name,
              size: AppAvatarSize.large,
            ),
            const SizedBox(width: AppSpacing.md),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tenant.name,
                    style: AppTypography.headline,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: [
                      AppBadge(
                        label: tenant.plan.name.toUpperCase(),
                        variant: _getPlanBadgeVariant(tenant.plan),
                        size: AppBadgeSize.small,
                      ),
                      if (tenant.isTrial) ...[
                        const SizedBox(width: AppSpacing.xs),
                        AppBadge(
                          label: 'Deneme',
                          variant: AppBadgeVariant.warning,
                          size: AppBadgeSize.small,
                        ),
                      ],
                    ],
                  ),
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

  AppBadgeVariant _getPlanBadgeVariant(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return AppBadgeVariant.secondary;
      case SubscriptionPlan.basic:
        return AppBadgeVariant.info;
      case SubscriptionPlan.professional:
        return AppBadgeVariant.primary;
      case SubscriptionPlan.enterprise:
        return AppBadgeVariant.success;
    }
  }
}
