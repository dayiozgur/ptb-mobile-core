import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class ControllerLogsScreen extends StatefulWidget {
  final String controllerId;
  final String? controllerName;

  const ControllerLogsScreen({
    super.key,
    required this.controllerId,
    this.controllerName,
  });

  @override
  State<ControllerLogsScreen> createState() => _ControllerLogsScreenState();
}

class _ControllerLogsScreenState extends State<ControllerLogsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;

  int _selectedDays = 7;
  List<LogTimeSeriesEntry> _timeSeries = [];
  LogValueStats _stats = const LogValueStats();
  List<IoTLog> _logList = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      iotLogService.setTenant(tenantId);
    }

    try {
      final results = await Future.wait([
        iotLogService.getLogTimeSeries(
          controllerId: widget.controllerId,
          days: _selectedDays,
        ),
        iotLogService.getLogValueStats(
          controllerId: widget.controllerId,
          days: _selectedDays,
        ),
        iotLogService.getLogs(
          controllerId: widget.controllerId,
          limit: 100,
          forceRefresh: true,
        ),
      ]);

      if (mounted) {
        setState(() {
          _timeSeries = results[0] as List<LogTimeSeriesEntry>;
          _stats = results[1] as LogValueStats;
          _logList = results[2] as List<IoTLog>;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load controller logs', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Log verileri yüklenirken hata oluştu';
          _isLoading = false;
        });
      }
    }
  }

  void _onPeriodChanged(int days) {
    setState(() => _selectedDays = days);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return AppTabScaffold(
      title: widget.controllerName ?? 'Controller Logları',
      onBack: () => context.pop(),
      tabs: const [
        Tab(text: 'Grafikler'),
        Tab(text: 'Log Listesi'),
      ],
      tabController: _tabController,
      children: [
        // Tab 1: Grafikler
        _buildChartsTab(),
        // Tab 2: Log Listesi
        _buildListTab(),
      ],
    );
  }

  Widget _buildChartsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (_errorMessage != null) {
      return Center(
        child: AppErrorView(
          message: _errorMessage!,
          onRetry: _loadData,
        ),
      );
    }

    final brightness = Theme.of(context).brightness;
    final hasOnOffData = _timeSeries.any((e) => e.hasOnOff);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.sm),

            // Dönem seçici
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Son $_selectedDays gün',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                  ChartPeriodSelector(
                    selectedDays: _selectedDays,
                    onChanged: _onPeriodChanged,
                    options: const [1, 7, 30, 90],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // İstatistik kartları
            if (_stats.hasData)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatMiniCard(
                        label: 'Min',
                        value: _stats.minValue?.toStringAsFixed(1) ?? '-',
                        color: AppColors.info,
                        brightness: brightness,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _StatMiniCard(
                        label: 'Max',
                        value: _stats.maxValue?.toStringAsFixed(1) ?? '-',
                        color: AppColors.error,
                        brightness: brightness,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _StatMiniCard(
                        label: 'Ort',
                        value: _stats.avgValue?.toStringAsFixed(1) ?? '-',
                        color: AppColors.warning,
                        brightness: brightness,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _StatMiniCard(
                        label: 'Son',
                        value: _stats.lastValue?.toStringAsFixed(1) ?? '-',
                        color: AppColors.success,
                        brightness: brightness,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: AppSpacing.sm),

            // Line Chart
            ChartContainer(
              title: 'Değer Grafiği',
              subtitle: '${_timeSeries.length} veri noktası',
              isEmpty: _timeSeries
                  .where((e) => e.hasNumericValue)
                  .length < 2,
              emptyMessage: 'Numerik log verisi bulunamadı',
              child: LogLineChart(
                entries: _timeSeries,
                config: const LogChartConfig(
                  lineColor: AppColors.primary,
                  showArea: true,
                  enableTouch: true,
                ),
                height: 220,
              ),
            ),

            // On/Off Chart (varsa)
            if (hasOnOffData) ...[
              const SizedBox(height: AppSpacing.sm),
              ChartContainer(
                title: 'On/Off Durumu',
                isEmpty: false,
                child: LogOnOffChart(
                  entries: _timeSeries,
                  height: 120,
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildListTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (_errorMessage != null) {
      return Center(
        child: AppErrorView(
          message: _errorMessage!,
          onRetry: _loadData,
        ),
      );
    }

    final brightness = Theme.of(context).brightness;

    if (_logList.isEmpty) {
      return const Center(
        child: AppEmptyState(
          icon: Icons.list_alt,
          title: 'Log Kaydı Yok',
          message: 'Bu controller için log kaydı bulunamadı.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        itemCount: _logList.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: AppColors.divider(brightness),
        ),
        itemBuilder: (context, index) {
          final log = _logList[index];
          return _LogListItem(log: log, brightness: brightness);
        },
      ),
    );
  }
}

class _StatMiniCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Brightness brightness;

  const _StatMiniCard({
    required this.label,
    required this.value,
    required this.color,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: AppColors.divider(brightness),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary(brightness),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogListItem extends StatelessWidget {
  final IoTLog log;
  final Brightness brightness;

  const _LogListItem({
    required this.log,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM HH:mm:ss');

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          // Zaman
          SizedBox(
            width: 100,
            child: Text(
              log.dateTime != null
                  ? dateFormat.format(log.dateTime!)
                  : '-',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(brightness),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),

          // Değer
          Expanded(
            child: Text(
              log.value ?? '-',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary(brightness),
              ),
            ),
          ),

          // On/Off
          if (log.onOff != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: log.onOff == 1
                    ? AppColors.success.withValues(alpha: 0.12)
                    : AppColors.systemGray4.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                log.onOffLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: log.onOff == 1
                      ? AppColors.success
                      : AppColors.systemGray,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
