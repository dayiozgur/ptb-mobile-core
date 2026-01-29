import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class ProvidersScreen extends StatefulWidget {
  const ProvidersScreen({super.key});

  @override
  State<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends State<ProvidersScreen> {
  bool _isLoading = true;
  List<DataProvider> _providers = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Tenant context'i IoT servisine aktar
      final tenantId = tenantService.currentTenantId;
      if (tenantId != null) {
        dataProviderService.setTenant(tenantId);
      }

      final providers = await dataProviderService.getAll();
      if (mounted) {
        setState(() => _providers = providers);
      }
    } catch (e) {
      Logger.error('Failed to load providers', e);
      if (mounted) {
        setState(() => _errorMessage = 'Veri sağlayıcılar yüklenemedi');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Veri Sağlayıcılar',
      onBack: () => context.go('/iot'),
      actions: [
        AppIconButton(
          icon: Icons.add,
          onPressed: () => _showAddProviderDialog(),
        ),
      ],
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return AppErrorView(
        title: 'Hata',
        message: _errorMessage!,
        actionLabel: 'Tekrar Dene',
        onAction: _loadProviders,
      );
    }

    if (_providers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storage, size: 64, color: AppColors.tertiaryLabel(context)),
            const SizedBox(height: AppSpacing.md),
            Text('Veri Sağlayıcı Bulunamadı', style: AppTypography.headline),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Henüz tanımlanmış veri sağlayıcı yok',
              style: AppTypography.subheadline.copyWith(color: AppColors.secondaryLabel(context)),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Veri Sağlayıcı Ekle',
              onPressed: () => _showAddProviderDialog(),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProviders,
      child: ListView.separated(
        padding: AppSpacing.screenPadding,
        itemCount: _providers.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final provider = _providers[index];
          return _ProviderCard(
            provider: provider,
            onTap: () => _showProviderDetail(provider),
          );
        },
      ),
    );
  }

  void _showAddProviderDialog() {
    AppSnackbar.showInfo(
      context,
      message: 'Veri sağlayıcı ekleme özelliği yakında eklenecek',
    );
  }

  void _showProviderDetail(DataProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ProviderDetailSheet(provider: provider),
    );
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
                color: _getStatusColor(context).withOpacity(0.1),
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
                      _StatusBadge(status: provider.status),
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
                        Icon(
                          Icons.lan,
                          size: 14,
                          color: AppColors.tertiaryLabel(context),
                        ),
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

