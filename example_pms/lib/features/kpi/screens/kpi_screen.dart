import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// KPI Özeti ekranı (salt-okunur)
///
/// Sunucu-taraflı KPI RPC'lerini (fn_pms_kpi_summary / fn_pms_controller_uptime
/// / fn_pms_provider_health) tenant kapsamında tüketir. Tüm agregasyon
/// sunucuda yapılır; burada yalnız görselleştirme vardır.
///
/// - Özet metrik kartları (toplam / aktif / çözülen alarm, ort. MTTR, etkilenen
///   saha & controller)
/// - Öncelik dağılımı (kritik / yüksek / orta / düşük)
/// - Controller kullanılabilirlik listesi
/// - Sağlayıcı sağlık listesi
class KpiScreen extends StatefulWidget {
  const KpiScreen({super.key});

  @override
  State<KpiScreen> createState() => _KpiScreenState();
}

class _KpiScreenState extends State<KpiScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  int _selectedDays = 30;

  AlarmKpiSummary _summary = AlarmKpiSummary.empty;
  List<ControllerUptime> _uptime = [];
  List<ProviderHealth> _providers = [];

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
      alarmService.setTenant(tenantId);
    }
    final orgId = organizationService.currentOrganizationId;
    if (orgId != null) {
      alarmService.setOrganization(orgId);
    }

    try {
      final results = await Future.wait([
        alarmService.getKpiSummary(days: _selectedDays),
        alarmService.getControllerUptime(days: _selectedDays),
        alarmService.getProviderHealth(days: _selectedDays),
      ]);

      if (mounted) {
        setState(() {
          _summary = results[0] as AlarmKpiSummary;
          _uptime = results[1] as List<ControllerUptime>;
          _providers = results[2] as List<ProviderHealth>;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load KPI summary', e);
      if (mounted) {
        setState(() {
          _errorMessage =
              sl<LocalizationService>().translate('common.data_load_error');
          _isLoading = false;
        });
      }
    }
  }

  void _onPeriodChanged(int days) {
    setState(() => _selectedDays = days);
    _loadData();
  }

  String _t(String key, {Map<String, dynamic>? params}) =>
      sl<LocalizationService>().translate(key, params: params);

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _t('kpi.title'),
      onBack: () => context.go('/dashboard'),
      actions: [
        AppIconButton(
          icon: Icons.refresh,
          onPressed: _loadData,
        ),
      ],
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: AppLoadingIndicator())
            : _errorMessage != null
                ? Center(
                    child: AppErrorView(
                      message: _errorMessage!,
                      onRetry: _loadData,
                    ),
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal,
                      vertical: AppSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Period selector
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _t('kpi.subtitle',
                                  params: {'days': '$_selectedDays'}),
                              style: AppTypography.subhead.copyWith(
                                color: AppColors.secondaryLabel(context),
                              ),
                            ),
                            ChartPeriodSelector(
                              selectedDays: _selectedDays,
                              onChanged: _onPeriodChanged,
                              options: const [7, 30, 90],
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Summary metric tiles
                        _buildSummaryGrid(),
                        const SizedBox(height: AppSpacing.lg),

                        // Priority breakdown
                        _buildPriorityBreakdown(context),
                        const SizedBox(height: AppSpacing.lg),

                        // Controller uptime
                        _buildSectionTitle(_t('kpi.controller_uptime')),
                        const SizedBox(height: AppSpacing.sm),
                        _buildUptimeList(context),
                        const SizedBox(height: AppSpacing.lg),

                        // Provider health
                        _buildSectionTitle(_t('kpi.provider_health')),
                        const SizedBox(height: AppSpacing.sm),
                        _buildProviderList(context),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
      ),
    );
  }

  // ============================================
  // SUMMARY TILES
  // ============================================

  Widget _buildSummaryGrid() {
    final mttrText = _t('kpi.hours_short', params: {
      'value': _summary.avgResolutionHours.toStringAsFixed(1),
    });

    return MetricCardGrid(
      childAspectRatio: 1.6,
      cards: [
        MetricCard(
          title: _t('kpi.total_alarms'),
          value: '${_summary.totalAlarms}',
          icon: Icons.notifications_outlined,
          color: AppColors.primary,
        ),
        MetricCard(
          title: _t('kpi.active_alarms'),
          value: '${_summary.activeAlarms}',
          icon: Icons.warning_amber_rounded,
          color: AppColors.error,
        ),
        MetricCard(
          title: _t('kpi.resolved_alarms'),
          value: '${_summary.resolvedAlarms}',
          icon: Icons.check_circle_outline,
          color: AppColors.success,
        ),
        MetricCard(
          title: _t('kpi.avg_mttr'),
          value: mttrText,
          icon: Icons.timer_outlined,
          color: AppColors.warning,
        ),
        MetricCard(
          title: _t('kpi.affected_sites'),
          value: '${_summary.distinctSitesAffected}',
          icon: Icons.location_on_outlined,
          color: AppColors.primary,
        ),
        MetricCard(
          title: _t('kpi.affected_controllers'),
          value: '${_summary.distinctControllersAffected}',
          icon: Icons.developer_board,
          color: AppColors.systemGray,
        ),
      ],
    );
  }

  // ============================================
  // PRIORITY BREAKDOWN
  // ============================================

  Widget _buildPriorityBreakdown(BuildContext context) {
    final items = <_PriorityRow>[
      _PriorityRow(_t('kpi.critical'), _summary.criticalCount, AppColors.error),
      _PriorityRow(_t('kpi.high'), _summary.highCount, AppColors.warning),
      _PriorityRow(_t('kpi.medium'), _summary.mediumCount, AppColors.primary),
      _PriorityRow(_t('kpi.low'), _summary.lowCount, AppColors.systemGray),
    ];
    final maxCount = items.fold<int>(
        0, (m, e) => e.count > m ? e.count : m);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('kpi.priority_breakdown'),
            style: AppTypography.headline,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final item in items) ...[
            _buildPriorityBar(context, item, maxCount),
            if (item != items.last) const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _buildPriorityBar(
      BuildContext context, _PriorityRow item, int maxCount) {
    final fraction = maxCount > 0 ? item.count / maxCount : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            item.label,
            style: AppTypography.subhead.copyWith(
              color: AppColors.primaryLabel(context),
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: AppColors.segmentedBackground(context),
              valueColor: AlwaysStoppedAnimation<Color>(item.color),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 40,
          child: Text(
            '${item.count}',
            textAlign: TextAlign.right,
            style: AppTypography.subhead.copyWith(
              fontWeight: FontWeight.w700,
              color: item.color,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================
  // CONTROLLER UPTIME
  // ============================================

  Widget _buildUptimeList(BuildContext context) {
    if (_uptime.isEmpty) {
      return _buildEmptyCard(context, _t('kpi.no_uptime_data'));
    }

    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < _uptime.length; i++) ...[
            _buildUptimeRow(context, _uptime[i]),
            if (i < _uptime.length - 1)
              Divider(height: AppSpacing.md, color: AppColors.separator(context)),
          ],
        ],
      ),
    );
  }

  Widget _buildUptimeRow(BuildContext context, ControllerUptime u) {
    final pct = u.availabilityPct.clamp(0, 100).toDouble();
    final color = pct >= 99
        ? AppColors.success
        : pct >= 95
            ? AppColors.warning
            : AppColors.error;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                u.controllerName.isNotEmpty ? u.controllerName : u.controllerId,
                style: AppTypography.subhead.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryLabel(context),
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (u.siteName != null && u.siteName!.isNotEmpty)
                Text(
                  u.siteName!,
                  style: AppTypography.caption1.copyWith(
                    color: AppColors.secondaryLabel(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              Text(
                _t('kpi.alarm_count', params: {'count': '${u.alarmCount}'}),
                style: AppTypography.caption2.copyWith(
                  color: AppColors.tertiaryLabel(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${pct.toStringAsFixed(1)}%',
              style: AppTypography.headline.copyWith(color: color),
            ),
            Text(
              _t('kpi.availability'),
              style: AppTypography.caption2.copyWith(
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================
  // PROVIDER HEALTH
  // ============================================

  Widget _buildProviderList(BuildContext context) {
    if (_providers.isEmpty) {
      return _buildEmptyCard(context, _t('kpi.no_provider_data'));
    }

    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < _providers.length; i++) ...[
            _buildProviderRow(context, _providers[i]),
            if (i < _providers.length - 1)
              Divider(height: AppSpacing.md, color: AppColors.separator(context)),
          ],
        ],
      ),
    );
  }

  Widget _buildProviderRow(BuildContext context, ProviderHealth p) {
    final score = p.healthScore.clamp(0, 100).toDouble();
    final color = score >= 80
        ? AppColors.success
        : score >= 50
            ? AppColors.warning
            : AppColors.error;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.providerName.isNotEmpty ? p.providerName : p.providerId,
                style: AppTypography.subhead.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryLabel(context),
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${_t('kpi.alarm_count', params: {'count': '${p.alarmCount}'})}'
                ' · ${_t('kpi.critical')}: ${p.criticalCount}',
                style: AppTypography.caption1.copyWith(
                  color: AppColors.secondaryLabel(context),
                ),
              ),
              if (p.lastAlarmAt != null)
                Text(
                  '${_t('kpi.last_alarm')}: ${_formatDate(p.lastAlarmAt!)}',
                  style: AppTypography.caption2.copyWith(
                    color: AppColors.tertiaryLabel(context),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              score.toStringAsFixed(0),
              style: AppTypography.title3.copyWith(color: color),
            ),
            Text(
              _t('kpi.health_score'),
              style: AppTypography.caption2.copyWith(
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================
  // HELPERS
  // ============================================

  Widget _buildSectionTitle(String title) {
    return Text(title, style: AppTypography.title3);
  }

  Widget _buildEmptyCard(BuildContext context, String message) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: Text(
            message,
            style: AppTypography.subhead.copyWith(
              color: AppColors.secondaryLabel(context),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _PriorityRow {
  final String label;
  final int count;
  final Color color;

  const _PriorityRow(this.label, this.count, this.color);
}
