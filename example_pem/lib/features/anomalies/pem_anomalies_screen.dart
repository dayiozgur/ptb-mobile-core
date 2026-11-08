import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../pem_common.dart';
import '../shared/pem_analytics_service.dart';
import '../shared/pem_models.dart';
import '../shared/pem_widgets.dart';

/// PEM **Tüketim anomalileri** (`/admin/energy/anomalies`) — saha seç →
/// web varsayılan parametreleriyle (referans 120→30 gün önce, tespit son
/// 30 gün, sürücü tepe talep, σ = 2) salt-okunur model tabanlı tespit.
/// Alarm yükseltme (`fn_energy_evaluate_anomaly_alarms`) mobilde YOK.
class PemAnomaliesScreen extends StatefulWidget {
  const PemAnomaliesScreen({super.key, this.service, this.title});

  final PemAnalyticsService? service;
  final String? title;

  @override
  State<PemAnomaliesScreen> createState() => _PemAnomaliesScreenState();
}

class _PemAnomaliesScreenState extends State<PemAnomaliesScreen> {
  late final PemAnalyticsService _service =
      widget.service ?? PemAnalyticsService();

  bool _sitesLoading = true;
  String? _sitesError;
  List<PemSite> _sites = const [];
  String? _siteId;

  bool _running = false;
  String? _runError;
  PemAnomalyResult? _result;
  bool _onlyFlagged = false;

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  Future<void> _loadSites() async {
    setState(() {
      _sitesLoading = true;
      _sitesError = null;
    });
    try {
      final s = await _service.sites();
      if (!mounted) return;
      setState(() {
        _sites = s;
        _sitesLoading = false;
      });
      if (s.length == 1) _pick(s.first.id);
    } catch (e) {
      Logger.error('PEM anomaly sites failed', e);
      if (!mounted) return;
      setState(() {
        _sitesLoading = false;
        _sitesError = e.toString();
      });
    }
  }

