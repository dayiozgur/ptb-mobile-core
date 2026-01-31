import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Provider Landing Page - Provider detayları ve ilişkili veriler
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
  Controller? _controller;

  // Related data
  List<Variable> _variables = [];
  List<Alarm> _activeAlarms = [];
  List<AlarmHistory> _alarmHistory = [];
  List<IoTLog> _logs = [];
  Map<String, Priority> _priorityMap = {};

  // Stats
  int _totalLogCount = 0;

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
      variableService.setTenant(tenantId);
      alarmService.setTenant(tenantId);
      iotLogService.setTenant(tenantId);
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

      // Load controller (DataProvider modelinde controllerId yok, controller bilgisi başka yolla alınabilir)
      Controller? controller;

      // Load priorities
      final priorities = await priorityService.getAll();
      final pMap = <String, Priority>{};
      for (final p in priorities) {
        pMap[p.id] = p;
      }

      // Load related data in parallel
      final results = await Future.wait([
        _loadVariables(),
        _loadActiveAlarms(),
        _loadAlarmHistory(),
        _loadLogs(),
        _loadLogCount(),
      ]);

      if (mounted) {
        setState(() {
          _provider = provider;
          _site = site;
          _controller = controller;
          _priorityMap = pMap;
          _variables = results[0] as List<Variable>;
          _activeAlarms = results[1] as List<Alarm>;
          _alarmHistory = results[2] as List<AlarmHistory>;
          _logs = results[3] as List<IoTLog>;
          _totalLogCount = results[4] as int;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load provider data', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Veriler yüklenirken hata oluştu';
          _isLoading = false;
        });
      }
    }
  }

  Future<List<Variable>> _loadVariables() async {
    try {
      // Variable modelinde dataProviderId yok, deviceModelId üzerinden filtreleme yapılabilir
      // Şimdilik tüm değişkenleri yükleyip gösteriyoruz
      final allVariables = await variableService.getAll();
      return allVariables.take(50).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Alarm>> _loadActiveAlarms() async {
    try {
      // Alarm modelinde dataProviderId yok
      // Provider'a ait alarmları filtrelemek için controller veya realtimeId kullanılabilir
      return await alarmService.getActiveAlarms();
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
      );
    } catch (_) {
      return [];
    }
  }

  Future<List<IoTLog>> _loadLogs() async {
    try {
      return await iotLogService.getLogs(
        providerId: widget.providerId,
        limit: 50,
      );
    } catch (_) {
      return [];
    }
  }

  Future<int> _loadLogCount() async {
    try {
      return await iotLogService.getLogCountByProvider(
        widget.providerId,
        lastHours: 24,
      );
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _provider?.name ?? 'Provider',
      onBack: () => context.go('/iot/providers'),
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
                              const Text('Değişkenler'),
                              if (_variables.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                _CountBadge(count: _variables.length),
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

                    // Tab Content
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildDashboardTab(),
                          _buildVariablesTab(),
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

  // ============================================================================
  // Dashboard Tab
  // ============================================================================
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
            // Provider Overview Card
            _buildProviderOverviewCard(),

            const SizedBox(height: AppSpacing.md),

            // Quick Stats
            _buildQuickStats(),

            const SizedBox(height: AppSpacing.md),

            // Connection Info Card
            AppSectionHeader(title: 'Bağlantı Durumu'),
            const SizedBox(height: AppSpacing.sm),
            _buildConnectionCard(),

            const SizedBox(height: AppSpacing.md),

            // Active Alarms Summary
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

            // Recent Variables
            if (_variables.isNotEmpty) ...[
              AppSectionHeader(
                title: 'Değişkenler',
                action: TextButton(
                  onPressed: () => _tabController.animateTo(1),
                  child: const Text('Tümü'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  children: _variables.take(5).map((variable) {
                    return _VariableRow(variable: variable);
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
            // Provider icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _getStatusColor().withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getTypeIcon(),
                color: _getStatusColor(),
                size: 28,
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _provider!.name,
                          style: AppTypography.title2,
                        ),
                      ),
                      _StatusBadge(status: _provider!.status),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _provider!.type.label,
                    style: AppTypography.subheadline.copyWith(
                      color: AppColors.secondaryLabel(context),
                    ),
                  ),
                  if (_site != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_city,
                          size: 14,
                          color: AppColors.tertiaryLabel(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _site!.name,
                          style: AppTypography.caption1.copyWith(
                            color: AppColors.tertiaryLabel(context),
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
            label: 'Alarm',
            value: _activeAlarms.length.toString(),
            color: _activeAlarms.isNotEmpty ? AppColors.error : AppColors.success,
            onTap: () => _tabController.animateTo(2),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            icon: Icons.data_object,
            label: 'Değişken',
            value: _variables.length.toString(),
            color: AppColors.info,
            onTap: () => _tabController.animateTo(1),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            icon: Icons.article_outlined,
            label: 'Log (24s)',
            value: _totalLogCount.toString(),
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
                      BoxShadow(
                        color: _getStatusColor().withValues(alpha: 0.4),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _getStatusText(),
                    style: AppTypography.headline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (_provider!.ip != null)
              _InfoRow(label: 'IP Adresi', value: _provider!.ip!),
            if (_provider!.hostname != null)
              _InfoRow(label: 'Hostname', value: _provider!.hostname!),
            if (_provider!.mac != null)
              _InfoRow(label: 'MAC', value: _provider!.mac!),
            if (_controller != null)
              _InfoRow(label: 'Controller', value: _controller!.name),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // Variables Tab
  // ============================================================================
  Widget _buildVariablesTab() {
    if (_variables.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.data_object,
          title: 'Değişken Bulunamadı',
          message: 'Bu provider\'a bağlı değişken yok',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: AppSpacing.screenPadding,
        itemCount: _variables.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final variable = _variables[index];
          return _VariableCard(variable: variable);
        },
      ),
    );
  }

  // ============================================================================
  // Alarms Tab
  // ============================================================================
  Widget _buildAlarmsTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Sub tabs
          Container(
            margin: const EdgeInsets.all(AppSpacing.screenHorizontal),
            decoration: BoxDecoration(
              color: AppColors.systemGray6,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppColors.textPrimary(Theme.of(context).brightness),
              unselectedLabelColor: AppColors.secondaryLabel(context),
              indicator: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.white
                    : AppColors.systemGray5,
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
                      const Text('Geçmiş'),
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

          // Tab content
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
          message: 'Bu provider\'da aktif alarm bulunmuyor',
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

  Widget _buildAlarmHistoryContent() {
    if (_alarmHistory.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.history,
          title: 'Alarm Geçmişi Boş',
          message: 'Bu provider\'da geçmiş alarm yok',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: AppSpacing.screenPadding,
        itemCount: _alarmHistory.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final alarm = _alarmHistory[index];
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
  // Logs Tab
  // ============================================================================
  Widget _buildLogsTab() {
    if (_logs.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.article_outlined,
          title: 'Log Bulunamadı',
          message: 'Bu provider için log kaydı yok',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: AppSpacing.screenPadding,
        itemCount: _logs.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, index) {
          final log = _logs[index];
          return _LogCard(log: log);
        },
      ),
    );
  }

  // ============================================================================
  // Details Tab
  // ============================================================================
  Widget _buildDetailsTab() {
    if (_provider == null) {
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
            // Status & Type
            AppSectionHeader(title: 'Durum & Tip'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    _InfoRow(label: 'Durum', value: _getStatusText()),
                    _InfoRow(label: 'Tip', value: _provider!.type.label),
                    if (_provider!.code != null)
                      _InfoRow(label: 'Kod', value: _provider!.code!),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Connection Info
            AppSectionHeader(title: 'Bağlantı Bilgileri'),
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

            // Relations
            AppSectionHeader(title: 'İlişkiler'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    _InfoRow(
                      label: 'Site',
                      value: _site?.name ?? '-',
                    ),
                    _InfoRow(
                      label: 'Controller',
                      value: _controller?.name ?? '-',
                    ),
                  ],
                ),
              ),
            ),

            if (_provider!.description != null &&
                _provider!.description!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              AppSectionHeader(title: 'Açıklama'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Padding(
                  padding: AppSpacing.cardInsets,
                  child: Text(
                    _provider!.description!,
                    style: AppTypography.body,
                  ),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.md),

            // Record Info
            AppSectionHeader(title: 'Kayıt Bilgileri'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    _InfoRow(label: 'ID', value: _provider!.id),
                    _InfoRow(
                      label: 'Oluşturulma',
                      value: _formatDate(_provider!.createdAt),
                    ),
                    if (_provider!.updatedAt != null)
                      _InfoRow(
                        label: 'Güncelleme',
                        value: _formatDate(_provider!.updatedAt!),
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
                      AppSnackbar.showInfo(
                        context,
                        message: 'Bağlantı testi başlatılıyor...',
                      );
                    },
                  ),
                ),
              ],
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
              title: 'Düzenle',
              onTap: () {
                Navigator.pop(context);
                AppSnackbar.showInfo(
                  context,
                  message: 'Düzenleme özelliği yakında',
                );
              },
            ),
            AppListTile(
              leading: const Icon(Icons.wifi_find),
              title: 'Bağlantı Test Et',
              onTap: () {
                Navigator.pop(context);
                AppSnackbar.showInfo(
                  context,
                  message: 'Bağlantı testi başlatılıyor...',
                );
              },
            ),
            AppListTile(
              leading: Icon(Icons.delete, color: AppColors.error),
              title: 'Sil',
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

  Color _getStatusColor() {
    switch (_provider?.status) {
      case DataProviderStatus.active:
        return AppColors.success;
      case DataProviderStatus.inactive:
        return AppColors.systemGray;
      case DataProviderStatus.connecting:
        return AppColors.warning;
      case DataProviderStatus.error:
        return AppColors.error;
      case DataProviderStatus.disabled:
        return AppColors.systemGray;
      default:
        return AppColors.systemGray;
    }
  }

  String _getStatusText() {
    switch (_provider?.status) {
      case DataProviderStatus.active:
        return 'Aktif - Bağlı';
      case DataProviderStatus.inactive:
        return 'Pasif';
      case DataProviderStatus.connecting:
        return 'Bağlanıyor...';
      case DataProviderStatus.error:
        return 'Hata';
      case DataProviderStatus.disabled:
        return 'Devre Dışı';
      default:
        return 'Bilinmiyor';
    }
  }

  IconData _getTypeIcon() {
    switch (_provider?.type) {
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
      default:
        return Icons.storage;
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

class _VariableRow extends StatelessWidget {
  final Variable variable;

  const _VariableRow({required this.variable});

  @override
  Widget build(BuildContext context) {
    return AppListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.data_object,
          color: AppColors.info,
          size: 18,
        ),
      ),
      title: variable.name,
      subtitle: variable.dataType.label,
      trailing: Text(
        variable.formattedValue,
        style: AppTypography.headline,
      ),
    );
  }
}

class _VariableCard extends StatelessWidget {
  final Variable variable;

  const _VariableCard({required this.variable});

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
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.data_object,
                color: AppColors.info,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    variable.name,
                    style: AppTypography.headline,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    variable.dataType.label,
                    style: AppTypography.caption1.copyWith(
                      color: AppColors.secondaryLabel(context),
                    ),
                  ),
                  if (variable.address != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Adres: ${variable.address}',
                      style: AppTypography.caption2.copyWith(
                        color: AppColors.tertiaryLabel(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  variable.formattedValue,
                  style: AppTypography.title2.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (variable.unit != null)
                  Text(
                    variable.unit!,
                    style: AppTypography.caption2.copyWith(
                      color: AppColors.secondaryLabel(context),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
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
                          label: priority!.name ?? '',
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

class _LogCard extends StatelessWidget {
  final IoTLog log;

  const _LogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _getIcon(),
              size: 16,
              color: _getColor(),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.description ?? log.name ?? log.value ?? '-',
                    style: AppTypography.caption1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(log.dateTime ?? log.createdAt),
                    style: AppTypography.caption2.copyWith(
                      color: AppColors.tertiaryLabel(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon() {
    // OnOff durumuna göre ikon
    if (log.onOff == 1) return Icons.toggle_on;
    if (log.onOff == 0) return Icons.toggle_off;
    if (log.maintenance != null) return Icons.build;
    return Icons.article;
  }

  Color _getColor() {
    // OnOff durumuna göre renk
    if (log.onOff == 1) return AppColors.success;
    if (log.onOff == 0) return AppColors.systemGray;
    if (log.maintenance != null) return AppColors.warning;
    return AppColors.info;
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '-';
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
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
            width: 100,
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
