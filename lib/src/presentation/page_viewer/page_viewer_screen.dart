import 'package:flutter/material.dart' hide FormField;
import 'package:protoolbag_core/protoolbag_core.dart';

/// Web builder'da tasarlanmış bir dashboard sayfasını (`pb_page_templates`)
/// yükleyip widget grid'ini render eden mobil görüntüleyici.
///
/// [pageCode] `pb_page_templates.code` değeridir. Şablon [PageService] ile
/// tenant/platform kapsamlı çözülür; her data-backed widget kendi
/// `dataSourceId` + `queryConfig` ile [ReportQueryService] üzerinden beslenir
/// ve [DynWidgetCard] içinde uygun dyn primitif (stat/chart/table) ile
/// gösterilir. Statik/layout widget'lar (heading, text, divider…) config'ten
/// inline render edilir.
///
/// Grid duyarlıdır: telefonda tek kolon yığın, geniş ekranda 12-kolon Wrap
/// (`grid_column: span N` oranını korur). Aşağı-çek yenile destekler.
class PageViewerScreen extends StatefulWidget {
  /// `pb_page_templates.code`.
  final String pageCode;

  const PageViewerScreen({super.key, required this.pageCode});

  @override
  State<PageViewerScreen> createState() => _PageViewerScreenState();
}

class _PageViewerScreenState extends State<PageViewerScreen> {
  /// Telefon/tablet kırılma noktası (px).
  static const double _wideBreakpoint = 600;

  bool _isLoading = true;
  String? _errorMessage;
  PageTemplate? _template;

  /// Data-backed widget'lar için tek-sefer çözülen future'lar (widget kodu →).
  final Map<String, Future<List<Map<String, dynamic>>>> _widgetData = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _t(String key) => sl<LocalizationService>().translate(key);

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final template = await sl<PageService>().getByCode(
        widget.pageCode,
        platformId: sl<PlatformContext>().activePlatformId,
      );

      _widgetData.clear();
      if (template != null) {
        for (final w in template.widgets) {
          if (_isDataBacked(w)) {
            _widgetData[w.code] = sl<ReportQueryService>().runWidget(
              dataSourceId: w.dataSourceId!,
              queryConfig: w.queryConfig,
            );
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _template = template;
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('PageViewerScreen yükleme başarısız (${widget.pageCode})', e);
      if (!mounted) return;
      setState(() {
        _errorMessage = '${_t('common.error')}: $e';
        _isLoading = false;
      });
    }
  }

  /// Widget'ın `report-query` ile veri çekmesi gerekiyor mu?
  bool _isDataBacked(PageWidget w) {
    final ds = w.dataSourceId;
    if (ds == null || ds.isEmpty) return false;
    switch (w.widgetType) {
      case 'chart_widget':
      case 'data_table':
        return true;
      case 'stat_card':
        // Inline değer varsa fetch gerekmez.
        return w.config['value'] == null;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final template = _template;
    final title = template?.headerTitle ?? template?.name ?? widget.pageCode;

    return AppScaffold(
      title: title,
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _load),
      ],
      child: RefreshIndicator(
        onRefresh: _load,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: AppLoadingIndicator());
    }

    if (_errorMessage != null) {
      return _scrollableCenter(
        AppErrorView(message: _errorMessage!, onRetry: _load),
      );
    }

    final template = _template;
    if (template == null) {
      return _scrollableCenter(
        AppEmptyState(
          icon: Icons.web_asset_off_outlined,
          title: _t('common.no_records'),
        ),
      );
    }

    if (template.widgets.isEmpty) {
      return _scrollableCenter(
        AppEmptyState(
          icon: Icons.dashboard_customize_outlined,
          title: _t('common.no_records'),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (template.headerSubtitle != null &&
              template.headerSubtitle!.isNotEmpty) ...[
            Text(
              template.headerSubtitle!,
              style: AppTypography.withColor(
                AppTypography.subhead,
                AppColors.textSecondary(Theme.of(context).brightness),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _buildGrid(template),
        ],
      ),
    );
  }

  /// Boş/hata durumları için ortalanmış, kaydırılabilir (pull-to-refresh) kap.
  Widget _scrollableCenter(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }

  /// Duyarlı widget grid'i.
  ///
  /// Telefon: tek kolon yığın. Geniş: 12-kolon Wrap; her widget genişliği
  /// `grid_column: span N` oranına göre hesaplanır.
  Widget _buildGrid(PageTemplate template) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        const gap = AppSpacing.md;

        if (maxWidth < _wideBreakpoint) {
          // Tek kolon yığın.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final w in template.widgets) ...[
                _buildWidget(w),
                const SizedBox(height: gap),
              ],
            ],
          );
        }

