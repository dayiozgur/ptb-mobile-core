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
  String _searchQuery = '';

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
        setState(() => _errorMessage = 'Controllerlar yuklenemedi: $e');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  List<Controller> get _filteredControllers {
    var result = _controllers;

    // Status filter
    if (_statusFilter != 'all') {
      result = result.where((c) {
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
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((c) =>
          c.name.toLowerCase().contains(query) ||
          (c.ipAddress?.toLowerCase().contains(query) ?? false) ||
          (c.code?.toLowerCase().contains(query) ?? false)).toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Controllers',
      onBack: () => context.go('/dashboard'),
      actions: [
        AppIconButton(
          icon: Icons.refresh,
          onPressed: _loadControllers,
        ),
      ],
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: AppLoadingIndicator());
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
      return AppEmptyState(
        icon: Icons.developer_board,
        title: 'Controller Bulunamadi',
        message: 'Henuz tanimlanmis controller yok.',
      );
    }

    final onlineCount = _controllers.where((c) => c.status == ControllerStatus.online).length;
    final offlineCount = _controllers.where((c) => c.status == ControllerStatus.offline).length;
    final errorCount = _controllers.where((c) => c.status == ControllerStatus.error).length;
    final filtered = _filteredControllers;

    return RefreshIndicator(
      onRefresh: _loadControllers,
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0,
            ),
            child: AppSearchField(
              placeholder: 'Controller ara...',
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Summary chips
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    if (errorCount > 0) ...[
                      const SizedBox(width: AppSpacing.xs),
                      AppChip(
                        label: '$errorCount Hata',
                        variant: AppChipVariant.tonal,
                        color: Colors.orange,
                        small: true,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                // Filter
                AppChoiceChips<String>(
                  selectedValue: _statusFilter,
                  onSelected: (val) => setState(() => _statusFilter = val),
                  scrollable: true,
                  items: const [
                    AppChoiceChipItem(value: 'all', label: 'Tumu'),
                    AppChoiceChipItem(value: 'online', label: 'Online'),
                    AppChoiceChipItem(value: 'offline', label: 'Offline'),
                    AppChoiceChipItem(value: 'error', label: 'Hata'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Controller list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 48, color: AppColors.tertiaryLabel(context)),
                        const SizedBox(height: AppSpacing.sm),
                        Text('Sonuc Bulunamadi', style: AppTypography.headline),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: AppSpacing.screenPadding,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final controller = filtered[index];
                      return _ControllerCard(
                        controller: controller,
                        onTap: () => context.push(
                          '/controllers/${controller.id}?name=${Uri.encodeComponent(controller.name)}',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
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
                      AppBadge(
                        label: controller.status.label,
                        variant: _getStatusBadgeVariant(),
                        size: AppBadgeSize.small,
                      ),
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

  AppBadgeVariant _getStatusBadgeVariant() {
    switch (controller.status) {
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
