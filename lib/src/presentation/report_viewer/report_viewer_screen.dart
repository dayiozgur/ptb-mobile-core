import 'package:flutter/material.dart' hide FormField;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:protoolbag_core/protoolbag_core.dart';

/// Web builder'ında tasarlanmış bir `dr_report_templates` kaydını yükleyip
/// widget'larını mobilde salt-okuma render eden viewer.
///
/// [reportCode] veya [reportId] ile açılır (en az biri). Şablon
/// [ReportService] ile çözülür; her widget kendi `data_source_id` +
/// `query_config` + geçerli global filtre değerleriyle `ReportQueryService`
/// üzerinden bağımsız çözülür ve uygun dinamik primitife dağıtılır.
///
/// Rota bağlaması entegrasyon anında `screen_resolver` tarafında yapılır — bu
/// ekran onu import ETMEZ.
class ReportViewerScreen extends StatefulWidget {
  /// `dr_report_templates.code`.
  final String? reportCode;

  /// `dr_report_templates.id`.
  final String? reportId;

  const ReportViewerScreen({
    super.key,
    this.reportCode,
    this.reportId,
  });

  @override
  State<ReportViewerScreen> createState() => _ReportViewerScreenState();
}

class _ReportViewerScreenState extends State<ReportViewerScreen> {
  bool _loading = true;
  String? _error;
  ReportTemplate? _template;

  /// Global filtrelerin geçerli değerleri (widget sorgularına geçilir).
  final Map<String, dynamic> _filterValues = <String, dynamic>{};

  /// Her artışta tüm widget'lar yeniden çözülür (Uygula / pull-to-refresh).
  int _reloadTick = 0;

  /// CSV dışa aktarım devam ediyor (buton geçici olarak devre dışı).
  bool _exporting = false;

  // Desteklenen widget tipleri.
  static const Set<String> _statTypes = {'stat_card', 'gauge', 'progress'};
  static const Set<String> _chartTypes = {
    'bar_chart',
    'horizontal_bar',
    'stacked_bar',
    'line_chart',
    'area_chart',
    'pie_chart',
    'donut_chart',
    'scatter_chart',
  };

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  Future<void> _loadTemplate() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      ReportTemplate? template;
      if (widget.reportId != null && widget.reportId!.isNotEmpty) {
        template = await reportService.getById(widget.reportId!);
      } else if (widget.reportCode != null && widget.reportCode!.isNotEmpty) {
        template = await reportService.getByCode(widget.reportCode!);
      } else {
        throw Exception('reportCode veya reportId gerekli');
      }

      if (!mounted) return;

      if (template == null) {
        setState(() {
          _loading = false;
          _template = null;
          _error = null;
        });
        return;
      }

      _seedFilterValues(template);

