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
          _errorMessage = 'Degisken detaylari yuklenemedi';
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
      title: widget.variableName ?? 'Degisken Detay',
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
        title: 'Hata',
        message: _errorMessage!,
        actionLabel: 'Tekrar Dene',
        onAction: _loadData,
      );
    }

    final variable = _variable;
    if (variable == null) {
      return AppErrorView(
        title: 'Bulunamadi',
        message: 'Degisken bulunamadi.',
        actionLabel: 'Geri Don',
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
                      'Mevcut Deger',
                      style: AppTypography.caption1.copyWith(
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _LargeValueDisplay(variable: variable),
                    if (variable.lastUpdate != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Son guncelleme: ${dateFormat.format(variable.lastUpdate!)}',
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
            AppSectionHeader(title: 'Degisken Bilgileri'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    _InfoRow(label: 'Veri Tipi', value: variable.dataType.label),
                    _InfoRow(label: 'Adres', value: variable.address ?? '-'),
                    _InfoRow(label: 'Birim', value: variable.unit ?? '-'),
                    _InfoRow(label: 'Erisim', value: variable.accessMode.label),
                  ],
                ),
              ),
            ),

            // Min/Max values
            if (variable.minimum != null || variable.maximum != null ||
                variable.minValue != null || variable.maxValue != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppSectionHeader(title: 'Deger Araligi'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Padding(
                  padding: AppSpacing.cardInsets,
                  child: Column(
                    children: [
                      if (variable.minimum != null)
                        _InfoRow(label: 'Minimum', value: variable.minimum!),
                      if (variable.maximum != null)
                        _InfoRow(label: 'Maximum', value: variable.maximum!),
                      if (variable.minValue != null)
                        _InfoRow(label: 'Min Deger', value: variable.minValue.toString()),
                      if (variable.maxValue != null)
                        _InfoRow(label: 'Max Deger', value: variable.maxValue.toString()),
                    ],
                  ),
                ),
              ),
            ],

            // Statistics
            if (_stats.hasData) ...[
              const SizedBox(height: AppSpacing.md),
              AppSectionHeader(title: 'Istatistikler (Son $_selectedDays gun)'),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      title: 'Min',
                      value: _stats.minValue?.toStringAsFixed(1) ?? '-',
                      icon: Icons.arrow_downward,
                      color: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: MetricCard(
                      title: 'Max',
                      value: _stats.maxValue?.toStringAsFixed(1) ?? '-',
                      icon: Icons.arrow_upward,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: MetricCard(
                      title: 'Ort',
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
                title: 'Deger Grafigi',
                subtitle: 'Son $_selectedDays gun',
                trailing: ChartPeriodSelector(
                  selectedDays: _selectedDays,
                  onChanged: _onPeriodChanged,
                  options: const [1, 7, 30],
                ),
                isEmpty: _timeSeries.where((e) => e.hasNumericValue).length < 2,
                emptyMessage: 'Yeterli veri yok',
                child: LogLineChart(
                  entries: _timeSeries,
                  config: const LogChartConfig(
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
                  title: 'On/Off Durumu',
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
              AppSectionHeader(title: 'Aciklama'),
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
                label: 'Deger Yaz',
                icon: Icons.edit,
                onPressed: () {
                  AppSnackbar.showInfo(
                    context,
                    message: 'Deger yazma ozelligi yakinda eklenecek',
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
          color: (boolValue ? AppColors.success : AppColors.error).withOpacity(0.1),
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
