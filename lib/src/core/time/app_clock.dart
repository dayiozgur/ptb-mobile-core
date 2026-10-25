import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../utils/logger.dart';

/// **Tenant-timezone farkındalıklı saat** — sunucu UTC saklar; iş zaman damgaları
/// (PDKS giriş/çıkış vb.) **tenant'ın saat dilimine** ([tenants.time_zone])
/// çevrilerek gösterilir. Böylece farklı ülkelerdeki tenant'lar kendi yerel
/// saatlerini görür (çok-timezone SaaS). DST-doğru (IANA tz veritabanı).
///
/// Kullanım:
/// - Başlangıçta [ensureInit] (tz veritabanını yükler).
/// - Tenant çözülünce [setZone] (`tenant.timeZone`).
/// - Gösterimde [toTenant] ile UTC → tenant-yerel çevir.
class AppClock {
  AppClock._();

  static const String _defaultZone = 'Europe/Istanbul';
  static bool _ready = false;
  static tz.Location? _loc;

  /// tz veritabanını yükle (idempotent) + varsayılan bölge.
  static void ensureInit() {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      _ready = true;
      _loc = tz.getLocation(_defaultZone);
    } catch (e) {
      Logger.warning('AppClock init hata: $e');
    }
  }

  /// Aktif tenant saat dilimini ayarla (ör. 'Europe/Istanbul'). Geçersizse varsayılan.
  static void setZone(String? ianaName) {
    ensureInit();
    final name = (ianaName != null && ianaName.trim().isNotEmpty)
        ? ianaName.trim()
        : _defaultZone;
    try {
      _loc = tz.getLocation(name);
    } catch (e) {
      Logger.warning('AppClock geçersiz zaman dilimi "$name" → $_defaultZone');
      try {
        _loc = tz.getLocation(_defaultZone);
      } catch (_) {}
    }
  }

  /// Aktif bölgenin IANA adı.
  static String get zoneName => _loc?.name ?? _defaultZone;

  /// Bir zaman damgasını tenant saat dilimine çevir. Girdi UTC değilse UTC'ye
  /// normalize edilir. Bölge yüklenmemişse aynen döner (bozmaz).
  static DateTime toTenant(DateTime dt) {
    ensureInit();
    final loc = _loc;
    if (loc == null) return dt;
    final utc = dt.isUtc ? dt : dt.toUtc();
    return tz.TZDateTime.from(utc, loc);
  }

  /// Tenant-yerel takvim günü `yyyy-MM-dd` (DST-doğru). PDKS `work_date` gibi
  /// iş-günü anahtarları cihaz saat dilimine göre DEĞİL, tenant'ın saat dilimine
  /// göre hesaplanmalı — sunucu `fn_pdks_geo_punch` da `now() AT TIME ZONE
  /// tenants.time_zone` kullanır (fallback Europe/Istanbul).
  static String ymd(DateTime dt) {
    final t = toTenant(dt);
    return '${t.year.toString().padLeft(4, '0')}-${_p2(t.month)}-${_p2(t.day)}';
  }

  /// Bugünün tenant-yerel tarihi (`yyyy-MM-dd`). [now] test içindir.
  static String todayYmd([DateTime? now]) => ymd(now ?? DateTime.now().toUtc());

  /// Tenant-yerel bugünün takvim günü — saatsiz, `DateTime(y, m, d)` (ay/aralık
  /// hesapları için; cihaz-yerel `DateTime.now()` gece yarısı civarında kayar).
  static DateTime todayDate([DateTime? now]) {
    final t = toTenant(now ?? DateTime.now().toUtc());
    return DateTime(t.year, t.month, t.day);
  }

  // ---------------------------------------------------------------------------
  // Formatlama — hepsi ÖNCE tenant-yerele çevirir. Önceden ~10 ekranda elle
  // padLeft ile tekrarlanıyordu; tek kaynak (tenant-tz garantili).
  // ---------------------------------------------------------------------------

  static const List<String> _trMonths = [
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];
  static const List<String> _trDays = [
    'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz',
  ];

  static String _p2(int n) => n.toString().padLeft(2, '0');

  /// `yyyy-MM-dd` gibi saatsiz bir takvim günü mü? (`DateTime.parse('2026-10-25')`
  /// yerel gece yarısı üretir.) Takvim günleri saat dilimine çevrilmemeli —
  /// çevrilirse cihaz ile tenant arasındaki ofset kadar bir gün kayabilir.
  /// Sunucu zaman damgaları (`timestamptz`) UTC olarak parse edilir → false.
  static bool isCalendarDate(DateTime dt) =>
      !dt.isUtc &&
      dt.hour == 0 &&
      dt.minute == 0 &&
      dt.second == 0 &&
      dt.millisecond == 0 &&
      dt.microsecond == 0;

  /// Tenant-yerel tarih: `05.01.2026`. Takvim günleri ([isCalendarDate])
  /// olduğu gibi gösterilir.
  static String date(DateTime dt) {
    final t = isCalendarDate(dt) ? dt : toTenant(dt);
    return '${_p2(t.day)}.${_p2(t.month)}.${t.year}';
  }

  /// Tenant-yerel saat: `14:30`.
  static String hm(DateTime dt) {
    final t = toTenant(dt);
    return '${_p2(t.hour)}:${_p2(t.minute)}';
  }

  /// Tenant-yerel tarih + saat: `05.01.2026 14:30`.
  static String dateTime(DateTime dt) => '${date(dt)} ${hm(dt)}';

  /// Kısa gün etiketi (tr): `Pzt, 5 Oca`.
  static String dayLabel(DateTime dt) {
    final t = isCalendarDate(dt) ? dt : toTenant(dt);
    return '${_trDays[t.weekday - 1]}, ${t.day} ${_trMonths[t.month - 1]}';
  }

  /// Tenant-yerel saniyeli saat: `14:30:05`.
  static String hms(DateTime dt) {
    final t = toTenant(dt);
    return '${_p2(t.hour)}:${_p2(t.minute)}:${_p2(t.second)}';
  }

  /// Tenant-yerel tarih + saniyeli saat: `05.01.2026 14:30:05`.
  static String dateTimeSeconds(DateTime dt) => '${date(dt)} ${hms(dt)}';

  /// Tenant-yerel kısa gün + saat: `05.01 14:30` (liste satırları).
  static String shortDateTime(DateTime dt) {
    final t = toTenant(dt);
    return '${_p2(t.day)}.${_p2(t.month)} ${_p2(t.hour)}:${_p2(t.minute)}';
  }

  /// Tenant-yerel takvim gününe göre göreli damga: bugün → `[today] 14:30`,
  /// dün → `[yesterday] 14:30`, aksi halde [shortDateTime]. Gün sınırı CİHAZ
  /// değil tenant saat dilimine göre hesaplanır. [now] test içindir.
  static String relativeDayTime(
    DateTime dt, {
    required String today,
    required String yesterday,
    DateTime? now,
  }) {
    final d = todayDate(dt);
    final n = todayDate(now ?? DateTime.now().toUtc());
    final days = DateTime.utc(n.year, n.month, n.day)
        .difference(DateTime.utc(d.year, d.month, d.day))
        .inDays;
    if (days == 0) return '$today ${hm(dt)}';
    if (days == 1) return '$yesterday ${hm(dt)}';
    return shortDateTime(dt);
  }

  /// Tenant-yerel zamanı intl [pattern] ile biçimle (ör. `dd/MM HH:mm:ss`).
  static String format(DateTime dt, String pattern) =>
      DateFormat(pattern).format(_naive(toTenant(dt)));

  /// TZDateTime'ı aynı duvar-saati değerleriyle düz DateTime'a çevirir
  /// (intl DateFormat cihaz ofsetini uygulamasın).
  static DateTime _naive(DateTime t) => DateTime(
      t.year, t.month, t.day, t.hour, t.minute, t.second, t.millisecond);
}

/// `intl.DateFormat` benzeri, ÖNCE tenant saat dilimine çeviren biçimleyici —
/// ekranlarda `DateFormat(...)` yerine (cihaz saat dilimi kullanılmasın).
class TenantDateFormat {
  const TenantDateFormat(this.pattern);

  final String pattern;

  String format(DateTime dt) => AppClock.format(dt, pattern);
}
