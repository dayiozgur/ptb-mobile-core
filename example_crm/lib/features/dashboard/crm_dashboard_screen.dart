import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// **CRM Özet / Gösterge** — satış hattı, kazanç/kayıp ve müşteri-adayı kaynak
/// analitiği. Tümü canlı `fn_crm_*_rollup` RPC'lerinden (web dashboard ile aynı
/// kaynak → tutarlı) çekirdek [SummaryScreen] + kart primitifleriyle çizilir.
class CrmDashboardScreen extends StatelessWidget {
  const CrmDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SummaryScreen(
      title: 'CRM Özet',
      cards: const [
        // Üst KPI şeridi — tek RPC (json) tüm ölçütleri verir.
        KpiRowCard(
          title: 'Genel Bakış',
          rpc: 'fn_crm_dashboard_rollup',
          objectPath: 'kpis',
          kpis: [
            KpiSpec('Açık Hat', 'pipeline_value', prefix: '₺'),
            KpiSpec('Ağırlıklı Tahmin', 'weighted_forecast', prefix: '₺'),
            KpiSpec('Kazanılan', 'won_amount', prefix: '₺'),
            KpiSpec('Açık Fırsat', 'open_count'),
          ],
        ),
        // Satış hattı — aşamaya göre tutar.
        AggregateChartCard(
          title: 'Satış Hattı (Aşama)',
          subtitle: 'Aşamaya göre toplam tutar',
          rpc: 'fn_crm_pipeline_rollup',
          chartKind: 'horizontal_bar',
          visualConfig: {
            'labelField': 'stage',
            'valueFields': ['total_amount'],
          },
          height: 240,
        ),
        // Kazanç / Kayıp — sonuç dağılımı.
        AggregateChartCard(
          title: 'Kazanç / Kayıp',
          subtitle: 'Sonuçlanan fırsat sayısı',
          rpc: 'fn_crm_win_loss_rollup',
          chartKind: 'donut_chart',
          visualConfig: {
            'labelField': 'outcome',
            'valueFields': ['deal_count'],
          },
          height: 220,
        ),
        // Müşteri adayı kaynak analizi.
        AggregateChartCard(
          title: 'Aday Kaynakları',
          subtitle: 'Kaynağa göre toplam aday',
          rpc: 'fn_crm_lead_source_rollup',
          chartKind: 'bar_chart',
          visualConfig: {
            'labelField': 'source',
            'valueFields': ['total'],
          },
          height: 240,
        ),
      ],
    );
  }
}
