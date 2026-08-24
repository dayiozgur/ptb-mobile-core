import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ppm_common.dart';

/// **PPM Proje Özeti** — MS-Project "Project Summary" mobil karşılığı (per-proje).
///
/// Tek RPC `fn_ppm_project_overview(p_tenant_id, p_root)` tüm özeti verir:
/// toplam/tamamlanan iş + puan + durum/tür dağılımı. Terminal sayım
/// `status_definitions.is_final` üzerinden (done + completed doğru sayılır).
class PpmProjectSummaryScreen extends StatelessWidget {
  final String projectId;
  final String title;

  const PpmProjectSummaryScreen({
    super.key,
    required this.projectId,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final tenantId = sl<TenantService>().currentTenantId;
    final params = <String, dynamic>{
      'p_tenant_id': tenantId,
      'p_root': projectId,
    };

    return SummaryScreen(
      title: title,
      cards: [
        KpiRowCard(
          title: ppmT('ppm.dashboard.overview', 'Genel Bakış'),
          rpc: 'fn_ppm_project_overview',
          params: params,
          kpis: [
            KpiSpec(ppmT('ppm.dashboard.total_issues', 'Toplam İş'), 'total'),
            KpiSpec(ppmT('ppm.dashboard.done', 'Tamamlanan'), 'done'),
            KpiSpec(ppmT('ppm.dashboard.pts_total', 'Puan (Toplam)'),
                'pts_total'),
          ],
        ),
        AggregateChartCard(
          title: ppmT('ppm.summary.status_dist', 'Durum Dağılımı'),
          subtitle: ppmT(
              'ppm.summary.status_dist_sub', 'İşlerin duruma göre dağılımı'),
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
        AggregateChartCard(
          title: ppmT('ppm.summary.type_dist', 'Tür Dağılımı'),
          subtitle: ppmT(
              'ppm.summary.type_dist_sub', 'Epik / story / task / alt-görev'),
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

  /// json gövdesindeki bir nesne alanını (`{k: sayı}`) grafik satırlarına çevirir.
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
