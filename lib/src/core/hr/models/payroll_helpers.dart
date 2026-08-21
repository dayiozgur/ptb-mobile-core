/// Ortak yardımcılar — admin bordro (payroll) modelleri için.
///
/// Web `PayrollService` mapper'larıyla (num/staffFullName) birebir aynı
/// dönüşüm mantığını taşır; yeni model dosyalarında tekrarı önler.
library;

/// Güvenli sayı dönüşümü — null/boş/geçersiz → 0 (web `num()` mapper eşi).
num payrollNum(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v;
  return num.tryParse(v.toString()) ?? 0;
}

/// PostgREST FK-embed'inden görünen personel adı üretir.
///
/// Web `staffFullName` ile aynı öncelik: `first_name last_name`, yoksa `name`.
/// Embed hem tekil obje hem tek-elemanlı dizi olabilir (PostgREST'e göre).
String? payrollStaffName(dynamic rel) {
  final s = rel is List ? (rel.isNotEmpty ? rel.first : null) : rel;
  if (s is! Map) return null;
  final first = (s['first_name'] as String?)?.trim();
  final last = (s['last_name'] as String?)?.trim();
  final full = [first, last].where((e) => e != null && e.isNotEmpty).join(' ');
  if (full.isNotEmpty) return full;
  final name = (s['name'] as String?)?.trim();
  return (name != null && name.isNotEmpty) ? name : null;
}
