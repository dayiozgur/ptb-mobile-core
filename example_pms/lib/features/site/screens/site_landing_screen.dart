import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Site Landing Page - Site detaylari ve IoT verileri icin sekmeli yapi
class SiteLandingScreen extends StatefulWidget {
  final String siteId;

  const SiteLandingScreen({
    super.key,
    required this.siteId,
  });

  @override
  State<SiteLandingScreen> createState() => _SiteLandingScreenState();
}

class _SiteLandingScreenState extends State<SiteLandingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  // Site data
  Site? _site;
  Organization? _organization;

  // IoT data
  List<DataProvider> _providers = [];
  List<Controller> _controllers = [];
  List<Alarm> _activeAlarms = [];
  List<AlarmHistory> _resetAlarms = [];
  Map<String, Priority> _priorityMap = {};

  // KPI data
  List<AlarmTimelineEntry> _timeline = [];
  AlarmMttrStats _mttrStats = const AlarmMttrStats(overallMttr: Duration.zero);
  List<AlarmFrequency> _topAlarms = [];
  AlarmHeatmapData _heatmapData = AlarmHeatmapData(
    matrix: List.generate(7, (_) => List.filled(24, 0)),
    maxCount: 0,
    weekStart: DateTime.now(),
  );

  // Stats
  int _activeControllerCount = 0;
  int _activeProviderCount = 0;

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
      controllerService.setTenant(tenantId);
      dataProviderService.setTenant(tenantId);
      alarmService.setTenant(tenantId);
    }

    final orgId = organizationService.currentOrganizationId;
    if (orgId != null) {
      controllerService.setOrganization(orgId);
      alarmService.setOrganization(orgId);
    }

    try {
      // Load site info
      final site = await siteService.getSite(widget.siteId);
      if (site == null) {
        setState(() {
          _errorMessage = 'Site bulunamadi';
          _isLoading = false;
        });
        return;
      }

      // Load organization
      Organization? org;
      try {
        org = await organizationService.getOrganization(site.organizationId);
      } catch (_) {}

      // Load priorities
      final priorities = await priorityService.getAll(forceRefresh: true);
      final pMap = <String, Priority>{};
      for (final p in priorities) {
        pMap[p.id] = p;
      }

      // Load IoT data + KPI data in parallel
      final results = await Future.wait([
        _loadProviders(),
        _loadControllers(),
        _loadActiveAlarms(),
        _loadResetAlarms(),
        alarmService.getAlarmTimeline(siteId: widget.siteId, days: 30),
        alarmService.getMttrStats(siteId: widget.siteId),
        alarmService.getTopAlarms(siteId: widget.siteId),
        alarmService.getAlarmHeatmap(siteId: widget.siteId),
      ]);

      if (mounted) {
        setState(() {
          _site = site;
          _organization = org;
          _priorityMap = pMap;
          _providers = results[0] as List<DataProvider>;
          _controllers = results[1] as List<Controller>;
          _activeAlarms = results[2] as List<Alarm>;
          _resetAlarms = results[3] as List<AlarmHistory>;
          _timeline = results[4] as List<AlarmTimelineEntry>;
          _mttrStats = results[5] as AlarmMttrStats;
          _topAlarms = results[6] as List<AlarmFrequency>;
          _heatmapData = results[7] as AlarmHeatmapData;
          _activeControllerCount = _controllers
              .where((c) => c.status == ControllerStatus.online)
              .length;
          _activeProviderCount = _providers
              .where((p) => p.status == DataProviderStatus.active)
              .length;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load site data', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Veriler yuklenirken hata olustu';
          _isLoading = false;
        });
      }
    }
  }

  Future<List<DataProvider>> _loadProviders() async {
    try {
      final allProviders = await dataProviderService.getAll();
      return allProviders.where((p) => p.siteId == widget.siteId).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Controller>> _loadControllers() async {
    try {
      final allControllers = await controllerService.getAll();
      return allControllers.where((c) => c.siteId == widget.siteId).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Alarm>> _loadActiveAlarms() async {
    try {
      final siteControllers = await controllerService.getAll();
      final filteredControllers = siteControllers
          .where((c) => c.siteId == widget.siteId)
          .toList();

      if (filteredControllers.isEmpty) return [];

      final controllerIds = filteredControllers.map((c) => c.id).toList();
      return await alarmService.getActiveAlarmsByControllers(controllerIds);
    } catch (_) {
      return [];
    }
  }

  Future<List<AlarmHistory>> _loadResetAlarms() async {
    try {
      return await alarmService.getHistory(
        siteId: widget.siteId,
        limit: 100,
        forceRefresh: true,
        includeVariable: true,
      );
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _site?.name ?? 'Site',
      actions: [
        AppIconButton(
          icon: Icons.refresh,
          onPressed: _loadData,
        ),
      ],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _errorMessage != null
              ? Center(
                  child: AppErrorView(
                    message: _errorMessage!,
                    onRetry: _loadData,
                  ),
                )
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
                              const Text('Providers'),
                              if (_providers.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                _CountBadge(count: _providers.length),
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
                                _CountBadge(
                                  count: _activeAlarms.length,
                                  color: AppColors.error,
                                ),
                              ],
                            ],
                          ),
                        ),
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
                        const Tab(text: 'Detaylar'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildDashboardTab(),
                          _buildProvidersTab(),
                          _buildAlarmsTab(),
                          _buildControllersTab(),
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
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSiteOverviewCard(),
            const SizedBox(height: AppSpacing.md),
            _buildQuickStats(),
            const SizedBox(height: AppSpacing.md),

            if (_activeAlarms.isNotEmpty) ...[
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
                    final priority = alarm.priorityId != null
                        ? _priorityMap[alarm.priorityId!]
                        : null;
                    return _AlarmRow(alarm: alarm, priority: priority);
                  }).toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            AppSectionHeader(title: 'IoT Ozeti'),
            const SizedBox(height: AppSpacing.sm),
            _buildIotSummary(),

            if (_resetAlarms.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              AppSectionHeader(title: 'Son Alarm Gecmisi'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  children: _resetAlarms.take(3).map((alarm) {
                    final priority = alarm.priorityId != null
                        ? _priorityMap[alarm.priorityId!]
                        : null;
                    return _ResetAlarmRow(alarm: alarm, priority: priority);
                  }).toList(),
                ),
              ),
            ],

            // KPI Widgets
            const SizedBox(height: AppSpacing.md),

            ChartContainer(
              title: 'Priority Trendi',
              subtitle: 'Son 30 gun',
              isEmpty: _timeline.every((e) => e.totalCount == 0),
              emptyMessage: 'Bu donemde alarm kaydi yok',
              child: AlarmPriorityTrendChart(
                entries: _timeline,
                priorities: _priorityMap,
                height: 180,
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            ChartContainer(
              title: 'Ortalama Cozum Suresi (MTTR)',
              subtitle: 'Son 30 gun',
              isEmpty: _mttrStats.totalAlarmCount == 0,
              emptyMessage: 'Cozulmus alarm bulunamadi',
              child: AlarmMttrCard(
                stats: _mttrStats,
                priorities: _priorityMap,
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            ChartContainer(
              title: 'En Sik Tekrarlayan Alarmlar',
              subtitle: 'Son 30 gun - Top 10',
              isEmpty: _topAlarms.isEmpty,
              emptyMessage: 'Alarm verisi bulunamadi',
              child: AlarmTopOffendersCard(
                alarms: _topAlarms,
                priorities: _priorityMap,
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            ChartContainer(
              title: 'Alarm Yogunluk Haritasi',
              subtitle: 'Haftalik gun x saat dagilimi',
              isEmpty: _heatmapData.totalCount == 0,
              emptyMessage: 'Bu haftada alarm kaydi yok',
              child: AlarmHeatmapChart(
                data: _heatmapData,
                height: 200,
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildSiteOverviewCard() {
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
                color: _getColorFromString(_site?.color),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _site?.imagePath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _site!.imagePath!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.location_city,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.location_city,
                      color: Colors.white,
                      size: 28,
                    ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_site?.name ?? '', style: AppTypography.title2),
                  if (_organization != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.apartment, size: 14, color: AppColors.secondaryLabel(context)),
                        const SizedBox(width: 4),
                        Text(
                          _organization!.name,
                          style: AppTypography.caption1.copyWith(
                            color: AppColors.secondaryLabel(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_site?.address != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: AppColors.tertiaryLabel(context)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _site!.fullAddress,
                            style: AppTypography.caption2.copyWith(
                              color: AppColors.tertiaryLabel(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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
            label: 'Aktif Alarm',
            value: _activeAlarms.length.toString(),
            color: _activeAlarms.isNotEmpty ? AppColors.error : AppColors.success,
            onTap: () => _tabController.animateTo(2),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            icon: Icons.storage,
            label: 'Provider',
            value: '$_activeProviderCount/${_providers.length}',
            color: AppColors.success,
            onTap: () => _tabController.animateTo(1),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            icon: Icons.developer_board,
            label: 'Controller',
            value: '$_activeControllerCount/${_controllers.length}',
            color: AppColors.info,
            onTap: () => _tabController.animateTo(3),
          ),
        ),
      ],
    );
  }

  Widget _buildIotSummary() {
    return AppCard(
      child: Column(
        children: [
          AppListTile(
            leading: _IconBox(icon: Icons.storage, color: Colors.green),
            title: 'Veri Saglayicilar',
            subtitle: '$_activeProviderCount aktif / ${_providers.length} toplam',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _tabController.animateTo(1),
          ),
          Divider(height: 1, color: AppColors.separator(context)),
          AppListTile(
            leading: _IconBox(icon: Icons.developer_board, color: Colors.blue),
            title: 'Controllers',
            subtitle: '$_activeControllerCount aktif / ${_controllers.length} toplam',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _tabController.animateTo(3),
          ),
          Divider(height: 1, color: AppColors.separator(context)),
          AppListTile(
            leading: _IconBox(icon: Icons.history, color: Colors.purple),
            title: 'Alarm Gecmisi',
            subtitle: '${_resetAlarms.length} kayit',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Show alarm history
            },
          ),
        ],
      ),
    );
  }

  // Providers Tab
  Widget _buildProvidersTab() {
    if (_providers.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.storage,
          title: 'Provider Bulunamadi',
          message: 'Bu siteye bagli veri saglayici yok',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: AppSpacing.screenPadding,
        itemCount: _providers.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final provider = _providers[index];
          return _ProviderCard(
            provider: provider,
            onTap: () => context.push('/providers/${provider.id}'),
          );
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
                      if (_resetAlarms.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        _CountBadge(count: _resetAlarms.length),
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
        child: AppEmptyState(
          icon: Icons.check_circle_outline,
          title: 'Aktif Alarm Yok',
          message: 'Bu sitede aktif alarm bulunmuyor',
        ),
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
          onTap: () {
            ActiveAlarmDetailSheet.show(context, alarm: alarm, priority: priority);
          },
        );
      },
    );
  }

  Widget _buildAlarmHistoryContent() {
    if (_resetAlarms.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.history,
          title: 'Alarm Gecmisi Bos',
          message: 'Resetlenmis alarm yok',
        ),
      );
    }

    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: _resetAlarms.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final alarm = _resetAlarms[index];
        final priority = alarm.priorityId != null ? _priorityMap[alarm.priorityId!] : null;
        return _ResetAlarmCard(
          alarm: alarm,
          priority: priority,
          onTap: () {
            AlarmDetailSheet.show(context, alarm: alarm, priority: priority);
          },
        );
      },
    );
  }

  // Controllers Tab
  Widget _buildControllersTab() {
    if (_controllers.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.developer_board,
          title: 'Controller Bulunamadi',
          message: 'Bu siteye bagli controller yok',
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
          return _ControllerCard(
            controller: controller,
            onTap: () {
              context.push(
                '/controllers/${controller.id}?name=${Uri.encodeComponent(controller.name)}',
              );
            },
          );
        },
      ),
    );
  }

  // Details Tab
  Widget _buildDetailsTab() {
    if (_site == null) return const Center(child: CircularProgressIndicator.adaptive());

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionHeader(title: 'Temel Bilgiler'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    _InfoRow(label: 'Site Adi', value: _site!.name),
                    _InfoRow(label: 'Kod', value: _site!.code ?? '-'),
                    if (_organization != null)
                      _InfoRow(label: 'Organizasyon', value: _organization!.name),
                    _InfoRow(label: 'Kat Sayisi', value: _site!.floorCount?.toString() ?? '-'),
                    _InfoRow(
                      label: 'Alan',
                      value: _site!.grossAreaSqm != null ? '${_site!.grossAreaSqm!.toInt()} m2' : '-',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            AppSectionHeader(title: 'Adres Bilgileri'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    _InfoRow(label: 'Adres', value: _site!.address ?? '-'),
                    _InfoRow(label: 'Sehir', value: _site!.city ?? '-'),
                    _InfoRow(label: 'Ilce', value: _site!.town ?? '-'),
                    _InfoRow(label: 'Ulke', value: _site!.country ?? '-'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            AppSectionHeader(title: 'Teknik Bilgiler'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    _InfoRow(label: 'Site ID', value: _site!.id),
                    if (_site!.createdAt != null)
                      _InfoRow(label: 'Olusturulma', value: _formatDate(_site!.createdAt!)),
                    if (_site!.updatedAt != null)
                      _InfoRow(label: 'Guncelleme', value: _formatDate(_site!.updatedAt!)),
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

  Color _getColorFromString(String? colorString) {
    if (colorString == null || colorString.isEmpty) return AppColors.primary;
    try {
      if (colorString.startsWith('#')) {
        return Color(int.parse(colorString.substring(1), radix: 16) + 0xFF000000);
      }
      return AppColors.primary;
    } catch (_) {
      return AppColors.primary;
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
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count.toString(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: badgeColor),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

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

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconBox({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
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
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: priorityColor, shape: BoxShape.circle),
          ),
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

class _ResetAlarmRow extends StatelessWidget {
  final AlarmHistory alarm;
  final Priority? priority;

  const _ResetAlarmRow({required this.alarm, this.priority});

  @override
  Widget build(BuildContext context) {
    final priorityColor = priority?.displayColor ?? AppColors.systemGray;

    return Padding(
      padding: AppSpacing.cardInsets,
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 14, color: AppColors.success),
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
          if (priority != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: priorityColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                priority!.name ?? '',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: priorityColor),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final DataProvider provider;
  final VoidCallback onTap;

  const _ProviderCard({required this.provider, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _getStatusColor(context).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_getTypeIcon(), color: _getStatusColor(context), size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(provider.name, style: AppTypography.headline, overflow: TextOverflow.ellipsis)),
                      _StatusBadge(status: provider.status),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(provider.type.label, style: AppTypography.caption1.copyWith(color: AppColors.secondaryLabel(context))),
                  if (provider.ip != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.lan, size: 12, color: AppColors.tertiaryLabel(context)),
                        const SizedBox(width: 4),
                        Text(provider.ip!, style: AppTypography.caption2.copyWith(color: AppColors.tertiaryLabel(context))),
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
      case DataProviderStatus.active: return AppColors.success;
      case DataProviderStatus.inactive: return AppColors.tertiaryLabel(context);
      case DataProviderStatus.connecting: return AppColors.warning;
      case DataProviderStatus.error: return AppColors.error;
      case DataProviderStatus.disabled: return AppColors.tertiaryLabel(context);
    }
  }

  IconData _getTypeIcon() {
    switch (provider.type) {
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
    }
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
  final VoidCallback onTap;

  const _ControllerCard({required this.controller, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
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
            const Icon(Icons.chevron_right),
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
          SizedBox(
            width: 120,
            child: Text(label, style: AppTypography.subheadline.copyWith(color: AppColors.secondaryLabel(context))),
          ),
          Expanded(child: Text(value, style: AppTypography.subheadline)),
        ],
      ),
    );
  }
}
