/// Teşvik (5746 / 4691 Ar-Ge) tahakkuk satırı — `tesvik_accruals` tablosunun
/// mobil salt-okuma görünüm modeli.
///
/// Web `TesvikService` (@ptb/rnd-management) `ACCRUAL_SELECT` okumasıyla birebir
/// sözleşme: her satır bir personel × dönem × `rule_code` teşvik kalemidir;
/// `staffs` FK-embed'inden personel adı türetilir.
library;

/// Bir hesaplanmış teşvik tahakkuk kalemi (personel/dönem/ruleCode).
class TesvikAccrualRow {
  final String id;
  final String regime; // '5746' | '4691'
  final String staffId;
  final String? staffName;
  final int periodYear;
  final int periodMonth;
  final String ruleCode;
  final String? titleCategory;
  final num argeHours;
  final num fte;
  final num baseAmount;
  final num incentiveAmount;
  final String status; // 'draft' | 'finalized' | 'approved'
  final DateTime? calculatedAt;

  const TesvikAccrualRow({
    required this.id,
    required this.regime,
    required this.staffId,
    required this.staffName,
    required this.periodYear,
    required this.periodMonth,
    required this.ruleCode,
    required this.titleCategory,
    required this.argeHours,
    required this.fte,
    required this.baseAmount,
    required this.incentiveAmount,
    required this.status,
    required this.calculatedAt,
  });

  factory TesvikAccrualRow.fromJson(Map<String, dynamic> json) {
    return TesvikAccrualRow(
      id: json['id'].toString(),
      regime: (json['regime'] as String?) ?? '5746',
      staffId: json['staff_id']?.toString() ?? '',
      staffName: _staffFullName(json['staffs']),
      periodYear: _asInt(json['period_year']),
      periodMonth: _asInt(json['period_month']),
      ruleCode: (json['rule_code'] as String?) ?? '',
      titleCategory: json['title_category'] as String?,
      argeHours: _asNum(json['arge_hours']),
      fte: _asNum(json['fte'], fallback: 1),
      baseAmount: _asNum(json['base_amount']),
      incentiveAmount: _asNum(json['incentive_amount']),
      status: (json['status'] as String?) ?? 'draft',
      calculatedAt: json['calculated_at'] != null
          ? DateTime.tryParse(json['calculated_at'].toString())
          : null,
    );
  }

  /// Dönem etiketi — `AA/YYYY` (web `arge-tesvik-icmal` biçimi).
  String get periodLabel =>
      '${periodMonth.toString().padLeft(2, '0')}/$periodYear';
}

/// `staffs` embed'inden görünen ad üretir (first+last, yoksa name).
String? _staffFullName(dynamic rel) {
  final s = rel is List ? (rel.isNotEmpty ? rel.first : null) : rel;
  if (s is! Map) return null;
  final first = (s['first_name'] as String?)?.trim() ?? '';
  final last = (s['last_name'] as String?)?.trim() ?? '';
  final full = [first, last].where((e) => e.isNotEmpty).join(' ');
  if (full.isNotEmpty) return full;
  final name = (s['name'] as String?)?.trim();
  return (name != null && name.isNotEmpty) ? name : null;
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

num _asNum(dynamic v, {num fallback = 0}) {
  if (v is num) return v;
  return num.tryParse(v?.toString() ?? '') ?? fallback;
}
