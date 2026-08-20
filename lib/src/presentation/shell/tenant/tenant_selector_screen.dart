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
          _error = sl<LocalizationService>()
              .translate('tenant.no_user_session');
          _isLoading = false;
        });
        return;
      }

      final tenants = await tenantService.getUserTenants(userId);

      setState(() {
        _tenants = tenants;
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Failed to load tenants', e);
      setState(() {
        _error =
            sl<LocalizationService>().translate('tenant.load_failed');
        _isLoading = false;
      });
    }
  }

  Future<void> _selectTenant(Tenant tenant) async {
    final success = await tenantService.selectTenant(tenant.id);
    if (success && mounted) {
      // Navigate to organization selection
      context.go('/organizations');
    } else if (mounted) {
      AppSnackbar.showError(
        context,
        message:
            sl<LocalizationService>().translate('tenant.select_failed'),
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
      title: sl<LocalizationService>().translate('tenant.title'),
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
        title: sl<LocalizationService>().translate('common.error'),
        message: _error!,
        actionLabel: sl<LocalizationService>().translate('common.retry'),
        onAction: _loadTenants,
      );
    }

    if (_tenants.isEmpty) {
      return AppEmptyState(
        icon: Icons.business_outlined,
        title: sl<LocalizationService>().translate('tenant.not_found'),
        message: sl<LocalizationService>().translate('tenant.empty_message'),
        actionLabel:
            sl<LocalizationService>().translate('tenant.create_new'),
        onAction: _showCreateTenantDialog,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTenants,
      child: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          Text(
            sl<LocalizationService>().translate('tenant.select_prompt'),
            style: AppTypography.subheadline.copyWith(
              color: AppColors.secondaryLabel(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),

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

          AppButton(
            label: sl<LocalizationService>().translate('tenant.create_new'),
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
          title: sl<LocalizationService>().translate('tenant.create_title'),
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
                    label: sl<LocalizationService>().translate('tenant.name_label'),
                    placeholder:
                        sl<LocalizationService>().translate('tenant.name_placeholder'),
                    prefixIcon: Icons.business,
                    validator: Validators.required(
                        sl<LocalizationService>().translate('tenant.name_required')),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: sl<LocalizationService>().translate('tenant.create'),
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
                            message: sl<LocalizationService>()
                                .translate('tenant.created'),
                          );
                          _loadTenants();
                        } else {
                          AppSnackbar.showError(
                            context,
                            message: sl<LocalizationService>()
                                .translate('tenant.create_failed'),
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
            AppAvatar(
              imageUrl: tenant.logoUrl,
              name: tenant.name,
              size: AppAvatarSize.large,
            ),
            const SizedBox(width: AppSpacing.md),
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
                          label: sl<LocalizationService>().translate('tenant.trial'),
                          variant: AppBadgeVariant.warning,
                          size: AppBadgeSize.small,
                        ),
                      ],
                    ],
                  ),
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
