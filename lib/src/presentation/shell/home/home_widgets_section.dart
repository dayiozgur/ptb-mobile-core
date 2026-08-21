import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Ana Sayfa'ya gömülü kişisel-pano ("Panom") bölümü.
///
/// Kullanıcının widget'larını (hava durumu · not · istatistik…) gösterir ve
/// buradan doğrudan yeni widget EKLENEBİLİR ([DashboardCatalogSheet]). Notlar
/// yerinde düzenlenir. Sıralama/kaldırma tam deneyimi [PersonalDashboardScreen]
/// ("Düzenle") içinde. Kalıcılık [PersonalDashboardService] →
/// `pb_page_instances.customizations` (web ile birebir) veya cihaz-yerel.
class HomeWidgetsSection extends StatefulWidget {
  const HomeWidgetsSection({super.key});

  @override
  State<HomeWidgetsSection> createState() => _HomeWidgetsSectionState();
}

class _HomeWidgetsSectionState extends State<HomeWidgetsSection> {
  final PersonalDashboardService _service = sl<PersonalDashboardService>();

  bool _loading = true;
  List<DashboardWidgetDescriptor> _widgets = <DashboardWidgetDescriptor>[];
  final Map<String, Future<List<Map<String, dynamic>>>> _data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final widgets = await _service.loadLayout();
      _data.clear();
      for (final w in widgets) {
        if (w.isDataBacked) _data[w.id] = _service.fetchWidgetData(w);
      }
      if (!mounted) return;
      setState(() {
        _widgets = widgets;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _persist() async {
    try {
      await _service.saveLayout(_widgets);
    } catch (_) {
      // sessiz — home akıcı kalsın; tam hata yönetimi PersonalDashboardScreen'de.
    }
  }

  void _add(DashboardWidgetDescriptor item) {
    final d = _service.instantiateForAdd(item);
    setState(() {
      _widgets = [..._widgets, d];
      if (d.isDataBacked) _data[d.id] = _service.fetchWidgetData(d);
    });
    _persist();
  }

  void _updateNote(DashboardWidgetDescriptor w, String text) {
    final idx = _widgets.indexWhere((e) => e.id == w.id);
    if (idx < 0) return;
    final cfg = Map<String, dynamic>.from(w.config)
      ..['text'] = text
      ..['content'] = text.isEmpty ? '' : '<p>$text</p>';
    setState(() => _widgets[idx] = w.copyWith(config: cfg));
    _persist();
  }

  Future<void> _openCatalog() async {
    final present = _widgets.map((w) => w.id).toSet();
    final selectable = _service
        .availableWidgets()
        .where((c) =>
            c.source == DashboardWidgetSource.added ||
            !present.contains(c.id))
        .toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background(Theme.of(context).brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DashboardCatalogSheet(
        items: selectable,
        onPick: (item) {
          Navigator.of(ctx).pop();
          _add(item);
        },
      ),
    );
  }

  void _openFull() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(
            builder: (_) => const PersonalDashboardScreen()))
        .then((_) => _load()); // dönüşte tazele (kaldırma/sıralama yansısın)
  }

  @override
  Widget build(BuildContext context) {
    // Yüklenirken sessiz — Ana Sayfa'nın kalanı akıcı kalsın.
    if (_loading) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: AppSectionHeader(title: 'Panom', padding: EdgeInsets.zero),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Widget Ekle',
              onPressed: _openCatalog,
            ),
            if (_widgets.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: 'Düzenle',
                onPressed: _openFull,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_widgets.isEmpty)
          AppCard(
            onTap: _openCatalog,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.dashboard_customize_outlined,
                      color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Panonuza widget ekleyin (hava durumu, not…)',
                      style: AppTypography.subhead,
                    ),
                  ),
                  const Icon(Icons.add_circle_outline),
                ],
              ),
            ),
          )
        else
          for (final w in _widgets) ...[
            DashboardWidgetView(
              descriptor: w,
              dataFuture: w.isDataBacked ? _data[w.id] : null,
              onRetry: _load,
              onNoteChanged:
                  w.type == 'text_block' ? (t) => _updateNote(w, t) : null,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }
}
