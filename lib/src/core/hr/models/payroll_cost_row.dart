import 'payroll_helpers.dart';

/// Boyutsal bordro-maliyet dökümünün tek bir kovası (`fn_payroll_cost_rollup`).
///
/// Web `PayrollCostRow` view-model'inin aynası. [key] ham grup anahtarı (bir
/// 'YYYY-MM' dönemi ya da departman id / '__none__'); [label] sunucu-sağlanan
/// etiket (departman adı; atanmamış kova için null). Tutarlar TRY,
/// [headcount] kovada ödenen ayrık personel sayısı.
class PayrollCostRow {
  final String key;
  final String? label;
  final num totalGross;
  final num totalNet;
  final num totalEmployerCost;
  final int headcount;

  const PayrollCostRow({
    required this.key,
    this.label,
    this.totalGross = 0,
    this.totalNet = 0,
    this.totalEmployerCost = 0,
    this.headcount = 0,
  });

  factory PayrollCostRow.fromJson(Map<String, dynamic> json) {
    return PayrollCostRow(
      key: (json['key'] as String?) ?? '',
      label: json['label'] as String?,
      totalGross: payrollNum(json['total_gross']),
      totalNet: payrollNum(json['total_net']),
      totalEmployerCost: payrollNum(json['total_employer_cost']),
      headcount: payrollNum(json['headcount']).toInt(),
    );
  }
}

/// Maliyet özeti — döküm satırları + toplam şeridi.
///
/// Toplamlar web `PayrollCostSummaryComponent` ile birebir: gross/net/employer
/// SUM, headcount ise kovalar arasında MAX (dönemler arası kişi mükerrer
/// sayılmasın diye — web'deki `Math.max` davranışının aynısı).
class PayrollCostSummary {
  final List<PayrollCostRow> rows;
  final String fromDate;
  final String toDate;
  final String dimension;

  const PayrollCostSummary({
    required this.rows,
    required this.fromDate,
    required this.toDate,
    this.dimension = 'month',
  });

  num get totalGross =>
      rows.fold<num>(0, (acc, r) => acc + r.totalGross);
  num get totalNet => rows.fold<num>(0, (acc, r) => acc + r.totalNet);
  num get totalEmployerCost =>
      rows.fold<num>(0, (acc, r) => acc + r.totalEmployerCost);
  int get headcount => rows.fold<int>(
      0, (acc, r) => r.headcount > acc ? r.headcount : acc);
}
