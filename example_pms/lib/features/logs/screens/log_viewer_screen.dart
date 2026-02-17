import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  List<Controller> _controllers = [];
  String? _selectedControllerId;
  List<IoTLog> _logList = [];
  String _searchQuery = '';

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
          _loadLogs();
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

  Future<void> _loadLogs() async {
    if (_selectedControllerId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final logs = await iotLogService.getLogs(
        controllerId: _selectedControllerId!,
        limit: 200,
        forceRefresh: true,
        includeVariable: true,
      );

      if (mounted) {
        setState(() {
          _logList = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load logs', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Log verileri yuklenemedi';
          _isLoading = false;
        });
      }
    }
  }

  List<IoTLog> get _filteredLogs {
    if (_searchQuery.isEmpty) return _logList;
    final query = _searchQuery.toLowerCase();
    return _logList.where((log) =>
        (log.effectiveName?.toLowerCase().contains(query) ?? false) ||
        (log.effectiveDescription?.toLowerCase().contains(query) ?? false) ||
        (log.value?.toLowerCase().contains(query) ?? false) ||
        (log.name?.toLowerCase().contains(query) ?? false) ||
        (log.code?.toLowerCase().contains(query) ?? false)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Log Goruntule',
      onBack: () => context.go('/dashboard'),
      actions: [
        AppIconButton(
          icon: Icons.analytics,
          onPressed: () => context.push('/logs/analytics'),
        ),
        AppIconButton(
          icon: Icons.refresh,
          onPressed: _selectedControllerId != null ? _loadLogs : _loadControllers,
        ),
      ],
      child: Column(
        children: [
          // Controller selector
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
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
                        _loadLogs();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: AppSearchField(
              placeholder: 'Variable adi veya deger ara...',
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Summary
          if (!_isLoading && _selectedControllerId != null)
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

          const SizedBox(height: AppSpacing.sm),

          // Log list
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final brightness = Theme.of(context).brightness;
    final dateFormat = DateFormat('dd/MM HH:mm:ss');

    if (_isLoading) {
      return const Center(child: AppLoadingIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: AppErrorView(
          message: _errorMessage!,
          onRetry: _selectedControllerId != null ? _loadLogs : _loadControllers,
        ),
      );
    }

    if (_selectedControllerId == null) {
      return AppEmptyState(
        icon: Icons.developer_board,
        title: 'Controller Secin',
        message: 'Loglari goruntulemek icin bir controller secin.',
      );
    }

    final filtered = _filteredLogs;

    if (filtered.isEmpty) {
      return AppEmptyState(
        icon: Icons.list_alt,
        title: 'Log Kaydi Yok',
        message: _logList.isEmpty
            ? 'Bu controller icin log kaydi bulunamadi.'
            : 'Arama kriterlerinize uygun log bulunamadi.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLogs,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: AppColors.divider(brightness),
        ),
        itemBuilder: (context, index) {
          final log = filtered[index];
          return _LogRow(log: log, dateFormat: dateFormat);
        },
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

    // Variable adı: JOIN'den gelen veya log'un kendi adı
    final varName = log.effectiveName;
    final varDesc = log.effectiveDescription;
    final unit = log.effectiveUnit;

    // Değer gösterimi
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
          // Sol: On/Off veya değer göstergesi
          if (isOnOff)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (isOn ? AppColors.success : AppColors.systemGray4).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isOn ? Icons.power : Icons.power_off,
                size: 18,
                color: isOn ? AppColors.success : AppColors.systemGray,
              ),
            )
          else
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.show_chart,
                size: 18,
                color: AppColors.primary,
              ),
            ),

          const SizedBox(width: 10),

          // Orta: Variable adı + açıklama + zaman
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Variable adı
                if (varName != null && varName.isNotEmpty)
                  Text(
                    varName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(brightness),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),

                // Açıklama (varsa ve addan farklıysa)
                if (varDesc != null && varDesc.isNotEmpty && varDesc != varName)
                  Text(
                    varDesc,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(brightness),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),

                // Zaman
                const SizedBox(height: 2),
                Text(
                  log.dateTime != null ? dateFormat.format(log.dateTime!) : '-',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.tertiaryLabel(context),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Sağ: Değer
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isOnOff)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isOn ? AppColors.success : AppColors.systemGray4).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isOn ? AppColors.success : AppColors.systemGray4,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    displayValue,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isOn ? AppColors.success : AppColors.systemGray,
                    ),
                  ),
                )
              else
                Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(brightness),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
