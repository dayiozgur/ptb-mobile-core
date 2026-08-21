import 'package:flutter/material.dart' hide FormField;
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../../core/dashboard/personal_dashboard_service.dart';

/// Kişisel pano ("Panom") — kullanıcının kendi seçtiği widget'ları SIRALI
/// gösteren, düzenlenebilir dashboard.
///
/// Web karşılığı `PersonalDashboardComponent` (`my-space` add-widget). Seçim +
/// sıra + kaldırma [PersonalDashboardService] ile kalıcılaştırılır (backend
/// `pb_page_instances` varsa oraya, yoksa cihaz-yerel). Widget içeriği mobilde
/// zaten kullanılan `report-query` yolu ([DynStatWidget]/[DynChartWidget]/
/// [DynDataTableWidget]) ile beslenir.
///
/// İki mod:
///  - **Görünüm**: widget'lar gerçek verisiyle render edilir (dikey yığın).
///  - **Düzenle**: [ReorderableListView] ile sürükle-sırala + kaldır; alttan
///    "Widget Ekle" sayfasıyla katalogdan ekleme. Her değişiklik anında kaydolur.
class PersonalDashboardScreen extends StatefulWidget {
  const PersonalDashboardScreen({super.key});

  @override
  State<PersonalDashboardScreen> createState() =>
      _PersonalDashboardScreenState();
}

class _PersonalDashboardScreenState extends State<PersonalDashboardScreen> {
  /// Grafik widget'ları için sabit yükseklik (scroll view'da sınırsız-Flex'ten kaçınır).
  static const double _chartHeight = 240;

  final PersonalDashboardService _service = sl<PersonalDashboardService>();

  bool _loading = true;
  String? _error;
  bool _editMode = false;

  List<DashboardWidgetDescriptor> _widgets = <DashboardWidgetDescriptor>[];

