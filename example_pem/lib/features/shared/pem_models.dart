import '../../pem_common.dart';

/// Toplanmış tüketim noktası (bucket_start · utility) —
/// `fn_energy_consumption_rollup` satırı.
class ConsumptionTrendPoint {
  final DateTime bucketStart;
  final String utilityType;
  final double totalKwh;
  final double totalCost;
  final double? avgPeakKw;
  final int readingCount;

  const ConsumptionTrendPoint({
    required this.bucketStart,
    required this.utilityType,
    required this.totalKwh,
    required this.totalCost,
    this.avgPeakKw,
    this.readingCount = 0,
  });

  static ConsumptionTrendPoint? fromRow(Map<String, dynamic> r) {
    final at = DateTime.tryParse(r['bucket_start']?.toString() ?? '');
    if (at == null) return null;
    return ConsumptionTrendPoint(
      bucketStart: at.toUtc(),
      utilityType: (r['utility_type'] as String?) ?? 'electricity',
      totalKwh: pemD(r['total_kwh']) ?? 0,
      totalCost: pemD(r['total_cost']) ?? 0,
      avgPeakKw: pemD(r['avg_peak_kw']),
      readingCount: (pemD(r['reading_count']) ?? 0).round(),
    );
  }
}

/// Boyut dilimi (utility ya da saha) — `fn_pms_energy_by_dimension` satırı.
class EnergyDimensionSlice {
  final String label;
  final double totalKwh;
  final double totalCost;
  final double pct;

  const EnergyDimensionSlice({
    required this.label,
    required this.totalKwh,
    required this.totalCost,
    required this.pct,
  });

  factory EnergyDimensionSlice.fromRow(Map<String, dynamic> r) =>
      EnergyDimensionSlice(
        label: (r['label'] as String?) ?? '—',
        totalKwh: pemD(r['total_kwh']) ?? 0,
        totalCost: pemD(r['total_cost']) ?? 0,
        pct: pemD(r['pct']) ?? 0,
      );
}

/// Grafik için dönem başına toplam kWh.
class PeriodValue {
  final DateTime period;
  final double value;
  const PeriodValue(this.period, this.value);
}

/// Saha (sites satırı + varsa benchmark sonucu).
class PemSite {
  final String id;
  final String name;
  final String? code;
  final String? city;

  /// `fn_energy_site_benchmark` sonuçları (saha ölçümlü değilse null).
  final double? consumptionKwh;
  final double? intensityKwhPerDd;
  final int? rank;
  final String? validity;

  const PemSite({
    required this.id,
    required this.name,
    this.code,
    this.city,
    this.consumptionKwh,
    this.intensityKwhPerDd,
    this.rank,
    this.validity,
  });

  PemSite withBenchmark(Map<String, dynamic>? b) => b == null
      ? this
      : PemSite(
          id: id,
          name: name,
          code: code,
          city: city,
          consumptionKwh: pemD(b['consumption_kwh']),
          intensityKwhPerDd: pemD(b['intensity_kwh_per_dd']),
          rank: pemD(b['rank'])?.round(),
          validity: b['validity']?.toString(),
        );
}

/// Bir sahanın günlük tüketimi (o günün tüm sayaç/utility'lerinin toplamı).
class DailyConsumption {
  final DateTime day;
  final double kwh;
  final double cost;
  final double? peakKw;
  const DailyConsumption(
      {required this.day, required this.kwh, required this.cost, this.peakKw});
}

/// Sayaç (`energy_meters`).
class PemMeter {
  final String id;
  final String? siteId;
  final String? controllerId;
  final String? utilityType;
  final String? meterRole;
  final String? unit;
  final String? readingKind;
  final String? source;
  final double? lastValue;
  final String? lastValueAt;
  final bool isSiteMain;

  const PemMeter({
    required this.id,
    this.siteId,
    this.controllerId,
    this.utilityType,
    this.meterRole,
    this.unit,
    this.readingKind,
    this.source,
    this.lastValue,
    this.lastValueAt,
    this.isSiteMain = false,
  });

  factory PemMeter.fromRow(Map<String, dynamic> r) => PemMeter(
        id: r['id']?.toString() ?? '',
        siteId: r['site_id']?.toString(),
        controllerId: r['controller_id']?.toString(),
        utilityType: r['utility_type']?.toString(),
        meterRole: r['meter_role']?.toString(),
        unit: r['unit']?.toString(),
        readingKind: r['reading_kind']?.toString(),
        source: r['source']?.toString(),
        lastValue: pemD(r['last_value']),
        lastValueAt: r['last_value_at']?.toString(),
        isSiteMain: r['is_site_main'] == true,
      );

  /// Telemetri (controller bağlı) mı yoksa manuel mi — web meter-management
  /// ile aynı kural: `controller_id` doluysa telemetri.
  bool get isTelemetry => (controllerId ?? '').isNotEmpty;
}

