import 'payroll_helpers.dart';

/// Bir çalıştırmaya (run) ait tek bir bordro satırı — çalıştırma detayında
/// listelenir (`payslips`, FK-embed ile personel adı).
///
/// Web `Payslip` view-model'inin admin çalıştırma-detayı için sadeleştirilmiş
/// alt kümesi: personel adı + brüt / net / net ödenecek. Salt-okuma.
class PayrollRunPayslip {
  final String id;
  final String? staffId;
  final String? staffName;
  final int? periodYear;
  final int? periodMonth;
  final num grossSalary;
  final num netSalary;
  final num netPayable;

  const PayrollRunPayslip({
    required this.id,
    this.staffId,
    this.staffName,
    this.periodYear,
    this.periodMonth,
    this.grossSalary = 0,
    this.netSalary = 0,
    this.netPayable = 0,
  });

  factory PayrollRunPayslip.fromJson(Map<String, dynamic> json) {
    // net_payable DB-generated; eski satırlarda null → net_salary'ye düş.
    final net = payrollNum(json['net_salary']);
    return PayrollRunPayslip(
      id: json['id'] as String,
      staffId: json['staff_id'] as String?,
      staffName: payrollStaffName(json['staffs']),
      periodYear: json['period_year'] == null
          ? null
          : payrollNum(json['period_year']).toInt(),
      periodMonth: json['period_month'] == null
          ? null
          : payrollNum(json['period_month']).toInt(),
      grossSalary: payrollNum(json['gross_salary']),
      netSalary: net,
      netPayable:
          json['net_payable'] == null ? net : payrollNum(json['net_payable']),
    );
  }
}
