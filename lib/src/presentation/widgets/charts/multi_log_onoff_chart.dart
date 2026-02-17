import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/iot_log/iot_log_stats_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import 'multi_log_line_chart.dart';

/// Çoklu digital variable'ı tek bir chart'ta gösteren On/Off widget
///
/// Her variable kendi satırında (band) gösterilir.
/// ON durumu dolgu rengi ile, OFF durumu boş/şeffaf ile ifade edilir.
/// Kompresör on/off durumlarını karşılaştırmalı görmek için idealdir.
class MultiLogOnOffChart extends StatelessWidget {
  final List<VariableTimeSeries> seriesList;
  final double rowHeight;
  final Color onColor;
  final Color offColor;

  const MultiLogOnOffChart({
    super.key,
    required this.seriesList,
    this.rowHeight = 36,
    this.onColor = AppColors.success,
    this.offColor = AppColors.systemGray4,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    // Veri olan serileri filtrele
    final validSeries = seriesList.where((s) {
      final onOffEntries = s.entries.where((e) => e.hasOnOff).toList();
      return onOffEntries.length >= 2;
    }).toList();

    if (validSeries.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text(
            'On/Off verisi bulunamadi',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary(brightness)),
          ),
        ),
      );
    }

    // Global zaman aralığı
    int globalFirst = double.maxFinite.toInt();
    int globalLast = 0;
    for (final s in validSeries) {
      final onOff = s.entries.where((e) => e.hasOnOff).toList();
      final ft = onOff.first.dateTime.millisecondsSinceEpoch;
      final lt = onOff.last.dateTime.millisecondsSinceEpoch;
      if (ft < globalFirst) globalFirst = ft;
      if (lt > globalLast) globalLast = lt;
    }
    final totalMs = (globalLast - globalFirst).toDouble();
    if (totalMs <= 0) return const SizedBox.shrink();

    // ON yüzdelerini hesapla
    final onPercentages = <String, double>{};
    for (final s in validSeries) {
      final data = s.entries.where((e) => e.hasOnOff).toList();
      Duration onDur = Duration.zero;
      Duration totalDur = Duration.zero;
      for (var i = 0; i < data.length - 1; i++) {
        final diff = data[i + 1].dateTime.difference(data[i].dateTime);
        totalDur += diff;
        if (data[i].onOff == 1) onDur += diff;
      }
      onPercentages[s.variableId] = totalDur.inMilliseconds > 0
          ? onDur.inMilliseconds / totalDur.inMilliseconds * 100
          : 0;
    }

    // Zaman etiketi formatı
    final timeFormat = totalMs > const Duration(days: 3).inMilliseconds
        ? DateFormat('dd/MM')
        : totalMs > const Duration(hours: 12).inMilliseconds
            ? DateFormat('dd HH:mm')
            : DateFormat('HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Satır bazlı ON/OFF bandları
        ...validSeries.asMap().entries.map((entry) {
          final index = entry.key;
          final series = entry.value;
          final data = series.entries.where((e) => e.hasOnOff).toList();
          final pct = onPercentages[series.variableId] ?? 0;
          final lastState = data.last.onOff == 1;

          return Padding(
            padding: EdgeInsets.only(bottom: index < validSeries.length - 1 ? 4 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Variable adı + durum + yüzde
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      // Renk göstergesi
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: series.color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Variable adı
                      Expanded(
                        child: Text(
                          series.variableName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(brightness),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Son durum
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: (lastState ? onColor : offColor).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: lastState ? onColor : offColor,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          lastState ? 'ON' : 'OFF',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: lastState ? onColor : offColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // ON yüzdesi
                      Text(
                        '%${pct.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: onColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // ON/OFF bant çizimi
                SizedBox(
                  height: rowHeight,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return CustomPaint(
                        size: Size(constraints.maxWidth, rowHeight),
                        painter: _OnOffBandPainter(
                          data: data,
                          globalFirstMs: globalFirst,
                          totalMs: totalMs,
                          onColor: series.color,
                          offColor: brightness == Brightness.light
                              ? AppColors.systemGray6
                              : AppColors.systemGray5,
                          borderColor: AppColors.divider(brightness),
                          borderRadius: 4,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 6),

        // Alt zaman ekseni
        SizedBox(
          height: 20,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              const labelCount = 5;
              return Stack(
                children: List.generate(labelCount, (i) {
                  if (i == 0 || i == labelCount - 1) return const SizedBox.shrink();
                  final ratio = i / (labelCount - 1);
                  final ms = globalFirst + (totalMs * ratio).toInt();
                  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
                  final left = ratio * width;
                  return Positioned(
                    left: left - 25,
                    child: SizedBox(
                      width: 50,
                      child: Text(
                        timeFormat.format(dt),
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary(brightness),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // Özet - toplam ON yüzdesi
        _buildSummaryRow(brightness, validSeries, onPercentages),
      ],
    );
  }

  Widget _buildSummaryRow(
    Brightness brightness,
    List<VariableTimeSeries> series,
    Map<String, double> onPercentages,
  ) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      alignment: WrapAlignment.center,
      children: series.map((s) {
        final pct = onPercentages[s.variableId] ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: s.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(
                '${s.variableName}: %${pct.toStringAsFixed(1)} ON',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: s.color,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// ON/OFF bandını çizen CustomPainter
///
/// Her veri noktası arasındaki zaman dilimini ON (renkli) veya OFF (gri) olarak boyar.
class _OnOffBandPainter extends CustomPainter {
  final List<LogTimeSeriesEntry> data;
  final int globalFirstMs;
  final double totalMs;
  final Color onColor;
  final Color offColor;
  final Color borderColor;
  final double borderRadius;

  _OnOffBandPainter({
    required this.data,
    required this.globalFirstMs,
    required this.totalMs,
    required this.onColor,
    required this.offColor,
    required this.borderColor,
    this.borderRadius = 4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Arka plan çiz (border ile rounded rect)
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );
    canvas.drawRRect(bgRect, Paint()..color = offColor);
    canvas.drawRRect(bgRect, borderPaint);

    // ON bölgelerini çiz
    canvas.save();
    canvas.clipRRect(bgRect);

    for (var i = 0; i < data.length - 1; i++) {
      if (data[i].onOff != 1) continue;

      final startMs = data[i].dateTime.millisecondsSinceEpoch - globalFirstMs;
      final endMs = data[i + 1].dateTime.millisecondsSinceEpoch - globalFirstMs;

      final x1 = (startMs / totalMs) * size.width;
      final x2 = (endMs / totalMs) * size.width;

      final paint = Paint()..color = onColor.withValues(alpha: 0.7);
      canvas.drawRect(Rect.fromLTWH(x1, 0, x2 - x1, size.height), paint);
    }

    // Son veri noktası ON ise, son bölgeyi çiz
    if (data.last.onOff == 1) {
      final startMs = data.last.dateTime.millisecondsSinceEpoch - globalFirstMs;
      final x1 = (startMs / totalMs) * size.width;
      final paint = Paint()..color = onColor.withValues(alpha: 0.7);
      canvas.drawRect(Rect.fromLTWH(x1, 0, size.width - x1, size.height), paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OnOffBandPainter oldDelegate) {
    return data != oldDelegate.data ||
        onColor != oldDelegate.onColor ||
        totalMs != oldDelegate.totalMs;
  }
}
