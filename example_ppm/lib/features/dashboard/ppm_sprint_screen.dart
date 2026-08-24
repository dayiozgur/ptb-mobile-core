import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ppm_common.dart';

/// **PPM Sprint** — aktif sprint burndown + ekip kapasitesi (Jira/MS-Project
/// benzeri). Burndown `fn_ppm_scope_burndown` (kalan vs ideal), kapasite
/// `fn_ppm_sprint_capacity` (kişi başı taahhüt/tamamlanan puan). Aktif sprint
/// yoksa/veri boşsa kartlar dürüstçe "veri yok" gösterir.
class PpmSprintScreen extends StatelessWidget {
  const PpmSprintScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tenantId = sl<TenantService>().currentTenantId;

    return SummaryScreen(
      title: ppmT('ppm.sprint.title', 'Sprint'),
      cards: [
        AggregateChartCard(
          title: ppmT('ppm.sprint.burndown', 'Burndown (Görev)'),
          subtitle:
              ppmT('ppm.sprint.burndown_sub', 'Kalan iş vs ideal — aktif sprint'),
          rpc: 'fn_ppm_scope_burndown',
          params: {'p_tenant_id': tenantId, 'p_entity_type': 'task'},
          chartKind: 'line_chart',
          visualConfig: const {
            'labelField': 'day',
            'valueFields': ['remaining', 'ideal'],
          },
          height: 240,
        ),
        AggregateChartCard(
          title: ppmT('ppm.sprint.capacity', 'Ekip Kapasitesi'),
          subtitle: ppmT(
              'ppm.sprint.capacity_sub', 'Kişi başı taahhüt / tamamlanan puan'),
          rpc: 'fn_ppm_sprint_capacity',
          chartKind: 'bar_chart',
          visualConfig: const {
            'labelField': 'assignee_name',
            'valueFields': ['committed_points', 'done_points'],
          },
          height: 240,
        ),
      ],
    );
  }
}
