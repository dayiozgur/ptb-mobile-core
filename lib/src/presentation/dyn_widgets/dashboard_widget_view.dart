import 'package:flutter/material.dart';

import '../../core/dashboard/personal_dashboard_service.dart';
import '../../core/di/service_locator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/weather/weather_service.dart';
import 'dashboard_hr_widgets.dart';
import 'dyn_widgets.dart';

/// Kişisel-pano widget'ının **paylaşılan** görünüm-modu renderer'ı.
///
/// Hem [PersonalDashboardScreen] hem Ana Sayfa'daki gömülü pano bunu kullanır
/// (tek renderer → sapma yok). Desteklenen tipler: stat_card · chart_widget ·
/// data_table · heading · text_block (düzenlenebilir not) · divider · **weather**.
/// Bilinmeyen tip → gri kutu (çökme yok).
class DashboardWidgetView extends StatelessWidget {
  final DashboardWidgetDescriptor descriptor;

  /// Data-backed widget'lar (stat/chart/table) için önceden çözülen satırlar.
  final Future<List<Map<String, dynamic>>>? dataFuture;

  /// Data hatası sonrası yeniden dene.
  final VoidCallback? onRetry;

  /// Not (text_block) düzenlenebilir olsun mu — sağlanırsa yeni metinle çağrılır
  /// (çağıran taraf descriptor.config'i güncelleyip kaydeder). null → salt-okuma.
  final ValueChanged<String>? onNoteChanged;

  const DashboardWidgetView({
    super.key,
    required this.descriptor,
    this.dataFuture,
    this.onRetry,
    this.onNoteChanged,
  });

  static const double _chartHeight = 240;

  @override
  Widget build(BuildContext context) {
    switch (descriptor.type) {
      case 'stat_card':
        return _stat(context);
      case 'chart_widget':
        return _chart(context);
      case 'data_table':
        return _table(context);
      case 'heading':
        return _heading(context);
      case 'text_block':
        return _note(context);
      case 'divider':
        return const Divider();
      case 'weather':
        return WeatherTile(descriptor: descriptor);
      // ── PHR (İK) veri-bağlı widget'lar (gri kutu yerine gerçek veri) ──
      case 'profile_card':
        return ProfileCardTile(descriptor: descriptor);
      case 'leave_balance':
        return LeaveBalanceTile(descriptor: descriptor);
      case 'payslip_net':
        return PayslipNetTile(descriptor: descriptor);
      case 'pdks_today':
        return PdksTodayTile(descriptor: descriptor);
      case 'pending_approvals':
        return PendingApprovalsTile(descriptor: descriptor);
      case 'news_feed':
        return NewsFeedTile(descriptor: descriptor);
      case 'link_card':
        return LinkCardTile(descriptor: descriptor);
      default:
        return _staticBox(context);
    }
  }

  Widget _stat(BuildContext context) {
    final w = descriptor;
    final inline = w.config['value'];
    final mode = DynStatWidget.modeFromString(w.config['mode']?.toString());
    if (inline != null) {
      return DynWidgetCard(
        title: w.title,
        subtitle: w.subtitle,
        child: DynStatWidget([<String, dynamic>{'value': inline}], w.config,
            mode: mode),
      );
    }
    final future = dataFuture;
    if (future == null) {
      return DynWidgetCard(
        title: w.title,
        subtitle: w.subtitle,
        child: DynStatWidget(const [<String, dynamic>{'value': '—'}], w.config,
            mode: mode),
      );
    }
    return _dataCard(context, future,
        (rows) => DynStatWidget(rows, w.config, mode: mode));
  }

  Widget _chart(BuildContext context) {
    final future = dataFuture;
    if (future == null) return _staticBox(context);
    final chartKind = descriptor.config['chartType']?.toString() ?? 'bar_chart';
    return _dataCard(
      context,
      future,
      (rows) => SizedBox(
        height: _chartHeight,
        child: DynChartWidget(rows, descriptor.config, chartKind: chartKind),
      ),
    );
  }

  Widget _table(BuildContext context) {
    final future = dataFuture;
    if (future == null) return _staticBox(context);
    return _dataCard(context, future,
        (rows) => DynDataTableWidget(rows, descriptor.config));
  }

