import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Renk paleti - çoklu variable serileri için
const _seriesColors = [
  Color(0xFF007AFF), // Blue
  Color(0xFFFF3B30), // Red
  Color(0xFF34C759), // Green
  Color(0xFFFF9500), // Orange
  Color(0xFFAF52DE), // Purple
  Color(0xFF00C7BE), // Teal
  Color(0xFFFF2D55), // Pink
  Color(0xFF5856D6), // Indigo
];

class LogAnalyticsScreen extends StatefulWidget {
  const LogAnalyticsScreen({super.key});

  @override
  State<LogAnalyticsScreen> createState() => _LogAnalyticsScreenState();
}

class _LogAnalyticsScreenState extends State<LogAnalyticsScreen> {
  bool _isLoading = true;
  bool _isLoadingChart = false;
  String? _errorMessage;

  List<Controller> _controllers = [];
  String? _selectedControllerId;
  int _selectedDays = 7;

  // Variable selection - ayrı listeler analog/integer ve digital için
  List<Map<String, dynamic>> _analogVars = [];
  List<Map<String, dynamic>> _digitalVars = [];

  // Seçili variable'lar (multi-select)
  Set<String> _selectedAnalogIds = {};
  Set<String> _selectedDigitalIds = {};

  // Chart verileri - her variable için ayrı time series
  Map<String, List<LogTimeSeriesEntry>> _timeSeriesMap = {};

  static const _maxAnalogSelection = 5;
  static const _maxDigitalSelection = 4;

  @override
  void initState() {
    super.initState();
    _loadControllers();
  }

  Future<void> _loadControllers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tenantId = tenantService.currentTenantId;
      if (tenantId != null) {
        controllerService.setTenant(tenantId);
        iotLogService.setTenant(tenantId);
      }

      final orgId = organizationService.currentOrganizationId;
      if (orgId != null) {
        controllerService.setOrganization(orgId);
        iotLogService.setOrganization(orgId);
      }

