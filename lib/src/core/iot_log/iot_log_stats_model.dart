/// IoT Log istatistik modelleri
///
/// Chart ve dashboard widget'ları için kullanılan veri yapıları.
/// logs tablosundaki kayıtların zaman serisi ve istatistik formuna dönüşümü.

/// Zaman serisi log verisi (line chart data noktası)
///
/// IoTLog.value String → double parse ile dönüştürülmüş hali.
class LogTimeSeriesEntry {
  final DateTime dateTime;

  /// Numerik değer (IoTLog.value'dan parse edilmiş)
  final double? value;

  /// On/Off durumu (0 veya 1)
  final int? onOff;

  /// Ham string değer (parse edilemezse kullanılır)
  final String? rawValue;

  const LogTimeSeriesEntry({
    required this.dateTime,
    this.value,
    this.onOff,
    this.rawValue,
  });

  /// Geçerli numerik değere sahip mi?
  bool get hasNumericValue => value != null;

  /// On/Off bilgisine sahip mi?
  bool get hasOnOff => onOff != null;

  @override
  String toString() =>
      'LogTimeSeriesEntry(${dateTime.toIso8601String()}, value: $value, onOff: $onOff)';
}

/// Log değer istatistikleri (metric card verisi)
///
/// Belirli bir controller/variable için log değerlerinin özet istatistikleri.
class LogValueStats {
  final double? minValue;
  final double? maxValue;
  final double? avgValue;
  final double? lastValue;
  final int totalCount;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const LogValueStats({
    this.minValue,
    this.maxValue,
    this.avgValue,
    this.lastValue,
    this.totalCount = 0,
    this.firstDate,
    this.lastDate,
  });

  /// Değer aralığı
  double? get range =>
      (minValue != null && maxValue != null) ? maxValue! - minValue! : null;

  /// Veri var mı?
  bool get hasData => totalCount > 0;

  @override
  String toString() =>
      'LogValueStats(min: $minValue, max: $maxValue, avg: $avgValue, count: $totalCount)';
}
