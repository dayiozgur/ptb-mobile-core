import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../pem_common.dart';
import '../shared/pem_widgets.dart';
import 'pem_dashboard_service.dart';

/// PEM **Enerji panosu** (`/admin/energy/dashboard`, `/admin/energy/cockpit`)
/// — web Enerji Kokpiti paritesi, telefona göre: 4 manşet KPI (toplam tüketim,
/// maliyet, tepe talep, aktif enerji alarmı), tüketim eğilimi, tesisat payı,
/// en çok tüketen sahalar ve veri tazeliği uyarısı (Core Bridge akışı yoksa
/// "canlı bağlantı bekleniyor").
class PemDashboardScreen extends StatefulWidget {
  const PemDashboardScreen({super.key, this.service, this.title});

  final PemDashboardService? service;

  /// Başlık (menü öğesine göre: pano / kokpit). Null → Enerji Panosu.
  final String? title;

  @override
  State<PemDashboardScreen> createState() => _PemDashboardScreenState();
}

class _PemDashboardScreenState extends State<PemDashboardScreen> {
  late final PemDashboardService _service =
      widget.service ?? PemDashboardService();

  PemPeriod _period = PemPeriod.last30Days;
  bool _loading = true;
  String? _error;
  PemDashboardData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final d = await _service.load(_period);
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      Logger.error('PEM dashboard load failed', e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _setPeriod(PemPeriod p) {
    if (p == _period) return;
    setState(() => _period = p);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.title ?? pemT('energy.dashboard.title', 'Enerji Panosu'),
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        AppIconButton(
          icon: Icons.refresh,
          tooltip: pemT('common.refresh', 'Yenile'),
          onPressed: () => _load(),
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<PemPeriod>(
                segments: [
                  ButtonSegment(
                    value: PemPeriod.last30Days,
                    label: Text(pemT('pem.mobile.period_30d', 'Son 30 gün')),
                  ),
                  ButtonSegment(
                    value: PemPeriod.yearToDate,
                    label: Text(pemT('pem.mobile.period_ytd', 'Yıl başından')),
                  ),
                ],
                selected: {_period},
                showSelectedIcon: false,
                onSelectionChanged: (s) => _setPeriod(s.first),
              ),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: AppLoadingIndicator());
    if (_error != null) {
      return PemErrorState(
        title: pemT('energy.cockpit.load_error',
            'Enerji kokpiti yüklenemedi. Lütfen tekrar deneyin.'),
        onRetry: () => _load(),
      );
    }
    final d = _data!;
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _kpiGrid(d),
          if (d.isEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            PemFreshnessNotice(latestReadingAt: d.latestReadingAt),
          ] else ...[
            PemSection(
              title: pemT('energy.cockpit.trend_title', 'Tüketim Eğilimi'),
              child: PemBarChart(
                values: d.series,
                labelOf: d.period == PemPeriod.last30Days
                    ? pemDayLabel
                    : pemMonthLabel,
              ),
            ),
            if (d.byUtility.length > 1)
              PemSection(
                title: pemT('pem.mobile.by_utility', 'Tesisata göre'),
                child: Column(children: [
                  for (final u in d.byUtility)
                    PemShareRow(
                      label: pemUtilityLabel(u.label),
                      value: pemKwh(u.totalKwh),
                      pct: u.pct,
                    ),
                ]),
              ),
            PemSection(
              title: pemT('energy.cockpit.top_consumers_title',
                  'En Çok Tüketenler'),
              child: d.topSites.isEmpty
                  ? PemInlineEmpty(
                      message: pemT('energy.cockpit.no_consumers',
                          'Seçili aralıkta saha tüketim verisi yok'))
                  : Column(children: [
                      for (final s in d.topSites.take(5))
                        PemShareRow(
                          label: s.label,
                          value: pemKwh(s.totalKwh),
                          pct: s.pct,
                        ),
                    ]),
            ),
            if (d.latestReadingAt != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(
                  '${pemT('energy.freshness.label', 'Sayaç verisi')}: '
                  '${pemDateTime(d.latestReadingAt)}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _kpiGrid(PemDashboardData d) {
    final k = d.kpis;
    final tiles = [
      PemKpiTile(
        label: pemT('energy.cockpit.kpi_total_kwh', 'Toplam Tüketim'),
        value: pemKwh(k.totalKwh),
        icon: Icons.bolt,
      ),
      PemKpiTile(
        label: pemT('energy.cockpit.kpi_total_cost', 'Toplam Maliyet'),
        value: pemNum(k.totalCost, decimals: 2),
        icon: Icons.payments_outlined,
      ),
      PemKpiTile(
        label: pemT('energy.cockpit.kpi_peak', 'Tepe Talep'),
        value: '${pemNum(k.peakDemandKw, decimals: 1)} kW',
        icon: Icons.show_chart,
      ),
      PemKpiTile(
        label: pemT('energy.cockpit.kpi_alarms', 'Aktif Enerji Alarmları'),
        value: pemNum(k.activeAlarms),
        icon: Icons.notifications_active_outlined,
        color: k.activeAlarms > 0
            ? Theme.of(context).colorScheme.error
            : null,
      ),
    ];
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - AppSpacing.sm) / 2;
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [for (final t in tiles) SizedBox(width: w, child: t)],
      );
    });
  }
}
