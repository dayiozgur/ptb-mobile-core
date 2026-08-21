/// Ar-Ge Puantaj İcmal satırı — `arge-puantaj-summary` (Ar-Ge B6 Bakanlık
/// raporu) veri kaynağının mobil salt-okuma görünüm modeli.
///
/// Web `dr_data_sources.code = 'arge-puantaj-summary'` özel sorgusuyla birebir
/// içerik: Ar-Ge personeli (`staffs.is_arge_personnel = true`) onaylı puantaj
/// föylerinin (`puantaj_sheets`) aylık Ar-Ge / toplam saat icmali.
/// Mobil v1'de rapor motoru yerine `puantaj_sheets` doğrudan okunur
/// (personel embed'i + inner-join is_arge_personnel filtresi).
library;

/// Bir Ar-Ge personelinin bir dönemdeki (ay) puantaj icmal satırı.
class ArgeReportRow {
  final String sheetId;
  final String staffId;
  final String? staffName;
  final int periodYear;
  final int periodMonth;
  final num argeHours;
  final num totalHours;

  const ArgeReportRow({
    required this.sheetId,
    required this.staffId,
    required this.staffName,
    required this.periodYear,
    required this.periodMonth,
    required this.argeHours,
    required this.totalHours,
  });

  factory ArgeReportRow.fromJson(Map<String, dynamic> json) {
    return ArgeReportRow(
      sheetId: json['id'].toString(),
      staffId: json['staff_id']?.toString() ?? '',
      staffName: _staffFullName(json['staffs']),
      periodYear: _asInt(json['period_year']),
      periodMonth: _asInt(json['period_month']),
      argeHours: _asNum(json['total_arge_hours']),
      totalHours: _asNum(json['total_hours']),
    );
  }

  /// Dönem etiketi — `AA/YYYY` (web icmal biçimi).
  String get periodLabel =>
      '${periodMonth.toString().padLeft(2, '0')}/$periodYear';

  /// Ar-Ge saatinin toplam içindeki oranı (0..1); toplam 0 ise 0.
  double get argeRatio =>
      totalHours > 0 ? (argeHours / totalHours).clamp(0, 1).toDouble() : 0;
}

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
