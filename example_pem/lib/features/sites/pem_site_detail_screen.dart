import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../pem_common.dart';
import '../meters/pem_meter_tile.dart';
import '../shared/pem_models.dart';
import '../shared/pem_widgets.dart';
import 'pem_sites_service.dart';

/// PEM **Saha enerji detayı** — son 30 günün günlük tüketimi (KPI + grafik),
/// sahadaki sayaçlar ve son 90 günün haftanın günü yük profili. Salt-okunur.
class PemSiteDetailScreen extends StatefulWidget {
  const PemSiteDetailScreen({super.key, required this.site, this.service});

  final PemSite site;
  final PemSitesService? service;

  @override
  State<PemSiteDetailScreen> createState() => _PemSiteDetailScreenState();
}

class _PemSiteDetailScreenState extends State<PemSiteDetailScreen> {
  late final PemSitesService _service = widget.service ?? PemSitesService();

  bool _loading = true;
  String? _error;
  PemSiteDetail? _detail;

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
      final d = await _service.siteDetail(widget.site.id);
      if (!mounted) return;
      setState(() {
        _detail = d;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      Logger.error('PEM site detail load failed', e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.site.name,
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        AppIconButton(
          icon: Icons.refresh,
          tooltip: pemT('common.refresh', 'Yenile'),
          onPressed: () => _load(),
        ),
      ],
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: AppLoadingIndicator());
    if (_error != null) {
      return PemErrorState(
        title: pemT('pem.mobile.site_load_error',
            'Saha enerji verisi yüklenemedi'),
        onRetry: () => _load(),
      );
    }
    final d = _detail!;
    final s = widget.site;
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          LayoutBuilder(builder: (context, c) {
            final w = (c.maxWidth - AppSpacing.sm) / 2;
            final tiles = [
              PemKpiTile(
                label: pemT('energy.cockpit.kpi_total_kwh', 'Toplam Tüketim'),
                value: pemKwh(d.totalKwh),
                icon: Icons.bolt,
              ),
              PemKpiTile(
                label: pemT('energy.cockpit.kpi_total_cost', 'Toplam Maliyet'),
                value: pemNum(d.totalCost, decimals: 2),
                icon: Icons.payments_outlined,
              ),
              PemKpiTile(
                label: pemT('energy.cockpit.kpi_peak', 'Tepe Talep'),
                value: '${pemNum(d.peakKw, decimals: 1)} kW',
                icon: Icons.show_chart,
              ),
              PemKpiTile(
                label: pemT('energy.benchmark.col.rank', 'Sıra'),
                value: s.rank != null ? '#${s.rank}' : '—',
                icon: Icons.leaderboard_outlined,
              ),
            ];
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [for (final t in tiles) SizedBox(width: w, child: t)],
            );
          }),
          if (s.validity != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                '${pemT('energy.benchmark.col.validity', 'Model kalitesi')}: '
                '${_validity(s.validity)}'
                '${s.intensityKwhPerDd != null ? ' · ${pemT('energy.benchmark.col.intensity', 'Yoğunluk (kWh/°gün)')}: ${pemNum(s.intensityKwhPerDd, decimals: 2)}' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          PemSection(
            title: pemT('pem.mobile.site_daily_title',
                'Günlük tüketim (son 30 gün)'),
            child: d.hasConsumption
                ? PemBarChart(
                    values: [
                      for (final x in d.daily) PeriodValue(x.day, x.kwh),
                    ],
                    labelOf: pemDayLabel,
                  )
                : PemInlineEmpty(
                    icon: Icons.sensors_off_outlined,
                    message: pemT('energy.loadprofile.no_data',
                        'Bu dönem için tüketim verisi yok.'),
                  ),
          ),
          PemSection(
            title: pemT('energy.loadprofile.chart_title',
                'Haftanın gününe göre ortalama tüketim'),
            child: d.loadProfile.isEmpty
                ? PemInlineEmpty(
                    message: pemT('energy.loadprofile.no_data',
                        'Bu dönem için tüketim verisi yok.'))
                : PemLoadProfileTable(points: d.loadProfile),
          ),
          PemSection(
            title: pemT('energy.meter.list_title', 'Sayaçlar'),
            child: d.meters.isEmpty
                ? PemInlineEmpty(
                    icon: Icons.speed_outlined,
                    message: pemT('energy.meter.no_meters_hint',
                        'Bu tesiste sayaç yok. Okuma girebilmek için bir sayaç oluşturun.'))
                : Column(children: [
                    for (final m in d.meters) PemMeterTile(meter: m),
                  ]),
          ),
        ],
      ),
    );
  }

  static String _validity(String? code) {
    final c = (code ?? '').trim();
    if (c.isEmpty) return '—';
    return pemT('energy.mvsavings.validity.$c', EntityStatusLabels.humanize(c));
  }
}
