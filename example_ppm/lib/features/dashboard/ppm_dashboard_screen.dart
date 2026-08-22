import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

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
    return SummaryScreen(
      title: 'Portföy Özeti',
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
      cards: const [
        // Projelere göre iş ilerlemesi — tamamlanan vs açık (yığılmış bar).
        AggregateChartCard(
          title: 'Proje İlerlemesi',
          subtitle: 'Projeye göre tamamlanan / açık iş',
          rpc: 'fn_ppm_portfolio_rollup',
          chartKind: 'stacked_bar',
          visualConfig: {
            'labelField': 'project_name',
            'valueFields': ['done_issues', 'open_issues'],
          },
          height: 260,
        ),
        // Story point — toplam vs tamamlanan.
        AggregateChartCard(
          title: 'Story Point',
          subtitle: 'Projeye göre toplam / tamamlanan puan',
          rpc: 'fn_ppm_portfolio_rollup',
          chartKind: 'bar_chart',
          visualConfig: {
            'labelField': 'project_name',
            'valueFields': ['total_points', 'done_points'],
          },
          height: 260,
        ),
      ],
    );
  }
}