  Widget _dataCard(
    BuildContext context,
    Future<List<Map<String, dynamic>>> future,
    Widget Function(List<Map<String, dynamic>> rows) builder,
  ) {
    final w = descriptor;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return DynWidgetCard(
              title: w.title, subtitle: w.subtitle, loading: true);
        }
        if (snap.hasError) {
          return DynWidgetCard(
            title: w.title,
            subtitle: w.subtitle,
            error: 'Hata: ${snap.error}',
            onRetry: onRetry,
          );
        }
        final rows = snap.data ?? const <Map<String, dynamic>>[];
        return DynWidgetCard(
          title: w.title,
          subtitle: w.subtitle,
          child: builder(rows),
        );
      },
    );
  }

  Widget _heading(BuildContext context) {
    final text = descriptor.config['text']?.toString() ?? descriptor.title ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Text(
        text,
        style: AppTypography.withColor(AppTypography.title3,
            AppColors.textPrimary(Theme.of(context).brightness)),
      ),
    );
  }

  Widget _note(BuildContext context) {
    final w = descriptor;
    // Web `config.content` (HTML) veya mobil `config.text` — HTML etiketlerini
    // temizleyerek düz metin göster (web↔mobil round-trip).
    final raw = (w.config['text'] ?? w.config['content'] ?? w.subtitle ?? '')
        .toString();
    final text = _stripHtml(raw);
    final editable = onNoteChanged != null;
    final secondary = AppColors.textSecondary(Theme.of(context).brightness);
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            text.isEmpty ? 'Notunuzu buraya yazın…' : text,
            style: AppTypography.withColor(AppTypography.body, secondary),
          ),
        ),
        if (editable) ...[
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.edit_outlined, size: 18, color: secondary),
        ],
      ],
    );
    final card = DynWidgetCard(title: w.title, child: content);
    if (!editable) return card;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showNoteEditor(context, text, onNoteChanged!),
      child: card,
    );
  }

  Widget _staticBox(BuildContext context) {
    final w = descriptor;
    final label = w.config['text']?.toString() ??
        w.config['label']?.toString() ??
        w.title ??
        w.type;
    return DynWidgetCard(
      title: w.title,
      subtitle: w.subtitle,
      child: Text(
        label,
        style: AppTypography.withColor(AppTypography.body,
            AppColors.textSecondary(Theme.of(context).brightness)),
      ),
    );
  }

  static String _stripHtml(String s) =>
      s.replaceAll(RegExp(r'<[^>]*>'), '').trim();

  static Future<void> _showNoteEditor(
    BuildContext context,
    String current,
    ValueChanged<String> onSave,
  ) async {
    final controller = TextEditingController(text: current);
    final brightness = Theme.of(context).brightness;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background(brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.md,
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Not',
                style: AppTypography.withColor(AppTypography.headline,
                    AppColors.textPrimary(brightness))),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 5,
              minLines: 3,
              decoration: const InputDecoration(
                hintText: 'Notunuzu yazın…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(sheetCtx).maybePop(),
                  child: const Text('İptal'),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: () {
                    Navigator.of(sheetCtx).maybePop();
                    onSave(controller.text.trim());
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Hava durumu widget'ı — [WeatherService] (open-meteo) ile anlık veriyi çeker.
/// `config`: `{lat, lon, city}` (yoksa varsayılan İstanbul).
class WeatherTile extends StatefulWidget {
  final DashboardWidgetDescriptor descriptor;
  const WeatherTile({super.key, required this.descriptor});

  @override
  State<WeatherTile> createState() => _WeatherTileState();
}

class _WeatherTileState extends State<WeatherTile> {
  late Future<WeatherData> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<WeatherData> _fetch() {
    final cfg = widget.descriptor.config;
    return sl<WeatherService>().current(
      lat: (cfg['lat'] as num?)?.toDouble(),
      lon: (cfg['lon'] as num?)?.toDouble(),
      city: cfg['city']?.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.descriptor.title ?? 'Hava Durumu';
    return FutureBuilder<WeatherData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return DynWidgetCard(title: title, loading: true);
        }
        if (snap.hasError || !snap.hasData) {
          return DynWidgetCard(
            title: title,
            error: 'Hava durumu alınamadı',
            onRetry: () => setState(() => _future = _fetch()),
          );
        }
        final w = snap.data!;
        final brightness = Theme.of(context).brightness;
        return DynWidgetCard(
          title: title,
          child: Row(
            children: [
              Icon(WeatherService.conditionIcon(w.code),
                  size: 44, color: AppColors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${w.temperature.round()}°C',
                        style: AppTypography.withColor(AppTypography.title1,
                            AppColors.textPrimary(brightness))),
                    const SizedBox(height: 2),
                    Text('${w.condition} · ${w.city}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.withColor(AppTypography.footnote,
                            AppColors.textSecondary(brightness))),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
