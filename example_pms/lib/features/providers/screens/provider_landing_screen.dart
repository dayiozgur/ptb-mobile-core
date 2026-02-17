import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Renk paleti - çoklu variable serileri için
const _seriesColors = [
  Color(0xFF007AFF),
  Color(0xFFFF3B30),
  Color(0xFF34C759),
  Color(0xFFFF9500),
  Color(0xFFAF52DE),
  Color(0xFF00C7BE),
  Color(0xFFFF2D55),
  Color(0xFF5856D6),
];

/// Provider Landing Page - Provider detaylari ve iliskili veriler
class ProviderLandingScreen extends StatefulWidget {
  final String providerId;

  const ProviderLandingScreen({
    super.key,
    required this.providerId,
  });

  @override
  State<ProviderLandingScreen> createState() => _ProviderLandingScreenState();
}

class _ProviderLandingScreenState extends State<ProviderLandingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  // Provider data
  DataProvider? _provider;
  Site? _site;

  // Related data
  List<Controller> _controllers = [];
  List<Alarm> _activeAlarms = [];
  List<AlarmHistory> _alarmHistory = [];
  List<IoTLog> _logs = [];
  Map<String, Priority> _priorityMap = {};

  // Log tab state
  String _logSearchQuery = '';
  String? _selectedLogControllerId;

  // Analytics state
  int _selectedDays = 7;
  bool _isLoadingChart = false;
  List<Map<String, dynamic>> _analogVars = [];
  List<Map<String, dynamic>> _digitalVars = [];
  Set<String> _selectedAnalogIds = {};
  Set<String> _selectedDigitalIds = {};
  Map<String, List<LogTimeSeriesEntry>> _timeSeriesMap = {};
  static const _maxAnalogSelection = 5;
  static const _maxDigitalSelection = 4;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final tenantId = tenantService.currentTenantId;
    if (tenantId != null) {
      dataProviderService.setTenant(tenantId);
      controllerService.setTenant(tenantId);
      alarmService.setTenant(tenantId);
      iotLogService.setTenant(tenantId);
    }

    final orgId = organizationService.currentOrganizationId;
    if (orgId != null) {
      controllerService.setOrganization(orgId);
      alarmService.setOrganization(orgId);
    }

    try {
      // Load provider
      final allProviders = await dataProviderService.getAll();
      final provider = allProviders.firstWhere(
        (p) => p.id == widget.providerId,
        orElse: () => throw Exception('Provider not found'),
      );

      // Load site
      Site? site;
      if (provider.siteId != null) {
        site = await siteService.getSite(provider.siteId!);
      }

      // Load priorities
      final priorities = await priorityService.getAll(forceRefresh: true);
      final pMap = <String, Priority>{};
      for (final p in priorities) {
        pMap[p.id] = p;
      }

      // Load related data in parallel
      final results = await Future.wait([
        _loadControllers(),
        _loadActiveAlarms(),
        _loadAlarmHistory(),
        _loadLogs(),
      ]);

      if (mounted) {
        setState(() {
          _provider = provider;
          _site = site;
          _priorityMap = pMap;
          _controllers = results[0] as List<Controller>;
          _activeAlarms = results[1] as List<Alarm>;
          _alarmHistory = results[2] as List<AlarmHistory>;
          _logs = results[3] as List<IoTLog>;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load provider data', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Veriler yuklenirken hata olustu';
          _isLoading = false;
        });
      }
    }
  }

  Future<List<Controller>> _loadControllers() async {
    try {
      final allControllers = await controllerService.getAll();
      return allControllers
          .where((c) => c.providerId == widget.providerId)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Alarm>> _loadActiveAlarms() async {
    try {
      final allControllers = await controllerService.getAll();
      final providerControllers = allControllers
          .where((c) => c.providerId == widget.providerId)
          .toList();

      if (providerControllers.isEmpty) return [];

      final controllerIds = providerControllers.map((c) => c.id).toList();
      return await alarmService.getActiveAlarmsByControllers(controllerIds);
    } catch (_) {
      return [];
    }
  }

  Future<List<AlarmHistory>> _loadAlarmHistory() async {
    try {
      return await alarmService.getHistory(
        providerId: widget.providerId,
        limit: 100,
        forceRefresh: true,
        includeVariable: true,
      );
    } catch (_) {
      return [];
    }
  }

  Future<List<IoTLog>> _loadLogs() async {
    try {
      return await iotLogService.getLogs(
        providerId: widget.providerId,
        limit: 200,
        forceRefresh: true,
        includeVariable: true,
      );
    } catch (_) {
      return [];
    }
  }

  List<IoTLog> get _filteredLogs {
    var logs = _logs;
    if (_selectedLogControllerId != null) {
      logs = logs.where((l) => l.controllerId == _selectedLogControllerId).toList();
    }
    if (_logSearchQuery.isNotEmpty) {
      final query = _logSearchQuery.toLowerCase();
      logs = logs.where((log) =>
          (log.effectiveName?.toLowerCase().contains(query) ?? false) ||
          (log.effectiveDescription?.toLowerCase().contains(query) ?? false) ||
          (log.value?.toLowerCase().contains(query) ?? false) ||
          (log.name?.toLowerCase().contains(query) ?? false) ||
          (log.code?.toLowerCase().contains(query) ?? false)).toList();
    }
    return logs;
  }

  Future<void> _loadLogVariables() async {
    if (_selectedLogControllerId == null) return;

    setState(() {
      _analogVars = [];
      _digitalVars = [];
      _selectedAnalogIds = {};
      _selectedDigitalIds = {};
      _timeSeriesMap = {};
    });

    try {
      final results = await Future.wait([
        iotLogService.getLoggedVariables(
          controllerId: _selectedLogControllerId!,
          variableType: 'ANALOG',
          forceRefresh: true,
        ),
        iotLogService.getLoggedVariables(
          controllerId: _selectedLogControllerId!,
          variableType: 'INTEGER',
          forceRefresh: true,
        ),
        iotLogService.getLoggedVariables(
          controllerId: _selectedLogControllerId!,
          variableType: 'DIGITAL',
          forceRefresh: true,
        ),
      ]);

      if (mounted) {
        final analogVars = [...results[0], ...results[1]];
        analogVars.sort((a, b) =>
            (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));

        setState(() {
          _analogVars = analogVars;
          _digitalVars = results[2];
          if (analogVars.isNotEmpty) {
            _selectedAnalogIds = {analogVars.first['id'] as String};
          }
        });

        _loadChartData();
      }
    } catch (e) {
      Logger.error('Failed to load log variables', e);
    }
  }

  Future<void> _loadChartData() async {
    final allSelectedIds = {..._selectedAnalogIds, ..._selectedDigitalIds};
    if (allSelectedIds.isEmpty) {
      setState(() => _timeSeriesMap = {});
      return;
    }

    setState(() => _isLoadingChart = true);

    try {
      final futures = <Future<MapEntry<String, List<LogTimeSeriesEntry>>>>[];
      for (final varId in allSelectedIds) {
        futures.add(
          iotLogService
              .getLogTimeSeries(
                controllerId: _selectedLogControllerId,
                variableId: varId,
                days: _selectedDays,
                forceRefresh: true,
              )
              .then((entries) => MapEntry(varId, entries)),
        );
      }

      final results = await Future.wait(futures);
      final tsMap = <String, List<LogTimeSeriesEntry>>{};
      for (final entry in results) {
        tsMap[entry.key] = entry.value;
      }

      if (mounted) {
        setState(() {
          _timeSeriesMap = tsMap;
          _isLoadingChart = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load chart data', e);
      if (mounted) setState(() => _isLoadingChart = false);
    }
  }

  void _toggleAnalogVariable(String id) {
    setState(() {
      if (_selectedAnalogIds.contains(id)) {
        _selectedAnalogIds.remove(id);
      } else if (_selectedAnalogIds.length < _maxAnalogSelection) {
        _selectedAnalogIds.add(id);
      }
    });
    _loadChartData();
  }

  void _toggleDigitalVariable(String id) {
    setState(() {
      if (_selectedDigitalIds.contains(id)) {
        _selectedDigitalIds.remove(id);
      } else if (_selectedDigitalIds.length < _maxDigitalSelection) {
        _selectedDigitalIds.add(id);
      }
    });
    _loadChartData();
  }

  Map<String, dynamic>? _findVariable(String id) {
    return _analogVars.where((v) => v['id'] == id).firstOrNull ??
        _digitalVars.where((v) => v['id'] == id).firstOrNull;
  }

  Color _getSeriesColor(int index) {
    return _seriesColors[index % _seriesColors.length];
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _provider?.name ?? 'Provider',
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _loadData),
      ],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _errorMessage != null
              ? Center(child: AppErrorView(message: _errorMessage!, onRetry: _loadData))
              : Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.secondaryLabel(context),
                      indicatorColor: AppColors.primary,
                      tabAlignment: TabAlignment.start,
                      tabs: [
                        const Tab(text: 'Dashboard'),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Controllers'),
                              if (_controllers.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                _CountBadge(count: _controllers.length),
                              ],
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Alarmlar'),
                              if (_activeAlarms.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                _CountBadge(count: _activeAlarms.length, color: AppColors.error),
                              ],
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Loglar'),
                              if (_logs.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                _CountBadge(count: _logs.length),
                              ],
                            ],
                          ),
                        ),
                        const Tab(text: 'Detaylar'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildDashboardTab(),
                          _buildControllersTab(),
                          _buildAlarmsTab(),
                          _buildLogsTab(),
                          _buildDetailsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  // Dashboard Tab
  Widget _buildDashboardTab() {
    if (_provider == null) return const SizedBox();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProviderOverviewCard(),
            const SizedBox(height: AppSpacing.md),
            _buildQuickStats(),
            const SizedBox(height: AppSpacing.md),

            AppSectionHeader(title: 'Baglanti Durumu'),
            const SizedBox(height: AppSpacing.sm),
            _buildConnectionCard(),

            if (_activeAlarms.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              AppSectionHeader(
                title: 'Aktif Alarmlar',
                action: TextButton(
                  onPressed: () => _tabController.animateTo(2),
                  child: const Text('Tumu'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  children: _activeAlarms.take(3).map((alarm) {
                    final priority = alarm.priorityId != null ? _priorityMap[alarm.priorityId!] : null;
                    return _AlarmRow(alarm: alarm, priority: priority);
                  }).toList(),
                ),
              ),
            ],

            if (_controllers.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              AppSectionHeader(
                title: 'Controllers',
                action: TextButton(
                  onPressed: () => _tabController.animateTo(1),
                  child: const Text('Tumu'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  children: _controllers.take(3).map((controller) {
                    return AppListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _getControllerStatusColor(controller).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.developer_board, color: _getControllerStatusColor(controller), size: 18),
                      ),
                      title: controller.name,
                      subtitle: controller.type.label,
                      trailing: AppBadge(
                        label: controller.status == ControllerStatus.online ? 'Online' : 'Offline',
                        variant: controller.status == ControllerStatus.online
                            ? AppBadgeVariant.success
                            : AppBadgeVariant.error,
                        size: AppBadgeSize.small,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderOverviewCard() {
    return AppCard(
      variant: AppCardVariant.filled,
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _getStatusColor().withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_getTypeIcon(), color: _getStatusColor(), size: 28),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(_provider!.name, style: AppTypography.title2)),
                      _StatusBadge(status: _provider!.status),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(_provider!.type.label, style: AppTypography.subheadline.copyWith(color: AppColors.secondaryLabel(context))),
                  if (_site != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.location_city, size: 14, color: AppColors.tertiaryLabel(context)),
                        const SizedBox(width: 4),
                        Text(_site!.name, style: AppTypography.caption1.copyWith(color: AppColors.tertiaryLabel(context))),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.warning_amber_rounded,
            label: 'Alarm',
            value: _activeAlarms.length.toString(),
            color: _activeAlarms.isNotEmpty ? AppColors.error : AppColors.success,
            onTap: () => _tabController.animateTo(2),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            icon: Icons.developer_board,
            label: 'Controller',
            value: _controllers.length.toString(),
            color: AppColors.info,
            onTap: () => _tabController.animateTo(1),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            icon: Icons.article_outlined,
            label: 'Log',
            value: _logs.length.toString(),
            color: AppColors.warning,
            onTap: () => _tabController.animateTo(3),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionCard() {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getStatusColor(),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: _getStatusColor().withOpacity(0.4), blurRadius: 4, spreadRadius: 1),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(_getStatusText(), style: AppTypography.headline)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (_provider!.ip != null) _InfoRow(label: 'IP Adresi', value: _provider!.ip!),
            if (_provider!.hostname != null) _InfoRow(label: 'Hostname', value: _provider!.hostname!),
            if (_provider!.mac != null) _InfoRow(label: 'MAC', value: _provider!.mac!),
          ],
        ),
      ),
    );
  }

  // Controllers Tab
  Widget _buildControllersTab() {
    if (_controllers.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.developer_board,
          title: 'Controller Bulunamadi',
          message: 'Bu provider\'a bagli controller yok',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: AppSpacing.screenPadding,
        itemCount: _controllers.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final controller = _controllers[index];
          return _ControllerCard(controller: controller);
        },
      ),
    );
  }

  // Alarms Tab
  Widget _buildAlarmsTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(AppSpacing.screenHorizontal),
            decoration: BoxDecoration(
              color: AppColors.segmentedBackground(context),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppColors.textPrimary(Theme.of(context).brightness),
              unselectedLabelColor: AppColors.secondaryLabel(context),
              indicator: BoxDecoration(
                color: AppColors.segmentedIndicator(context),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              indicatorPadding: const EdgeInsets.all(4),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Aktif'),
                      if (_activeAlarms.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        _CountBadge(count: _activeAlarms.length, color: AppColors.error),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Gecmis'),
                      if (_alarmHistory.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        _CountBadge(count: _alarmHistory.length),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildActiveAlarmsContent(),
                _buildAlarmHistoryContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveAlarmsContent() {
    if (_activeAlarms.isEmpty) {
      return Center(
        child: AppEmptyState(icon: Icons.check_circle_outline, title: 'Aktif Alarm Yok', message: 'Bu provider\'da aktif alarm bulunmuyor'),
      );
    }

    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: _activeAlarms.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final alarm = _activeAlarms[index];
        final priority = alarm.priorityId != null ? _priorityMap[alarm.priorityId!] : null;
        return _ActiveAlarmCard(
          alarm: alarm,
          priority: priority,
          onTap: () => ActiveAlarmDetailSheet.show(context, alarm: alarm, priority: priority),
        );
      },
    );
  }

  Widget _buildAlarmHistoryContent() {
    if (_alarmHistory.isEmpty) {
      return Center(
        child: AppEmptyState(icon: Icons.history, title: 'Alarm Gecmisi Bos', message: 'Bu provider\'da gecmis alarm yok'),
      );
    }

    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: _alarmHistory.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final alarm = _alarmHistory[index];
        final priority = alarm.priorityId != null ? _priorityMap[alarm.priorityId!] : null;
        return _ResetAlarmCard(
          alarm: alarm,
          priority: priority,
          onTap: () => AlarmDetailSheet.show(context, alarm: alarm, priority: priority),
        );
      },
    );
  }

  // Logs Tab
  Widget _buildLogsTab() {
    final brightness = Theme.of(context).brightness;
    final dateFormat = DateFormat('dd/MM HH:mm:ss');

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Inner tab bar: Liste / Analiz
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.segmentedBackground(context),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppColors.textPrimary(brightness),
              unselectedLabelColor: AppColors.secondaryLabel(context),
              indicator: BoxDecoration(
                color: AppColors.segmentedIndicator(context),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              indicatorPadding: const EdgeInsets.all(4),
              tabs: const [
                Tab(text: 'Liste'),
                Tab(text: 'Analiz'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildLogListContent(brightness, dateFormat),
                _buildLogAnalyticsContent(brightness),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogListContent(Brightness brightness, DateFormat dateFormat) {
    return Column(
      children: [
        // Controller filter
        if (_controllers.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChip(
                    label: 'Tumu',
                    isSelected: _selectedLogControllerId == null,
                    onTap: () => setState(() => _selectedLogControllerId = null),
                  ),
                  const SizedBox(width: 6),
                  ..._controllers.map((c) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _FilterChip(
                      label: c.name,
                      isSelected: _selectedLogControllerId == c.id,
                      onTap: () => setState(() => _selectedLogControllerId = c.id),
                    ),
                  )),
                ],
              ),
            ),
          ),

        // Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: AppSearchField(
            placeholder: 'Variable adi veya deger ara...',
            onChanged: (value) => setState(() => _logSearchQuery = value),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),

        // Count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              AppChip(
                label: '${_filteredLogs.length} kayit',
                variant: AppChipVariant.tonal,
                color: AppColors.primary,
                small: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),

        // List
        Expanded(
          child: _filteredLogs.isEmpty
              ? Center(
                  child: AppEmptyState(
                    icon: Icons.article_outlined,
                    title: 'Log Bulunamadi',
                    message: _logs.isEmpty
                        ? 'Bu provider icin log kaydi yok'
                        : 'Arama kriterlerinize uygun log bulunamadi',
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    itemCount: _filteredLogs.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.divider(brightness)),
                    itemBuilder: (context, index) {
                      final log = _filteredLogs[index];
                      return _LogRow(log: log, dateFormat: dateFormat);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildLogAnalyticsContent(Brightness brightness) {
    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Controller selector for analytics
          if (_controllers.isNotEmpty) ...[
            Text('Controller', style: AppTypography.caption1.copyWith(color: AppColors.secondaryLabel(context))),
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.separator(context)),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedLogControllerId ?? (_controllers.isNotEmpty ? _controllers.first.id : null),
                  hint: Text('Controller secin', style: AppTypography.body.copyWith(color: AppColors.tertiaryLabel(context))),
                  isExpanded: true,
                  items: _controllers.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: c.status == ControllerStatus.online ? AppColors.success : AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text(c.name, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  )).toList(),
                  onChanged: (value) {
                    setState(() => _selectedLogControllerId = value);
                    _loadLogVariables();
                  },
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Period selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Son $_selectedDays gun',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary(brightness)),
              ),
              ChartPeriodSelector(
                selectedDays: _selectedDays,
                onChanged: (days) {
                  setState(() => _selectedDays = days);
                  _loadChartData();
                },
                options: const [1, 7, 30, 90],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Analog / Integer section
          _buildAnalyticsSectionHeader(brightness, Icons.show_chart, 'Analog / Integer', _analogVars.length, _selectedAnalogIds.length, _maxAnalogSelection),
          const SizedBox(height: AppSpacing.sm),
          _buildAnalyticsVariableChips(brightness, _analogVars, _selectedAnalogIds, _toggleAnalogVariable),
          const SizedBox(height: AppSpacing.sm),
          _buildAnalogChartContent(brightness),

          const SizedBox(height: AppSpacing.lg),

          // Digital section
          _buildAnalyticsSectionHeader(brightness, Icons.toggle_on, 'Digital', _digitalVars.length, _selectedDigitalIds.length, _maxDigitalSelection),
          const SizedBox(height: AppSpacing.sm),
          _buildAnalyticsVariableChips(brightness, _digitalVars, _selectedDigitalIds, _toggleDigitalVariable),
          const SizedBox(height: AppSpacing.sm),
          _buildDigitalChartContent(brightness),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSectionHeader(Brightness brightness, IconData icon, String title, int count, int selectedCount, int maxCount) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary(brightness))),
        const SizedBox(width: AppSpacing.sm),
        AppChip(label: '$count', variant: AppChipVariant.tonal, color: AppColors.primary, small: true),
        const Spacer(),
        if (count > 0) Text('$selectedCount/$maxCount secili', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(brightness))),
      ],
    );
  }

  Widget _buildAnalyticsVariableChips(Brightness brightness, List<Map<String, dynamic>> variables, Set<String> selectedIds, void Function(String) onToggle) {
    if (variables.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.separator(context)),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Text(
          _selectedLogControllerId == null ? 'Once controller secin' : 'Bu tip icin variable bulunamadi',
          style: TextStyle(fontSize: 13, color: AppColors.tertiaryLabel(context)),
          textAlign: TextAlign.center,
        ),
      );
    }

    final selectedList = selectedIds.toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: variables.map((v) {
        final id = v['id'] as String;
        final name = v['name'] as String? ?? '';
        final unit = v['measure_unit'] as String? ?? v['unit'] as String? ?? '';
        final isSelected = selectedIds.contains(id);
        final colorIndex = isSelected ? selectedList.indexOf(id) : 0;
        final chipColor = isSelected ? _getSeriesColor(colorIndex) : AppColors.systemGray;

        return GestureDetector(
          onTap: () => onToggle(id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? chipColor.withValues(alpha: 0.15)
                  : AppColors.segmentedBackground(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isSelected ? chipColor : Colors.transparent, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: chipColor, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                ],
                Text(
                  unit.isNotEmpty ? '$name ($unit)' : name,
                  style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, color: isSelected ? chipColor : AppColors.textSecondary(brightness)),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAnalogChartContent(Brightness brightness) {
    if (_isLoadingChart && _selectedAnalogIds.isNotEmpty) {
      return const Padding(padding: EdgeInsets.all(40), child: Center(child: AppLoadingIndicator()));
    }
    if (_selectedAnalogIds.isEmpty) {
      return _buildEmptyChart(brightness, 'Grafik icin analog/integer variable secin');
    }

    final seriesList = <VariableTimeSeries>[];
    final selectedList = _selectedAnalogIds.toList();
    for (var i = 0; i < selectedList.length; i++) {
      final varId = selectedList[i];
      final entries = _timeSeriesMap[varId];
      if (entries == null || entries.isEmpty) continue;
      final variable = _findVariable(varId);
      final name = variable?['name'] as String? ?? '';
      final unit = variable?['measure_unit'] as String? ?? variable?['unit'] as String? ?? '';
      seriesList.add(VariableTimeSeries(variableId: varId, variableName: name, unit: unit, color: _getSeriesColor(i), entries: entries));
    }

    if (seriesList.isEmpty) return _buildEmptyChart(brightness, 'Secili variable icin veri bulunamadi');

    return ChartContainer(
      title: 'Deger Grafigi',
      subtitle: '${seriesList.length} variable - Son $_selectedDays gun',
      isEmpty: false,
      child: MultiLogLineChart(seriesList: seriesList, height: 260, showLegend: seriesList.length > 1),
    );
  }

  Widget _buildDigitalChartContent(Brightness brightness) {
    if (_isLoadingChart && _selectedDigitalIds.isNotEmpty) {
      return const Padding(padding: EdgeInsets.all(40), child: Center(child: AppLoadingIndicator()));
    }
    if (_selectedDigitalIds.isEmpty) {
      return _buildEmptyChart(brightness, 'On/Off grafigi icin digital variable secin');
    }

    final seriesList = <VariableTimeSeries>[];
    final selectedList = _selectedDigitalIds.toList();
    for (var i = 0; i < selectedList.length; i++) {
      final varId = selectedList[i];
      final entries = _timeSeriesMap[varId];
      if (entries == null || entries.isEmpty) continue;
      final variable = _findVariable(varId);
      final name = variable?['name'] as String? ?? '';
      seriesList.add(VariableTimeSeries(variableId: varId, variableName: name, color: _getSeriesColor(i), entries: entries));
    }

    if (seriesList.isEmpty) return _buildEmptyChart(brightness, 'Secili variable icin veri bulunamadi');

    return ChartContainer(
      title: 'On/Off Durumu',
      subtitle: '${seriesList.length} digital variable - Son $_selectedDays gun',
      isEmpty: false,
      child: MultiLogOnOffChart(seriesList: seriesList, rowHeight: 32),
    );
  }

  Widget _buildEmptyChart(Brightness brightness, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.divider(brightness)),
      ),
      child: Column(
        children: [
          Icon(Icons.touch_app, size: 28, color: AppColors.textSecondary(brightness)),
          const SizedBox(height: AppSpacing.sm),
          Text(message, style: TextStyle(fontSize: 13, color: AppColors.textSecondary(brightness)), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // Details Tab
  Widget _buildDetailsTab() {
    if (_provider == null) return const Center(child: CircularProgressIndicator.adaptive());

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionHeader(title: 'Durum & Tip'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    _InfoRow(label: 'Durum', value: _getStatusText()),
                    _InfoRow(label: 'Tip', value: _provider!.type.label),
                    if (_provider!.code != null) _InfoRow(label: 'Kod', value: _provider!.code!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            AppSectionHeader(title: 'Baglanti Bilgileri'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    _InfoRow(label: 'IP Adresi', value: _provider!.ip ?? '-'),
                    _InfoRow(label: 'Hostname', value: _provider!.hostname ?? '-'),
                    _InfoRow(label: 'MAC', value: _provider!.mac ?? '-'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            AppSectionHeader(title: 'Iliskiler'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    _InfoRow(label: 'Site', value: _site?.name ?? '-'),
                    _InfoRow(label: 'Controller', value: _controllers.isNotEmpty ? _controllers.map((c) => c.name).join(', ') : '-'),
                  ],
                ),
              ),
            ),

            if (_provider!.description != null && _provider!.description!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              AppSectionHeader(title: 'Aciklama'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Padding(
                  padding: AppSpacing.cardInsets,
                  child: Text(_provider!.description!, style: AppTypography.body),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.md),
            AppSectionHeader(title: 'Kayit Bilgileri'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    _InfoRow(label: 'ID', value: _provider!.id),
                    _InfoRow(label: 'Olusturulma', value: _formatDate(_provider!.createdAt)),
                    if (_provider!.updatedAt != null)
                      _InfoRow(label: 'Guncelleme', value: _formatDate(_provider!.updatedAt!)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (_provider?.status) {
      case DataProviderStatus.active: return AppColors.success;
      case DataProviderStatus.inactive: return AppColors.systemGray;
      case DataProviderStatus.connecting: return AppColors.warning;
      case DataProviderStatus.error: return AppColors.error;
      case DataProviderStatus.disabled: return AppColors.systemGray;
      default: return AppColors.systemGray;
    }
  }

  String _getStatusText() {
    switch (_provider?.status) {
      case DataProviderStatus.active: return 'Aktif - Bagli';
      case DataProviderStatus.inactive: return 'Pasif';
      case DataProviderStatus.connecting: return 'Baglaniyor...';
      case DataProviderStatus.error: return 'Hata';
      case DataProviderStatus.disabled: return 'Devre Disi';
      default: return 'Bilinmiyor';
    }
  }

  IconData _getTypeIcon() {
    switch (_provider?.type) {
      case DataProviderType.modbus: return Icons.memory;
      case DataProviderType.opcUa: return Icons.account_tree;
      case DataProviderType.mqtt: return Icons.cloud_sync;
      case DataProviderType.http: return Icons.http;
      case DataProviderType.bacnet: return Icons.home_work;
      case DataProviderType.s7: return Icons.precision_manufacturing;
      case DataProviderType.allenBradley: return Icons.settings_input_component;
      case DataProviderType.database: return Icons.storage;
      case DataProviderType.file: return Icons.file_present;
      case DataProviderType.custom: return Icons.extension;
      default: return Icons.storage;
    }
  }

  Color _getControllerStatusColor(Controller controller) {
    switch (controller.status) {
      case ControllerStatus.online: return AppColors.success;
      case ControllerStatus.offline: return AppColors.error;
      case ControllerStatus.error: return AppColors.error;
      default: return AppColors.systemGray;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// ============================================================================
// Private Widgets
// ============================================================================

class _CountBadge extends StatelessWidget {
  final int count;
  final Color? color;

  const _CountBadge({required this.count, this.color});

  @override
  Widget build(BuildContext context) {
    final badgeColor = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: badgeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
      child: Text(count.toString(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: badgeColor)),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: AppSpacing.xxs),
            Text(value, style: AppTypography.headline.copyWith(fontWeight: FontWeight.w700)),
            Text(label, style: AppTypography.caption2.copyWith(color: AppColors.secondaryLabel(context))),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final DataProviderStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return AppBadge(label: _getLabel(), variant: _getVariant(), size: AppBadgeSize.small);
  }

  String _getLabel() {
    switch (status) {
      case DataProviderStatus.active: return 'Aktif';
      case DataProviderStatus.inactive: return 'Pasif';
      case DataProviderStatus.connecting: return 'Baglaniyor';
      case DataProviderStatus.error: return 'Hata';
      case DataProviderStatus.disabled: return 'Devre Disi';
    }
  }

  AppBadgeVariant _getVariant() {
    switch (status) {
      case DataProviderStatus.active: return AppBadgeVariant.success;
      case DataProviderStatus.inactive: return AppBadgeVariant.secondary;
      case DataProviderStatus.connecting: return AppBadgeVariant.warning;
      case DataProviderStatus.error: return AppBadgeVariant.error;
      case DataProviderStatus.disabled: return AppBadgeVariant.secondary;
    }
  }
}

class _ControllerCard extends StatelessWidget {
  final Controller controller;

  const _ControllerCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _getStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.developer_board, color: _getStatusColor(), size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(controller.name, style: AppTypography.headline, overflow: TextOverflow.ellipsis)),
                      AppBadge(label: _getStatusLabel(), variant: _getStatusVariant(), size: AppBadgeSize.small),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(controller.type.label, style: AppTypography.caption1.copyWith(color: AppColors.secondaryLabel(context))),
                  if (controller.ipAddress != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.lan, size: 12, color: AppColors.tertiaryLabel(context)),
                        const SizedBox(width: 4),
                        Text(controller.ipAddress!, style: AppTypography.caption2.copyWith(color: AppColors.tertiaryLabel(context))),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (controller.status) {
      case ControllerStatus.online: return AppColors.success;
      case ControllerStatus.offline: return AppColors.error;
      case ControllerStatus.connecting: return AppColors.info;
      case ControllerStatus.error: return AppColors.error;
      case ControllerStatus.maintenance: return AppColors.warning;
      case ControllerStatus.disabled: return AppColors.systemGray;
      case ControllerStatus.unknown: return AppColors.systemGray;
    }
  }

  String _getStatusLabel() {
    switch (controller.status) {
      case ControllerStatus.online: return 'Online';
      case ControllerStatus.offline: return 'Offline';
      case ControllerStatus.connecting: return 'Baglaniyor';
      case ControllerStatus.error: return 'Hata';
      case ControllerStatus.maintenance: return 'Bakimda';
      case ControllerStatus.disabled: return 'Devre Disi';
      case ControllerStatus.unknown: return 'Bilinmiyor';
    }
  }

  AppBadgeVariant _getStatusVariant() {
    switch (controller.status) {
      case ControllerStatus.online: return AppBadgeVariant.success;
      case ControllerStatus.offline: return AppBadgeVariant.error;
      case ControllerStatus.connecting: return AppBadgeVariant.info;
      case ControllerStatus.error: return AppBadgeVariant.error;
      case ControllerStatus.maintenance: return AppBadgeVariant.warning;
      case ControllerStatus.disabled: return AppBadgeVariant.secondary;
      case ControllerStatus.unknown: return AppBadgeVariant.secondary;
    }
  }
}

class _AlarmRow extends StatelessWidget {
  final Alarm alarm;
  final Priority? priority;

  const _AlarmRow({required this.alarm, this.priority});

  @override
  Widget build(BuildContext context) {
    final priorityColor = priority?.displayColor ?? AppColors.error;

    return Padding(
      padding: AppSpacing.cardInsets,
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: priorityColor, shape: BoxShape.circle)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alarm.name ?? alarm.code ?? 'Alarm', style: AppTypography.subheadline, overflow: TextOverflow.ellipsis),
                Text(alarm.durationFormatted, style: AppTypography.caption2.copyWith(color: AppColors.secondaryLabel(context))),
              ],
            ),
          ),
          if (priority != null) AppBadge(label: priority!.name ?? '', variant: AppBadgeVariant.neutral, size: AppBadgeSize.small),
        ],
      ),
    );
  }
}

class _ActiveAlarmCard extends StatelessWidget {
  final Alarm alarm;
  final Priority? priority;
  final VoidCallback onTap;

  const _ActiveAlarmCard({required this.alarm, this.priority, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final priorityColor = priority?.displayColor ?? AppColors.error;

    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            Container(width: 4, height: 48, decoration: BoxDecoration(color: priorityColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: priorityColor, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(alarm.name ?? alarm.code ?? 'Alarm', style: AppTypography.headline, overflow: TextOverflow.ellipsis)),
                      if (priority != null) AppBadge(label: priority!.name ?? '', variant: AppBadgeVariant.neutral, size: AppBadgeSize.small),
                    ],
                  ),
                  if (alarm.effectiveDescription != null) ...[
                    const SizedBox(height: 2),
                    Text(alarm.effectiveDescription!, style: AppTypography.caption1.copyWith(color: AppColors.secondaryLabel(context)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: AppColors.tertiaryLabel(context)),
                      const SizedBox(width: 2),
                      Text(alarm.durationFormatted, style: AppTypography.caption2.copyWith(color: AppColors.tertiaryLabel(context))),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _ResetAlarmCard extends StatelessWidget {
  final AlarmHistory alarm;
  final Priority? priority;
  final VoidCallback onTap;

  const _ResetAlarmCard({required this.alarm, this.priority, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final priorityColor = priority?.displayColor ?? AppColors.systemGray;

    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            Container(width: 4, height: 48, decoration: BoxDecoration(color: priorityColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, size: 14, color: AppColors.success),
                      const SizedBox(width: 6),
                      Expanded(child: Text(alarm.name ?? alarm.code ?? 'Alarm', style: AppTypography.headline, overflow: TextOverflow.ellipsis)),
                      if (priority != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: priorityColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                          child: Text(priority!.name ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: priorityColor)),
                        ),
                    ],
                  ),
                  if (alarm.effectiveDescription != null) ...[
                    const SizedBox(height: 2),
                    Text(alarm.effectiveDescription!, style: AppTypography.caption1.copyWith(color: AppColors.secondaryLabel(context)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 12, color: AppColors.tertiaryLabel(context)),
                      const SizedBox(width: 2),
                      Text(alarm.durationFormatted, style: AppTypography.caption2.copyWith(color: AppColors.tertiaryLabel(context))),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final IoTLog log;
  final DateFormat dateFormat;

  const _LogRow({required this.log, required this.dateFormat});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isOnOff = log.onOff != null;
    final isOn = log.onOff == 1;

    final varName = log.effectiveName;
    final varDesc = log.effectiveDescription;
    final unit = log.effectiveUnit;

    String displayValue;
    if (isOnOff) {
      displayValue = isOn ? 'ON' : 'OFF';
    } else {
      displayValue = log.value ?? '-';
      if (unit != null && unit.isNotEmpty && log.value != null) {
        displayValue = '${log.value} $unit';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isOnOff)
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: (isOn ? AppColors.success : AppColors.systemGray4).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(isOn ? Icons.power : Icons.power_off, size: 18, color: isOn ? AppColors.success : AppColors.systemGray),
            )
          else
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.show_chart, size: 18, color: AppColors.primary),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (varName != null && varName.isNotEmpty)
                  Text(varName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary(brightness)), overflow: TextOverflow.ellipsis),
                if (varDesc != null && varDesc.isNotEmpty && varDesc != varName)
                  Text(varDesc, style: TextStyle(fontSize: 12, color: AppColors.textSecondary(brightness)), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  log.dateTime != null ? dateFormat.format(log.dateTime!) : '-',
                  style: TextStyle(fontSize: 11, color: AppColors.tertiaryLabel(context), fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isOnOff)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (isOn ? AppColors.success : AppColors.systemGray4).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isOn ? AppColors.success : AppColors.systemGray4, width: 1),
              ),
              child: Text(displayValue, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isOn ? AppColors.success : AppColors.systemGray)),
            )
          else
            Text(displayValue, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary(brightness), fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.separator(context),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? AppColors.primary : AppColors.secondaryLabel(context),
          ),
        ),
      ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: AppTypography.subheadline.copyWith(color: AppColors.secondaryLabel(context)))),
          Expanded(child: Text(value, style: AppTypography.subheadline)),
        ],
      ),
    );
  }
}
