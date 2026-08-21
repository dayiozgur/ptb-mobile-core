import 'payroll_helpers.dart';

/// Personel-başına aylık brüt maaş tanımı (`payroll_salaries`).
///
/// Web `PayrollSalary` view-model'inin aynası. HASSAS: brüt maaş rakamı yalnızca
/// RLS/grants ile yetkilendirilen (admin) kullanıcıya döner; sorgu tablonun
/// `authenticated`'a açtığı kolonları okur. Salt-okuma (mobil v1).
class PayrollSalary {
  final String id;
  final String? tenantId;
  final String? staffId;
  final String? staffName;
  final num grossMonthly;
  final String currency;
  final bool active;

  const PayrollSalary({
    required this.id,
    this.tenantId,
    this.staffId,
    this.staffName,
    this.grossMonthly = 0,
    this.currency = 'TRY',
    this.active = true,
  });

  factory PayrollSalary.fromJson(Map<String, dynamic> json) {
    return PayrollSalary(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String?,
      staffId: json['staff_id'] as String?,
      staffName: payrollStaffName(json['staffs']),
      grossMonthly: payrollNum(json['gross_monthly']),
      currency: (json['currency'] as String?) ?? 'TRY',
      active: json['active'] != false,
    );
  }
}
