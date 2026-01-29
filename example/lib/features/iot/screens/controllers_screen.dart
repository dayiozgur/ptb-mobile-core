import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class ControllersScreen extends StatefulWidget {
  const ControllersScreen({super.key});

  @override
  State<ControllersScreen> createState() => _ControllersScreenState();
}

class _ControllersScreenState extends State<ControllersScreen> {
  bool _isLoading = true;
  List<Controller> _controllers = [];
  String? _errorMessage;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadControllers();
  }

  Future<void> _loadControllers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Tenant context'i IoT servisine aktar
      final tenantId = tenantService.currentTenantId;
      if (tenantId != null) {
        controllerService.setTenant(tenantId);
      }

      final controllers = await controllerService.getAll();
      if (mounted) {
        setState(() => _controllers = controllers);
      }
    } catch (e) {
      Logger.error('Failed to load controllers', e);
      if (mounted) {
        setState(() => _errorMessage = 'Controllerlar yüklenemedi: $e');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Controllers',
      onBack: () => context.go('/iot'),
      actions: [
        AppIconButton(
          icon: Icons.add,
          onPressed: () => _showAddControllerDialog(),
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
        onAction: _loadControllers,
      );
    }

    if (_controllers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.developer_board, size: 64, color: AppColors.tertiaryLabel(context)),
            const SizedBox(height: AppSpacing.md),
            Text('Controller Bulunamadı', style: AppTypography.headline),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Henüz tanımlanmış controller yok',
              style: AppTypography.subheadline.copyWith(color: AppColors.secondaryLabel(context)),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Controller Ekle',
              onPressed: () => _showAddControllerDialog(),
            ),
          ],
        ),
      );
    }

    final filtered = _statusFilter == 'all'
        ? _controllers
        : _controllers.where((c) {
            switch (_statusFilter) {
              case 'online':
                return c.status == ControllerStatus.online;
              case 'offline':
                return c.status == ControllerStatus.offline;
              case 'error':
                return c.status == ControllerStatus.error;
              default:
                return true;
            }
          }).toList();

    final onlineCount = _controllers.where((c) => c.status == ControllerStatus.online).length;
    final offlineCount = _controllers.where((c) => c.status == ControllerStatus.offline).length;

    return RefreshIndicator(
      onRefresh: _loadControllers,
      child: Column(
        children: [
          // Status filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary chips
                Row(
                  children: [
                    AppChip(
                      label: '${_controllers.length} Toplam',
                      variant: AppChipVariant.tonal,
                      color: AppColors.primary,
                      small: true,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    AppChip(
                      label: '$onlineCount Online',
                      variant: AppChipVariant.tonal,
                      color: AppColors.success,
                      icon: Icons.circle,
                      small: true,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    AppChip(
                      label: '$offlineCount Offline',
                      variant: AppChipVariant.tonal,
                      color: AppColors.error,
                      small: true,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                // Filter
                AppChoiceChips<String>(
                  selectedValue: _statusFilter,
                  onSelected: (val) => setState(() => _statusFilter = val),
                  scrollable: true,
                  items: const [
                    AppChoiceChipItem(value: 'all', label: 'Tümü'),
                    AppChoiceChipItem(value: 'online', label: 'Online'),
                    AppChoiceChipItem(value: 'offline', label: 'Offline'),
                    AppChoiceChipItem(value: 'error', label: 'Hata'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: ListView.separated(
              padding: AppSpacing.screenPadding,
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final controller = filtered[index];
                return _ControllerCard(
                  controller: controller,
                  onTap: () => _showControllerDetail(controller),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddControllerDialog() {
    AppSnackbar.showInfo(
      context,
      message: 'Controller ekleme özelliği yakında eklenecek',
    );
  }

  void _showControllerDetail(Controller controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ControllerDetailSheet(controller: controller),
    );
  }
}

class _ControllerCard extends StatelessWidget {
  final Controller controller;
  final VoidCallback onTap;

  const _ControllerCard({
    required this.controller,
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
                          controller.name,
                          style: AppTypography.headline,
                        ),
                      ),
                      _StatusBadge(status: controller.status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    controller.type.label,
                    style: AppTypography.caption1.copyWith(
                      color: AppColors.secondaryLabel(context),
                    ),
                  ),
                  if (controller.ipAddress != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Row(
                      children: [
                        Icon(
                          Icons.lan,
                          size: 14,
                          color: AppColors.tertiaryLabel(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          controller.connectionAddress,
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
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(BuildContext context) {
    switch (controller.status) {
      case ControllerStatus.online:
        return AppColors.success;
      case ControllerStatus.offline:
        return AppColors.error;
      case ControllerStatus.connecting:
        return AppColors.warning;
      case ControllerStatus.error:
        return AppColors.error;
      case ControllerStatus.maintenance:
        return AppColors.info;
      case ControllerStatus.disabled:
      case ControllerStatus.unknown:
        return AppColors.tertiaryLabel(context);
    }
  }

  IconData _getTypeIcon() {
    switch (controller.type) {
      case ControllerType.plc:
        return Icons.memory;
      case ControllerType.rtu:
        return Icons.router;
      case ControllerType.scada:
        return Icons.monitor;
      case ControllerType.hmi:
        return Icons.touch_app;
      case ControllerType.gateway:
      case ControllerType.iotGateway:
        return Icons.settings_input_antenna;
      case ControllerType.edge:
        return Icons.devices_other;
      case ControllerType.sensorHub:
        return Icons.sensors;
      case ControllerType.virtual:
        return Icons.cloud;
      case ControllerType.other:
        return Icons.developer_board;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final ControllerStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return AppBadge(
      label: status.label,
      variant: _getVariant(),
      size: AppBadgeSize.small,
    );
  }

  AppBadgeVariant _getVariant() {
    switch (status) {
      case ControllerStatus.online:
        return AppBadgeVariant.success;
      case ControllerStatus.offline:
        return AppBadgeVariant.error;
      case ControllerStatus.connecting:
        return AppBadgeVariant.warning;
      case ControllerStatus.error:
        return AppBadgeVariant.error;
      case ControllerStatus.maintenance:
        return AppBadgeVariant.info;
      case ControllerStatus.disabled:
      case ControllerStatus.unknown:
        return AppBadgeVariant.secondary;
    }
  }
}

class _ControllerDetailSheet extends StatelessWidget {
  final Controller controller;

  const _ControllerDetailSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: controller.name,
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Durum & Temel Bilgiler
            AppCard(
              variant: AppCardVariant.filled,
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Row(
                  children: [
                    Expanded(
                      child: _DetailItem(
                        label: 'Durum',
                        child: _StatusBadge(status: controller.status),
                      ),
                    ),
                    Expanded(
                      child: _DetailItem(
                        label: 'Aktif',
                        value: controller.active ? 'Evet' : 'Hayır',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Cihaz Bilgileri
            AppSectionHeader(title: 'Cihaz Bilgileri'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    if (controller.code != null)
                      _InfoRow(label: 'Kod', value: controller.code!),
                    _InfoRow(label: 'IP', value: controller.ipAddress ?? '-'),
                    if (controller.serialNumber != null)
                      _InfoRow(label: 'Seri No', value: controller.serialNumber!),
                    if (controller.model != null)
                      _InfoRow(label: 'Model', value: controller.model!),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // İletişim Bilgileri
            AppSectionHeader(title: 'İletişim Bilgileri'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    if (controller.lastConnectedAt != null)
                      _InfoRow(
                        label: 'Son Bağlantı',
                        value: _formatDate(controller.lastConnectedAt!),
                      ),
                    if (controller.lastDataAt != null)
                      _InfoRow(
                        label: 'Son İletişim',
                        value: _formatDate(controller.lastDataAt!),
                      ),
                  ],
                ),
              ),
            ),

            if (controller.description != null && controller.description!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              AppSectionHeader(title: 'Açıklama'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Padding(
                  padding: AppSpacing.cardInsets,
                  child: Text(
                    controller.description!,
                    style: AppTypography.body,
                  ),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.md),

            // Zaman Bilgileri
            AppSectionHeader(title: 'Kayıt Bilgileri'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    _InfoRow(
                      label: 'Oluşturulma',
                      value: _formatDate(controller.createdAt),
                    ),
                    if (controller.updatedAt != null)
                      _InfoRow(
                        label: 'Güncelleme',
                        value: _formatDate(controller.updatedAt!),
                      ),
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
                    label: 'Logları Gör',
                    variant: AppButtonVariant.secondary,
                    icon: Icons.timeline,
                    onPressed: () {
                      Navigator.pop(context);
                      context.push(
                        '/iot/controllers/${controller.id}/logs?name=${Uri.encodeComponent(controller.name)}',
                      );
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'Test Et',
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
          Text(
            value,
            style: AppTypography.subheadline,
          ),
        ],
      ),
    );
  }
}
