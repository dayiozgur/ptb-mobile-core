import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../shell/screens/main_shell_screen.dart';

class MonitoringDashboardScreen extends StatefulWidget {
  const MonitoringDashboardScreen({super.key});

  @override
  State<MonitoringDashboardScreen> createState() => _MonitoringDashboardScreenState();
}

class _MonitoringDashboardScreenState extends State<MonitoringDashboardScreen> {
  bool _isLoading = true;

  // Controller stats
  int _totalControllers = 0;

  // Provider stats
  int _totalProviders = 0;
  int _activeProviders = 0;
  int _inactiveProviders = 0;
  int _errorProviders = 0;

  // Alarm stats
  int _activeAlarmCount = 0;
  Map<String, int> _alarmCountByPriority = {};
  List<Alarm> _recentAlarms = [];
  Map<String, Priority> _priorityMap = {};
  List<Priority> _priorities = [];

  // Site stats
  int _siteCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final tenantId = tenantService.currentTenantId;
    final orgId = organizationService.currentOrganizationId;

    if (tenantId != null) {
      controllerService.setTenant(tenantId);
      alarmService.setTenant(tenantId);
      dataProviderService.setTenant(tenantId);
    }

    if (orgId != null) {
      controllerService.setOrganization(orgId);
      alarmService.setOrganization(orgId);
    }

    // Load sites count
    int siteCount = 0;
    if (orgId != null) {
      try {
        final sites = await siteService.getSites(orgId);
        siteCount = sites.length;
      } catch (e) {
        Logger.error('Failed to load sites', e);
      }
    }

    // Load controllers
    List<Controller> controllers = [];
    try {
      controllers = await controllerService.getAll();
    } catch (e) {
      Logger.error('Failed to load controllers', e);
    }

    // Load providers
    List<DataProvider> providers = [];
    try {
      providers = await dataProviderService.getAll();
    } catch (e) {
      Logger.error('Failed to load providers', e);
    }

    // Load priorities
    List<Priority> priorities = [];
    try {
      priorities = await priorityService.getAll(forceRefresh: true);
    } catch (e) {
      Logger.error('Failed to load priorities', e);
    }

    final pMap = <String, Priority>{};
    for (final p in priorities) {
      pMap[p.id] = p;
    }

    // Load active alarms
    List<Alarm> activeAlarms = [];
    try {
      activeAlarms = await alarmService.getActiveAlarms(includeVariable: true);
    } catch (e) {
      Logger.error('Failed to load alarms', e);
    }

    // Count alarms by priority
    final alarmCountByPriority = <String, int>{};
    for (final alarm in activeAlarms) {
      if (alarm.priorityId != null && pMap.containsKey(alarm.priorityId)) {
        alarmCountByPriority[alarm.priorityId!] =
            (alarmCountByPriority[alarm.priorityId!] ?? 0) + 1;
      }
    }

