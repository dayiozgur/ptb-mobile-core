import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Site Landing Page - Site detayları ve IoT verileri için sekmeli yapı
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

  // Stats
  int _unitCount = 0;
  int _activeControllerCount = 0;
  int _activeProviderCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
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

    try {
      // Load site info
      final site = await siteService.getSite(widget.siteId);
      if (site == null) {
        setState(() {
          _errorMessage = 'Site bulunamadı';
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
      final priorities = await priorityService.getAll();
      final pMap = <String, Priority>{};
      for (final p in priorities) {
        pMap[p.id] = p;
      }

      // Load IoT data in parallel
      final results = await Future.wait([
        _loadProviders(),
        _loadControllers(),
        _loadActiveAlarms(),
        _loadResetAlarms(),
        _loadUnitCount(),
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
          _unitCount = results[4] as int;
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
          _errorMessage = 'Veriler yüklenirken hata oluştu';
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
      // Alarm tablosunda site_id yok, controller_id üzerinden filtreleme yapıyoruz
      // Önce site'a ait controller'ları yüklüyoruz (_loadControllers zaten çağrıldı)
      // Sonra bu controller'ların alarm'larını çekiyoruz
      final siteControllers = await controllerService.getAll();
      final filteredControllers = siteControllers
          .where((c) => c.siteId == widget.siteId)
          .toList();

      if (filteredControllers.isEmpty) {
        return [];
      }

      final controllerIds = filteredControllers.map((c) => c.id).toList();
      return await alarmService.getActiveAlarmsByControllers(controllerIds);
    } catch (_) {
      return [];
    }
  }

  Future<List<AlarmHistory>> _loadResetAlarms() async {
    try {
      // siteId parametresini direkt gönder - client-side filtreleme yerine
      // server-side filtreleme yap
      return await alarmService.getHistory(
        siteId: widget.siteId,
        limit: 100,
        forceRefresh: true,
      );
    } catch (_) {
      return [];
    }
  }

  Future<int> _loadUnitCount() async {
    try {
      final units = await unitService.getUnits(widget.siteId);
      return units.length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _site?.name ?? 'Site',
      onBack: () => context.go('/sites'),
      actions: [
        AppIconButton(
          icon: Icons.refresh,
          onPressed: _loadData,
        ),
        AppIconButton(
          icon: Icons.more_vert,
          onPressed: _showOptionsMenu,
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
                    // Tabs
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
                              const Text('Alarm Geçmişi'),
                              if (_resetAlarms.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                _CountBadge(count: _resetAlarms.length),
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

                    // Tab Content
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildDashboardTab(),
                          _buildProvidersTab(),
                          _buildAlarmsTab(),
                          _buildAlarmHistoryTab(),
                          _buildControllersTab(),
                          _buildDetailsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  // ============================================================================
  // Dashboard Tab
  // ============================================================================
  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Site Overview Card
            _buildSiteOverviewCard(),

            const SizedBox(height: AppSpacing.md),

            // Quick Stats
            _buildQuickStats(),

            const SizedBox(height: AppSpacing.md),

            // Alarm Status
            if (_activeAlarms.isNotEmpty) ...[
              AppSectionHeader(
                title: 'Aktif Alarmlar',
                action: TextButton(
                  onPressed: () => _tabController.animateTo(2),
                  child: const Text('Tümü'),
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

            // IoT Summary
            AppSectionHeader(title: 'IoT Özeti'),
            const SizedBox(height: AppSpacing.sm),
            _buildIotSummary(),

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
            // Site icon
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
                        errorBuilder: (_, __, ___) => _buildSiteIcon(),
                      ),
                    )
                  : _buildSiteIcon(),
            ),
            const SizedBox(width: AppSpacing.md),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _site?.name ?? '',
                    style: AppTypography.title2,
                  ),
                  if (_organization != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.apartment,
                          size: 14,
                          color: AppColors.secondaryLabel(context),
                        ),
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
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.tertiaryLabel(context),
                        ),
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

  Widget _buildSiteIcon() {
    return const Icon(
      Icons.location_city,
      color: Colors.white,
      size: 28,
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
            icon: Icons.developer_board,
            label: 'Controller',
            value: '$_activeControllerCount/${_controllers.length}',
            color: AppColors.info,
            onTap: () => _tabController.animateTo(4),
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
      ],
    );
  }

  Widget _buildIotSummary() {
    return AppCard(
      child: Column(
        children: [
          AppListTile(
            leading: _IconBox(
              icon: Icons.developer_board,
              color: Colors.blue,
            ),
            title: 'Controllers',
            subtitle: '$_activeControllerCount aktif / ${_controllers.length} toplam',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _tabController.animateTo(4),
          ),
          Divider(height: 1, color: AppColors.separator(context)),
          AppListTile(
            leading: _IconBox(
              icon: Icons.storage,
              color: Colors.green,
            ),
            title: 'Veri Sağlayıcılar',
            subtitle: '$_activeProviderCount aktif / ${_providers.length} toplam',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _tabController.animateTo(1),
          ),
          Divider(height: 1, color: AppColors.separator(context)),
          AppListTile(
            leading: _IconBox(
              icon: Icons.space_dashboard,
              color: Colors.orange,
            ),
            title: 'Birimler',
            subtitle: '$_unitCount birim',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/units'),
          ),
          Divider(height: 1, color: AppColors.separator(context)),
          AppListTile(
            leading: _IconBox(
              icon: Icons.history,
              color: Colors.purple,
            ),
            title: 'Alarm Geçmişi',
            subtitle: 'Son 30 gün: ${_resetAlarms.length} alarm',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _tabController.animateTo(3),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // Providers Tab
  // ============================================================================
  Widget _buildProvidersTab() {
    if (_providers.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.storage,
          title: 'Provider Bulunamadı',
          message: 'Bu siteye bağlı veri sağlayıcı yok',
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
            onTap: () {
              context.go('/iot/providers/${provider.id}');
            },
          );
        },
      ),
    );
  }

  // ============================================================================
  // Alarms Tab
  // ============================================================================
  Widget _buildAlarmsTab() {
    if (_activeAlarms.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.check_circle_outline,
          title: 'Aktif Alarm Yok',
          message: 'Bu sitede aktif alarm bulunmuyor',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: AppSpacing.screenPadding,
        itemCount: _activeAlarms.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final alarm = _activeAlarms[index];
          final priority = alarm.priorityId != null
              ? _priorityMap[alarm.priorityId!]
              : null;
          return _ActiveAlarmCard(
            alarm: alarm,
            priority: priority,
            onTap: () {
              ActiveAlarmDetailSheet.show(
                context,
                alarm: alarm,
                priority: priority,
              );
            },
          );
        },
      ),
    );
  }

  // ============================================================================
  // Alarm History Tab
  // ============================================================================
  Widget _buildAlarmHistoryTab() {
    if (_resetAlarms.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.history,
          title: 'Alarm Geçmişi Boş',
          message: 'Son 30 günde resetlenmiş alarm yok',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: AppSpacing.screenPadding,
        itemCount: _resetAlarms.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final alarm = _resetAlarms[index];
          final priority = alarm.priorityId != null
              ? _priorityMap[alarm.priorityId!]
              : null;
          return _ResetAlarmCard(
            alarm: alarm,
            priority: priority,
            onTap: () {
              AlarmDetailSheet.show(
                context,
                alarm: alarm,
                priority: priority,
              );
            },
          );
        },
      ),
    );
  }

  // ============================================================================
  // Controllers Tab
  // ============================================================================
  Widget _buildControllersTab() {
    if (_controllers.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.developer_board,
          title: 'Controller Bulunamadı',
          message: 'Bu siteye bağlı controller yok',
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
              context.go(
                '/iot/controllers/${controller.id}/logs?name=${Uri.encodeComponent(controller.name)}',
              );
            },
          );
        },
      ),
    );
  }

  // ============================================================================
  // Details Tab
  // ============================================================================
  Widget _buildDetailsTab() {
    if (_site == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic Info
            AppSectionHeader(title: 'Temel Bilgiler'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    _InfoRow(label: 'Site Adı', value: _site!.name),
                    _InfoRow(label: 'Kod', value: _site!.code ?? '-'),
                    if (_organization != null)
                      _InfoRow(label: 'Organizasyon', value: _organization!.name),
                    _InfoRow(
                      label: 'Kat Sayısı',
                      value: _site!.floorCount?.toString() ?? '-',
                    ),
                    _InfoRow(
                      label: 'Alan',
                      value: _site!.grossAreaSqm != null
                          ? '${_site!.grossAreaSqm!.toInt()} m²'
                          : '-',
                    ),
                    if (_site!.energyCertificateClass != null)
                      _InfoRow(
                        label: 'Enerji Sınıfı',
                        value: _site!.energyCertificateClass!.value,
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Address Info
            AppSectionHeader(title: 'Adres Bilgileri'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    _InfoRow(label: 'Adres', value: _site!.address ?? '-'),
                    _InfoRow(label: 'Şehir', value: _site!.city ?? '-'),
                    _InfoRow(label: 'İlçe', value: _site!.town ?? '-'),
                    _InfoRow(label: 'Ülke', value: _site!.country ?? '-'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Technical Info
            AppSectionHeader(title: 'Teknik Bilgiler'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    _InfoRow(label: 'Site ID', value: _site!.id),
                    if (_site!.createdAt != null)
                      _InfoRow(
                        label: 'Oluşturulma',
                        value: _formatDate(_site!.createdAt!),
                      ),
                    if (_site!.updatedAt != null)
                      _InfoRow(
                        label: 'Güncelleme',
                        value: _formatDate(_site!.updatedAt!),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Actions
            AppButton(
              label: 'Siteyi Düzenle',
              variant: AppButtonVariant.secondary,
              icon: Icons.edit,
              isFullWidth: true,
              onPressed: () {
                AppSnackbar.showInfo(
                  context,
                  message: 'Site düzenleme özelliği yakında',
                );
              },
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => AppBottomSheet(
        title: 'Seçenekler',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppListTile(
              leading: const Icon(Icons.edit),
              title: 'Siteyi Düzenle',
              onTap: () {
                Navigator.pop(context);
                AppSnackbar.showInfo(
                  context,
                  message: 'Düzenleme özelliği yakında',
                );
              },
            ),
            AppListTile(
              leading: const Icon(Icons.check_circle),
              title: 'Bu Siteyi Seç',
              onTap: () async {
                Navigator.pop(context);
                await siteService.selectSite(widget.siteId);
                if (mounted) {
                  context.go('/home');
                }
              },
            ),
            AppListTile(
              leading: Icon(Icons.delete, color: AppColors.error),
              title: 'Siteyi Sil',
              onTap: () {
                Navigator.pop(context);
                AppSnackbar.showInfo(
                  context,
                  message: 'Silme özelliği yakında',
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Color _getColorFromString(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return AppColors.primary;
    }
    try {
      if (colorString.startsWith('#')) {
        return Color(
            int.parse(colorString.substring(1), radix: 16) + 0xFF000000);
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
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count.toString(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: badgeColor,
        ),
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
            Text(
              value,
              style: AppTypography.headline.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: AppTypography.caption2.copyWith(
                color: AppColors.secondaryLabel(context),
              ),
            ),
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
        color: color.withValues(alpha: 0.1),
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
    final priorityColor = priority?.color != null
        ? Color(int.parse(priority!.color!.substring(1), radix: 16) + 0xFF000000)
        : AppColors.error;

    return Padding(
      padding: AppSpacing.cardInsets,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: priorityColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alarm.name ?? alarm.code ?? 'Alarm',
                  style: AppTypography.subheadline,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  alarm.durationFormatted,
                  style: AppTypography.caption2.copyWith(
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
              ],
            ),
          ),
          if (priority != null)
            AppBadge(
              label: priority!.name ?? '',
              variant: AppBadgeVariant.neutral,
              size: AppBadgeSize.small,
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
                color: _getStatusColor(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getTypeIcon(),
                color: _getStatusColor(context),
                size: 22,
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
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _StatusBadge(status: provider.status),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    provider.type.label,
                    style: AppTypography.caption1.copyWith(
                      color: AppColors.secondaryLabel(context),
                    ),
                  ),
                  if (provider.ip != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.lan,
                          size: 12,
                          color: AppColors.tertiaryLabel(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          provider.ip!,
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
                color: _getStatusColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.developer_board,
                color: _getStatusColor(),
                size: 22,
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
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      AppBadge(
                        label: _getStatusLabel(),
                        variant: _getStatusVariant(),
                        size: AppBadgeSize.small,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    controller.type.label,
                    style: AppTypography.caption1.copyWith(
                      color: AppColors.secondaryLabel(context),
                    ),
                  ),
                  if (controller.ipAddress != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.lan,
                          size: 12,
                          color: AppColors.tertiaryLabel(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          controller.ipAddress!,
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
        return AppColors.info;
      case ControllerStatus.error:
        return AppColors.error;
      case ControllerStatus.maintenance:
        return AppColors.warning;
      case ControllerStatus.disabled:
        return AppColors.systemGray;
      case ControllerStatus.unknown:
        return AppColors.systemGray;
    }
  }

  String _getStatusLabel() {
    switch (controller.status) {
      case ControllerStatus.online:
        return 'Online';
      case ControllerStatus.offline:
        return 'Offline';
      case ControllerStatus.connecting:
        return 'Bağlanıyor';
      case ControllerStatus.error:
        return 'Hata';
      case ControllerStatus.maintenance:
        return 'Bakımda';
      case ControllerStatus.disabled:
        return 'Devre Dışı';
      case ControllerStatus.unknown:
        return 'Bilinmiyor';
    }
  }

  AppBadgeVariant _getStatusVariant() {
    switch (controller.status) {
      case ControllerStatus.online:
        return AppBadgeVariant.success;
      case ControllerStatus.offline:
        return AppBadgeVariant.error;
      case ControllerStatus.connecting:
        return AppBadgeVariant.info;
      case ControllerStatus.error:
        return AppBadgeVariant.error;
      case ControllerStatus.maintenance:
        return AppBadgeVariant.warning;
      case ControllerStatus.disabled:
        return AppBadgeVariant.secondary;
      case ControllerStatus.unknown:
        return AppBadgeVariant.secondary;
    }
  }
}

class _ActiveAlarmCard extends StatelessWidget {
  final Alarm alarm;
  final Priority? priority;
  final VoidCallback onTap;

  const _ActiveAlarmCard({
    required this.alarm,
    this.priority,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final priorityColor = priority?.color != null
        ? Color(int.parse(priority!.color!.substring(1), radix: 16) + 0xFF000000)
        : AppColors.error;

    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: priorityColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: priorityColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          alarm.name ?? alarm.code ?? 'Alarm',
                          style: AppTypography.headline,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (priority != null)
                        AppBadge(
                          label: priority!.name ?? '',
                          variant: AppBadgeVariant.neutral,
                          size: AppBadgeSize.small,
                        ),
                    ],
                  ),
                  if (alarm.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      alarm.description!,
                      style: AppTypography.caption1.copyWith(
                        color: AppColors.secondaryLabel(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: AppColors.tertiaryLabel(context),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        alarm.durationFormatted,
                        style: AppTypography.caption2.copyWith(
                          color: AppColors.tertiaryLabel(context),
                        ),
                      ),
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

  const _ResetAlarmCard({
    required this.alarm,
    this.priority,
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
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, size: 14, color: AppColors.success),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          alarm.name ?? alarm.code ?? 'Alarm',
                          style: AppTypography.headline,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (priority != null)
                        AppBadge(
                          label: priority!.name,
                          variant: AppBadgeVariant.secondary,
                          size: AppBadgeSize.small,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 12,
                        color: AppColors.tertiaryLabel(context),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        alarm.durationFormatted,
                        style: AppTypography.caption2.copyWith(
                          color: AppColors.tertiaryLabel(context),
                        ),
                      ),
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
            child: Text(
              label,
              style: AppTypography.subheadline.copyWith(
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.subheadline,
            ),
          ),
        ],
      ),
    );
  }
}
