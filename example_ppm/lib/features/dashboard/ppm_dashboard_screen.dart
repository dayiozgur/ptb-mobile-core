import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ppm_common.dart';
import '../board/ppm_board_screen.dart';

/// **PPM Portföy Özeti** — MS-Project "Project Summary" mobil karşılığı (portföy
/// düzeyi). Projelere göre iş/story-point ilerlemesi; canlı
/// `fn_ppm_portfolio_rollup` RPC'sinden (durum `done/closed/completed` doğru
/// sayılır) çekirdek özet primitifleriyle çizilir. App-bar'dan tek-proje
/// özet-drill-down'a (fn_ppm_project_overview) geçilir.
class PpmDashboardScreen extends StatelessWidget {
  const PpmDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tenantId = sl<TenantService>().currentTenantId;
    return SummaryScreen(
      title: ppmT('ppm.dashboard.title', 'Portföy Özeti'),
      actions: [
        Builder(
          builder: (ctx) => AppIconButton(
            icon: Icons.insights_outlined,
            onPressed: () => Navigator.of(ctx).push(MaterialPageRoute(
              builder: (_) =>
                  const PpmBoardScreen(target: PpmScopeTarget.summary),
            )),
          ),
        ),
      ],
      cards: [
        // Tenant-geneli KPI (tüm projeler; p_root boş → hepsi).
        KpiRowCard(
          title: ppmT('ppm.dashboard.overview', 'Genel Bakış'),
          rpc: 'fn_ppm_project_overview',
          params: {'p_tenant_id': tenantId},
          kpis: [
            KpiSpec(ppmT('ppm.dashboard.total_issues', 'Toplam İş'), 'total'),
            KpiSpec(ppmT('ppm.dashboard.done', 'Tamamlanan'), 'done'),
            KpiSpec(ppmT('ppm.dashboard.pts_total', 'Puan (Toplam)'),
                'pts_total'),
          ],
        ),
        // Projelere göre iş ilerlemesi — tamamlanan vs açık (yığılmış bar).
        AggregateChartCard(
          title: ppmT('ppm.dashboard.project_progress', 'Proje İlerlemesi'),
          subtitle: ppmT('ppm.dashboard.project_progress_sub',
              'Projeye göre tamamlanan / açık iş'),
          rpc: 'fn_ppm_portfolio_rollup',
          chartKind: 'stacked_bar',
          visualConfig: const {
            'labelField': 'project_name',
            'valueFields': ['done_issues', 'open_issues'],
          },
          height: 260,
        ),
        // Story point — toplam vs tamamlanan.
        AggregateChartCard(
          title: ppmT('ppm.dashboard.story_point', 'Story Point'),
          subtitle: ppmT('ppm.dashboard.story_point_sub',
              'Projeye göre toplam / tamamlanan puan'),
          rpc: 'fn_ppm_portfolio_rollup',
          chartKind: 'bar_chart',
          visualConfig: const {
            'labelField': 'project_name',
            'valueFields': ['total_points', 'done_points'],
          },
          height: 260,
        ),
      ],
    );
  }
}
