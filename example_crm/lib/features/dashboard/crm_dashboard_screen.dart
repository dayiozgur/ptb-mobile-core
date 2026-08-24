import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../crm_common.dart';

/// **CRM Özet / Gösterge** — satış hattı, kazanç/kayıp ve müşteri-adayı kaynak
/// analitiği. Tümü canlı `fn_crm_*_rollup` RPC'lerinden (web dashboard ile aynı
/// kaynak → tutarlı) çekirdek [SummaryScreen] + kart primitifleriyle çizilir.
class CrmDashboardScreen extends StatelessWidget {
  const CrmDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SummaryScreen(
      title: crmT('crm.dashboard.title', 'CRM Özet'),
      cards: [
        // Üst KPI şeridi — tek RPC (json) tüm ölçütleri verir.
        KpiRowCard(
          title: crmT('crm.dashboard.overview', 'Genel Bakış'),
          rpc: 'fn_crm_dashboard_rollup',
          objectPath: 'kpis',
          kpis: [
            KpiSpec(crmT('crm.dashboard.pipeline_value', 'Açık Hat'),
                'pipeline_value',
                prefix: '₺'),
            KpiSpec(
                crmT('crm.dashboard.weighted_forecast', 'Ağırlıklı Tahmin'),
                'weighted_forecast',
                prefix: '₺'),
            KpiSpec(crmT('crm.dashboard.won', 'Kazanılan'), 'won_amount',
                prefix: '₺'),
            KpiSpec(crmT('crm.dashboard.open_count', 'Açık Fırsat'),
                'open_count'),
          ],
        ),
        // Satış hattı — aşamaya göre tutar.
        AggregateChartCard(
          title: crmT('crm.dashboard.pipeline_stage', 'Satış Hattı (Aşama)'),
          subtitle: crmT(
              'crm.dashboard.pipeline_stage_sub', 'Aşamaya göre toplam tutar'),
          rpc: 'fn_crm_pipeline_rollup',
          chartKind: 'horizontal_bar',
          visualConfig: const {
            'labelField': 'stage',
            'valueFields': ['total_amount'],
          },
          height: 240,
        ),
        // Kazanç / Kayıp — sonuç dağılımı.
        AggregateChartCard(
          title: crmT('crm.dashboard.win_loss', 'Kazanç / Kayıp'),
          subtitle:
              crmT('crm.dashboard.win_loss_sub', 'Sonuçlanan fırsat sayısı'),
          rpc: 'fn_crm_win_loss_rollup',
          chartKind: 'donut_chart',
          visualConfig: const {
            'labelField': 'outcome',
            'valueFields': ['deal_count'],
          },
          height: 220,
        ),
        // Müşteri adayı kaynak analizi.
        AggregateChartCard(
          title: crmT('crm.dashboard.lead_sources', 'Aday Kaynakları'),
          subtitle:
              crmT('crm.dashboard.lead_sources_sub', 'Kaynağa göre toplam aday'),
          rpc: 'fn_crm_lead_source_rollup',
          chartKind: 'bar_chart',
          visualConfig: const {
            'labelField': 'source',
            'valueFields': ['total'],
          },
          height: 240,
        ),
      ],
    );
  }
}
