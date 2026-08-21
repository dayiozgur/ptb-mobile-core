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
}
