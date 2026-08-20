/// A single attendance (PDKS) day from `fn_pdks_range`.
class PdksDay {
  final DateTime? workDate;
  final String? shiftName;
  final int expectedMinutes;
  final int workedMinutes;
  final DateTime? entryTime;
  final DateTime? exitTime;
  final bool isHoliday;
  final bool isLeave;
  final bool isWorkingDay;
  final int lateMinutes;
  final int overtimeMinutes;
  final int missingMinutes;
  final String? status;

  const PdksDay({
    this.workDate,
    this.shiftName,
    this.expectedMinutes = 0,
    this.workedMinutes = 0,
    this.entryTime,
    this.exitTime,
    this.isHoliday = false,
    this.isLeave = false,
    this.isWorkingDay = false,
    this.lateMinutes = 0,
    this.overtimeMinutes = 0,
    this.missingMinutes = 0,
    this.status,
  });

  factory PdksDay.fromJson(Map<String, dynamic> json) {
    return PdksDay(
      workDate: json['work_date'] != null
          ? DateTime.tryParse(json['work_date'] as String)
          : null,
      shiftName: json['shift_name'] as String?,
      expectedMinutes: (json['expected_minutes'] as num?)?.toInt() ?? 0,
      workedMinutes: (json['worked_minutes'] as num?)?.toInt() ?? 0,
      entryTime: json['entry_time'] != null
          ? DateTime.tryParse(json['entry_time'] as String)
          : null,
      exitTime: json['exit_time'] != null
          ? DateTime.tryParse(json['exit_time'] as String)
          : null,
      isHoliday: json['is_holiday'] as bool? ?? false,
      isLeave: json['is_leave'] as bool? ?? false,
      isWorkingDay: json['is_working_day'] as bool? ?? false,
      lateMinutes: (json['late_minutes'] as num?)?.toInt() ?? 0,
      overtimeMinutes: (json['overtime_minutes'] as num?)?.toInt() ?? 0,
      missingMinutes: (json['missing_minutes'] as num?)?.toInt() ?? 0,
      status: json['status'] as String?,
    );
  }
}