/// Haftanın günü yük profili (`fn_energy_load_profile` satırı).
class LoadProfilePoint {
  final int dow; // 0 = Pazar … 6 = Cumartesi (Postgres EXTRACT(DOW))
  final double avgConsumptionKwh;
  final double maxPeakDemandKw;
  final double totalConsumptionKwh;
  final int dayCount;

  const LoadProfilePoint({
    required this.dow,
    required this.avgConsumptionKwh,
    required this.maxPeakDemandKw,
    required this.totalConsumptionKwh,
    required this.dayCount,
  });

  factory LoadProfilePoint.fromRow(Map<String, dynamic> r) => LoadProfilePoint(
        dow: (pemD(r['dow']) ?? 0).round(),
        avgConsumptionKwh: pemD(r['avg_consumption_kwh']) ?? 0,
        maxPeakDemandKw: pemD(r['max_peak_demand_kw']) ?? 0,
        totalConsumptionKwh: pemD(r['total_consumption_kwh']) ?? 0,
        dayCount: (pemD(r['day_count']) ?? 0).round(),
      );
}

/// Anomali tespit penceresindeki bir gün
/// (`fn_energy_consumption_anomalies` satırı).
class AnomalyPoint {
  final DateTime day;
  final double? actualKwh;
  final double? predictedKwh;
  final double? deviationPct;
  final double? zScore;
  final bool isAnomaly;

  const AnomalyPoint({
    required this.day,
    this.actualKwh,
    this.predictedKwh,
    this.deviationPct,
    this.zScore,
    this.isAnomaly = false,
  });

  static AnomalyPoint? fromRow(Map<String, dynamic> r) {
    final d = DateTime.tryParse(r['period_day']?.toString() ?? '');
    if (d == null) return null;
    return AnomalyPoint(
      day: d.toUtc(),
      actualKwh: pemD(r['actual_kwh']),
      predictedKwh: pemD(r['predicted_kwh']),
      deviationPct: pemD(r['deviation_pct']),
      zScore: pemD(r['z_score']),
      isAnomaly: r['is_anomaly'] == true,
    );
  }
}

/// Alarm önceliği (`priorities`).
class PemPriority {
  final String id;
  final String name;
  final String? code;
  final String? color;
  final int? level;

  const PemPriority(
      {required this.id, required this.name, this.code, this.color, this.level});

  factory PemPriority.fromRow(Map<String, dynamic> r) => PemPriority(
        id: r['id']?.toString() ?? '',
        name: r['name']?.toString() ?? '',
        code: r['code']?.toString(),
        color: r['color']?.toString(),
        level: pemD(r['level'])?.round(),
      );

  /// Etiket: `alarm.priority.<code küçük harf>` (PMS ile aynı anahtarlar),
  /// yoksa DB `name`.
  String get label {
    final c = (code ?? '').trim().toLowerCase();
    if (c.isEmpty) return name;
    return pemT('alarm.priority.$c', name.isEmpty ? c : name);
  }
}

/// Tetiklenen enerji alarmı (`alarms`, ENERGY_* kodu).
class PemAlarm {
  final String id;
  final String? name;
  final String? code;
  final String? description;
  final int? category;
  final String? status;
  final String? startTime;
  final String? priorityId;
  final String? siteId;
  final PemPriority? priority;

  const PemAlarm({
    required this.id,
    this.name,
    this.code,
    this.description,
    this.category,
    this.status,
    this.startTime,
    this.priorityId,
    this.siteId,
    this.priority,
  });

  factory PemAlarm.fromRow(Map<String, dynamic> r,
          {Map<String, PemPriority> priorities = const {}}) =>
      PemAlarm(
        id: r['id']?.toString() ?? '',
        name: r['name']?.toString(),
        code: r['code']?.toString(),
        description: r['description']?.toString(),
        category: pemD(r['category'])?.round(),
        status: r['status']?.toString(),
        startTime: r['start_time']?.toString(),
        priorityId: r['priority_id']?.toString(),
        siteId: r['site_id']?.toString(),
        priority: priorities[r['priority_id']?.toString()],
      );

  /// Kapalı değilse "açık" (web dedup kuralı: `status <> 'closed'`).
  bool get isOpen => (status ?? '').toLowerCase() != 'closed';

  /// Başlık: ad, yoksa kod.
  String get title {
    final n = (name ?? '').trim();
    if (n.isNotEmpty) return n;
    final c = (code ?? '').trim();
    return c.isEmpty ? '—' : c;
  }

  /// Durum etiketi: `status.<code>` anahtarı, yoksa okunur kod.
  String get statusLabel {
    final s = (status ?? '').trim().toLowerCase();
    if (s.isEmpty) return '—';
    return pemT('status.$s', s[0].toUpperCase() + s.substring(1));
  }
}
