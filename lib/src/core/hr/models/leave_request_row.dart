/// A single leave request row from the `leave_requests` table.
///
/// [leaveTypeName] yalnızca `leave_types` lookup çözülebildiğinde dolar;
/// aksi halde `null` kalır ve tüketici [leaveTypeId]'yi kullanabilir.
class LeaveRequestRow {
  final String id;
  final String? staffId;
  final String? leaveTypeId;
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

  const LeaveRequestRow({
    required this.id,
    this.staffId,
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

  factory LeaveRequestRow.fromJson(
    Map<String, dynamic> json, {
    String? leaveTypeName,
  }) {
    return LeaveRequestRow(
      id: json['id'] as String,
      staffId: json['staff_id'] as String?,
      leaveTypeId: json['leave_type_id'] as String?,
      leaveTypeName: leaveTypeName,
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'] as String)
          : null,
      dayCount: (json['day_count'] as num?) ?? 0,
      halfDayStart: json['half_day_start'] as bool? ?? false,
      halfDayEnd: json['half_day_end'] as bool? ?? false,
      status: json['status'] as String?,
      note: json['note'] as String?,
      decisionNote: json['decision_note'] as String?,
      decidedAt: json['decided_at'] != null
          ? DateTime.tryParse(json['decided_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}
