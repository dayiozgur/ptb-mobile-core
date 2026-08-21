import 'payroll_helpers.dart';

/// Tek bir gelir-vergisi dilimi (`income_tax_brackets` jsonb elemanı).
///
/// [upto] bu dilimin kümülatif yıllık matrah tavanı (null = en üst / açık uçlu
/// dilim); [rate] bir orandır (0.15 = %15).
class PayrollTaxBracket {
  final num? upto;
  final num rate;

  const PayrollTaxBracket({this.upto, this.rate = 0});

  factory PayrollTaxBracket.fromJson(Map<String, dynamic> json) {
    return PayrollTaxBracket(
      upto: json['upto'] == null ? null : payrollNum(json['upto']),
      rate: payrollNum(json['rate']),
    );
  }
}

/// Yıl-kapsamlı TR bordro parametre yapılandırması (`payroll_parameters`).
///
/// Web `PayrollParameter` view-model'inin aynası. [tenantId] null = paylaşımlı
/// global varsayılan (salt-okuma temel); dolu = tenant override satırı. Oranlar
/// birer kesirdir (ör. [sgkEmployeeRate] 0.14). Salt-okuma (mobil v1).
class PayrollParameter {
  final String id;
  final String? tenantId;
  final int year;
  final num sgkEmployeeRate;
  final num unemploymentEmployeeRate;
  final num sgkEmployerRate;
  final num unemploymentEmployerRate;
  final num stampTaxRate;
  final num sgkFloor;
  final num sgkCeiling;
  final num minimumWageGross;
  final List<PayrollTaxBracket> incomeTaxBrackets;
  final String? notes;
  final bool active;

  const PayrollParameter({
    required this.id,
    this.tenantId,
    required this.year,
    this.sgkEmployeeRate = 0,
    this.unemploymentEmployeeRate = 0,
    this.sgkEmployerRate = 0,
    this.unemploymentEmployerRate = 0,
    this.stampTaxRate = 0,
    this.sgkFloor = 0,
    this.sgkCeiling = 0,
    this.minimumWageGross = 0,
    this.incomeTaxBrackets = const [],
    this.notes,
    this.active = true,
  });

  /// tenant_id null → paylaşımlı global varsayılan satır (salt-okuma temel).
  bool get isGlobalDefault => tenantId == null;

  factory PayrollParameter.fromJson(Map<String, dynamic> json) {
    final rawBrackets = json['income_tax_brackets'];
    final brackets = rawBrackets is List
        ? rawBrackets
            .whereType<Map>()
            .map((b) => PayrollTaxBracket.fromJson(
                Map<String, dynamic>.from(b)))
            .toList()
        : <PayrollTaxBracket>[];

    return PayrollParameter(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String?,
      year: payrollNum(json['year']).toInt(),
      sgkEmployeeRate: payrollNum(json['sgk_employee_rate']),
      unemploymentEmployeeRate: payrollNum(json['unemployment_employee_rate']),
      sgkEmployerRate: payrollNum(json['sgk_employer_rate']),
      unemploymentEmployerRate: payrollNum(json['unemployment_employer_rate']),
      stampTaxRate: payrollNum(json['stamp_tax_rate']),
      sgkFloor: payrollNum(json['sgk_floor']),
      sgkCeiling: payrollNum(json['sgk_ceiling']),
      minimumWageGross: payrollNum(json['minimum_wage_gross']),
      incomeTaxBrackets: brackets,
      notes: json['notes'] as String?,
      active: json['active'] != false,
    );
  }
}
