/// Bir dönemin (yıl/ay) puantaj-kilit (onay) durumu — `attendance_locks`
/// tablosundan türetilir.
///
/// Kilitli dönem = puantaj onaylanmış (bordroya kapatılmış). Onaysız dönemler
/// "onay bekliyor" olarak listelenir; web `PdksService.lockMonth` ile onaylanır.
class AttendanceLockRow {
  final int periodYear;
  final int periodMonth;
  final bool locked;
  final String? lockId;
  final DateTime? lockedAt;
  final String? lockedBy;

  const AttendanceLockRow({
    required this.periodYear,
    required this.periodMonth,
    this.locked = false,
    this.lockId,
    this.lockedAt,
    this.lockedBy,
  });

  factory AttendanceLockRow.fromJson(Map<String, dynamic> json) {
    return AttendanceLockRow(
      periodYear: (json['period_year'] as num).toInt(),
      periodMonth: (json['period_month'] as num).toInt(),
      locked: true,
      lockId: json['id'] as String?,
      lockedAt: json['locked_at'] != null
          ? DateTime.tryParse(json['locked_at'] as String)
          : null,
      lockedBy: json['locked_by'] as String?,
    );
  }
}
