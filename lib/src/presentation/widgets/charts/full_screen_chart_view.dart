import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../feedback/app_loading_indicator.dart';
import 'multi_log_line_chart.dart';
import 'multi_log_onoff_chart.dart';

/// Landscape modda tam ekran grafik goruntuleme widget'i.
///
/// Analog/Integer seriler ustte, digital seriler altta gosterilir.
/// TradingView/Bloomberg benzeri borsa yazilimi deneyimi sunar.
/// Analog grafik üzerinde gezinirken digital chart'ta senkron crosshair gösterilir.
class FullScreenChartView extends StatefulWidget {
  final List<VariableTimeSeries> analogSeries;
  final List<VariableTimeSeries> digitalSeries;
  final String? subtitle;
  final VoidCallback? onClose;
  final bool isLoading;

  const FullScreenChartView({
    super.key,
    required this.analogSeries,
    required this.digitalSeries,
    this.subtitle,
    this.onClose,
    this.isLoading = false,
  });

  @override
  State<FullScreenChartView> createState() => _FullScreenChartViewState();
}

class _FullScreenChartViewState extends State<FullScreenChartView> {
  DateTime? _crosshairTime;

  void _handleClose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    Future.delayed(const Duration(milliseconds: 300), () {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    });
    widget.onClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgColor = brightness == Brightness.dark
        ? const Color(0xFF0A0A0A)
        : const Color(0xFF1C1C1E);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Ana icerik
            if (widget.isLoading)
              const Center(child: AppLoadingIndicator())
            else
              _buildChartContent(brightness),

            // Ust kontroller
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  // Subtitle
                  if (widget.subtitle != null)
                    Expanded(
                      child: Text(
                        widget.subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    const Spacer(),

                  // Close button
                  GestureDetector(
                    onTap: _handleClose,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartContent(Brightness brightness) {
    final hasAnalog = widget.analogSeries.isNotEmpty;
    final hasDigital = widget.digitalSeries.isNotEmpty;

    if (!hasAnalog && !hasDigital) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app, size: 36, color: Colors.white.withValues(alpha: 0.4)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Grafik icin variable secin',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 44, left: 8, right: 8, bottom: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalHeight = constraints.maxHeight;

          if (hasAnalog && hasDigital) {
            // Ikisi de var: analog %60, digital %40
            final analogHeight = (totalHeight * 0.58).clamp(100.0, totalHeight - 80);
            const dividerHeight = 12.0;
            final digitalHeight = totalHeight - analogHeight - dividerHeight;
            final digitalRowCount = widget.digitalSeries.length.clamp(1, 4);
            final digitalRowHeight = ((digitalHeight - (digitalRowCount * 24)) / digitalRowCount)
                .clamp(16.0, 40.0);

            return Column(
              children: [
                Expanded(
                  flex: 3,
                  child: MultiLogLineChart(
                    seriesList: widget.analogSeries,
                    height: analogHeight,
                    showLegend: widget.analogSeries.length > 1,
                    onTouchTime: (time) {
                      setState(() => _crosshairTime = time);
                    },
                  ),
                ),
                Divider(
                  height: dividerHeight,
                  thickness: 0.5,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                Expanded(
                  flex: 2,
                  child: MultiLogOnOffChart(
                    seriesList: widget.digitalSeries,
                    rowHeight: digitalRowHeight,
                    crosshairTime: _crosshairTime,
                  ),
                ),
              ],
            );
          }

          if (hasAnalog) {
            return MultiLogLineChart(
              seriesList: widget.analogSeries,
              height: totalHeight,
              showLegend: widget.analogSeries.length > 1,
            );
          }

          // Sadece digital
          final digitalRowCount = widget.digitalSeries.length.clamp(1, 4);
          final digitalRowHeight = ((totalHeight - (digitalRowCount * 24)) / digitalRowCount)
              .clamp(20.0, 50.0);

          return MultiLogOnOffChart(
            seriesList: widget.digitalSeries,
            rowHeight: digitalRowHeight,
          );
        },
      ),
    );
  }
}
