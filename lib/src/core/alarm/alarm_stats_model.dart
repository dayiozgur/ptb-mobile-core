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

/// MTTR haftalık trend girişi
class MttrTrendEntry {
  final DateTime date;
  final Duration avgMttr;
  final int alarmCount;

  const MttrTrendEntry({
    required this.date,
    required this.avgMttr,
    required this.alarmCount,
  });

  @override
  String toString() =>
      'MttrTrendEntry(${date.toIso8601String()}, mttr: ${avgMttr.inMinutes}dk, count: $alarmCount)';
}

/// MTTR (Mean Time To Resolve) istatistikleri
///
/// alarm_histories tablosundan end_time - start_time farkı üzerinden hesaplanır.
class AlarmMttrStats {
  final Duration overallMttr;
  final Map<String, Duration> mttrByPriority;
  final List<MttrTrendEntry> trend;
  final int totalAlarmCount;

  const AlarmMttrStats({
    required this.overallMttr,
    this.mttrByPriority = const {},
    this.trend = const [],
    this.totalAlarmCount = 0,
  });

  /// Formatlanmış MTTR: "2g 3s" / "45dk" / "3s 12dk"
  String get overallMttrFormatted => formatDuration(overallMttr);

  /// Priority bazlı formatlanmış MTTR
  String mttrFormattedForPriority(String priorityId) {
    final d = mttrByPriority[priorityId];
    if (d == null) return '-';
    return formatDuration(d);
  }

  static String formatDuration(Duration d) {
    if (d.inDays > 0) return '${d.inDays}g ${d.inHours % 24}s';
    if (d.inHours > 0) return '${d.inHours}s ${d.inMinutes % 60}dk';
    return '${d.inMinutes}dk';
  }

  @override
  String toString() =>
      'AlarmMttrStats(mttr: $overallMttrFormatted, count: $totalAlarmCount)';
}

/// Sık tekrarlayan alarm girişi (Top N)
class AlarmFrequency {
  final String variableId;
  final String alarmName;
  final String? alarmCode;
  final String? priorityId;
  final int count;
  final DateTime lastOccurrence;

  const AlarmFrequency({
    required this.variableId,
    required this.alarmName,
    this.alarmCode,
    this.priorityId,
    required this.count,
    required this.lastOccurrence,
  });

  @override
  String toString() =>
      'AlarmFrequency($alarmName, count: $count)';
}

/// Saatlik alarm heatmap verisi (7 gün x 24 saat)
class AlarmHeatmapData {
  /// 7x24 matris: [günIndex][saatIndex] = alarm sayısı
  /// günIndex: 0=Pazartesi, 6=Pazar
  final List<List<int>> matrix;
  final int maxCount;
  final DateTime weekStart;

  const AlarmHeatmapData({
    required this.matrix,
    required this.maxCount,
    required this.weekStart,
  });

  int get totalCount {
    int sum = 0;
    for (final row in matrix) {
      for (final cell in row) {
        sum += cell;
      }
    }
    return sum;
  }

  @override
  String toString() =>
      'AlarmHeatmapData(week: ${weekStart.toIso8601String()}, total: $totalCount, max: $maxCount)';
}
