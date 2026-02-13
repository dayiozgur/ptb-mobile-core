/// IoT Sistemi Konfigürasyon Sabitleri
///
/// Alarm, log ve diğer IoT servislerinde kullanılan
/// merkezi konfigürasyon değerleri.
///
/// Bu değerler ileride artırılabilir (örn: 1 yıla kadar).
/// Değişiklik yapmak için sadece bu dosyayı güncellemek yeterlidir.
class IoTConfig {
  IoTConfig._();

  // ============================================
  // ZAMAN ARALIĞI LİMİTLERİ
  // ============================================

  /// Maksimum gün aralığı (tüm IoT sorgulamaları için)
  ///
  /// Alarm timeline, log zaman serisi, distribution sorguları vb.
  /// için kullanılan üst limit.
  ///
  /// NOT: Bu değer artırıldığında veritabanı performansı
  /// ve mobil cihaz bellek kullanımı göz önünde bulundurulmalıdır.
  static const int maxDaysRange = 90;

  /// Varsayılan gün aralığı (kısa sorgular için)
  ///
  /// Log zaman serisi, istatistik sorguları için varsayılan değer.
  static const int defaultDaysRange = 7;

  /// Alarm timeline varsayılan gün aralığı
  static const int defaultAlarmTimelineDays = 30;

  /// Reset alarm sorgusu varsayılan gün aralığı
  static const int defaultResetAlarmDays = 90;

  /// Alarm distribution varsayılan gün aralığı
  static const int defaultAlarmDistributionDays = 90;

  // ============================================
  // SAYFALAMA LİMİTLERİ
  // ============================================

  /// Varsayılan liste limiti
  static const int defaultListLimit = 50;

  /// Maksimum liste limiti
  static const int maxListLimit = 500;

  /// Log zaman serisi maksimum veri noktası
  ///
  /// Performans optimizasyonu için chart'ta gösterilecek
  /// maksimum veri noktası sayısı. Aşıldığında sampling uygulanır.
  static const int maxTimeSeriesDataPoints = 500;

  // ============================================
  // CACHE SÜRELERİ (DAKİKA)
  // ============================================

  /// Alarm verisi cache süresi
  static const int alarmCacheMinutes = 5;

  /// Log verisi cache süresi
  static const int logCacheMinutes = 5;

  /// Realtime verisi cache süresi
  static const int realtimeCacheMinutes = 2;

  // ============================================
  // YARDIMCI METODLAR
  // ============================================

  /// Gün aralığını geçerli limite sınırla
  ///
  /// [days] değeri 1 ile [maxDaysRange] arasında olmalıdır.
  static int clampDaysRange(int days) {
    return days.clamp(1, maxDaysRange);
  }

  /// Liste limitini geçerli aralığa sınırla
  static int clampListLimit(int limit) {
    return limit.clamp(1, maxListLimit);
  }
}