class _StatusBadge extends StatelessWidget {
  final DataProviderStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return AppBadge(
      label: _getLabel(),
      variant: _getVariant(),
      size: AppBadgeSize.small,
    );
  }

  String _getLabel() {
    switch (status) {
      case DataProviderStatus.active:
        return 'Aktif';
      case DataProviderStatus.inactive:
        return 'Pasif';
      case DataProviderStatus.connecting:
        return 'Bağlanıyor';
      case DataProviderStatus.error:
        return 'Hata';
      case DataProviderStatus.disabled:
        return 'Devre Dışı';
    }
  }

  AppBadgeVariant _getVariant() {
    switch (status) {
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
}

class _ProviderDetailSheet extends StatefulWidget {
  final DataProvider provider;

  const _ProviderDetailSheet({required this.provider});

  @override
  State<_ProviderDetailSheet> createState() => _ProviderDetailSheetState();
}

class _ProviderDetailSheetState extends State<_ProviderDetailSheet> {
  int _alarmCount = 0;
  int _logCount = 0;
  List<AlarmHistory> _recentAlarms = [];
  bool _loadingExtras = true;

  @override
  void initState() {
    super.initState();
    _loadExtras();
  }

  Future<void> _loadExtras() async {
    try {
      final alarmCount = await alarmService.getResetAlarmCountByProvider(widget.provider.id);
      final logCount = await iotLogService.getLogCountByProvider(widget.provider.id, lastHours: 24);
      final recentAlarms = await alarmService.getHistory(
        providerId: widget.provider.id,
        limit: 5,
      );
      if (mounted) {
        setState(() {
          _alarmCount = alarmCount;
          _logCount = logCount;
          _recentAlarms = recentAlarms;
          _loadingExtras = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingExtras = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    return AppBottomSheet(
      title: provider.name,
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Durum & Tip
            AppCard(
              variant: AppCardVariant.filled,
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Row(
                  children: [
                    Expanded(
                      child: _DetailItem(
                        label: 'Durum',
                        child: _StatusBadge(status: provider.status),
                      ),
                    ),
                    Expanded(
                      child: _DetailItem(
                        label: 'Tip',
                        value: provider.type.label,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Alarm & Log Sayıları
            if (!_loadingExtras) ...[
              Row(
                children: [
                  Expanded(
                    child: AppCard(
                      child: Padding(
                        padding: AppSpacing.cardInsets,
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: _alarmCount > 0 ? AppColors.error : AppColors.tertiaryLabel(context),
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Aktif Alarm', style: AppTypography.caption2.copyWith(
                                  color: AppColors.secondaryLabel(context),
                                )),
                                Text('$_alarmCount', style: AppTypography.headline),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppCard(
                      child: Padding(
                        padding: AppSpacing.cardInsets,
                        child: Row(
                          children: [
                            Icon(
                              Icons.article_outlined,
                              color: AppColors.tertiaryLabel(context),
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Log (24s)', style: AppTypography.caption2.copyWith(
                                  color: AppColors.secondaryLabel(context),
                                )),
                                Text('$_logCount', style: AppTypography.headline),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Bağlantı Bilgileri
            AppSectionHeader(title: 'Bağlantı Bilgileri'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    _InfoRow(label: 'IP Adresi', value: provider.ip ?? '-'),
                    _InfoRow(label: 'Hostname', value: provider.hostname ?? '-'),
                    _InfoRow(label: 'MAC', value: provider.mac ?? '-'),
                    if (provider.code != null)
                      _InfoRow(label: 'Kod', value: provider.code!),
                  ],
                ),
              ),
            ),

            if (provider.description != null && provider.description!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              AppSectionHeader(title: 'Açıklama'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Padding(
                  padding: AppSpacing.cardInsets,
                  child: Text(
                    provider.description!,
                    style: AppTypography.body,
                  ),
                ),
              ),
            ],

            // Son Alarmlar
            if (_recentAlarms.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              AppSectionHeader(title: 'Son Alarmlar'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Padding(
                  padding: AppSpacing.cardInsets,
                  child: Column(
                    children: _recentAlarms.map((alarm) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              alarm.isResolved ? Icons.check_circle_outline : Icons.warning_amber,
                              size: 16,
                              color: alarm.isResolved ? AppColors.success : AppColors.error,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                alarm.name ?? alarm.code ?? '-',
                                style: AppTypography.caption1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              alarm.durationFormatted,
                              style: AppTypography.caption2.copyWith(
                                color: AppColors.secondaryLabel(context),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.md),

            // Kayıt Bilgileri
            AppSectionHeader(title: 'Kayıt Bilgileri'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    _InfoRow(label: 'Oluşturulma', value: _formatDate(provider.createdAt)),
                    if (provider.updatedAt != null)
                      _InfoRow(label: 'Güncelleme', value: _formatDate(provider.updatedAt!)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Actions
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Bağlantı Test Et',
                    variant: AppButtonVariant.secondary,
                    icon: Icons.wifi_find,
                    onPressed: () {
                      Navigator.pop(context);
                      AppSnackbar.showInfo(
                        context,
                        message: 'Bağlantı testi başlatılıyor...',
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? child;

  const _DetailItem({
    required this.label,
    this.value,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption1.copyWith(
            color: AppColors.secondaryLabel(context),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        child ??
            Text(
              value ?? '-',
              style: AppTypography.headline,
            ),
      ],
    );
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
