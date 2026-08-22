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

  /// Tenant-yerel tarih: `05.01.2026`.
  static String date(DateTime dt) {
    final t = toTenant(dt);
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
    final t = toTenant(dt);
    return '${_trDays[t.weekday - 1]}, ${t.day} ${_trMonths[t.month - 1]}';
  }
}
