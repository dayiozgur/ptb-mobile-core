import 'package:intl/intl.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// PEM ekranları için ortak i18n yardımcısı.
///
/// Anahtar bulunamazsa (`translate` anahtarın kendisini geri döndürür) Türkçe
/// [fallback] gösterilir — DB seed'i gecikse bile UI güvenli biçimde Türkçe
/// görünür (CRM `crmT` ile aynı desen).
String pemT(String key, String fallback) {
  if (!sl.isRegistered<LocalizationService>()) return fallback;
  final v = sl<LocalizationService>().translate(key);
  return v == key ? fallback : v;
}

/// [pemT] + `{{param}}` / `{param}` yer tutucu ikamesi (web ngx-translate biçimi).
String pemTp(String key, String fallback, Map<String, Object?> params) {
  var text = pemT(key, fallback);
  params.forEach((k, v) {
    final s = v?.toString() ?? '';
    text = text.replaceAll('{{$k}}', s).replaceAll('{$k}', s);
  });
  return text;
}

/// Tesisat (utility_type) etiketi: `energy.utility.<code>` (web ile aynı
/// anahtarlar), yoksa okunur kod.
String pemUtilityLabel(String? code) {
  final c = (code ?? '').trim();
  if (c.isEmpty) return '—';
  return pemT('energy.utility.$c', EntityStatusLabels.humanize(c));
}

/// UI dilinin sayı biçimi yereli (tarih/sayı biçimi UI diline bağlı;
/// en → en-GB). LocalizationService yoksa / okunamazsa `tr`.
String pemNumberLocale() {
  try {
    if (!sl.isRegistered<LocalizationService>()) return 'tr';
    final lang = sl<LocalizationService>().currentLocale.languageCode;
    switch (lang) {
      case 'en':
        return 'en_GB';
      case 'de':
        return 'de';
      case 'it':
        return 'it';
      default:
        return 'tr';
    }
  } catch (_) {
    return 'tr';
  }
}

/// Binlik ayraçlı sayı (ondalık hane sayısı [decimals]).
String pemNum(num? v, {int decimals = 0}) {
  if (v == null) return '—';
  final f = NumberFormat.decimalPatternDigits(
      locale: pemNumberLocale(), decimalDigits: decimals);
  return f.format(v);
}

/// kWh değeri — birim sabit, sayı binlik ayraçlı (web `format() + ' kWh'`).
String pemKwh(num? v) => v == null ? '—' : '${pemNum(v)} kWh';

/// `2026-11-05T11:00:00Z` → `05.11.2026 11:00` (UTC'den yerel saate).
String pemDateTime(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  if (d == null) return '—';
  return DateFormat('dd.MM.yyyy HH:mm').format(d.toLocal());
}

/// `2026-11-05T00:00:00Z` → `05.11` (grafik ekseni / gün listesi).
String pemDayLabel(DateTime d) => DateFormat('dd.MM').format(d);

/// UTC gün → `05.11.2026`.
String pemDate(DateTime d) => DateFormat('dd.MM.yyyy').format(d);

/// `2026-11-01T00:00:00Z` → `11.2026`.
String pemMonthLabel(DateTime d) => DateFormat('MM.yyyy').format(d);

/// Gün başı (UTC) — sorgu pencereleri web ile aynı biçimde UTC'dir.
DateTime pemUtcDay(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// Sayısal hücre: num | String | null → double? (PostgREST numeric = String
/// ya da num gelebilir).
double? pemD(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}