      final controllers = await controllerService.getAll();
      if (mounted) {
        setState(() {
          _controllers = controllers;
          _isLoading = false;
        });

        if (controllers.isNotEmpty) {
          _selectedControllerId = controllers.first.id;
          _loadVariables();
        }
      }
    } catch (e) {
      Logger.error('Failed to load controllers', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Controller listesi yuklenemedi';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadVariables() async {
    if (_selectedControllerId == null) return;

    setState(() {
      _analogVars = [];
      _digitalVars = [];
      _selectedAnalogIds = {};
      _selectedDigitalIds = {};
      _timeSeriesMap = {};
    });

    try {
      // Analog + Integer ve Digital variable'ları paralel yükle
      final results = await Future.wait([
        iotLogService.getLoggedVariables(
          controllerId: _selectedControllerId!,
          variableType: 'ANALOG',
          forceRefresh: true,
        ),
        iotLogService.getLoggedVariables(
          controllerId: _selectedControllerId!,
          variableType: 'INTEGER',
          forceRefresh: true,
        ),
        iotLogService.getLoggedVariables(
          controllerId: _selectedControllerId!,
          variableType: 'DIGITAL',
          forceRefresh: true,
        ),
      ]);

      if (mounted) {
        // Analog + Integer birleştir
        final analogVars = [...results[0], ...results[1]];
        analogVars.sort((a, b) =>
            (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));

        setState(() {
          _analogVars = analogVars;
          _digitalVars = results[2];

          // İlk analog variable'ı otomatik seç
          if (analogVars.isNotEmpty) {
            _selectedAnalogIds = {analogVars.first['id'] as String};
          }
        });

        _loadChartData();
      }
    } catch (e) {
      Logger.error('Failed to load variables', e);
    }
  }

  Future<void> _loadChartData() async {
    final allSelectedIds = {..._selectedAnalogIds, ..._selectedDigitalIds};
    if (allSelectedIds.isEmpty) {
      setState(() => _timeSeriesMap = {});
      return;
    }

    setState(() {
      _isLoadingChart = true;
      _errorMessage = null;
    });

    try {
      final futures = <Future<MapEntry<String, List<LogTimeSeriesEntry>>>>[];

      for (final varId in allSelectedIds) {
        futures.add(
          iotLogService
              .getLogTimeSeries(
                controllerId: _selectedControllerId,
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
      if (mounted) {
        setState(() {
          _errorMessage = 'Grafik verileri yuklenemedi';
          _isLoadingChart = false;
        });
      }
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
    final brightness = Theme.of(context).brightness;

    return AppScaffold(
      title: 'Log Analiz',
      onBack: () => context.go('/logs'),
      actions: [
        AppIconButton(
          icon: Icons.refresh,
          onPressed: _selectedControllerId != null ? _loadChartData : _loadControllers,
        ),
      ],
      child: _isLoading
          ? const Center(child: AppLoadingIndicator())
          : _errorMessage != null && _selectedControllerId == null
              ? Center(child: AppErrorView(message: _errorMessage!, onRetry: _loadControllers))
              : SingleChildScrollView(
                  padding: AppSpacing.screenPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Controller selector
                      _buildControllerSelector(brightness),
                      const SizedBox(height: AppSpacing.md),

                      // Period selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Son $_selectedDays gun',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(brightness),
                            ),
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

                      // === ANALOG / INTEGER SECTION ===
                      _buildSectionHeader(
                        brightness,
                        icon: Icons.show_chart,
                        title: 'Analog / Integer',
                        count: _analogVars.length,
                        selectedCount: _selectedAnalogIds.length,
                        maxCount: _maxAnalogSelection,
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Analog variable chips
                      _buildVariableChips(
                        brightness,
                        variables: _analogVars,
                        selectedIds: _selectedAnalogIds,
                        onToggle: _toggleAnalogVariable,
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Analog chart
                      _buildAnalogChart(brightness),

                      const SizedBox(height: AppSpacing.lg),

                      // === DIGITAL SECTION ===
                      _buildSectionHeader(
                        brightness,
                        icon: Icons.toggle_on,
                        title: 'Digital',
                        count: _digitalVars.length,
                        selectedCount: _selectedDigitalIds.length,
                        maxCount: _maxDigitalSelection,
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Digital variable chips
                      _buildVariableChips(
                        brightness,
                        variables: _digitalVars,
                        selectedIds: _selectedDigitalIds,
                        onToggle: _toggleDigitalVariable,
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Digital charts
                      _buildDigitalCharts(brightness),

                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
    );
  }

  Widget _buildControllerSelector(Brightness brightness) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              value: _selectedControllerId,
              hint: Text('Controller secin', style: AppTypography.body.copyWith(color: AppColors.tertiaryLabel(context))),
              isExpanded: true,
              items: _controllers.map((c) => DropdownMenuItem(
                value: c.id,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
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
                setState(() => _selectedControllerId = value);
                _loadVariables();
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    Brightness brightness, {
    required IconData icon,
    required String title,
    required int count,
    required int selectedCount,
    required int maxCount,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(brightness),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        AppChip(
          label: '$count',
          variant: AppChipVariant.tonal,
          color: AppColors.primary,
          small: true,
        ),
        const Spacer(),
        if (count > 0)
          Text(
            '$selectedCount/$maxCount secili',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(brightness),
            ),
          ),
      ],
    );
  }

  Widget _buildVariableChips(
    Brightness brightness, {
    required List<Map<String, dynamic>> variables,
    required Set<String> selectedIds,
    required void Function(String) onToggle,
  }) {
    if (variables.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.separator(context)),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Text(
          'Bu tip icin variable bulunamadi',
          style: TextStyle(fontSize: 13, color: AppColors.tertiaryLabel(context)),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Seçili olanların index'ini bul - renk ataması için
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
              border: Border.all(
                color: isSelected ? chipColor : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: chipColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  unit.isNotEmpty ? '$name ($unit)' : name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? chipColor : AppColors.textSecondary(brightness),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAnalogChart(Brightness brightness) {
    if (_isLoadingChart && _selectedAnalogIds.isNotEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: AppLoadingIndicator()),
      );
    }

    if (_selectedAnalogIds.isEmpty) {
      return _buildEmptyChartMessage(brightness, 'Grafik icin analog/integer variable secin');
    }

    // Multi-series verisi oluştur
    final seriesList = <VariableTimeSeries>[];
    final selectedList = _selectedAnalogIds.toList();

    for (var i = 0; i < selectedList.length; i++) {
      final varId = selectedList[i];
      final entries = _timeSeriesMap[varId];
      if (entries == null || entries.isEmpty) continue;

      final variable = _findVariable(varId);
      final name = variable?['name'] as String? ?? '';
      final unit = variable?['measure_unit'] as String? ?? variable?['unit'] as String? ?? '';

      seriesList.add(VariableTimeSeries(
        variableId: varId,
        variableName: name,
        unit: unit,
        color: _getSeriesColor(i),
        entries: entries,
      ));
    }

    if (seriesList.isEmpty) {
      return _buildEmptyChartMessage(brightness, 'Secili variable\'lar icin veri bulunamadi');
    }

    return ChartContainer(
      title: 'Deger Grafigi',
      subtitle: '${seriesList.length} variable - Son $_selectedDays gun',
      isEmpty: false,
      child: MultiLogLineChart(
        seriesList: seriesList,
        height: 260,
        showLegend: seriesList.length > 1,
      ),
    );
  }

  Widget _buildDigitalCharts(Brightness brightness) {
    if (_isLoadingChart && _selectedDigitalIds.isNotEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: AppLoadingIndicator()),
      );
    }

    if (_selectedDigitalIds.isEmpty) {
      return _buildEmptyChartMessage(brightness, 'On/Off grafigi icin digital variable secin');
    }

    // Multi-series verisi oluştur
    final seriesList = <VariableTimeSeries>[];
    final selectedList = _selectedDigitalIds.toList();

    for (var i = 0; i < selectedList.length; i++) {
      final varId = selectedList[i];
      final entries = _timeSeriesMap[varId];
      if (entries == null || entries.isEmpty) continue;

      final variable = _findVariable(varId);
      final name = variable?['name'] as String? ?? '';

      seriesList.add(VariableTimeSeries(
        variableId: varId,
        variableName: name,
        color: _getSeriesColor(i),
        entries: entries,
      ));
    }

    if (seriesList.isEmpty) {
      return _buildEmptyChartMessage(brightness, 'Secili variable\'lar icin veri bulunamadi');
    }

    return ChartContainer(
      title: 'On/Off Durumu',
      subtitle: '${seriesList.length} digital variable - Son $_selectedDays gun',
      isEmpty: false,
      child: MultiLogOnOffChart(
        seriesList: seriesList,
        rowHeight: 32,
      ),
    );
  }

  Widget _buildEmptyChartMessage(Brightness brightness, String message) {
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
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary(brightness),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
