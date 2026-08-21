/// Vardiya tanımı — `work_shifts` tablosu satırı (salt-okuma).
///
/// `startTime`/`endTime` `HH:mm` biçiminde tutulur (web `mapShift` gibi ilk 5
/// karakter). `daysOfWeek` ISO gün numaraları (1=Pzt .. 7=Paz).
class WorkShiftRow {
  final String id;
  final String name;
  final String? code;
  final String startTime; // HH:mm
  final String endTime; // HH:mm
  final int breakMinutes;
  final List<int> daysOfWeek;
  final bool active;

  const WorkShiftRow({
    required this.id,
    required this.name,
    this.code,
    this.startTime = '',
    this.endTime = '',
    this.breakMinutes = 0,
    this.daysOfWeek = const [],
    this.active = true,
  });

  factory WorkShiftRow.fromJson(Map<String, dynamic> json) {
    String hhmm(dynamic v) {
      final s = (v as String?) ?? '';
      return s.length >= 5 ? s.substring(0, 5) : s;
    }

    final dow = json['days_of_week'];
    return WorkShiftRow(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '—',
      code: json['code'] as String?,
      startTime: hhmm(json['start_time']),
      endTime: hhmm(json['end_time']),
      breakMinutes: (json['break_minutes'] as num?)?.toInt() ?? 0,
      daysOfWeek: dow is List
          ? dow.map((e) => (e as num).toInt()).toList()
          : const [],
      active: json['active'] as bool? ?? true,
    );
  }
}
