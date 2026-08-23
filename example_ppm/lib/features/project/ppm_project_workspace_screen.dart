import 'package:flutter/material.dart' hide FormField;
import 'package:protoolbag_core/protoolbag_core.dart';

/// **PPM Proje Çalışma Alanı** — web `PtbProjectWorkspaceComponent` mobil
/// karşılığı. Tek proje bağlamında SEKME'li yapı: Genel (overview) · Pano
/// (kanban) · Backlog — hepsi bu projenin alt-ağacına (`ancestorId`) kapsanır.
///
/// Tek proje-seçim adımını ortadan kaldırır (eskiden her facet ayrı picker'dı).
/// Gövdeler mevcut ekranların `embedded` modunu yeniden kullanır (iç-içe
/// AppScaffold olmadan).
class PpmProjectWorkspaceScreen extends StatefulWidget {
  final String projectId;
  final String? title;

  const PpmProjectWorkspaceScreen({
    super.key,
    required this.projectId,
    this.title,
  });

  @override
  State<PpmProjectWorkspaceScreen> createState() =>
      _PpmProjectWorkspaceScreenState();
}

class _PpmProjectWorkspaceScreenState extends State<PpmProjectWorkspaceScreen> {
  int _tab = 0;
  String? _projectTitle;

  @override
  void initState() {
    super.initState();
    _projectTitle = widget.title;
    _loadTitle();
  }

  /// Proje kaydının subject'ini başlık için çek (başlık verilmediyse).
  Future<void> _loadTitle() async {
    if ((_projectTitle ?? '').isNotEmpty) return;
    try {
      final cfg = await sl<EntityConfigService>().getByCode('project');
      if (cfg == null) return;
      final tenantId = sl<TenantService>().currentTenantId;
      final ds = sl<EntityDataService>();
      if (tenantId != null) ds.setTenant(tenantId);
      final e = await ds.getEntity(cfg, widget.projectId);
      if (mounted && e != null && (e.subject ?? '').isNotEmpty) {
        setState(() => _projectTitle = e.subject);
      }
    } catch (_) {
      // başlık best-effort — hata durumunda generic kalır
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _projectTitle ?? 'Proje',
      showBackButton: true,
      onBack: () => Navigator.of(context).maybePop(),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface(Theme.of(context).brightness),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.divider(Theme.of(context).brightness),
                  width: 0.5,
                ),
              ),
            ),
            child: AppTabBar(
              tabs: const ['Genel', 'Pano', 'Backlog'],
              selectedIndex: _tab,
              onTabChanged: (i) => setState(() => _tab = i),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                _overviewTab(context),
                EntityKanbanScreen(
                  typeCode: 'task',
                  ancestorId: widget.projectId,
                  embedded: true,
                ),
                BacklogScreen(
                  // İş-öğeleri board ile aynı tipte (task) — 'story' çoğu projede
                  // boş olduğundan backlog boş görünüyordu; sıralı liste görünümü.
                  typeCode: 'task',
                  ancestorId: widget.projectId,
                  embedded: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewTab(BuildContext context) {
    final tenantId = sl<TenantService>().currentTenantId;
    final params = <String, dynamic>{
      'p_tenant_id': tenantId,
      'p_root': widget.projectId,
    };
    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        KpiRowCard(
          title: 'Genel Bakış',
          rpc: 'fn_ppm_project_overview',
          params: params,
          kpis: const [
            KpiSpec('Toplam İş', 'total'),
            KpiSpec('Tamamlanan', 'done'),
            KpiSpec('Puan (Toplam)', 'pts_total'),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AggregateChartCard(
          title: 'Durum Dağılımı',
          subtitle: 'İşlerin duruma göre dağılımı',
          rpc: 'fn_ppm_project_overview',
          params: params,
          chartKind: 'donut_chart',
          transform: (raw) => _objectToRows(raw, 'by_status', 'status'),
          visualConfig: const {
            'labelField': 'status',
            'valueFields': ['count'],
          },
          height: 220,
        ),
        const SizedBox(height: AppSpacing.md),
        AggregateChartCard(
          title: 'Tür Dağılımı',
          subtitle: 'Epik / story / task / alt-görev',
          rpc: 'fn_ppm_project_overview',
          params: params,
          chartKind: 'bar_chart',
          transform: (raw) => _objectToRows(raw, 'by_type', 'type'),
          visualConfig: const {
            'labelField': 'type',
            'valueFields': ['count'],
          },
          height: 220,
        ),
      ],
    );
  }

  static List<Map<String, dynamic>> _objectToRows(
    dynamic raw,
    String key,
    String labelName,
  ) {
    if (raw is! Map || raw[key] is! Map) return const [];
    final obj = Map<String, dynamic>.from(raw[key] as Map);
    return obj.entries
        .map((e) => {labelName: e.key, 'count': e.value})
        .toList();
  }
}