        final columns = template.layoutColumns <= 0 ? 12 : template.layoutColumns;
        final unitWidth = (maxWidth - (columns - 1) * gap) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final w in template.widgets)
              SizedBox(
                width: _spanWidth(w, columns, unitWidth, gap, maxWidth),
                child: _buildWidget(w),
              ),
          ],
        );
      },
    );
  }

  double _spanWidth(
    PageWidget w,
    int columns,
    double unitWidth,
    double gap,
    double maxWidth,
  ) {
    final span = w.spanColumns(columns);
    final width = unitWidth * span + (span - 1) * gap;
    // Taşmayı önle.
    return width.clamp(0, maxWidth);
  }

  // ---------------------------------------------------------------------------
  // Widget-type çözümleme
  // ---------------------------------------------------------------------------

  Widget _buildWidget(PageWidget w) {
    switch (w.widgetType) {
      case 'stat_card':
        return _buildStat(w);
      case 'chart_widget':
        return _buildChart(w);
      case 'data_table':
        return _buildTable(w);
      case 'heading':
        return _buildHeading(w);
      case 'text_block':
        return _buildText(w);
      case 'divider':
        return const Divider();
      case 'spacer':
        return SizedBox(height: _minHeightPx(w) ?? AppSpacing.lg);
      case 'report_embed':
        return _buildReportEmbed(w);
      case 'entity_list':
        return _buildPlaceholder(w, _t('common.no_records'));
      case 'link_card':
      case 'button':
      case 'image':
      case 'card':
      case 'container':
      case 'status_badge':
      case 'filter_bar':
      case 'tabs':
        return _buildStaticBox(w);
      default:
        return _buildPlaceholder(w, w.widgetType);
    }
  }

  Widget _buildStat(PageWidget w) {
    // Inline değer → fetch yok.
    final inlineValue = w.config['value'];
    if (inlineValue != null) {
      return DynWidgetCard(
        title: w.title,
        subtitle: w.subtitle,
        child: DynStatWidget(
          [<String, dynamic>{'value': inlineValue}],
          w.config,
          mode: DynStatWidget.modeFromString(w.config['mode']?.toString()),
        ),
      );
    }

    final future = _widgetData[w.code];
    if (future == null) {
      // dataSourceId/value yok (ör. entity_count) → placeholder.
      return DynWidgetCard(
        title: w.title,
        subtitle: w.subtitle,
        child: DynStatWidget(
          const [<String, dynamic>{'value': '—'}],
          w.config,
          mode: DynStatWidget.modeFromString(w.config['mode']?.toString()),
        ),
      );
    }

    return _dataCard(
      w,
      future,
      (rows) => DynStatWidget(
        rows,
        w.config,
        mode: DynStatWidget.modeFromString(w.config['mode']?.toString()),
      ),
    );
  }

  Widget _buildChart(PageWidget w) {
    final future = _widgetData[w.code];
    if (future == null) {
      return _buildPlaceholder(w, w.widgetType);
    }
    final chartKind = w.config['chartType']?.toString() ?? 'bar_chart';
    return _dataCard(
      w,
      future,
      (rows) => DynChartWidget(rows, w.config, chartKind: chartKind),
    );
  }

  Widget _buildTable(PageWidget w) {
    final future = _widgetData[w.code];
    if (future == null) {
      return _buildPlaceholder(w, w.widgetType);
    }
    return _dataCard(
      w,
      future,
      (rows) => DynDataTableWidget(rows, w.config),
    );
  }

  /// Data-backed widget'ı [DynWidgetCard] + [FutureBuilder] ile sarar.
  Widget _dataCard(
    PageWidget w,
    Future<List<Map<String, dynamic>>> future,
    Widget Function(List<Map<String, dynamic>> rows) builder,
  ) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return DynWidgetCard(
            title: w.title,
            subtitle: w.subtitle,
            loading: true,
          );
        }
        if (snap.hasError) {
          return DynWidgetCard(
            title: w.title,
            subtitle: w.subtitle,
            error: '${_t('common.error')}: ${snap.error}',
            onRetry: _load,
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

  Widget _buildHeading(PageWidget w) {
    final text = w.config['text']?.toString() ?? w.title ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Text(
        text,
        style: AppTypography.withColor(
          AppTypography.title3,
          AppColors.textPrimary(Theme.of(context).brightness),
        ),
      ),
    );
  }

  Widget _buildText(PageWidget w) {
    final text = w.config['text']?.toString() ?? w.subtitle ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Text(
        text,
        style: AppTypography.withColor(
          AppTypography.body,
          AppColors.textSecondary(Theme.of(context).brightness),
        ),
      ),
    );
  }

  Widget _buildReportEmbed(PageWidget w) {
    final reportCode =
        w.config['reportCode']?.toString() ?? w.config['reportId']?.toString();
    return DynWidgetCard(
      title: w.title,
      subtitle: w.subtitle,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.assessment_outlined),
        title: Text('${_t('common.report')}: ${reportCode ?? '—'}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {}, // Entegrasyonda rota bağlanır (report viewer).
      ),
    );
  }

  Widget _buildStaticBox(PageWidget w) {
    final label = w.config['text']?.toString() ??
        w.config['label']?.toString() ??
        w.title ??
        w.widgetType;
    return DynWidgetCard(
      title: w.title,
      subtitle: w.subtitle,
      child: Text(
        label,
        style: AppTypography.withColor(
          AppTypography.body,
          AppColors.textSecondary(Theme.of(context).brightness),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(PageWidget w, String hint) {
    return DynWidgetCard(
      title: w.title ?? w.code,
      subtitle: w.subtitle,
      child: Row(
        children: [
          Icon(
            Icons.widgets_outlined,
            size: AppSpacing.iconSizeSm,
            color: AppColors.textSecondary(Theme.of(context).brightness),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              hint,
              style: AppTypography.withColor(
                AppTypography.footnote,
                AppColors.textSecondary(Theme.of(context).brightness),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// `min_height` string'inden (ör. `'200px'`) px değeri çözer.
  double? _minHeightPx(PageWidget w) {
    final raw = w.minHeight;
    if (raw == null) return null;
    final match = RegExp(r'(\d+)').firstMatch(raw);
    if (match == null) return null;
    return double.tryParse(match.group(1)!);
  }
}
