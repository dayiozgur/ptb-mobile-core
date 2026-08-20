import 'package:intl/intl.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// PHR ESS ekranları için ortak yardımcılar (i18n + biçimlendirme).
///
/// Tarih/sayı biçimlendirmesi Türk pazarı (LOCALE_ID=tr-TR) ile tutarlıdır.
/// NOT: `intl` tarih-locale verisi `initializeDateFormatting` olmadan
/// yüklenmediği için tarihler MANUEL biçimlenir (Türkçe ay adları burada).
/// Sayı sembolleri intl'e gömülü olduğundan `NumberFormat(..., 'tr_TR')` güvenli.

/// i18n çeviri — anahtar bulunamazsa (translate anahtarı geri döndürür)
/// Türkçe [fallback] gösterilir.
String essT(String key, String fallback) {
  final v = sl<LocalizationService>().translate(key);
  return v == key ? fallback : v;
}

const List<String> _trMonths = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

final NumberFormat _moneyFmt = NumberFormat('#,##0.00', 'tr_TR');

/// Para birimi — `₺1.234,56` (Türk biçimi).
String essMoney(num value) => '₺${_moneyFmt.format(value)}';

/// Kısa tarih — `gg.aa.yyyy`.
String essDate(DateTime? d) {
  if (d == null) return '-';
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd.$mm.${d.year}';
}

/// Tarih aralığı — `gg.aa.yyyy → gg.aa.yyyy` (tek gün ise tek tarih).
String essDateRange(DateTime? start, DateTime? end) {
  if (start == null && end == null) return '-';
  if (start == null) return essDate(end);
  if (end == null || _sameDay(start, end)) return essDate(start);
  return '${essDate(start)} → ${essDate(end)}';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Ay + yıl — `Ağustos 2026`.
String essMonthYear(int? year, int? month) {
  if (year == null || month == null || month < 1 || month > 12) {
    return [month, year].where((e) => e != null).join('/');
  }
  return '${_trMonths[month - 1]} $year';
}

/// Saat/dakika biçimi — dakikadan `Xs Ydk` (ör. 90 → `1s 30dk`).
String essDuration(int minutes) {
  if (minutes <= 0) return '0dk';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}dk';
  if (m == 0) return '${h}s';
  return '${h}s ${m}dk';
}

/// Saat — `HH:mm`.
String essTime(DateTime? d) {
  if (d == null) return '-';
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

/// Durum kodunu Türkçe etikete çevir (bulunamazsa kodun kendisi).
String essStatusLabel(String? status) {
  switch (status?.toLowerCase()) {
    case 'pending':
      return essT('common.pending', 'Beklemede');
    case 'approved':
      return essT('common.approved', 'Onaylandı');
    case 'rejected':
      return essT('common.rejected', 'Reddedildi');
    case 'cancelled':
    case 'canceled':
      return essT('common.cancelled', 'İptal edildi');
    case 'completed':
    case 'done':
      return essT('common.completed', 'Tamamlandı');
    case 'in_progress':
    case 'in-progress':
      return essT('common.in_progress', 'Devam ediyor');
    case 'todo':
    case 'open':
    case 'new':
      return essT('common.todo', 'Yapılacak');
    default:
      return status ?? '-';
  }
}

/// Durum → rozet varyantı (list/entity ekranıyla tutarlı).
AppBadgeVariant essStatusVariant(String? status) {
  switch (status?.toLowerCase()) {
    case 'approved':
    case 'completed':
    case 'done':
    case 'active':
      return AppBadgeVariant.success;
    case 'pending':
    case 'todo':
    case 'open':
    case 'new':
    case 'in_progress':
    case 'in-progress':
      return AppBadgeVariant.info;
    case 'on_hold':
    case 'waiting':
    case 'review':
      return AppBadgeVariant.warning;
    case 'cancelled':
    case 'canceled':
    case 'rejected':
    case 'failed':
      return AppBadgeVariant.error;
    default:
      return AppBadgeVariant.neutral;
  }
}
