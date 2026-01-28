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
      final tenantId = tenantService.currentTenantId;
      if (tenantId == null) {
        setState(() => _errorMessage = 'Tenant seçili değil');
        return;
      }

      final controllers = await controllerService.getControllers(tenantId);
      if (mounted) {
        setState(() => _controllers = controllers);
      }
    } catch (e) {
      Logger.error('Failed to load controllers', e);
      if (mounted) {
        setState(() => _errorMessage = 'Controllerlar yüklenemedi');
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
      return const AppLoadingView();
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
      return AppEmptyView(
        icon: Icons.developer_board,
        title: 'Controller Bulunamadı',
        message: 'Henüz tanımlanmış controller yok',
        actionLabel: 'Controller Ekle',
        onAction: () => _showAddControllerDialog(),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadControllers,
      child: ListView.separated(
        padding: AppSpacing.screenPadding,
        itemCount: _controllers.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final controller = _controllers[index];
          return _ControllerCard(
            controller: controller,
            onTap: () => _showControllerDetail(controller),
          );
        },
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
                color: _getStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getTypeIcon(),
                color: _getStatusColor(),
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
                    controller.type.name.toUpperCase(),
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
                          '${controller.ipAddress}:${controller.port ?? "-"}',
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

  Color _getStatusColor() {
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
        return AppColors.tertiaryLabel(null);
    }
  }

  IconData _getTypeIcon() {
    switch (controller.type) {
      case ControllerType.plc:
        return Icons.memory;
      case ControllerType.rtu:
        return Icons.router;
      case ControllerType.dcs:
        return Icons.hub;
      case ControllerType.scada:
        return Icons.monitor;
      case ControllerType.hmi:
        return Icons.touch_app;
      case ControllerType.gateway:
        return Icons.settings_input_antenna;
      case ControllerType.edgeDevice:
        return Icons.devices_other;
      case ControllerType.virtualController:
        return Icons.cloud;
      case ControllerType.custom:
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
      label: _getLabel(),
      variant: _getVariant(),
      size: AppBadgeSize.small,
    );
  }

  String _getLabel() {
    switch (status) {
      case ControllerStatus.online:
        return 'Çevrimiçi';
      case ControllerStatus.offline:
        return 'Çevrimdışı';
      case ControllerStatus.connecting:
        return 'Bağlanıyor';
      case ControllerStatus.error:
        return 'Hata';
      case ControllerStatus.maintenance:
        return 'Bakım';
      case ControllerStatus.disabled:
        return 'Devre Dışı';
    }
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
            // Status card
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
                        label: 'Tip',
                        value: controller.type.name.toUpperCase(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Connection info
            AppSectionHeader(title: 'Bağlantı Bilgileri'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    _InfoRow(label: 'IP Adresi', value: controller.ipAddress ?? '-'),
                    _InfoRow(label: 'Port', value: controller.port?.toString() ?? '-'),
                    _InfoRow(label: 'Protokol', value: controller.protocol ?? '-'),
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

            // Metadata
            AppSectionHeader(title: 'Bilgiler'),
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
                    _InfoRow(
                      label: 'Güncelleme',
                      value: _formatDate(controller.updatedAt),
                    ),
                    if (controller.lastConnectedAt != null)
                      _InfoRow(
                        label: 'Son Bağlantı',
                        value: _formatDate(controller.lastConnectedAt!),
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
          Text(
            value,
            style: AppTypography.subheadline,
          ),
        ],
      ),
    );
  }
}
