import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class ProvidersScreen extends StatefulWidget {
  const ProvidersScreen({super.key});

  @override
  State<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends State<ProvidersScreen> {
  final _ctrl = AsyncViewController();
  String _searchQuery = '';

  Future<List<DataProvider>> _load() {
    final tenantId = tenantService.currentTenantId;
    if (tenantId != null) {
      dataProviderService.setTenant(tenantId);
    }
    return dataProviderService.getAll();
  }

  List<DataProvider> _filtered(List<DataProvider> providers) {
    if (_searchQuery.isEmpty) return providers;
    final query = _searchQuery.toLowerCase();
    return providers.where((p) =>
        p.name.toLowerCase().contains(query) ||
        (p.ip?.toLowerCase().contains(query) ?? false) ||
        (p.hostname?.toLowerCase().contains(query) ?? false) ||
        p.type.label.toLowerCase().contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: sl<LocalizationService>().translate('provider.list_title'),
      onBack: () => context.go('/main'),
      actions: [
        AppIconButton(
          icon: Icons.refresh,
          onPressed: _ctrl.reload,
        ),
      ],
      child: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppSearchField(
              placeholder: sl<LocalizationService>().translate('provider.search_placeholder'),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          Expanded(
            child: AsyncView<List<DataProvider>>(
              controller: _ctrl,
              load: _load,
              errorFallback:
                  sl<LocalizationService>().translate('provider.load_failed'),
              isEmpty: (providers) => providers.isEmpty,
              emptyBuilder: (context) => AppEmptyState(
                icon: Icons.storage,
                title: sl<LocalizationService>().translate('provider.not_found'),
                message: sl<LocalizationService>().translate('provider.empty_message'),
              ),
              builder: (context, providers) => _content(context, providers),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, List<DataProvider> providers) {
    final filtered = _filtered(providers);

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: AppColors.tertiaryLabel(context)),
            const SizedBox(height: AppSpacing.sm),
            Text(sl<LocalizationService>().translate('common.no_results_ascii'), style: AppTypography.headline),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final provider = filtered[index];
        return _ProviderCard(
          provider: provider,
          onTap: () => _showProviderDetail(provider),
        );
      },
    );
  }

  void _showProviderDetail(DataProvider provider) {
    context.push('/providers/${provider.id}');
  }
}

class _ProviderCard extends StatelessWidget {
  final DataProvider provider;
  final VoidCallback onTap;

  const _ProviderCard({
    required this.provider,
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getStatusColor(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getTypeIcon(),
                color: _getStatusColor(context),
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          provider.name,
                          style: AppTypography.headline,
                        ),
                      ),
                      AppBadge(
                        label: _getStatusLabel(),
                        variant: _getStatusBadgeVariant(),
                        size: AppBadgeSize.small,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    provider.type.label,
                    style: AppTypography.caption1.copyWith(
                      color: AppColors.secondaryLabel(context),
                    ),
                  ),
                  if (provider.ip != null || provider.hostname != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Row(
                      children: [
                        Icon(Icons.lan, size: 14, color: AppColors.tertiaryLabel(context)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            provider.hostname ?? provider.ip ?? '',
                            style: AppTypography.caption2.copyWith(
                              color: AppColors.tertiaryLabel(context),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(BuildContext context) {
    switch (provider.status) {
      case DataProviderStatus.active:
        return AppColors.success;
      case DataProviderStatus.inactive:
        return AppColors.tertiaryLabel(context);
      case DataProviderStatus.connecting:
        return AppColors.warning;
      case DataProviderStatus.error:
        return AppColors.error;
      case DataProviderStatus.disabled:
        return AppColors.tertiaryLabel(context);
    }
  }

  String _getStatusLabel() {
    final loc = sl<LocalizationService>();
    switch (provider.status) {
      case DataProviderStatus.active:
        return loc.translate('common.active');
      case DataProviderStatus.inactive:
        return loc.translate('common.inactive');
      case DataProviderStatus.connecting:
        return loc.translate('common.connecting');
      case DataProviderStatus.error:
        return loc.translate('common.error');
      case DataProviderStatus.disabled:
        return loc.translate('common.disabled_ascii');
    }
  }

  AppBadgeVariant _getStatusBadgeVariant() {
    switch (provider.status) {
      case DataProviderStatus.active:
        return AppBadgeVariant.success;
      case DataProviderStatus.inactive:
        return AppBadgeVariant.secondary;
      case DataProviderStatus.connecting:
        return AppBadgeVariant.warning;
      case DataProviderStatus.error:
        return AppBadgeVariant.error;
      case DataProviderStatus.disabled:
        return AppBadgeVariant.secondary;
    }
  }

  IconData _getTypeIcon() {
    switch (provider.type) {
      case DataProviderType.modbus:
        return Icons.memory;
      case DataProviderType.opcUa:
        return Icons.account_tree;
      case DataProviderType.mqtt:
        return Icons.cloud_sync;
      case DataProviderType.http:
        return Icons.http;
      case DataProviderType.bacnet:
        return Icons.home_work;
      case DataProviderType.s7:
        return Icons.precision_manufacturing;
      case DataProviderType.allenBradley:
        return Icons.settings_input_component;
      case DataProviderType.database:
        return Icons.storage;
      case DataProviderType.file:
        return Icons.file_present;
      case DataProviderType.custom:
        return Icons.extension;
    }
  }
}

class _ProviderDetailSheet extends StatelessWidget {
  final DataProvider provider;

  const _ProviderDetailSheet({required this.provider});

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: provider.name,
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & Type
            AppCard(
              variant: AppCardVariant.filled,
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sl<LocalizationService>().translate('common.status'),
                            style: AppTypography.caption1.copyWith(
                              color: AppColors.secondaryLabel(context),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          AppBadge(
                            label: _statusLabel(provider.status),
                            variant: _statusVariant(provider.status),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sl<LocalizationService>().translate('field.tip'),
                            style: AppTypography.caption1.copyWith(
                              color: AppColors.secondaryLabel(context),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(provider.type.label, style: AppTypography.headline),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Connection Info
            AppSectionHeader(title: sl<LocalizationService>().translate('provider.connection_info')),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    _InfoRow(label: sl<LocalizationService>().translate('provider.ip_address'), value: provider.ip ?? '-'),
                    _InfoRow(label: sl<LocalizationService>().translate('common.hostname'), value: provider.hostname ?? '-'),
                    _InfoRow(label: sl<LocalizationService>().translate('common.mac'), value: provider.mac ?? '-'),
                    if (provider.code != null)
                      _InfoRow(label: sl<LocalizationService>().translate('common.code'), value: provider.code!),
                  ],
                ),
              ),
            ),

            if (provider.description != null && provider.description!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              AppSectionHeader(title: sl<LocalizationService>().translate('field.aciklama')),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Padding(
                  padding: AppSpacing.cardInsets,
                  child: Text(provider.description!, style: AppTypography.body),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.md),

            // Record Info
            AppSectionHeader(title: sl<LocalizationService>().translate('provider.record_info')),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    _InfoRow(label: sl<LocalizationService>().translate('common.created'), value: _formatDate(provider.createdAt)),
                    if (provider.updatedAt != null)
                      _InfoRow(label: sl<LocalizationService>().translate('common.updated'), value: _formatDate(provider.updatedAt!)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            AppButton(
              label: sl<LocalizationService>().translate('provider.test_connection'),
              variant: AppButtonVariant.secondary,
              icon: Icons.wifi_find,
              onPressed: () {
                Navigator.pop(context);
                AppSnackbar.showInfo(
                  context,
                  message: sl<LocalizationService>().translate('provider.test_connection_starting'),
                );
              },
            ),

            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  String _statusLabel(DataProviderStatus status) {
    final loc = sl<LocalizationService>();
    switch (status) {
      case DataProviderStatus.active: return loc.translate('common.active');
      case DataProviderStatus.inactive: return loc.translate('common.inactive');
      case DataProviderStatus.connecting: return loc.translate('common.connecting');
      case DataProviderStatus.error: return loc.translate('common.error');
      case DataProviderStatus.disabled: return loc.translate('common.disabled_ascii');
    }
  }

  AppBadgeVariant _statusVariant(DataProviderStatus status) {
    switch (status) {
      case DataProviderStatus.active: return AppBadgeVariant.success;
      case DataProviderStatus.inactive: return AppBadgeVariant.secondary;
      case DataProviderStatus.connecting: return AppBadgeVariant.warning;
      case DataProviderStatus.error: return AppBadgeVariant.error;
      case DataProviderStatus.disabled: return AppBadgeVariant.secondary;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.subheadline.copyWith(
              color: AppColors.secondaryLabel(context),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.subheadline,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
