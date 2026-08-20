/// A single payslip row from the `payslips` table.
class Payslip {
  final String id;
  final String? staffId;
  final String? runId;
  final int? periodYear;
  final int? periodMonth;
  final num grossSalary;
  final num netSalary;
  final num netPayable;
  final num sgkEmployee;
  final num incomeTax;
  final num workedDays;
  final num absentDays;
  final num overtimeMinutes;
  final DateTime? createdAt;

  const Payslip({
    required this.id,
    this.staffId,
    this.runId,
    this.periodYear,
    this.periodMonth,
    this.grossSalary = 0,
    this.netSalary = 0,
    this.netPayable = 0,
    this.sgkEmployee = 0,
    this.incomeTax = 0,
    this.workedDays = 0,
    this.absentDays = 0,
    this.overtimeMinutes = 0,
    this.createdAt,
  });

  factory Payslip.fromJson(Map<String, dynamic> json) {
    return Payslip(
      id: json['id'] as String,
      staffId: json['staff_id'] as String?,
      runId: json['run_id'] as String?,
      periodYear: (json['period_year'] as num?)?.toInt(),
      periodMonth: (json['period_month'] as num?)?.toInt(),
      grossSalary: (json['gross_salary'] as num?) ?? 0,
      netSalary: (json['net_salary'] as num?) ?? 0,
      netPayable: (json['net_payable'] as num?) ?? 0,
      sgkEmployee: (json['sgk_employee'] as num?) ?? 0,
      incomeTax: (json['income_tax'] as num?) ?? 0,
      workedDays: (json['worked_days'] as num?) ?? 0,
      absentDays: (json['absent_days'] as num?) ?? 0,
      overtimeMinutes: (json['overtime_minutes'] as num?) ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}
