/// Aylık puantaj özeti — bir personelin bir aydaki `fn_pdks_range` günlerinin
/// toplamı (client tarafında gruplanır). Salt-okuma.
///
/// Web `PdksBoardComponent`'in "Aylık Puantaj" görünümü tek-personel günlük
/// grid gösterir; mobilde tüm-tenant için personel-başı aylık özet toplanır.
class PuantajSummaryRow {
  final String staffId;
  final String staffName;
  final int workedMinutes;
  final int expectedMinutes;
  final int overtimeMinutes;
  final int missingMinutes;
  final int lateMinutes;
  final int presentDays;
  final int absentDays;
  final int leaveDays;
  final int holidayOffDays;

  const PuantajSummaryRow({
    required this.staffId,
    this.staffName = '—',
    this.workedMinutes = 0,
    this.expectedMinutes = 0,
    this.overtimeMinutes = 0,
    this.missingMinutes = 0,
    this.lateMinutes = 0,
    this.presentDays = 0,
    this.absentDays = 0,
    this.leaveDays = 0,
    this.holidayOffDays = 0,
  });

  PuantajSummaryRow copyAdd({
    int worked = 0,
    int expected = 0,
    int overtime = 0,
    int missing = 0,
    int late = 0,
    int present = 0,
    int absent = 0,
    int leave = 0,
    int holidayOff = 0,
  }) {
    return PuantajSummaryRow(
      staffId: staffId,
      staffName: staffName,
      workedMinutes: workedMinutes + worked,
      expectedMinutes: expectedMinutes + expected,
      overtimeMinutes: overtimeMinutes + overtime,
      missingMinutes: missingMinutes + missing,
      lateMinutes: lateMinutes + late,
      presentDays: presentDays + present,
      absentDays: absentDays + absent,
      leaveDays: leaveDays + leave,
      holidayOffDays: holidayOffDays + holidayOff,
    );
  }
}
