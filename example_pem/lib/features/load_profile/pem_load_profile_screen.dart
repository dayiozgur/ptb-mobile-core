import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../pem_common.dart';
import '../shared/pem_analytics_service.dart';
import '../shared/pem_models.dart';
import '../shared/pem_widgets.dart';

/// PEM **Yük profili** (`/admin/energy/load-profile`) — son 90 günün haftanın
/// günü profili (ort. günlük kWh + tepe kW); saha seçimi ya da tüm portföy
/// (`fn_energy_load_profile`, site = null).
class PemLoadProfileScreen extends StatefulWidget {
  const PemLoadProfileScreen({super.key, this.service, this.title});

  final PemAnalyticsService? service;
  final String? title;

  @override
  State<PemLoadProfileScreen> createState() => _PemLoadProfileScreenState();
}

class _PemLoadProfileScreenState extends State<PemLoadProfileScreen> {
  late final PemAnalyticsService _service =
      widget.service ?? PemAnalyticsService();

  /// Seçim değeri: '' = tüm portföy.
  static const String _all = '';

  List<PemSite> _sites = const [];
  String _siteId = _all;
  bool _loading = true;
  String? _error;
  List<LoadProfilePoint> _points = const [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final s = await _service.sites();
      if (mounted) setState(() => _sites = s);
    } catch (e) {
      // Saha listesi yalnız seçici içindir — portföy profili yine yüklenir.
      Logger.warning('PEM load profile sites failed: $e');
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p =
          await _service.loadProfile(_siteId == _all ? null : _siteId);
      if (!mounted) return;
      setState(() {
        _points = p;
        _loading = false;
      });
    } catch (e) {
      Logger.error('PEM load profile failed', e);
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
      title: widget.title ??
          pemT('energy.loadprofile.title', 'Yük Profili ve Puant Talebi'),
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        AppIconButton(
          icon: Icons.refresh,
          tooltip: pemT('common.refresh', 'Yenile'),
          onPressed: _load,
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          DropdownButtonFormField<String>(
            key: const Key('pem-load-profile-site'),
            initialValue: _siteId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: pemT('energy.loadprofile.field_site', 'Saha'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              DropdownMenuItem(
                value: _all,
                child: Text(pemT(
                    'energy.loadprofile.all_sites', 'Tüm sahalar (portföy)')),
              ),
              for (final s in _sites)
                DropdownMenuItem(
                  value: s.id,
                  child: Text(s.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) {
              if (v == null || v == _siteId) return;
              setState(() => _siteId = v);
              _load();
            },
          ),
          ..._content(),
        ],
      ),
    );
  }

  List<Widget> _content() {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Center(child: AppLoadingIndicator()),
        ),
      ];
    }
    if (_error != null) {
      return [
        const SizedBox(height: AppSpacing.md),
        AppEmptyState(
          icon: Icons.error_outline,
          title: pemT('energy.loadprofile.load_error',
              'Yük profili yüklenemedi. Lütfen tekrar deneyin.'),
          actionLabel: pemT('common.retry', 'Yeniden dene'),
          onAction: _load,
          compact: true,
        ),
      ];
    }
    if (_points.isEmpty || _points.every((p) => p.dayCount == 0)) {
      return [
        PemSection(
          title: pemT('energy.loadprofile.chart_title',
              'Haftanın gününe göre ortalama tüketim'),
          child: PemInlineEmpty(
            icon: Icons.sensors_off_outlined,
            message: pemT('energy.loadprofile.no_data',
                'Bu dönem için tüketim verisi yok.'),
          ),
        ),
      ];
    }
    final total = _points.fold<double>(0, (s, p) => s + p.totalConsumptionKwh);
    final days = _points.fold<int>(0, (s, p) => s + p.dayCount);
    final peak = _points.fold<double>(0, (m, p) => math.max(m, p.maxPeakDemandKw));
    final peakDay = _points.reduce(
        (a, b) => b.avgConsumptionKwh > a.avgConsumptionKwh ? b : a);
    return [
      const SizedBox(height: AppSpacing.md),
      LayoutBuilder(builder: (context, c) {
        final w = (c.maxWidth - 2 * AppSpacing.sm) / 3;
        return Row(children: [
          SizedBox(
              width: w,
              child: PemKpiTile(
                  label: pemT('energy.loadprofile.kpi_avg_daily',
                      'Ort. günlük tüketim'),
                  value: pemKwh(days > 0 ? total / days : 0),
                  icon: Icons.bolt)),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
              width: w,
              child: PemKpiTile(
                  label: pemT('energy.loadprofile.kpi_peak', 'Puant talep'),
                  value: '${pemNum(peak, decimals: 1)} kW',
                  icon: Icons.show_chart)),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
              width: w,
              child: PemKpiTile(
                  label: pemT('energy.loadprofile.kpi_peak_day', 'Puant gün'),
                  value: pemDowLabel(peakDay.dow),
                  icon: Icons.event)),
        ]);
      }),
      PemSection(
        title: pemT('energy.loadprofile.table_title', 'Gün bazında döküm'),
        child: PemLoadProfileTable(points: _points),
      ),
    ];
  }
}
