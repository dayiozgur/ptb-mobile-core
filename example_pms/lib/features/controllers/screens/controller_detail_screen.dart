import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class ControllerDetailScreen extends StatefulWidget {
  final String controllerId;
  final String? controllerName;

  const ControllerDetailScreen({
    super.key,
    required this.controllerId,
    this.controllerName,
  });

  @override
  State<ControllerDetailScreen> createState() => _ControllerDetailScreenState();
}

class _ControllerDetailScreenState extends State<ControllerDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Controller? _controller;
  List<Variable> _variables = [];
  List<Alarm> _alarms = [];
  List<IoTLog> _recentLogs = [];

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
      controllerService.setTenant(tenantId);
      variableService.setTenant(tenantId);
      alarmService.setTenant(tenantId);
      iotLogService.setTenant(tenantId);
    }

    try {
      // Load controller details
      final controller = await controllerService.getById(widget.controllerId);

      // Load related variables (variables don't have controllerId directly,
      // so we load all and can filter by context if needed)
      List<Variable> variables = [];
      try {
        variables = await variableService.getAll(forceRefresh: false);
      } catch (e) {
        Logger.error('Failed to load variables', e);
      }

      // Load related alarms
      List<Alarm> alarms = [];
      try {
        alarms = await alarmService.getActiveAlarms();
        alarms = alarms.where((a) => a.controllerId == widget.controllerId).toList();
      } catch (e) {
        Logger.error('Failed to load alarms', e);
      }

      // Load recent logs
      List<IoTLog> logs = [];
      try {
        logs = await iotLogService.getLogs(
          controllerId: widget.controllerId,
          limit: 20,
          forceRefresh: true,
          includeVariable: true,
        );
      } catch (e) {
        Logger.error('Failed to load logs', e);
      }

      if (mounted) {
        setState(() {
          _controller = controller;
          _variables = variables;
          _alarms = alarms;
          _recentLogs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load controller detail', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Controller detaylari yuklenemedi';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.controllerName ?? 'Controller Detay',
      onBack: () => context.go('/controllers'),
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

    final controller = _controller;
    if (controller == null) {
      return AppErrorView(
        title: 'Bulunamadi',
        message: 'Controller bulunamadi.',
        actionLabel: 'Geri Don',
        onAction: () => context.go('/controllers'),
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
            // Status & Basic Info
            AppCard(
              variant: AppCardVariant.filled,
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Row(
                  children: [
                    Expanded(
                      child: _DetailItem(
                        label: 'Durum',
                        child: AppBadge(
                          label: controller.status.label,
                          variant: _getStatusVariant(controller.status),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _DetailItem(
                        label: 'Tip',
                        value: controller.type.label,
                      ),
                    ),
                    Expanded(
                      child: _DetailItem(
                        label: 'Aktif',
                        value: controller.active ? 'Evet' : 'Hayir',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Connection Info
            AppSectionHeader(title: 'Baglanti Bilgileri'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    _InfoRow(label: 'IP Adresi', value: controller.ipAddress ?? '-'),
                    if (controller.code != null)
                      _InfoRow(label: 'Kod', value: controller.code!),
                    if (controller.serialNumber != null)
                      _InfoRow(label: 'Seri No', value: controller.serialNumber!),
                    if (controller.model != null)
                      _InfoRow(label: 'Model', value: controller.model!),
                    if (controller.lastConnectedAt != null)
                      _InfoRow(
                        label: 'Son Baglanti',
                        value: dateFormat.format(controller.lastConnectedAt!),
                      ),
                    if (controller.lastDataAt != null)
                      _InfoRow(
                        label: 'Son Iletisim',
                        value: dateFormat.format(controller.lastDataAt!),
                      ),
                  ],
                ),
              ),
            ),

            if (controller.description != null && controller.description!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              AppSectionHeader(title: 'Aciklama'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Padding(
                  padding: AppSpacing.cardInsets,
                  child: Text(controller.description!, style: AppTypography.body),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.md),

            // Related Variables
            AppSectionHeader(
              title: 'Degiskenler (${_variables.length})',
              action: _variables.isNotEmpty
                  ? TextButton(
                      onPressed: () => context.push('/variables'),
                      child: Text('Tumunu Gor', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                    )
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_variables.isEmpty)
              AppCard(
                child: Padding(
                  padding: AppSpacing.cardInsets,
                  child: Center(
                    child: Text(
                      'Bu controller icin degisken bulunamadi',
                      style: AppTypography.subheadline.copyWith(
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                  ),
                ),
              )
            else
              AppCard(
                child: Column(
                  children: _variables.take(5).map((variable) {
                    final isLast = variable == _variables.take(5).last;
                    return Column(
                      children: [
                        AppListTile(
                          title: variable.name,
                          subtitle: '${variable.dataType.label} - ${variable.formattedValue}',
                          trailing: variable.isBoolean
                              ? Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: (variable.booleanValue ?? false) ? AppColors.success : AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : Text(
                                  variable.formattedValue,
                                  style: AppTypography.caption1.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                          onTap: () => context.push(
                            '/variables/${variable.id}?name=${Uri.encodeComponent(variable.name)}',
                          ),
                        ),
                        if (!isLast) Divider(height: 1, color: AppColors.separator(context)),
                      ],
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: AppSpacing.md),

            // Active Alarms
            AppSectionHeader(title: 'Aktif Alarmlar (${_alarms.length})'),
            const SizedBox(height: AppSpacing.sm),
            if (_alarms.isEmpty)
              AppCard(
                child: Padding(
                  padding: AppSpacing.cardInsets,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: AppColors.success, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Aktif alarm yok',
                        style: AppTypography.subheadline.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...List.generate(_alarms.length, (index) {
                final alarm = _alarms[index];
                return Padding(
                  padding: EdgeInsets.only(bottom: index < _alarms.length - 1 ? AppSpacing.sm : 0),
                  child: AppCard(
                    child: Padding(
                      padding: AppSpacing.cardInsets,
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(alarm.name ?? alarm.code ?? 'Alarm', style: AppTypography.headline),
                                Text(alarm.durationFormatted, style: AppTypography.caption2.copyWith(color: AppColors.error)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

            const SizedBox(height: AppSpacing.md),

            // Recent Logs
            AppSectionHeader(
              title: 'Son Loglar (${_recentLogs.length})',
              action: TextButton(
                onPressed: () => context.push('/logs'),
                child: Text('Tumunu Gor', style: TextStyle(color: AppColors.primary, fontSize: 13)),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_recentLogs.isEmpty)
              AppCard(
                child: Padding(
                  padding: AppSpacing.cardInsets,
                  child: Center(
                    child: Text(
                      'Log kaydı bulunamadi',
                      style: AppTypography.subheadline.copyWith(
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                  ),
                ),
              )
            else
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Column(
                    children: _recentLogs.take(10).map((log) {
                      final isLast = log == _recentLogs.take(10).last;
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

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isOnOff)
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: (isOn ? AppColors.success : AppColors.systemGray4).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(isOn ? Icons.power : Icons.power_off, size: 16, color: isOn ? AppColors.success : AppColors.systemGray),
                                  )
                                else
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.show_chart, size: 16, color: AppColors.primary),
                                  ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (varName != null && varName.isNotEmpty)
                                        Text(varName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                      if (varDesc != null && varDesc.isNotEmpty && varDesc != varName)
                                        Text(varDesc, style: TextStyle(fontSize: 11, color: AppColors.secondaryLabel(context)), overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 2),
                                      Text(
                                        log.dateTime != null ? dateFormat.format(log.dateTime!) : '-',
                                        style: AppTypography.caption2.copyWith(color: AppColors.tertiaryLabel(context)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (isOnOff)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: (isOn ? AppColors.success : AppColors.systemGray4).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: isOn ? AppColors.success : AppColors.systemGray4, width: 1),
                                    ),
                                    child: Text(displayValue, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isOn ? AppColors.success : AppColors.systemGray)),
                                  )
                                else
                                  Text(displayValue, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
                              ],
                            ),
                          ),
                          if (!isLast) Divider(height: 1, color: AppColors.separator(context)),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  AppBadgeVariant _getStatusVariant(ControllerStatus status) {
    switch (status) {
      case ControllerStatus.online:
        return AppBadgeVariant.success;
      case ControllerStatus.offline:
        return AppBadgeVariant.error;
      case ControllerStatus.connecting:
        return AppBadgeVariant.warning;
      case ControllerStatus.error:
        return AppBadgeVariant.error;
      case ControllerStatus.maintenance:
        return AppBadgeVariant.info;
      case ControllerStatus.disabled:
      case ControllerStatus.unknown:
        return AppBadgeVariant.secondary;
    }
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? child;

  const _DetailItem({required this.label, this.value, this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption1.copyWith(
            color: AppColors.secondaryLabel(context),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        child ?? Text(value ?? '-', style: AppTypography.headline),
      ],
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
