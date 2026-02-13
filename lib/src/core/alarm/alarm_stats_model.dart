/// Alarm istatistik modelleri
///
/// Chart ve dashboard widget'ları için kullanılan veri yapıları.
/// Aktif alarmlar: alarms tablosu, Resetli alarmlar: alarm_histories tablosu.

/// Günlük alarm zaman serisi girişi (bar chart verisi)
///
/// alarm_histories tablosundaki kayıtların güne göre gruplandırılmış hali.
/// Son 90 güne kadar desteklenir.
class AlarmTimelineEntry {
  final DateTime date;
  final int totalCount;
  final Map<String, int> countByPriority;

  const AlarmTimelineEntry({
    required this.date,
    required this.totalCount,
    this.countByPriority = const {},
  });

  @override
  String toString() =>
      'AlarmTimelineEntry(${date.toIso8601String()}, total: $totalCount)';
}

/// Alarm durum dağılımı (pie/donut chart verisi)
///
/// activeCount: alarms tablosundan (aktif alarmlar)
/// resetCount: alarm_histories tablosundan (resetli/kapanmış alarmlar)
class AlarmDistribution {
  /// Aktif alarm sayısı (alarms tablosu, active = true)
  final int activeCount;

  /// Resetli alarm sayısı (alarm_histories tablosu)
  final int resetCount;

  /// Onaylanmış alarm sayısı
  final int acknowledgedCount;

  /// Priority bazlı aktif alarm dağılımı
  /// Key: priority_id, Value: alarm sayısı
  final Map<String, int> activeByPriority;

  /// Priority bazlı reset alarm dağılımı
  /// Key: priority_id, Value: alarm sayısı
  final Map<String, int> resetByPriority;

  /// Toplam
  int get totalCount => activeCount + resetCount;

  const AlarmDistribution({
    required this.activeCount,
    required this.resetCount,
    this.acknowledgedCount = 0,
    this.activeByPriority = const {},
    this.resetByPriority = const {},
  });

  /// Priority bazlı dağılım var mı?
  bool get hasPriorityDistribution =>
      activeByPriority.isNotEmpty || resetByPriority.isNotEmpty;

  /// Aktif yüzde
  double get activePercent =>
      totalCount > 0 ? (activeCount / totalCount) * 100 : 0;

  /// Reset yüzde
  double get resetPercent =>
      totalCount > 0 ? (resetCount / totalCount) * 100 : 0;

  @override
  String toString() =>
      'AlarmDistribution(active: $activeCount, reset: $resetCount, ack: $acknowledgedCount)';
}
