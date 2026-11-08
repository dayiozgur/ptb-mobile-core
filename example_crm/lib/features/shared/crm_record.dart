import 'package:intl/intl.dart';

/// Bir CRM entity kaydı (`form_submissions` satırı: deal / lead / company).
///
/// Web liste projeksiyonları alanları `metadata`dan türetir (metadata, form
/// alan değerlerinin aynasıdır); mobil de aynı kaynaktan okur — ek
/// `form_field_values` sorgusu gerekmez.
class CrmRecord {
  final String id;
  final String? code;
  final String? subject;
  final String? status;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;
  final String? organizationId;

  const CrmRecord({
    required this.id,
    this.code,
    this.subject,
    this.status,
    this.metadata = const {},
    this.createdAt,
    this.organizationId,
  });

  factory CrmRecord.fromRow(Map<String, dynamic> r) {
    final meta = r['metadata'];
    return CrmRecord(
      id: r['id']?.toString() ?? '',
      code: r['code'] as String?,
      subject: r['subject'] as String?,
      status: r['status'] as String?,
      metadata: meta is Map ? Map<String, dynamic>.from(meta) : const {},
      createdAt: r['created_at'] != null
          ? DateTime.tryParse(r['created_at'].toString())
          : null,
      organizationId: r['organization_id'] as String?,
    );
  }

  /// Metin alanı: düz string ya da lookup objesi (`displayValue` / `name`).
  String metaStr(String key) => crmText(metadata[key]);

  /// Sayısal alan (number ya da sayısal string); yoksa null.
  num? metaNum(String key) => crmNum(metadata[key]);

  /// Lookup alanının hedef id'si (`{entityId|id|value}`), yoksa null.
  String? metaRefId(String key) {
    final v = metadata[key];
    if (v is Map) {
      final e = v['entityId'] ?? v['id'] ?? v['value'];
      if (e is String && e.trim().isNotEmpty) return e.trim();
    }
    return null;
  }

  // ── Fırsat (deal) alanları — web deal-pipeline AMOUNT/PROBABILITY/CURRENCY ──
  num? get amount => metaNum('amount');
  num? get probability => metaNum('probability');
  String get currency => metaStr('currency');
  String get companyName => metaStr('company');
  DateTime? get expectedClose {
    final s = metaStr('expected_close');
    return s.isEmpty ? null : DateTime.tryParse(s);
  }

  /// Fırsat başlığı: subject → "Firma · Kod" → kod → '—'.
  String get dealTitle {
    final s = (subject ?? '').trim();
    if (s.isNotEmpty) return s;
    final parts = [companyName, code ?? ''].where((p) => p.isNotEmpty);
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  /// Potansiyel başlığı — web `leadDisplayTitle` ile birebir: gerçek subject
  /// (metadata.name kopyası değilse) → "Ad · Firma" → e-posta → subject →
  /// null (çağıran "başlıksız" gösterir).
  String? get leadTitle {
    final name = metaStr('name').isNotEmpty
        ? metaStr('name')
        : metaStr('contact_name');
    final company = metaStr('company');
    final s = (subject ?? '').trim();
    if (s.isNotEmpty && s != name) return s;
    final parts = [name, company].where((p) => p.isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.join(' · ');
    final email = metaStr('email').isNotEmpty
        ? metaStr('email')
        : metaStr('contact_email');
    if (email.isNotEmpty) return email;
    return s.isNotEmpty ? s : null;
  }
}

/// Lookup/düz değerden görünen metin.
String crmText(dynamic v) {
  if (v is String) return v.trim();
  if (v is Map) {
    final d = v['displayValue'] ?? v['name'];
    if (d is String) return d.trim();
  }
  return '';
}

/// number / sayısal string → num; aksi halde null.
num? crmNum(dynamic v) {
  if (v is num) return v;
  if (v is String && v.trim().isNotEmpty) return num.tryParse(v.trim());
  return null;
}

/// Tutar biçimi — cihaz/uygulama yereline göre gruplanmış (sabit 'tr-TR'
/// YOK), varsa para birimi kodu sonda.
String crmMoney(num value, [String currency = '']) {
  final s = NumberFormat.decimalPattern().format(value.round());
  return currency.isEmpty ? s : '$s $currency';
}

/// Para birimi → toplam. Karışık para birimlerinde FX çevirimi YOK (web
/// TRY'ye çevirir); mobil her para birimini ayrı toplar, karıştırmaz.
Map<String, num> crmSumByCurrency(
  Iterable<CrmRecord> deals, {
  bool weighted = false,
}) {
  final out = <String, num>{};
  for (final d in deals) {
    final a = d.amount;
    if (a == null) continue;
    final p = weighted ? (d.probability ?? 0) / 100 : 1;
    out.update(d.currency, (v) => v + a * p, ifAbsent: () => a * p);
  }
  return out;
}

/// `{TRY: 10, USD: 5}` → "10 TRY · 5 USD" (boşsa '—').
String crmMoneyTotals(Map<String, num> totals) {
  if (totals.isEmpty) return '—';
  return totals.entries.map((e) => crmMoney(e.value, e.key)).join(' · ');
}
