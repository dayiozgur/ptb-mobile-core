/// Personel-vardiya ataması — `staff_shifts` tablosu satırı (salt-okuma).
///
/// Web `StaffShift` aynası: personel adı + vardiya adı embed'le çözülür.
class StaffShiftRow {
  final String id;
  final String staffId;
  final String staffName;
  final String shiftId;
  final String shiftName;
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;
  final bool active;

  const StaffShiftRow({
    required this.id,
    required this.staffId,
    this.staffName = '—',
    required this.shiftId,
    this.shiftName = '—',
    this.effectiveFrom,
    this.effectiveTo,
    this.active = true,
  });

  factory StaffShiftRow.fromJson(Map<String, dynamic> json) {
    final st = json['staffs'] as Map<String, dynamic>?;
    final sh = json['work_shifts'] as Map<String, dynamic>?;
    String staffName = '—';
    if (st != null) {
      final full = (st['name'] as String?) ??
          [st['first_name'], st['last_name']]
              .where((e) => e != null && (e as String).isNotEmpty)
              .join(' ');
      if (full.trim().isNotEmpty) staffName = full;
    }
    return StaffShiftRow(
      id: json['id'] as String,
      staffId: json['staff_id'] as String,
      staffName: staffName,
      shiftId: json['shift_id'] as String,
      shiftName: (sh?['name'] as String?) ?? '—',
      effectiveFrom: json['effective_from'] != null
          ? DateTime.tryParse(json['effective_from'] as String)
          : null,
      effectiveTo: json['effective_to'] != null
          ? DateTime.tryParse(json['effective_to'] as String)
          : null,
      active: json['active'] as bool? ?? true,
    );
  }
}
