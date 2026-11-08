import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../pem_common.dart';
import 'pem_models.dart';

/// `#RRGGBB` / `#AARRGGBB` → Color (geçersizse null).
Color? pemHexColor(String? hex) {
  var h = (hex ?? '').trim().replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(v);
}

/// KPI kutucuğu (etiket + değer + ikon).
class PemKpiTile extends StatelessWidget {
  const PemKpiTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, color: c, size: 28),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSpacing.xxs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Başlıklı bölüm kartı.
class PemSection extends StatelessWidget {
  const PemSection({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

/// Bölüm içi küçük boş durum satırı.
class PemInlineEmpty extends StatelessWidget {
  const PemInlineEmpty({super.key, required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon ?? Icons.info_outline, size: 18, color: muted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              child: Text(message, style: TextStyle(color: muted))),
        ],
      ),
    );
  }
}

/// Aşağı-çek-yenile destekli tam sayfa boş durum (RefreshIndicator içinde).
class PemScrollableEmpty extends StatelessWidget {
  const PemScrollableEmpty({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 96),
        AppEmptyState(
          icon: icon,
          title: title,
          message: message,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
      ],
    );
  }
}

/// Hata durumu (yeniden dene düğmesiyle).
class PemErrorState extends StatelessWidget {
  const PemErrorState({super.key, required this.title, required this.onRetry});

  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return PemScrollableEmpty(
      icon: Icons.error_outline,
      title: title,
      actionLabel: pemT('common.retry', 'Yeniden dene'),
      onAction: onRetry,
    );
  }
}

/// Veri tazeliği / canlı bağlantı bilgisi (web `energy.freshness.*`).
///
/// [latestReadingAt] null → hiç sayaç verisi alınmamış ("Canlı bağlantı
/// bekleniyor"); seçili dönemde veri yok ama geçmiş veri var → "Son sayaç
/// verisi: …".
class PemFreshnessNotice extends StatelessWidget {
  const PemFreshnessNotice({super.key, required this.latestReadingAt});

  final String? latestReadingAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final never = latestReadingAt == null;
    final title = never
        ? pemT('energy.freshness.waiting_title', 'Canlı bağlantı bekleniyor')
        : pemT('energy.cockpit.no_trend', 'Seçili aralıkta tüketim verisi yok');
    final msg = never
        ? pemT(
            'energy.freshness.waiting_message',
            'Henüz sayaç verisi alınmadı. Sayaçlar Core Bridge üzerinden veri '
                'göndermeye başladığında veya veri içe aktarıldığında grafikler '
                'dolacak.')
        : pemTp('energy.freshness.last_data_message',
            'Bu dönemde veri yok. Son sayaç verisi: {{time}}',
            {'time': pemDateTime(latestReadingAt)});
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(never ? Icons.sensors_off_outlined : Icons.history,
              color: theme.colorScheme.tertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.xs),
                Text(msg, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dönem başına değer çubuk grafiği (fl_chart — çekirdeğin bağımlılığı).
class PemBarChart extends StatelessWidget {
  const PemBarChart({
    super.key,
    required this.values,
    required this.labelOf,
    this.height = 180,
    this.unit = 'kWh',
    this.highlight,
  });

  final List<PeriodValue> values;
  final String Function(DateTime) labelOf;
  final double height;
  final String unit;

  /// Verilirse true dönen çubuklar vurgu rengiyle çizilir (ör. anomali günü).
  final bool Function(PeriodValue v)? highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxV = values.fold<double>(0, (m, v) => math.max(m, v.value));
    final labelEvery = math.max(1, (values.length / 5).ceil());
    final barWidth = values.length > 20 ? 6.0 : 12.0;
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: maxV <= 0 ? 1 : maxV * 1.15,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: theme.dividerColor.withValues(alpha: 0.4),
              strokeWidth: 0.5,
            ),
          ),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItem: (group, _, rod, __) {
                final i = group.x;
                if (i < 0 || i >= values.length) return null;
                return BarTooltipItem(
                  '${labelOf(values[i].period)}\n${pemNum(rod.toY)} $unit',
                  TextStyle(
                      color: theme.colorScheme.onInverseSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, meta) {
                  if (v == meta.max || v == 0) return const SizedBox.shrink();
                  return Text(_compact(v),
                      style: theme.textTheme.labelSmall,
                      textAlign: TextAlign.right);
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= values.length || i % labelEvery != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(labelOf(values[i].period),
                        style: theme.textTheme.labelSmall),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < values.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: values[i].value,
                  width: barWidth,
                  borderRadius: BorderRadius.circular(2),
                  color: (highlight?.call(values[i]) ?? false)
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ]),
          ],
        ),
      ),
    );
  }

  static String _compact(double v) {
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(v >= 1e4 ? 0 : 1)}k';
    return v.toStringAsFixed(0);
  }
}

/// Pay çubuğu satırı (etiket · değer · %).
class PemShareRow extends StatelessWidget {
  const PemShareRow({
    super.key,
    required this.label,
    required this.value,
    required this.pct,
  });

  final String label;
  final String value;
  final double pct;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium),
              ),
              Text(value, style: theme.textTheme.bodySmall),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 48,
                child: Text('${pemNum(pct, decimals: 1)}%',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Haftanın günü etiketi (`energy.loadprofile.dow.<0-6>`; 0 = Pazar).
String pemDowLabel(int dow) {
  const tr = ['Pazar', 'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma',
    'Cumartesi'];
  final i = dow.clamp(0, 6);
  return pemT('energy.loadprofile.dow.$i', tr[i]);
}

/// Yük profili tablosu (gün · ort. kWh · tepe kW).
class PemLoadProfileTable extends StatelessWidget {
  const PemLoadProfileTable({super.key, required this.points});

  final List<LoadProfilePoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxAvg =
        points.fold<double>(0, (m, p) => math.max(m, p.avgConsumptionKwh));
    TextStyle? head = theme.textTheme.labelSmall
        ?.copyWith(fontWeight: FontWeight.w600);
    return Column(
      children: [
        Row(children: [
          Expanded(
              child: Text(pemT('energy.loadprofile.col_day', 'Gün'),
                  style: head)),
          SizedBox(
              width: 96,
              child: Text(pemT('energy.loadprofile.col_avg', 'Ort. kWh'),
                  textAlign: TextAlign.right, style: head)),
          SizedBox(
              width: 80,
              child: Text(pemT('energy.loadprofile.col_peak', 'Puant kW'),
                  textAlign: TextAlign.right, style: head)),
        ]),
        const Divider(height: AppSpacing.md),
        for (final p in points)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Row(children: [
              Expanded(
                child: Text(pemDowLabel(p.dow),
                    style: p.avgConsumptionKwh == maxAvg && maxAvg > 0
                        ? theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700)
                        : theme.textTheme.bodyMedium),
              ),
              SizedBox(
                  width: 96,
                  child: Text(pemNum(p.avgConsumptionKwh, decimals: 1),
                      textAlign: TextAlign.right)),
              SizedBox(
                  width: 80,
                  child: Text(pemNum(p.maxPeakDemandKw, decimals: 1),
                      textAlign: TextAlign.right)),
            ]),
          ),
      ],
    );
  }
}