  Future<void> _pick(String? id) async {
    if (id == null) return;
    setState(() {
      _siteId = id;
      _running = true;
      _runError = null;
      _result = null;
    });
    try {
      final r = await _service.anomalies(id);
      if (!mounted || _siteId != id) return;
      setState(() {
        _result = r;
        _running = false;
      });
    } catch (e) {
      Logger.error('PEM anomalies failed', e);
      if (!mounted || _siteId != id) return;
      setState(() {
        _running = false;
        _runError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.title ??
          pemT('energy.anomalies.title', 'Tüketim Anomalileri'),
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        AppIconButton(
          icon: Icons.refresh,
          tooltip: pemT('common.refresh', 'Yenile'),
          onPressed: () => _siteId == null ? _loadSites() : _pick(_siteId),
        ),
      ],
      child: _body(),
    );
  }

  Widget _body() {
    if (_sitesLoading) return const Center(child: AppLoadingIndicator());
    if (_sitesError != null) {
      return PemErrorState(
        title: pemT('pem.mobile.sites_load_error', 'Sahalar yüklenemedi'),
        onRetry: _loadSites,
      );
    }
    if (_sites.isEmpty) {
      return PemScrollableEmpty(
        icon: Icons.location_city_outlined,
        title: pemT('energy.meter.no_sites_title', 'Henüz tesis yok'),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        DropdownButtonFormField<String>(
          key: const Key('pem-anomaly-site'),
          initialValue: _siteId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: pemT('energy.anomalies.field_site', 'Saha'),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          hint: Text(pemT('energy.anomalies.select_site', 'Bir saha seçin…')),
          items: [
            for (final s in _sites)
              DropdownMenuItem(
                value: s.id,
                child: Text(s.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _pick,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          pemT('pem.mobile.anomaly_window',
              'Referans: 120–30 gün önce · Tespit: son 30 gün · σ = 2'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        ..._resultWidgets(),
      ],
    );
  }

  List<Widget> _resultWidgets() {
    if (_siteId == null) return const [];
    if (_running) {
      return const [
        Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Center(child: AppLoadingIndicator()),
        ),
      ];
    }
    if (_runError != null) {
      return [
        const SizedBox(height: AppSpacing.md),
        AppEmptyState(
          icon: Icons.error_outline,
          title: pemT('energy.anomalies.load_error',
              'Anomali tespiti çalıştırılamadı. Lütfen tekrar deneyin.'),
          actionLabel: pemT('common.retry', 'Yeniden dene'),
          onAction: () => _pick(_siteId),
          compact: true,
        ),
      ];
    }
    final r = _result;
    if (r == null) return const [];
    if (r.days.isEmpty) {
      return [
        PemSection(
          title: pemT('energy.anomalies.list_title', 'Günlük sonuçlar'),
          child: PemInlineEmpty(
            icon: Icons.sensors_off_outlined,
            message: pemT('energy.anomalies.no_data',
                'Bu pencere için incelenecek günlük veri yok.'),
          ),
        ),
      ];
    }
    final theme = Theme.of(context);
    final rows =
        _onlyFlagged ? r.days.where((d) => d.isAnomaly).toList() : r.days;
    final chron = [...r.days]..sort((a, b) => a.day.compareTo(b.day));
    final flagged = {for (final d in r.days) if (d.isAnomaly) d.day};
    return [
      const SizedBox(height: AppSpacing.md),
      LayoutBuilder(builder: (context, c) {
        final w = (c.maxWidth - 2 * AppSpacing.sm) / 3;
        return Row(children: [
          SizedBox(
              width: w,
              child: PemKpiTile(
                  label: pemT('energy.anomalies.kpi_days', 'İncelenen gün'),
                  value: pemNum(r.analysedDays),
                  icon: Icons.calendar_today_outlined)),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
              width: w,
              child: PemKpiTile(
                  label: pemT('energy.anomalies.kpi_flagged', 'İşaretli günler'),
                  value: pemNum(r.flaggedDays),
                  icon: Icons.flag_outlined,
                  color: r.flaggedDays > 0 ? theme.colorScheme.error : null)),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
              width: w,
              child: PemKpiTile(
                  label: pemT('energy.anomalies.kpi_max_dev', 'Maks. sapma'),
                  value: r.maxAbsDeviationPct == null
                      ? '—'
                      : '${pemNum(r.maxAbsDeviationPct, decimals: 1)}%',
                  icon: Icons.trending_up)),
        ]);
      }),
      PemSection(
        title: pemT('energy.anomalies.col_actual', 'Gerçekleşen'),
        child: PemBarChart(
          values: [
            for (final d in chron) PeriodValue(d.day, d.actualKwh ?? 0),
          ],
          labelOf: pemDayLabel,
          highlight: (v) => flagged.contains(v.period),
        ),
      ),
      PemSection(
        title: pemT('energy.anomalies.list_title', 'Günlük sonuçlar'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                  pemT('energy.anomalies.only_flagged', 'Yalnızca işaretliler')),
              value: _onlyFlagged,
              onChanged: (v) => setState(() => _onlyFlagged = v),
            ),
            if (rows.isEmpty)
              PemInlineEmpty(
                icon: Icons.check_circle_outline,
                message: pemT('energy.anomalies.no_anomalies',
                    'Bu pencere için işaretli anomali yok.'),
              )
            else
              for (final d in rows) _dayRow(d),
          ],
        ),
      ),
    ];
  }

  Widget _dayRow(AnomalyPoint d) {
    final theme = Theme.of(context);
    final color =
        d.isAnomaly ? theme.colorScheme.error : theme.colorScheme.outline;
    final dev = d.deviationPct == null
        ? '—'
        : '${d.deviationPct! >= 0 ? '+' : ''}${pemNum(d.deviationPct, decimals: 1)}%';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
          d.isAnomaly ? Icons.warning_amber_rounded : Icons.check_circle_outline,
          color: color),
      title: Text(pemDate(d.day)),
      subtitle: Text(
          '${pemT('energy.anomalies.col_actual', 'Gerçekleşen')}: ${pemNum(d.actualKwh, decimals: 1)} · '
          '${pemT('energy.anomalies.col_predicted', 'Tahmini')}: ${pemNum(d.predictedKwh, decimals: 1)}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(dev,
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          Text(
            d.isAnomaly
                ? pemT('energy.anomalies.badge_anomaly', 'Anomali')
                : pemT('energy.anomalies.badge_normal', 'Normal'),
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
