import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/reporting/aggregate_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../dyn_widgets/dyn_widgets.dart';

/// Tek bir KPI tanımı — json gövdesindeki [key] değerini [label] ile gösterir.
class KpiSpec {
  final String label;
  final String key;
  final String? prefix;
  final String? suffix;
  final int decimals;
  const KpiSpec(
    this.label,
    this.key, {
    this.prefix,
    this.suffix,
    this.decimals = 0,
  });
}

/// **KPI satır kartı** — `json`/`jsonb` dönen bir rollup'ı çeker, [objectPath]
/// (nokta-yol) ile KPI nesnesine iner ve [kpis] tile'larını sarılmış bir satır
/// olarak gösterir. Kendini çeker (yükleme/hata/boş durumu [DynWidgetCard]).
class KpiRowCard extends StatefulWidget {
  final String title;
  final String rpc;
  final Map<String, dynamic>? params;

  /// json köküne göre KPI nesnesinin yolu (ör. `kpis`); null → kök nesne.
  final String? objectPath;
  final List<KpiSpec> kpis;

  const KpiRowCard({
    super.key,
    required this.title,
    required this.rpc,
    required this.kpis,
    this.params,
    this.objectPath,
  });

  @override
  State<KpiRowCard> createState() => _KpiRowCardState();
}

class _KpiRowCardState extends State<KpiRowCard> {
  late Future<dynamic> _future;

  @override
  void initState() {
    super.initState();
    _future = AggregateService().json(widget.rpc, params: widget.params);
  }

  void _reload() {
    setState(() {
      _future = AggregateService().json(widget.rpc, params: widget.params);
    });
  }

  Map<String, dynamic> _resolveObject(dynamic raw) {
    dynamic node = raw;
    // Bazı sürücüler json/jsonb'yi String olarak döndürebilir → çöz.
    if (node is String) {
      try {
        node = jsonDecode(node);
      } catch (_) {
        node = null;
      }
    }
    // TABLE dönen rollup → satır listesi; tek-satır özetlerde ilk satırı
    // nesne olarak al (json-nesne dönenler zaten Map).
    if (node is List) node = node.isNotEmpty ? node.first : null;
    final path = widget.objectPath;
    if (node is Map && path != null && path.isNotEmpty) {
      for (final seg in path.split('.')) {
        if (node is Map && node.containsKey(seg)) {
          node = node[seg];
        } else {
          node = null;
          break;
        }
      }
    }
    return node is Map ? Map<String, dynamic>.from(node) : <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: _future,
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        final error = snap.hasError ? 'Yüklenemedi' : null;
        final obj = snap.hasData ? _resolveObject(snap.data) : null;

        return DynWidgetCard(
          title: widget.title,
          loading: loading,
          error: error,
          onRetry: _reload,
          child: obj == null
              ? const SizedBox.shrink()
              : Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.md,
                  children: [
                    for (final spec in widget.kpis)
                      _KpiTile(spec: spec, value: obj[spec.key]),
                  ],
                ),
        );
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  final KpiSpec spec;
  final dynamic value;
  const _KpiTile({required this.spec, this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _format(value),
          style: AppTypography.title2.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primaryLabel(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          spec.label,
          style: AppTypography.caption1.copyWith(
            color: AppColors.secondaryLabel(context),
          ),
        ),
      ],
    );
  }

  String _format(dynamic v) {
    final n = _toNum(v);
    if (n == null) return v?.toString() ?? '—';
    // Çekirdek Formatters (intl tr_TR) — elle binlik-ayraç yerine tek kaynak.
    return '${spec.prefix ?? ''}'
        '${Formatters.number(n, decimals: spec.decimals)}'
        '${spec.suffix ?? ''}';
  }

  num? _toNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }
}

/// **Aggregate grafik kartı** — bir rollup RPC'sinden satır çeker ve
/// [DynChartWidget] ile çizer. `TABLE(...)` dönen RPC'ler doğrudan; `json`
/// dönenler [transform] ile satıra çevrilir. Kendini çeker.
class AggregateChartCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String rpc;
  final Map<String, dynamic>? params;

  /// `bar_chart` | `horizontal_bar` | `stacked_bar` | `line_chart` |
  /// `area_chart` | `pie_chart` | `donut_chart`.
  final String chartKind;

  /// `labelField`, `valueFields`, `colors` vb.
  final Map<String, dynamic> visualConfig;
  final double height;

  /// `json` dönen RPC'ler için ham → satır dönüşümü (null → satır listesi bekle).
  final List<Map<String, dynamic>> Function(dynamic raw)? transform;

  const AggregateChartCard({
    super.key,
    required this.title,
    required this.rpc,
    required this.chartKind,
    this.subtitle,
    this.params,
    this.visualConfig = const {},
    this.height = 220,
    this.transform,
  });

  @override
  State<AggregateChartCard> createState() => _AggregateChartCardState();
}

class _AggregateChartCardState extends State<AggregateChartCard> {
  late Future<List<Map<String, dynamic>>> _future;

  Future<List<Map<String, dynamic>>> _fetch() async {
    final t = widget.transform;
    if (t != null) {
      final raw = await AggregateService().json(widget.rpc, params: widget.params);
      return t(raw);
    }
    return AggregateService().rows(widget.rpc, params: widget.params);
  }

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  void _reload() => setState(() => _future = _fetch());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        final error = snap.hasError ? 'Yüklenemedi' : null;
        final rows = snap.data ?? const <Map<String, dynamic>>[];

        return DynWidgetCard(
          title: widget.title,
          subtitle: widget.subtitle,
          loading: loading,
          error: error,
          onRetry: _reload,
          child: rows.isEmpty
              ? _empty(context)
              : DynChartWidget(
                  rows,
                  widget.visualConfig,
                  chartKind: widget.chartKind,
                  height: widget.height,
                ),
        );
      },
    );
  }

  Widget _empty(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: Text(
            'Henüz veri yok',
            style: AppTypography.caption1.copyWith(
              color: AppColors.secondaryLabel(context),
            ),
          ),
        ),
      );
}
