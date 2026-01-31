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
  int _activeAlarmCount = 0;

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
      alarmService.setTenant(tenantId);
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

    int activeAlarmCount = 0;
    try {
      final alarms = await alarmService.getActiveAlarms();
      activeAlarmCount = alarms.length;
    } catch (e) {
      Logger.error('Failed to load alarms', e);
    }

    if (mounted) {
      setState(() {
        _controllerCount = controllers.length;
        _providerCount = providers.length;
        _variableCount = variables.length;
        _workflowCount = workflows.length;
        _activeControllers = controllers.where((c) => c.status == ControllerStatus.online).length;
        _activeWorkflows = workflows.where((w) => w.status == WorkflowStatus.active).length;
        _activeAlarmCount = activeAlarmCount;
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
                activeAlarmCount: _activeAlarmCount,
                isLoading: _isLoading,
              ),

              const SizedBox(height: AppSpacing.lg),

              // Metric Cards with trends
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
              _IotMetricCards(
                controllerCount: _controllerCount,
                providerCount: _providerCount,
                variableCount: _variableCount,
                workflowCount: _workflowCount,
                isLoading: _isLoading,
              ),

              const SizedBox(height: AppSpacing.lg),

              // System Health
              AppSectionHeader(title: 'Sistem Durumu'),
              const SizedBox(height: AppSpacing.sm),
              _SystemHealthCard(
                activeControllers: _activeControllers,
                totalControllers: _controllerCount,
                activeWorkflows: _activeWorkflows,
                totalWorkflows: _workflowCount,
                activeAlarmCount: _activeAlarmCount,
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
  final int activeAlarmCount;
  final bool isLoading;

  const _StatusOverview({
    required this.activeControllers,
    required this.totalControllers,
    required this.activeWorkflows,
    required this.totalWorkflows,
    required this.activeAlarmCount,
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
            Container(
              width: 1,
              height: 50,
              color: AppColors.separator(context),
            ),
            Expanded(
              child: _StatusItem(
                icon: Icons.warning_amber_rounded,
                label: 'Aktif Alarm',
                value: isLoading ? '-' : '$activeAlarmCount',
                color: activeAlarmCount > 0 ? AppColors.error : AppColors.success,
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


class _IotMetricCards extends StatelessWidget {
  final int controllerCount;
  final int providerCount;
  final int variableCount;
  final int workflowCount;
  final bool isLoading;

  const _IotMetricCards({
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
              child: MetricCard(
                title: 'Controller',
                value: isLoading ? '-' : '$controllerCount',
                icon: Icons.developer_board,
                color: Colors.blue,
                onTap: () => context.go('/iot/controllers'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MetricCard(
                title: 'Veri Sağlayıcı',
                value: isLoading ? '-' : '$providerCount',
                icon: Icons.storage,
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
              child: MetricCard(
                title: 'Değişken',
                value: isLoading ? '-' : '$variableCount',
                icon: Icons.data_object,
                color: Colors.orange,
                onTap: () => context.go('/iot/variables'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MetricCard(
                title: 'Workflow',
                value: isLoading ? '-' : '$workflowCount',
                icon: Icons.account_tree,
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

class _SystemHealthCard extends StatelessWidget {
  final int activeControllers;
  final int totalControllers;
  final int activeWorkflows;
  final int totalWorkflows;
  final int activeAlarmCount;
  final bool isLoading;

  const _SystemHealthCard({
    required this.activeControllers,
    required this.totalControllers,
    required this.activeWorkflows,
    required this.totalWorkflows,
    required this.activeAlarmCount,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return AppCard(
        child: Padding(
          padding: AppSpacing.cardInsets,
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    final controllerRatio = totalControllers > 0
        ? activeControllers.toDouble() / totalControllers.toDouble()
        : 0.0;
    final workflowRatio = totalWorkflows > 0
        ? activeWorkflows.toDouble() / totalWorkflows.toDouble()
        : 0.0;

    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Controller health
            AppProgressBar(
              value: controllerRatio,
              label: 'Controller Durumu',
              showPercentage: true,
              color: controllerRatio > 0.7 ? AppColors.success : AppColors.warning,
              height: 6,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$activeControllers / $totalControllers aktif',
              style: AppTypography.caption2.copyWith(
                color: AppColors.secondaryLabel(context),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Workflow health
            AppProgressBar(
              value: workflowRatio,
              label: 'Workflow Durumu',
              showPercentage: true,
              color: workflowRatio > 0.5 ? AppColors.info : AppColors.warning,
              height: 6,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$activeWorkflows / $totalWorkflows aktif',
              style: AppTypography.caption2.copyWith(
                color: AppColors.secondaryLabel(context),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Alarm status chip
            Row(
              children: [
                Text(
                  'Alarm Durumu',
                  style: AppTypography.subheadline.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                AppChip(
                  label: activeAlarmCount > 0
                      ? '$activeAlarmCount Aktif Alarm'
                      : 'Alarm Yok',
                  variant: AppChipVariant.tonal,
                  color: activeAlarmCount > 0 ? AppColors.error : AppColors.success,
                  icon: activeAlarmCount > 0
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle,
                  small: true,
                  onTap: () => context.go('/iot/alarms'),
                ),
              ],
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
          Divider(height: 1, color: AppColors.separator(context)),
          _IotModuleItem(
            icon: Icons.warning_amber_rounded,
            color: Colors.red,
            title: 'Alarm Yönetimi',
            subtitle: 'Alarmları görüntüleyin ve yönetin',
            onTap: () => context.go('/iot/alarms'),
          ),
          Divider(height: 1, color: AppColors.separator(context)),
          _IotModuleItem(
            icon: Icons.notifications_active,
            color: Colors.deepOrange,
            title: 'Global Alarmlar',
            subtitle: 'Tüm site ve provider alarmları',
            onTap: () => context.go('/iot/alarms/global'),
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
