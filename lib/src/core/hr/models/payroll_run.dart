import 'payroll_helpers.dart';

/// Bir tenant'a ait aylık bordro çalıştırması (`payroll_runs`).
///
/// Web `PayrollRun` view-model'inin aynası. Yaşam döngüsü:
/// `draft → calculated → approved → paid`. Salt-okuma (mobil v1).
class PayrollRun {
  final String id;
  final String? tenantId;
  final int periodYear;
  final int periodMonth;
  final String? label;
  final String status;
  final DateTime? calculatedAt;
  final DateTime? approvedAt;
  final bool active;

  const PayrollRun({
    required this.id,
    this.tenantId,
    required this.periodYear,
    required this.periodMonth,
    this.label,
    this.status = 'draft',
    this.calculatedAt,
    this.approvedAt,
    this.active = true,
  });

  factory PayrollRun.fromJson(Map<String, dynamic> json) {
    return PayrollRun(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String?,
      periodYear: payrollNum(json['period_year']).toInt(),
      periodMonth: payrollNum(json['period_month']).toInt(),
      label: json['label'] as String?,
      status: (json['status'] as String?) ?? 'draft',
      calculatedAt: json['calculated_at'] != null
          ? DateTime.tryParse(json['calculated_at'] as String)
          : null,
      approvedAt: json['approved_at'] != null
          ? DateTime.tryParse(json['approved_at'] as String)
          : null,
      active: json['active'] != false,
    );
  }
}
