import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class VariableDetailScreen extends StatefulWidget {
  final String variableId;
  final String? variableName;

  const VariableDetailScreen({
    super.key,
    required this.variableId,
    this.variableName,
  });

  @override
  State<VariableDetailScreen> createState() => _VariableDetailScreenState();
}

class _VariableDetailScreenState extends State<VariableDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Variable? _variable;
  List<LogTimeSeriesEntry> _timeSeries = [];
  LogValueStats _stats = const LogValueStats();
  int _selectedDays = 7;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final tenantId = tenantService.currentTenantId;
    if (tenantId != null) {
      variableService.setTenant(tenantId);
      iotLogService.setTenant(tenantId);
    }

    try {
      final variable = await variableService.getById(widget.variableId);

      // Load chart data using variable ID
      List<LogTimeSeriesEntry> timeSeries = [];
      LogValueStats stats = const LogValueStats();

      if (variable != null) {
        try {
          final results = await Future.wait([
            iotLogService.getLogTimeSeries(
              variableId: variable.id,
              days: _selectedDays,
              forceRefresh: true,
            ),
            iotLogService.getLogValueStats(
              variableId: variable.id,
              days: _selectedDays,
            ),
          ]);
          timeSeries = results[0] as List<LogTimeSeriesEntry>;
          stats = results[1] as LogValueStats;
        } catch (e) {
          Logger.error('Failed to load log data', e);
        }
      }

      if (mounted) {
        setState(() {
          _variable = variable;
          _timeSeries = timeSeries;
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load variable detail', e);
      if (mounted) {
        setState(() {
          _errorMessage = sl<LocalizationService>().translate('variable.load_failed_detail');
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
    return AppScaffold(
      title: widget.variableName ?? sl<LocalizationService>().translate('variable.detail_title'),
      onBack: () => context.go('/variables'),
      actions: [
        AppIconButton(
          icon: Icons.refresh,
          onPressed: _loadData,
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
        title: sl<LocalizationService>().translate('common.error'),
        message: _errorMessage!,
        actionLabel: sl<LocalizationService>().translate('common.retry'),
        onAction: _loadData,
      );
    }

    final variable = _variable;
    if (variable == null) {
      return AppErrorView(
        title: sl<LocalizationService>().translate('common.not_found_title'),
        message: sl<LocalizationService>().translate('variable.not_found_message'),
        actionLabel: sl<LocalizationService>().translate('common.go_back'),
        onAction: () => context.go('/variables'),
      );
    }

    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Value
            AppCard(
              variant: AppCardVariant.filled,
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    Text(
                      sl<LocalizationService>().translate('variable.current_value'),
                      style: AppTypography.caption1.copyWith(
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _LargeValueDisplay(variable: variable),
                    if (variable.lastUpdate != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        sl<LocalizationService>().translate('variable.last_update', params: {'date': dateFormat.format(variable.lastUpdate!)}),
                        style: AppTypography.caption2.copyWith(
                          color: AppColors.tertiaryLabel(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Variable Info
            AppSectionHeader(title: sl<LocalizationService>().translate('variable.info_title')),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    _InfoRow(label: sl<LocalizationService>().translate('variable.data_type'), value: variable.dataType.label),
                    _InfoRow(label: sl<LocalizationService>().translate('variable.address'), value: variable.address ?? '-'),
                    _InfoRow(label: sl<LocalizationService>().translate('variable.unit'), value: variable.unit ?? '-'),
                    _InfoRow(label: sl<LocalizationService>().translate('variable.access'), value: variable.accessMode.label),
                  ],
                ),
              ),
            ),

            // Min/Max values
            if (variable.minimum != null || variable.maximum != null ||
                variable.minValue != null || variable.maxValue != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppSectionHeader(title: sl<LocalizationService>().translate('variable.value_range')),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Padding(
                  padding: AppSpacing.cardInsets,
                  child: Column(
                    children: [
                      if (variable.minimum != null)
                        _InfoRow(label: sl<LocalizationService>().translate('common.minimum'), value: variable.minimum!),
                      if (variable.maximum != null)
                        _InfoRow(label: sl<LocalizationService>().translate('common.maximum'), value: variable.maximum!),
                      if (variable.minValue != null)
                        _InfoRow(label: sl<LocalizationService>().translate('variable.min_value'), value: variable.minValue.toString()),
                      if (variable.maxValue != null)
                        _InfoRow(label: sl<LocalizationService>().translate('variable.max_value'), value: variable.maxValue.toString()),
                    ],
                  ),
                ),
              ),
            ],

            // Statistics
            if (_stats.hasData) ...[
              const SizedBox(height: AppSpacing.md),
              AppSectionHeader(title: sl<LocalizationService>().translate('variable.stats_title', params: {'days': _selectedDays})),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      title: sl<LocalizationService>().translate('common.min'),
                      value: _stats.minValue?.toStringAsFixed(1) ?? '-',
                      icon: Icons.arrow_downward,
                      color: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: MetricCard(
                      title: sl<LocalizationService>().translate('common.max'),
                      value: _stats.maxValue?.toStringAsFixed(1) ?? '-',
                      icon: Icons.arrow_upward,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: MetricCard(
                      title: sl<LocalizationService>().translate('common.avg'),
                      value: _stats.avgValue?.toStringAsFixed(1) ?? '-',
                      icon: Icons.trending_flat,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
            ],

            // Chart
            if (_timeSeries.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              ChartContainer(
                title: sl<LocalizationService>().translate('provider.value_chart'),
                subtitle: sl<LocalizationService>().translate('common.last_n_days', params: {'days': _selectedDays}),
                trailing: ChartPeriodSelector(
                  selectedDays: _selectedDays,
                  onChanged: _onPeriodChanged,
                  options: const [1, 7, 30],
                ),
                isEmpty: _timeSeries.where((e) => e.hasNumericValue).length < 2,
                emptyMessage: sl<LocalizationService>().translate('chart.insufficient_data'),
                child: LogLineChart(
                  entries: _timeSeries,
                  config: LogChartConfig(
                    lineColor: AppColors.primary,
                    showArea: true,
                    enableTouch: true,
                  ),
                  height: 200,
                ),
              ),

              // On/Off chart
              if (_timeSeries.any((e) => e.hasOnOff)) ...[
                const SizedBox(height: AppSpacing.sm),
                ChartContainer(
                  title: sl<LocalizationService>().translate('provider.onoff_status'),
                  isEmpty: false,
                  child: LogOnOffChart(
                    entries: _timeSeries,
                    height: 100,
                  ),
                ),
              ],
            ],

            if (variable.description != null && variable.description!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              AppSectionHeader(title: sl<LocalizationService>().translate('field.aciklama')),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Padding(
                  padding: AppSpacing.cardInsets,
                  child: Text(variable.description!, style: AppTypography.body),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),

            // Write value action
            if (variable.isWritable)
              AppButton(
                label: sl<LocalizationService>().translate('variable.write_value'),
                icon: Icons.edit,
                onPressed: () {
                  AppSnackbar.showInfo(
                    context,
                    message: sl<LocalizationService>().translate('variable.write_coming_soon'),
                  );
                },
              ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _LargeValueDisplay extends StatelessWidget {
  final Variable variable;

  const _LargeValueDisplay({required this.variable});

  @override
  Widget build(BuildContext context) {
    final value = variable.value;

    if (value == null || value.isEmpty) {
      return Text(
        '-',
        style: AppTypography.largeTitle.copyWith(
          color: AppColors.tertiaryLabel(context),
        ),
      );
    }

    if (variable.isBoolean) {
      final boolValue = variable.booleanValue ?? false;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: (boolValue ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          boolValue ? 'ON' : 'OFF',
          style: AppTypography.largeTitle.copyWith(
            fontWeight: FontWeight.bold,
            color: boolValue ? AppColors.success : AppColors.error,
          ),
        ),
      );
    }

    return Text(
      variable.formattedValue,
      style: AppTypography.largeTitle.copyWith(
        fontWeight: FontWeight.bold,
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.subheadline.copyWith(
              color: AppColors.secondaryLabel(context),
            ),
          ),
          Text(value, style: AppTypography.subheadline),
        ],
      ),
    );
  }
}