    if (mounted) {
      setState(() {
        _siteCount = siteCount;
        _totalControllers = controllers.length;
        _totalProviders = providers.length;
        _activeProviders = providers.where((p) => p.status == DataProviderStatus.active).length;
        _inactiveProviders = providers.where((p) => p.status == DataProviderStatus.inactive).length;
        _errorProviders = providers.where((p) => p.status == DataProviderStatus.error).length;
        _activeAlarmCount = activeAlarms.length;
        _alarmCountByPriority = alarmCountByPriority;
        _recentAlarms = activeAlarms.take(5).toList();
        _priorityMap = pMap;
        _priorities = priorities..sort((a, b) => (b.level ?? 0).compareTo(a.level ?? 0));
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'PMS Dashboard',
      showBackButton: false,
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
              // Context Info (Organization)
              _buildContextInfo(),
              const SizedBox(height: AppSpacing.lg),

              // Genel Bakis: Siteler, Controllerlar, Providerlar
              AppSectionHeader(title: 'Genel Bakis'),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      title: 'Siteler',
                      value: _isLoading ? '-' : '$_siteCount',
                      icon: Icons.location_city,
                      color: AppColors.primary,
                      onTap: () {
                        // Siteler tab'ina gecis
                        MainShellScope.of(context)?.switchTab(2);
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: MetricCard(
                      title: 'Controllerlar',
                      value: _isLoading ? '-' : '$_totalControllers',
                      icon: Icons.developer_board,
                      color: Colors.blue,
                      onTap: () => context.push('/controllers'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: MetricCard(
                      title: 'Providerlar',
                      value: _isLoading ? '-' : '$_totalProviders',
                      icon: Icons.storage,
                      color: Colors.green,
                      onTap: () => context.push('/providers'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Provider Durumu
              AppSectionHeader(
                title: 'Provider Durumu',
                action: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      title: 'Aktif',
                      value: _isLoading ? '-' : '$_activeProviders',
                      icon: Icons.check_circle,
                      color: AppColors.success,
                      onTap: () => context.push('/providers'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: MetricCard(
                      title: 'Pasif',
                      value: _isLoading ? '-' : '$_inactiveProviders',
                      icon: Icons.pause_circle,
                      color: AppColors.warning,
                      onTap: () => context.push('/providers'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: MetricCard(
                      title: 'Hata',
                      value: _isLoading ? '-' : '$_errorProviders',
                      icon: Icons.error,
                      color: AppColors.error,
                      onTap: () => context.push('/providers'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Alarm Durumu
              AppSectionHeader(title: 'Alarm Durumu'),
              const SizedBox(height: AppSpacing.sm),
              // Aktif alarm kart
              MetricCard(
                title: 'Aktif Alarm',
                value: _isLoading ? '-' : '$_activeAlarmCount',
                icon: Icons.warning_amber_rounded,
                color: AppColors.error,
              ),
              const SizedBox(height: AppSpacing.sm),
              // Priority bazli alarm sayilari
              if (!_isLoading && _priorities.isNotEmpty)
                _buildPriorityAlarmCards(),

              const SizedBox(height: AppSpacing.lg),

              // Son Alarmlar
              AppSectionHeader(
                title: 'Son Alarmlar',
                action: TextButton(
                  onPressed: () => context.push('/alarms/active'),
                  child: Text(
                    'Tumunu Gor',
                    style: AppTypography.footnote.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildRecentAlarms(),

              const SizedBox(height: AppSpacing.lg),

              // Hizli Erisim
              AppSectionHeader(title: 'Hizli Erisim'),
              const SizedBox(height: AppSpacing.sm),
              _buildQuickNavigation(),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityAlarmCards() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: _priorities.map((priority) {
        final count = _alarmCountByPriority[priority.id] ?? 0;
        return SizedBox(
          width: (MediaQuery.of(context).size.width - AppSpacing.screenHorizontal * 2 - AppSpacing.sm) / 2,
          child: AppCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 32,
                    decoration: BoxDecoration(
                      color: priority.displayColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          priority.label,
                          style: AppTypography.caption1.copyWith(
                            color: AppColors.secondaryLabel(context),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$count',
                          style: AppTypography.title3.copyWith(
                            color: count > 0 ? priority.displayColor : AppColors.secondaryLabel(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildContextInfo() {
    final org = organizationService.currentOrganization;

    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            Icon(Icons.apartment, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (org != null)
                    Text(
                      org.name,
                      style: AppTypography.subheadline,
                    ),
                  if (org?.city != null)
                    Text(
                      org!.city!,
                      style: AppTypography.caption1.copyWith(
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.go('/organizations'),
              child: const Text('Degistir'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAlarms() {
    if (_isLoading) {
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

    if (_recentAlarms.isEmpty) {
      return AppCard(
        child: Padding(
          padding: AppSpacing.cardInsets,
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 40,
                  color: AppColors.success,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Aktif alarm bulunmuyor',
                  style: AppTypography.subheadline.copyWith(
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AppCard(
      child: Column(
        children: List.generate(_recentAlarms.length, (index) {
          final alarm = _recentAlarms[index];
          final priority = alarm.priorityId != null
              ? _priorityMap[alarm.priorityId!]
              : null;
          final priorityColor = priority?.displayColor ?? AppColors.error;

          return Column(
            children: [
              if (index > 0)
                Divider(height: 1, color: AppColors.separator(context)),
              AppListTile(
                leading: Container(
                  width: 8,
                  height: 40,
                  decoration: BoxDecoration(
                    color: priorityColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                title: alarm.name ?? alarm.code ?? 'Alarm',
                subtitle: priority?.label ?? alarm.durationFormatted,
                trailing: Text(
                  alarm.durationFormatted,
                  style: AppTypography.caption2.copyWith(
                    color: priorityColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  ActiveAlarmDetailSheet.show(
                    context,
                    alarm: alarm,
                    priority: priority,
                  );
                },
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildQuickNavigation() {
    return AppCard(
      child: Column(
        children: [
          _QuickNavItem(
            icon: Icons.developer_board,
            color: Colors.blue,
            title: 'Controllers',
            subtitle: _isLoading ? '...' : '$_totalControllers controller',
            onTap: () => context.push('/controllers'),
          ),
          Divider(height: 1, color: AppColors.separator(context)),
          _QuickNavItem(
            icon: Icons.data_object,
            color: Colors.orange,
            title: 'Degiskenler',
            subtitle: 'Tag ve veri noktalarini goruntule',
            onTap: () => context.push('/variables'),
          ),
          Divider(height: 1, color: AppColors.separator(context)),
          _QuickNavItem(
            icon: Icons.warning_amber_rounded,
            color: Colors.red,
            title: 'Alarm Yonetimi',
            subtitle: 'Alarm dashboard ve gecmisi',
            onTap: () => context.push('/alarms'),
          ),
          Divider(height: 1, color: AppColors.separator(context)),
          _QuickNavItem(
            icon: Icons.article_outlined,
            color: Colors.teal,
            title: 'Log Goruntule',
            subtitle: 'IoT log verileri ve analiz',
            onTap: () => context.push('/logs'),
          ),
          Divider(height: 1, color: AppColors.separator(context)),
          _QuickNavItem(
            icon: Icons.storage,
            color: Colors.green,
            title: 'Veri Saglayicilar',
            subtitle: _isLoading ? '...' : '$_totalProviders provider',
            onTap: () => context.push('/providers'),
          ),
        ],
      ),
    );
  }
}

class _QuickNavItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickNavItem({
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