  /// Data-backed widget'lar için tek-sefer çözülen future'lar (widget id →).
  final Map<String, Future<List<Map<String, dynamic>>>> _data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final widgets = await _service.loadLayout();
      _rebuildData(widgets);
      if (!mounted) return;
      setState(() {
        _widgets = widgets;
        _loading = false;
      });
    } catch (e) {
      Logger.error('Panom yüklenemedi', e);
      if (!mounted) return;
      setState(() {
        _error = 'Panom yüklenemedi: $e';
        _loading = false;
      });
    }
  }

  /// Data-backed widget'lar için future haritasını yeniden kurar.
  void _rebuildData(List<DashboardWidgetDescriptor> widgets) {
    _data.clear();
    for (final w in widgets) {
      if (w.isDataBacked) {
        _data[w.id] = _service.fetchWidgetData(w);
      }
    }
  }

  Future<void> _persist() async {
    try {
      await _service.saveLayout(_widgets);
    } catch (e) {
      Logger.error('Panom kaydedilemedi', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kaydedilemedi: $e')),
        );
      }
    }
  }

  // ─── Mutasyonlar ──────────────────────────────────────────────────────────

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _widgets.removeAt(oldIndex);
      _widgets.insert(newIndex, item);
    });
    _persist();
  }

  void _remove(DashboardWidgetDescriptor w) {
    setState(() => _widgets.removeWhere((e) => e.id == w.id));
    _persist();
  }

  void _add(DashboardWidgetDescriptor catalogItem) {
    final descriptor = _service.instantiateForAdd(catalogItem);
    setState(() {
      _widgets = [..._widgets, descriptor];
      if (descriptor.isDataBacked) {
        _data[descriptor.id] = _service.fetchWidgetData(descriptor);
      }
    });
    _persist();
  }

  // ─── Katalog sayfası ────────────────────────────────────────────────────

  Future<void> _openCatalog() async {
    final catalog = _service.availableWidgets();
    // Zaten panoda olan temel (base) widget'ları katalogtan gizle.
    final presentIds = _widgets.map((w) => w.id).toSet();
    final selectable = catalog
        .where((c) =>
            c.source == DashboardWidgetSource.added ||
            !presentIds.contains(c.id))
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background(Theme.of(context).brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => _CatalogSheet(
        items: selectable,
        onPick: (item) {
          Navigator.of(sheetCtx).pop();
          _add(item);
        },
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Panom',
      showBackButton: true,
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        if (!_loading && _error == null)
          AppIconButton(
            icon: _editMode ? Icons.check : Icons.edit_outlined,
            onPressed: () => setState(() => _editMode = !_editMode),
          ),
      ],
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: AppLoadingIndicator());
    }
    if (_error != null) {
      return _scrollableCenter(AppErrorView(message: _error!, onRetry: _load));
    }
    if (_widgets.isEmpty) {
      return _buildEmpty();
    }
    return _editMode ? _buildEditList() : _buildViewList();
  }

  Widget _buildEmpty() {
    return _scrollableCenter(
      AppEmptyState(
        icon: Icons.dashboard_customize_outlined,
        title: 'Panonuz boş — widget ekleyin',
        actionLabel: 'Widget Ekle',
        onAction: _openCatalog,
      ),
    );
  }

  /// Görünüm modu: gerçek verili widget yığını (pull-to-refresh).
  Widget _buildViewList() {
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final w in _widgets) ...[
              _buildWidget(w),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }

  /// Düzenle modu: sürükle-sırala + kaldır. ReorderableListView Expanded ile
  /// SINIRLI (scaffold gövdesi yükseklik verir) — scroll-view içinde değil.
  Widget _buildEditList() {
    return Column(
      children: [
        Padding(
          padding: AppSpacing.screenPadding,
          child: AppButton(
            label: 'Widget Ekle',
            variant: AppButtonVariant.secondary,
            icon: Icons.add,
            onPressed: _openCatalog,
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            itemCount: _widgets.length,
            onReorder: _onReorder,
            itemBuilder: (context, index) {
              final w = _widgets[index];
              return _buildEditTile(w, index, key: ValueKey('edit_${w.id}'));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEditTile(
    DashboardWidgetDescriptor w,
    int index, {
    required Key key,
  }) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Icon(
                  Icons.drag_indicator,
                  color: AppColors.textSecondary(brightness),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w.title ?? _typeLabel(w.type),
                      style: AppTypography.withColor(
                        AppTypography.subhead,
                        AppColors.textPrimary(brightness),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _typeLabel(w.type),
                      style: AppTypography.withColor(
                        AppTypography.caption1,
                        AppColors.textSecondary(brightness),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: AppColors.error,
                tooltip: 'Kaldır',
                onPressed: () => _remove(w),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Widget-type render (görünüm modu) ──────────────────────────────────

  Widget _buildWidget(DashboardWidgetDescriptor w) {
    switch (w.type) {
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
      default:
        return _buildStaticBox(w);
    }
  }

  Widget _buildStat(DashboardWidgetDescriptor w) {
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
    final future = _data[w.id];
    if (future == null) {
      return DynWidgetCard(
        title: w.title,
        subtitle: w.subtitle,
        child: DynStatWidget(
            const [<String, dynamic>{'value': '—'}], w.config,
            mode: mode),
      );
    }
    return _dataCard(
      w,
      future,
      (rows) => DynStatWidget(rows, w.config, mode: mode),
    );
  }

  Widget _buildChart(DashboardWidgetDescriptor w) {
    final future = _data[w.id];
    if (future == null) return _buildStaticBox(w);
    final chartKind = w.config['chartType']?.toString() ?? 'bar_chart';
    return _dataCard(
      w,
      future,
      (rows) => SizedBox(
        height: _chartHeight,
        child: DynChartWidget(rows, w.config, chartKind: chartKind),
      ),
    );
  }

  Widget _buildTable(DashboardWidgetDescriptor w) {
    final future = _data[w.id];
    if (future == null) return _buildStaticBox(w);
    return _dataCard(w, future, (rows) => DynDataTableWidget(rows, w.config));
  }

  Widget _dataCard(
    DashboardWidgetDescriptor w,
    Future<List<Map<String, dynamic>>> future,
    Widget Function(List<Map<String, dynamic>> rows) builder,
  ) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return DynWidgetCard(title: w.title, subtitle: w.subtitle, loading: true);
        }
        if (snap.hasError) {
          return DynWidgetCard(
            title: w.title,
            subtitle: w.subtitle,
            error: 'Hata: ${snap.error}',
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

  Widget _buildHeading(DashboardWidgetDescriptor w) {
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

  Widget _buildText(DashboardWidgetDescriptor w) {
    final text = w.config['text']?.toString() ?? w.subtitle ?? '';
    return DynWidgetCard(
      title: w.title,
      child: Text(
        text,
        style: AppTypography.withColor(
          AppTypography.body,
          AppColors.textSecondary(Theme.of(context).brightness),
        ),
      ),
    );
  }

  Widget _buildStaticBox(DashboardWidgetDescriptor w) {
    final label = w.config['text']?.toString() ??
        w.config['label']?.toString() ??
        w.title ??
        _typeLabel(w.type);
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

  /// Boş/hata durumları için ortalanmış, kaydırılabilir (pull-to-refresh) kap.
  Widget _scrollableCenter(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: Padding(
            padding: AppSpacing.screenPadding,
            child: child,
          )),
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'stat_card':
        return 'İstatistik';
      case 'chart_widget':
        return 'Grafik';
      case 'data_table':
        return 'Tablo';
      case 'text_block':
        return 'Not / Metin';
      case 'heading':
        return 'Başlık';
      case 'divider':
        return 'Ayraç';
      case 'link_card':
        return 'Bağlantı';
      default:
        return type;
    }
  }
}

/// "Widget Ekle" alt sayfası — katalogdan tek dokunuşla ekleme.
class _CatalogSheet extends StatelessWidget {
  const _CatalogSheet({required this.items, required this.onPick});

  final List<DashboardWidgetDescriptor> items;
  final void Function(DashboardWidgetDescriptor item) onPick;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Widget Ekle',
                      style: AppTypography.withColor(
                        AppTypography.headline,
                        AppColors.textPrimary(brightness),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            if (items.isEmpty)
              Padding(
                padding: AppSpacing.screenPadding,
                child: Text(
                  'Eklenebilecek widget yok',
                  style: AppTypography.withColor(
                    AppTypography.subhead,
                    AppColors.textSecondary(brightness),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return AppCard(
                      onTap: () => onPick(item),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          _iconFor(item.type),
                          color: AppColors.primary,
                        ),
                        title: Text(
                          item.title ?? item.type,
                          style: AppTypography.subhead,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: item.subtitle != null
                            ? Text(item.subtitle!)
                            : null,
                        trailing: const Icon(Icons.add_circle_outline),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'stat_card':
        return Icons.insights_outlined;
      case 'chart_widget':
        return Icons.bar_chart_outlined;
      case 'data_table':
        return Icons.table_chart_outlined;
      case 'text_block':
        return Icons.notes_outlined;
      case 'heading':
        return Icons.title_outlined;
      case 'divider':
        return Icons.horizontal_rule;
      case 'link_card':
        return Icons.link_outlined;
      default:
        return Icons.widgets_outlined;
    }
  }
}
