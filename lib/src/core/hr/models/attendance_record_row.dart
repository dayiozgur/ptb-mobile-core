/// Ham devam/giriş-çıkış kaydı — `attendance_records` tablosu satırı (salt-okuma).
///
/// NOT: bu tabloda uzlaştırılmış `status` kolonu YOKTUR (durum `fn_pdks_range`
/// ile türetilir). Ham kayıt için "açık/tamamlandı" durumu `exitTime`'ın var
/// olup olmamasından türetilir ([isOpen]).
class AttendanceRecordRow {
  final String id;
  final String? staffId;
  final String staffName;
  final DateTime? workDate;
  final DateTime? entryTime;
  final DateTime? exitTime;
  final int workedMinutes;
  final String? source;
  final String? location;
  final String? note;

  const AttendanceRecordRow({
    required this.id,
    this.staffId,
    this.staffName = '—',
    this.workDate,
    this.entryTime,
    this.exitTime,
    this.workedMinutes = 0,
    this.source,
    this.location,
    this.note,
  });

  /// Kapanmamış (çıkış saati girilmemiş) kayıt.
  bool get isOpen => entryTime != null && exitTime == null;

  factory AttendanceRecordRow.fromJson(
    Map<String, dynamic> json, {
    String? staffName,
  }) {
    return AttendanceRecordRow(
      id: json['id'] as String,
      staffId: json['staff_id'] as String?,
      staffName: staffName ?? '—',
      workDate: json['work_date'] != null
          ? DateTime.tryParse(json['work_date'] as String)
          : null,
      entryTime: json['entry_time'] != null
          ? DateTime.tryParse(json['entry_time'] as String)
          : null,
      exitTime: json['exit_time'] != null
          ? DateTime.tryParse(json['exit_time'] as String)
          : null,
      workedMinutes: (json['worked_minutes'] as num?)?.toInt() ?? 0,
      source: json['source'] as String?,
      location: json['location'] as String?,
      note: json['note'] as String?,
    );
  }
}
