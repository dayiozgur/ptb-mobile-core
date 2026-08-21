/// Takvimde bir kişinin izin aralığını temsil eden satır — `leave_requests`
/// tablosundan (approved + pending) türetilir.
///
/// Web `LeaveService.getTeamRequests` ile birebir sözleşme: satırlar
///   `status in (approved, pending)` AND `start_date <= to` AND `end_date >= from`
/// ile çekilir; kapsam RLS ile belirlenir (çalışan → kendi + astları/organizasyonu,
/// yönetici → ekip, admin → tüm tenant). Embed'ler:
///   `leave_types(name)`                       → [leaveTypeName]
///   `staffs!leave_requests_staff_id_fkey`     → [staffName]
class LeaveCalendarEntry {
  final String id;
  final String? staffId;

  /// İzni alan kişinin görünen adı — embed'den çözülür (ad+soyad, yoksa `name`).
  final String? staffName;

  final String? leaveTypeId;

  /// İzin türü adı — embed'den çözülür.
  final String? leaveTypeName;

  final DateTime? startDate;
  final DateTime? endDate;
  final num dayCount;

  /// `approved` | `pending` (takvim yalnızca bu ikisini çeker).
  final String? status;

  const LeaveCalendarEntry({
    required this.id,
    this.staffId,
    this.staffName,
    this.leaveTypeId,
    this.leaveTypeName,
    this.startDate,
    this.endDate,
    this.dayCount = 0,
    this.status,
  });

  /// Belirli bir [day] (tarih-only) bu izin aralığına giriyor mu?
  bool coversDay(DateTime day) {
    final s = startDate, e = endDate;
    if (s == null || e == null) return false;
    final d = DateTime(day.year, day.month, day.day);
    final ds = DateTime(s.year, s.month, s.day);
    final de = DateTime(e.year, e.month, e.day);
    return !d.isBefore(ds) && !d.isAfter(de);
  }

  factory LeaveCalendarEntry.fromJson(Map<String, dynamic> json) {
    return LeaveCalendarEntry(
      id: json['id'] as String,
      staffId: json['staff_id'] as String?,
      staffName: _staffFullName(json['staffs']),
      leaveTypeId: json['leave_type_id'] as String?,
      leaveTypeName: _embeddedName(json['leave_types']),
      startDate: _parseDate(json['start_date']),
      endDate: _parseDate(json['end_date']),
      dayCount: (json['day_count'] as num?) ?? 0,
      status: json['status'] as String?,
    );
  }

  static DateTime? _parseDate(dynamic v) =>
      v is String ? DateTime.tryParse(v) : null;

  /// PostgREST many-to-one embed'i obje (bazı yapılarda dizi) döndürür.
  static String? _embeddedName(dynamic rel) {
    if (rel == null) return null;
    if (rel is List) {
      if (rel.isEmpty) return null;
      final first = rel.first;
      return first is Map ? first['name'] as String? : null;
    }
    if (rel is Map) return rel['name'] as String?;
    return null;
  }

  /// Embed edilmiş staff ilişkisinden görünen ad (ad+soyad, yoksa `name`).
  static String? _staffFullName(dynamic rel) {
    final s = rel is List ? (rel.isEmpty ? null : rel.first) : rel;
    if (s is! Map) return null;
    final first = s['first_name'] as String?;
    final last = s['last_name'] as String?;
    final full = [first, last].where((e) => e != null && e.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;
    return s['name'] as String?;
  }
}