      setState(() {
        _template = template;
        _loading = false;
      });
    } catch (e) {
      Logger.error('ReportViewerScreen şablon yükleme başarısız', e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _extractMessage(e);
      });
    }
  }

  /// Filtre değerlerini tanımların `defaultValue`'larından tohumlar.
  void _seedFilterValues(ReportTemplate template) {
    _filterValues.clear();
    for (final f in template.globalFilters) {
      if (f.fieldType == 'daterange') {
        final def = f.defaultValue;
        if (def is Map) {
          final from = def['from'] ?? def['start'];
          final to = def['to'] ?? def['end'];
          if (from != null) _filterValues['${f.code}_from'] = from;
          if (to != null) _filterValues['${f.code}_to'] = to;
        }
      } else if (f.defaultValue != null) {
        _filterValues[f.code] = f.defaultValue;
      }
    }
  }

  void _applyFilters() {
    FocusScope.of(context).unfocus();
    setState(() => _reloadTick++);
  }

  Future<void> _refreshAll() async {
    setState(() => _reloadTick++);
  }

  String _extractMessage(Object e) {
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }

  // ============================================
  // CSV DIŞA AKTARIM
  // ============================================

  /// Raporun tablo verisini CSV'ye çevirip panoya kopyalar.
  ///
  /// `share_plus` bağımlılığı projede yok → SnackBar ile bilgilendirilen
  /// pano-kopyalama geri dönüşü kullanılır. Öncelik `data_table` widget'ları;
  /// yoksa desteklenen tüm veri widget'ları. Sorgular dışa aktarım anında
  /// mevcut filtre değerleriyle yeniden çözülür.
  Future<void> _exportCsv() async {
    final template = _template;
    if (template == null) return;

    final tables =
        template.widgets.where((w) => w.widgetType == 'data_table').toList();
    final targets = tables.isNotEmpty
        ? tables
        : template.widgets.where((w) => _isSupported(w.widgetType)).toList();

    if (targets.isEmpty) {
      _showSnack('Dışa aktarılacak veri yok');
      return;
    }

    setState(() => _exporting = true);
    try {
      final blocks = <String>[];
      for (final w in targets) {
        final rows = await reportQueryService.runWidget(
          dataSourceId: w.dataSourceId,
          queryConfig: w.queryConfig,
          filterValues: Map<String, dynamic>.from(_filterValues),
        );
        final csv = _buildCsv(w, rows);
        if (csv.isNotEmpty) blocks.add(csv);
      }

      final out = blocks.join('\n\n');
      if (!mounted) return;
      if (out.trim().isEmpty) {
        _showSnack('Dışa aktarılacak veri yok');
        return;
      }

      await Clipboard.setData(ClipboardData(text: out));
      if (!mounted) return;
      _showSnack('Rapor panoya kopyalandı (CSV)');
    } catch (e) {
      Logger.error('ReportViewerScreen CSV dışa aktarım başarısız', e);
      if (!mounted) return;
      _showSnack('Dışa aktarma başarısız: ${_extractMessage(e)}');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Tek bir widget'ın satırlarından CSV metni üretir (başlık + gövde).
  String _buildCsv(ReportWidget w, List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return '';

    // Kolonlar: visualConfig.columns varsa onu, yoksa satır anahtar birleşimi.
    final configured = <String>[];
    final raw = w.visualConfig['columns'];
    if (raw is List) {
      for (final c in raw) {
        final s = c.toString();
        if (s.isNotEmpty) configured.add(s);
      }
    }
    final columns = configured.isNotEmpty ? configured : _unionKeys(rows);
    if (columns.isEmpty) return '';

    final labels = w.visualConfig['columnLabels'];
    final header = columns.map((c) {
      final label = (labels is Map && labels[c] != null) ? labels[c] : c;
      return _csvEscape(label.toString());
    }).join(',');

    final body = rows.map((row) {
      return columns.map((c) => _csvEscape(_csvCell(row[c]))).join(',');
    }).join('\n');

    return '$header\n$body';
  }

  /// Tüm satırların anahtarlarını ilk-görülme sırasıyla birleştirir.
  List<String> _unionKeys(List<Map<String, dynamic>> rows) {
    final keys = <String>[];
    for (final row in rows) {
      for (final k in row.keys) {
        if (!keys.contains(k)) keys.add(k);
      }
    }
    return keys;
  }

  /// Ham hücre değerini CSV metnine çevirir (biçimlendirmeden).
  String _csvCell(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  /// Tırnak/virgül/yeni-satır içeren alanları RFC-4180'e göre kaçışlar.
  String _csvEscape(String value) {
    if (value.contains('"') ||
        value.contains(',') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasWidgets = _template != null && _template!.widgets.isNotEmpty;
    return AppScaffold(
      title: _template?.name ?? 'Rapor',
      actions: hasWidgets
          ? [
              IconButton(
                icon: const Icon(Icons.ios_share),
                tooltip: 'Dışa Aktar',
                color: AppColors.primary,
                onPressed: _exporting ? null : _exportCsv,
              ),
            ]
          : null,
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const AppLoadingIndicator(
        centered: true,
        message: 'Rapor yükleniyor…',
      );
    }

    if (_error != null) {
      return AppErrorView(
        message: _error!,
        onRetry: _loadTemplate,
        fullScreen: true,
      );
    }

    final template = _template;
    if (template == null) {
      return const AppEmptyState(
        icon: Icons.assessment_outlined,
        title: 'Rapor bulunamadı',
        message: 'Bu rapor yayınlanmamış olabilir ya da erişiminiz yok.',
      );
    }

    if (template.widgets.isEmpty) {
      return const AppEmptyState(
        icon: Icons.widgets_outlined,
        title: 'Bu raporda görüntülenecek widget yok',
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (template.description != null) ...[
                Text(
                  template.description!,
                  style: AppTypography.withColor(
                    AppTypography.subhead,
                    AppColors.textSecondary(Theme.of(context).brightness),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (template.globalFilters.isNotEmpty) ...[
                _buildFilterBar(template),
                const SizedBox(height: AppSpacing.md),
              ],
              _buildGrid(template, constraints.maxWidth),
            ],
          );
        },
      ),
    );
  }

  // ============================================
  // GLOBAL FILTER BAR
  // ============================================

  Widget _buildFilterBar(ReportTemplate template) {
    final brightness = Theme.of(context).brightness;
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Filtreler',
            style: AppTypography.withColor(
              AppTypography.headline,
              AppColors.textPrimary(brightness),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...template.globalFilters.map(_buildFilterInput),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: 'Uygula',
              icon: Icons.filter_alt_outlined,
              size: AppButtonSize.small,
              onPressed: _applyFilters,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterInput(ReportGlobalFilter filter) {
    Widget field;
    switch (filter.fieldType) {
      case 'number':
        field = AppTextField(
          label: filter.label,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          controller: TextEditingController(
            text: _filterValues[filter.code]?.toString() ?? '',
          ),
          onChanged: (v) {
            if (v.trim().isEmpty) {
              _filterValues.remove(filter.code);
            } else {
              _filterValues[filter.code] = num.tryParse(v.trim()) ?? v.trim();
            }
          },
        );
        break;
      case 'select':
        field = AppDropdown<String>(
          label: filter.label,
          value: _filterValues[filter.code]?.toString(),
          items: _selectItems(filter),
          onChanged: (v) {
            if (v == null) {
              _filterValues.remove(filter.code);
            } else {
              _filterValues[filter.code] = v;
            }
          },
        );
        break;
      case 'date':
        field = AppDatePicker(
          label: filter.label,
          value: _parseDate(_filterValues[filter.code]),
          onChanged: (d) {
            if (d == null) {
              _filterValues.remove(filter.code);
            } else {
              _filterValues[filter.code] = _formatDate(d);
            }
          },
        );
        break;
      case 'daterange':
        field = Row(
          children: [
            Expanded(
              child: AppDatePicker(
                label: '${filter.label} (başl.)',
                value: _parseDate(_filterValues['${filter.code}_from']),
                onChanged: (d) {
                  if (d == null) {
                    _filterValues.remove('${filter.code}_from');
                  } else {
                    _filterValues['${filter.code}_from'] = _formatDate(d);
                  }
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppDatePicker(
                label: '${filter.label} (bit.)',
                value: _parseDate(_filterValues['${filter.code}_to']),
                onChanged: (d) {
                  if (d == null) {
                    _filterValues.remove('${filter.code}_to');
                  } else {
                    _filterValues['${filter.code}_to'] = _formatDate(d);
                  }
                },
              ),
            ),
          ],
        );
        break;
      case 'text':
      default:
        field = AppTextField(
          label: filter.label,
          controller: TextEditingController(
            text: _filterValues[filter.code]?.toString() ?? '',
          ),
          onChanged: (v) {
            if (v.trim().isEmpty) {
              _filterValues.remove(filter.code);
            } else {
              _filterValues[filter.code] = v.trim();
            }
          },
        );
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: field,
    );
  }

  List<AppDropdownItem<String>> _selectItems(ReportGlobalFilter filter) {
    return filter.options.map((opt) {
      if (opt is Map) {
        final value =
            (opt['value'] ?? opt['code'] ?? opt['id'] ?? '').toString();
        final label =
            (opt['label'] ?? opt['name'] ?? opt['title'] ?? value).toString();
        return AppDropdownItem<String>(value: value, label: label);
      }
      final s = opt.toString();
      return AppDropdownItem<String>(value: s, label: s);
    }).toList();
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  String _formatDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  // ============================================
  // WIDGET GRID
  // ============================================

  Widget _buildGrid(ReportTemplate template, double maxWidth) {
    final isPhone = maxWidth < 600;
    const gap = AppSpacing.md;

    if (isPhone) {
      // Telefon: tek sütun yığın.
      final children = <Widget>[];
      for (final w in template.widgets) {
        children.add(_widgetCell(w, double.infinity));
        children.add(const SizedBox(height: gap));
      }
      if (children.isNotEmpty) children.removeLast();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    // Geniş ekran: 12-kolon Wrap, her widget span N/12 genişlik.
    final columns = template.layoutColumns <= 0 ? 12 : template.layoutColumns;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: template.widgets.map((w) {
        final span = w.spanColumns.clamp(1, columns);
        final fraction = span / columns;
        // spacing için küçük pay bırak → satır taşmasını önle.
        final width = (maxWidth * fraction) - gap;
        return SizedBox(
          width: width < 120 ? 120 : width,
          child: _widgetCell(w, width),
        );
      }).toList(),
    );
  }

  Widget _widgetCell(ReportWidget w, double width) {
    final cell = _ReportWidgetCell(
      key: ValueKey('${w.code}_$_reloadTick'),
      widget: w,
      filterValues: Map<String, dynamic>.from(_filterValues),
      supported: _isSupported(w.widgetType),
      buildChild: _buildWidgetChild,
    );

    final minHeight = w.minHeight;
    if (minHeight != null && minHeight > 0) {
      return ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight.toDouble()),
        child: cell,
      );
    }
    return cell;
  }

  bool _isSupported(String type) {
    return _statTypes.contains(type) ||
        _chartTypes.contains(type) ||
        type == 'data_table';
  }

  /// widget_type → uygun dinamik primitif.
  Widget _buildWidgetChild(ReportWidget w, List<Map<String, dynamic>> rows) {
    final type = w.widgetType;
    if (_statTypes.contains(type)) {
      return DynStatWidget(
        rows,
        w.visualConfig,
        mode: DynStatWidget.modeFromString(type),
      );
    }
    if (_chartTypes.contains(type)) {
      return DynChartWidget(rows, w.visualConfig, chartKind: type);
    }
    if (type == 'data_table') {
      return DynDataTableWidget(rows, w.visualConfig);
    }
    // Desteklenmeyen (echarts kinds / pivot / timeline …).
    return _unsupportedPlaceholder();
  }

  Widget _unsupportedPlaceholder() {
    return Builder(
      builder: (context) {
        final textSecondary =
            AppColors.textSecondary(Theme.of(context).brightness);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline,
                  size: AppSpacing.iconSizeSm, color: textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  'Bu widget mobilde desteklenmiyor',
                  style: AppTypography.withColor(
                    AppTypography.footnote,
                    textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Tek bir rapor widget'ının hücresi — kendi veri Future'ını tutar.
///
/// Veri [ReportQueryService.runWidget] ile çözülür; yükleniyor/hata(tekrar-dene)
/// /boş durumları [DynWidgetCard] içinde gösterilir. `key` içindeki reloadTick
/// değişince yeni bir hücre oluşturulup sorgu baştan çalışır.
class _ReportWidgetCell extends StatefulWidget {
  final ReportWidget widget;
  final Map<String, dynamic> filterValues;
  final bool supported;
  final Widget Function(ReportWidget, List<Map<String, dynamic>>) buildChild;

  const _ReportWidgetCell({
    super.key,
    required this.widget,
    required this.filterValues,
    required this.supported,
    required this.buildChild,
  });

  @override
  State<_ReportWidgetCell> createState() => _ReportWidgetCellState();
}

class _ReportWidgetCellState extends State<_ReportWidgetCell> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _run();
  }

  Future<List<Map<String, dynamic>>> _run() {
    // Desteklenmeyen tipler için veri çekme — boş satır listesi yeterli.
    if (!widget.supported) {
      return Future<List<Map<String, dynamic>>>.value(
        const <Map<String, dynamic>>[],
      );
    }
    return reportQueryService.runWidget(
      dataSourceId: widget.widget.dataSourceId,
      queryConfig: widget.widget.queryConfig,
      filterValues: widget.filterValues,
    );
  }

  void _retry() {
    setState(() => _future = _run());
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.widget;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return DynWidgetCard(
            title: w.title,
            subtitle: w.subtitle,
            loading: true,
          );
        }

        if (snapshot.hasError) {
          return DynWidgetCard(
            title: w.title,
            subtitle: w.subtitle,
            error: _message(snapshot.error!),
            onRetry: _retry,
          );
        }

        final rows = snapshot.data ?? const <Map<String, dynamic>>[];

        if (!widget.supported) {
          // Desteklenmeyen widget: placeholder child, footer yok.
          return DynWidgetCard(
            title: w.title,
            subtitle: w.subtitle,
            child: widget.buildChild(w, rows),
          );
        }

        return DynWidgetCard(
          title: w.title,
          subtitle: w.subtitle,
          footer: '${rows.length} kayıt',
          child: widget.buildChild(w, rows),
        );
      },
    );
  }

  String _message(Object e) {
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }
}
