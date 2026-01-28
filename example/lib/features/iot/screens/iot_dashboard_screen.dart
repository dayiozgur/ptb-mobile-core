import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class IotDashboardScreen extends StatefulWidget {
  const IotDashboardScreen({super.key});

  @override
  State<IotDashboardScreen> createState() => _IotDashboardScreenState();
}

class _IotDashboardScreenState extends State<IotDashboardScreen> {
  bool _isLoading = true;
  int _controllerCount = 0;
  int _providerCount = 0;
  int _variableCount = 0;
  int _workflowCount = 0;
  int _activeControllers = 0;
  int _activeWorkflows = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Tenant context'i tüm IoT servislerine aktar
    final tenantId = tenantService.currentTenantId;
    if (tenantId != null) {
      controllerService.setTenant(tenantId);
      dataProviderService.setTenant(tenantId);
      variableService.setTenant(tenantId);
      workflowService.setTenant(tenantId);
    }

    // Her servisi bağımsız yükle - biri başarısız olursa diğerleri etkilenmesin
    List<Controller> controllers = [];
    try {
      controllers = await controllerService.getAll();
    } catch (e) {
      Logger.error('Failed to load controllers', e);
    }

    List<DataProvider> providers = [];
    try {
      providers = await dataProviderService.getAll();
    } catch (e) {
      Logger.error('Failed to load providers', e);
    }

    List<Variable> variables = [];
    try {
      variables = await variableService.getAll();
    } catch (e) {
      Logger.error('Failed to load variables', e);
    }

    List<Workflow> workflows = [];
    try {
      workflows = await workflowService.getAll();
    } catch (e) {
      Logger.error('Failed to load workflows', e);
    }

    if (mounted) {
      setState(() {
        _controllerCount = controllers.length;
        _providerCount = providers.length;
        _variableCount = variables.length;
        _workflowCount = workflows.length;
        _activeControllers = controllers.where((c) => c.status == ControllerStatus.online).length;
        _activeWorkflows = workflows.where((w) => w.status == WorkflowStatus.active).length;
      });
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'IoT Yönetimi',
      onBack: () => context.go('/home'),
      actions: [
        AppIconButton(
          icon: Icons.refresh,
          onPressed: _loadData,
        ),
      ],
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status overview
              _StatusOverview(
                activeControllers: _activeControllers,
                totalControllers: _controllerCount,
                activeWorkflows: _activeWorkflows,
                totalWorkflows: _workflowCount,
                isLoading: _isLoading,
              ),

              const SizedBox(height: AppSpacing.lg),

              // Stats grid
              AppSectionHeader(
                title: 'Genel Bakış',
                action: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              _IotStatsGrid(
                controllerCount: _controllerCount,
                providerCount: _providerCount,
                variableCount: _variableCount,
                workflowCount: _workflowCount,
                isLoading: _isLoading,
              ),

              const SizedBox(height: AppSpacing.lg),

              // Quick actions
              AppSectionHeader(title: 'IoT Modülleri'),
              const SizedBox(height: AppSpacing.sm),
              _IotModules(),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusOverview extends StatelessWidget {
  final int activeControllers;
  final int totalControllers;
  final int activeWorkflows;
  final int totalWorkflows;
  final bool isLoading;

  const _StatusOverview({
    required this.activeControllers,
    required this.totalControllers,
    required this.activeWorkflows,
    required this.totalWorkflows,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.filled,
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            Expanded(
              child: _StatusItem(
                icon: Icons.developer_board,
                label: 'Aktif Controller',
                value: isLoading ? '-' : '$activeControllers / $totalControllers',
                color: AppColors.success,
              ),
            ),
            Container(
              width: 1,
              height: 50,
              color: AppColors.separator(context),
            ),
            Expanded(
              child: _StatusItem(
                icon: Icons.account_tree,
                label: 'Aktif Workflow',
                value: isLoading ? '-' : '$activeWorkflows / $totalWorkflows',
                color: AppColors.info,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatusItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: AppTypography.title2.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          label,
          style: AppTypography.caption1.copyWith(
            color: AppColors.secondaryLabel(context),
          ),
        ),
      ],
    );
  }
}

class _IotStatsGrid extends StatelessWidget {
  final int controllerCount;
  final int providerCount;
  final int variableCount;
  final int workflowCount;
  final bool isLoading;

  const _IotStatsGrid({
    required this.controllerCount,
    required this.providerCount,
    required this.variableCount,
    required this.workflowCount,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _IotStatCard(
                icon: Icons.developer_board,
                value: isLoading ? '-' : '$controllerCount',
                label: 'Controller',
                color: Colors.blue,
                onTap: () => context.go('/iot/controllers'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _IotStatCard(
                icon: Icons.storage,
                value: isLoading ? '-' : '$providerCount',
                label: 'Veri Sağlayıcı',
                color: Colors.green,
                onTap: () => context.go('/iot/providers'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _IotStatCard(
                icon: Icons.data_object,
                value: isLoading ? '-' : '$variableCount',
                label: 'Değişken',
                color: Colors.orange,
                onTap: () => context.go('/iot/variables'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _IotStatCard(
                icon: Icons.account_tree,
                value: isLoading ? '-' : '$workflowCount',
                label: 'Workflow',
                color: Colors.purple,
                onTap: () => context.go('/iot/workflows'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _IotStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _IotStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              style: AppTypography.title1.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              label,
              style: AppTypography.caption1.copyWith(
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IotModules extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          _IotModuleItem(
            icon: Icons.developer_board,
            color: Colors.blue,
            title: 'Controllers',
            subtitle: 'PLC ve kontrol cihazlarını yönetin',
            onTap: () => context.go('/iot/controllers'),
          ),
          Divider(height: 1, color: AppColors.separator(context)),
          _IotModuleItem(
            icon: Icons.storage,
            color: Colors.green,
            title: 'Veri Sağlayıcılar',
            subtitle: 'Modbus, OPC-UA, MQTT bağlantıları',
            onTap: () => context.go('/iot/providers'),
          ),
          Divider(height: 1, color: AppColors.separator(context)),
          _IotModuleItem(
            icon: Icons.data_object,
            color: Colors.orange,
            title: 'Değişkenler',
            subtitle: 'Tag ve veri noktalarını yönetin',
            onTap: () => context.go('/iot/variables'),
          ),
          Divider(height: 1, color: AppColors.separator(context)),
          _IotModuleItem(
            icon: Icons.account_tree,
            color: Colors.purple,
            title: 'Workflows',
            subtitle: 'Otomasyon senaryolarını oluşturun',
            onTap: () => context.go('/iot/workflows'),
          ),
        ],
      ),
    );
  }
}

class _IotModuleItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _IotModuleItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color),
      ),
      title: title,
      subtitle: subtitle,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
