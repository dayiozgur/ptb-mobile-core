/// Bir `leave_requests` satırının admin (tüm-tenant) görünümü.
///
/// ESS'teki [LeaveRequestRow]'dan farkı: talep sahibinin adını ([staffName]) ve
/// izin türü adını ([leaveTypeName]) doğrudan PostgREST embed'lerinden çözer —
/// web `LeaveService.REQUEST_SELECT` sözleşmesiyle birebir:
///   `leave_types(name)`,
///   `staffs!leave_requests_staff_id_fkey(name,first_name,last_name)`.
class AdminLeaveRequestRow {
  final String id;
  final String? staffId;

  /// Embed `staffs` → first+last, yoksa `name`.
  final String? staffName;
  final String? leaveTypeId;

  /// Embed `leave_types.name`.
  final String? leaveTypeName;
  final DateTime? startDate;
  final DateTime? endDate;
  final num dayCount;
  final bool halfDayStart;
  final bool halfDayEnd;
  final String? status;
  final String? note;
  final String? decisionNote;
  final DateTime? decidedAt;
  final DateTime? createdAt;

  const AdminLeaveRequestRow({
    required this.id,
    this.staffId,
    this.staffName,
    this.leaveTypeId,
    this.leaveTypeName,
    this.startDate,
    this.endDate,
    this.dayCount = 0,
    this.halfDayStart = false,
    this.halfDayEnd = false,
    this.status,
    this.note,
    this.decisionNote,
    this.decidedAt,
    this.createdAt,
  });

  /// Bekleyen (karar verilebilir) mi?
  bool get isPending => status?.toLowerCase() == 'pending';

  factory AdminLeaveRequestRow.fromJson(Map<String, dynamic> json) {
    DateTime? parse(dynamic v) =>
        v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

    return AdminLeaveRequestRow(
      id: json['id'] as String,
      staffId: json['staff_id'] as String?,
      staffName: _staffFullName(json['staffs']),
      leaveTypeId: json['leave_type_id'] as String?,
      leaveTypeName: _embeddedName(json['leave_types']),
      startDate: parse(json['start_date']),
      endDate: parse(json['end_date']),
      dayCount: (json['day_count'] as num?) ?? 0,
      halfDayStart: json['half_day_start'] as bool? ?? false,
      halfDayEnd: json['half_day_end'] as bool? ?? false,
      status: json['status'] as String?,
      note: json['note'] as String?,
      decisionNote: json['decision_note'] as String?,
      decidedAt: parse(json['decided_at']),
      createdAt: parse(json['created_at']),
    );
  }

  /// PostgREST many-to-one embed'i obje (bazı kurulumlarda tek elemanlı dizi)
  /// olarak döndürür — her ikisinden de `name` çıkar.
  static String? _embeddedName(dynamic rel) {
    if (rel is Map<String, dynamic>) return rel['name'] as String?;
    if (rel is List && rel.isNotEmpty) {
      final first = rel.first;
      if (first is Map<String, dynamic>) return first['name'] as String?;
    }
    return null;
  }

  /// Embed staff'tan görünen ad: first+last, yoksa `name`.
  static String? _staffFullName(dynamic rel) {
    final s = rel is List ? (rel.isNotEmpty ? rel.first : null) : rel;
    if (s is! Map<String, dynamic>) return null;
    final first = (s['first_name'] as String?)?.trim() ?? '';
    final last = (s['last_name'] as String?)?.trim() ?? '';
    final full = [first, last].where((e) => e.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;
    final name = (s['name'] as String?)?.trim();
    return (name != null && name.isNotEmpty) ? name : null;
  }
}
