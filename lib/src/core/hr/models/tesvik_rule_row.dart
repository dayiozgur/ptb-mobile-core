/// Teşvik kural (versiyonlu oran) satırı — `tesvik_rules` tablosunun mobil
/// salt-okuma görünüm modeli.
///
/// Web `TesvikService` (@ptb/rnd-management) `RULE_SELECT` okumasıyla birebir
/// sözleşme. Her satır bir (`rule_code` × `title_category`) oranının
/// [effectiveFrom, effectiveTo] penceresinde geçerli versiyonudur.
///
/// ⚠️ EN YÜKSEK MEVZUAT RİSKİ: oran ASLA gömülü değildir — `tesvik_rules`
/// versiyonlu yapılandırmasından okunur; mobil yalnız görüntüler.
library;

/// Bir versiyonlu teşvik oran satırı.
class TesvikRuleRow {
  final String id;
  final String? tenantId; // null = global (platform-yönetimli, paylaşımlı)
  final String regime; // '5746' | '4691'
  final String ruleCode;
  final String titleCategory;
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo; // null = açık uçlu (güncel)
  final num rate; // oran (ör. 1.0 / 0.5 / 0.95)
  final num? capPct; // destek nitelendirme tavanı (ör. 0.1), null = tavansız
  final bool active;

  const TesvikRuleRow({
    required this.id,
    required this.tenantId,
    required this.regime,
    required this.ruleCode,
    required this.titleCategory,
    required this.effectiveFrom,
    required this.effectiveTo,
    required this.rate,
    required this.capPct,
    required this.active,
  });

  factory TesvikRuleRow.fromJson(Map<String, dynamic> json) {
    return TesvikRuleRow(
      id: json['id'].toString(),
      tenantId: json['tenant_id'] as String?,
      regime: (json['regime'] as String?) ?? '5746',
      ruleCode: (json['rule_code'] as String?) ?? '',
      titleCategory: (json['title_category'] as String?) ?? '',
      effectiveFrom: json['effective_from'] != null
          ? DateTime.tryParse(json['effective_from'].toString())
          : null,
      effectiveTo: json['effective_to'] != null
          ? DateTime.tryParse(json['effective_to'].toString())
          : null,
      rate: _asNum(json['rate']),
      capPct: json['cap_pct'] != null ? _asNum(json['cap_pct']) : null,
      active: json['active'] != false,
    );
  }

  /// Global (paylaşımlı) kural mı? (`tenant_id == null`)
  bool get isGlobal => tenantId == null;

  /// Oranı yüzde metnine çevirir — ör. `%100`, `%95`, `%50`.
  String get ratePercentLabel {
    final pct = rate * 100;
    final asInt = pct.roundToDouble() == pct;
    return '%${asInt ? pct.toInt() : pct}';
  }
}

num _asNum(dynamic v, {num fallback = 0}) {
  if (v is num) return v;
  return num.tryParse(v?.toString() ?? '') ?? fallback;
}
