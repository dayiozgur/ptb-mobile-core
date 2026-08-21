import 'payroll_helpers.dart';

/// Personel-başına bordro ek/kesintisi (`payroll_adjustments`).
///
/// Web `PayrollAdjustment` view-model'inin aynası. Kaynağı onaylı bir
/// hr_advance (kesinti / avans mahsubu) veya hr_expense (ek / masraf iadesi)
/// form gönderimidir. [kind] `deduction` (kesinti) | `addition` (ek).
/// Salt-okuma (mobil v1).
class PayrollAdjustment {
  final String id;
  final String? tenantId;
  final String? staffId;
  final String? staffName;
  final String? runId;
  final int? periodYear;
  final int? periodMonth;

  /// `advance` (avans) | `expense` (masraf).
  final String sourceType;
  final String? sourceRef;

  /// `deduction` (kesinti) | `addition` (ek).
  final String kind;
  final num amount;
  final num? sourceTotal;
  final num? installmentAmount;
  final int installmentNo;

  /// `pending` | `applied` | `cancelled`.
  final String status;
  final String? description;
  final DateTime? createdAt;
  final DateTime? appliedAt;

  const PayrollAdjustment({
    required this.id,
    this.tenantId,
    this.staffId,
    this.staffName,
    this.runId,
    this.periodYear,
    this.periodMonth,
    this.sourceType = 'advance',
    this.sourceRef,
    this.kind = 'deduction',
    this.amount = 0,
    this.sourceTotal,
    this.installmentAmount,
    this.installmentNo = 1,
    this.status = 'pending',
    this.description,
    this.createdAt,
    this.appliedAt,
  });

  bool get isDeduction => kind == 'deduction';

  factory PayrollAdjustment.fromJson(Map<String, dynamic> json) {
    return PayrollAdjustment(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String?,
      staffId: json['staff_id'] as String?,
      staffName: payrollStaffName(json['staffs']),
      runId: json['run_id'] as String?,
      periodYear: json['period_year'] == null
          ? null
          : payrollNum(json['period_year']).toInt(),
      periodMonth: json['period_month'] == null
          ? null
          : payrollNum(json['period_month']).toInt(),
      sourceType: (json['source_type'] as String?) ?? 'advance',
      sourceRef: json['source_ref'] as String?,
      kind: (json['kind'] as String?) ?? 'deduction',
      amount: payrollNum(json['amount']),
      sourceTotal:
          json['source_total'] == null ? null : payrollNum(json['source_total']),
      installmentAmount: json['installment_amount'] == null
          ? null
          : payrollNum(json['installment_amount']),
      installmentNo: payrollNum(json['installment_no'] ?? 1).toInt(),
      status: (json['status'] as String?) ?? 'pending',
      description: json['description'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      appliedAt: json['applied_at'] != null
          ? DateTime.tryParse(json['applied_at'] as String)
          : null,
    );
  }
}
