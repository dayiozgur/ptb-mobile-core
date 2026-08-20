/// Leave balance summary row.
///
/// `fn_leave_balance_summary(p_staff_id)` RPC'sinin bir satırını temsil eder.
/// Tüm sayısal alanlar `numeric` olduğu için `num` olarak okunur.
class LeaveBalance {
  final String? leaveTypeId;
  final String? leaveTypeName;
  final bool isPaid;
  final int? year;
  final num entitled;
  final num accrued;
  final num used;
  final num pending;
  final num remaining;

  const LeaveBalance({
    this.leaveTypeId,
    this.leaveTypeName,
    this.isPaid = false,
    this.year,
    this.entitled = 0,
    this.accrued = 0,
    this.used = 0,
    this.pending = 0,
    this.remaining = 0,
  });

  factory LeaveBalance.fromJson(Map<String, dynamic> json) {
    return LeaveBalance(
      leaveTypeId: json['leave_type_id'] as String?,
      leaveTypeName: json['leave_type_name'] as String?,
      isPaid: json['is_paid'] as bool? ?? false,
      year: (json['year'] as num?)?.toInt(),
      entitled: (json['entitled'] as num?) ?? 0,
      accrued: (json['accrued'] as num?) ?? 0,
      used: (json['used'] as num?) ?? 0,
      pending: (json['pending'] as num?) ?? 0,
      remaining: (json['remaining'] as num?) ?? 0,
    );
  }
}
