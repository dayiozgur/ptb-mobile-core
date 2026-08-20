/// Alarm istatistik modelleri
///
/// Chart ve dashboard widget'ları için kullanılan veri yapıları.
/// Aktif alarmlar: alarms tablosu, Resetli alarmlar: alarm_histories tablosu.

/// Server-side KPI özeti (fn_pms_kpi_summary çıktısı)
///
/// Tüm agregasyon sunucuda `alarm_histories` + `alarms` üzerinden yapılır;
/// client tarafında satır taraması yapılmaz. İmza sürüklenmesinde (drift)
/// RPC çağrısı hata fırlatır → sessiz 0 dashboard yerine görünür hata.
class AlarmKpiSummary {
  final int totalAlarms;
  final int activeAlarms;
  final int resolvedAlarms;

  /// Ortalama çözüm süresi (saat) - MTTR
  final double avgResolutionHours;

  final int criticalCount;
  final int highCount;
  final int mediumCount;
  final int lowCount;
  final int distinctSitesAffected;
  final int distinctControllersAffected;

  const AlarmKpiSummary({
    this.totalAlarms = 0,
    this.activeAlarms = 0,
    this.resolvedAlarms = 0,
    this.avgResolutionHours = 0,
    this.criticalCount = 0,
    this.highCount = 0,
    this.mediumCount = 0,
    this.lowCount = 0,
    this.distinctSitesAffected = 0,
    this.distinctControllersAffected = 0,
  });

  static const AlarmKpiSummary empty = AlarmKpiSummary();

  factory AlarmKpiSummary.fromRow(Map<String, dynamic> row) {
    int i(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    double d(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return AlarmKpiSummary(
      totalAlarms: i(row['total_alarms']),
      activeAlarms: i(row['active_alarms']),
      resolvedAlarms: i(row['resolved_alarms']),
      avgResolutionHours: d(row['avg_resolution_hours']),
      criticalCount: i(row['critical_count']),
      highCount: i(row['high_count']),
      mediumCount: i(row['medium_count']),
      lowCount: i(row['low_count']),
      distinctSitesAffected: i(row['distinct_sites_affected']),
      distinctControllersAffected: i(row['distinct_controllers_affected']),
    );
  }

  @override
  String toString() =>
      'AlarmKpiSummary(total: $totalAlarms, active: $activeAlarms, resolved: $resolvedAlarms, mttrH: $avgResolutionHours)';
}

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

/// Site bazlı alarm sayısı (ranking chart verisi)
class SiteAlarmCount {
  final String siteId;
  final String siteName;
  final int resetCount;
  final int activeCount;

  int get totalCount => resetCount + activeCount;

  const SiteAlarmCount({
    required this.siteId,
    required this.siteName,
    this.resetCount = 0,
    this.activeCount = 0,
  });

  @override
  String toString() =>
      'SiteAlarmCount($siteName, active: $activeCount, reset: $resetCount)';
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

/// Controller uptime / kullanılabilirlik girişi (fn_pms_controller_uptime çıktısı)
///
/// Belirli bir dönemde controller bazlı alarm sayısı, toplam alarm süresi ve
/// yüzde kullanılabilirlik (availability). Tüm agregasyon sunucuda yapılır.
class ControllerUptime {
  final String controllerId;
  final String controllerName;
  final String? siteName;
  final int alarmCount;
  final double totalAlarmMinutes;

  /// Kullanılabilirlik yüzdesi (0-100)
  final double availabilityPct;

  const ControllerUptime({
    required this.controllerId,
    required this.controllerName,
    this.siteName,
    this.alarmCount = 0,
    this.totalAlarmMinutes = 0,
    this.availabilityPct = 0,
  });

  factory ControllerUptime.fromRow(Map<String, dynamic> row) {
    int i(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    double d(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return ControllerUptime(
      controllerId: row['controller_id']?.toString() ?? '',
      controllerName: row['controller_name']?.toString() ?? '',
      siteName: row['site_name']?.toString(),
      alarmCount: i(row['alarm_count']),
      totalAlarmMinutes: d(row['total_alarm_minutes']),
      availabilityPct: d(row['availability_pct']),
    );
  }

  @override
  String toString() =>
      'ControllerUptime($controllerName, availability: $availabilityPct%)';
}

/// Provider sağlık skoru girişi (fn_pms_provider_health çıktısı)
///
/// Provider (veri sağlayıcı) bazlı alarm sayısı, kritik sayısı, son alarm zamanı
/// ve 0-100 arası sağlık skoru. Tüm agregasyon sunucuda yapılır.
class ProviderHealth {
  final String providerId;
  final String providerName;
  final int alarmCount;
  final int criticalCount;
  final DateTime? lastAlarmAt;

  /// Sağlık skoru (0-100, yüksek = iyi)
  final double healthScore;

  const ProviderHealth({
    required this.providerId,
    required this.providerName,
    this.alarmCount = 0,
    this.criticalCount = 0,
    this.lastAlarmAt,
    this.healthScore = 0,
  });

  factory ProviderHealth.fromRow(Map<String, dynamic> row) {
    int i(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    double d(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    final rawLast = row['last_alarm_at'];
    return ProviderHealth(
      providerId: row['provider_id']?.toString() ?? '',
      providerName: row['provider_name']?.toString() ?? '',
      alarmCount: i(row['alarm_count']),
      criticalCount: i(row['critical_count']),
      lastAlarmAt: rawLast != null ? DateTime.tryParse(rawLast.toString()) : null,
      healthScore: d(row['health_score']),
    );
  }

  @override
  String toString() =>
      'ProviderHealth($providerName, score: $healthScore, alarms: $alarmCount)';
}
