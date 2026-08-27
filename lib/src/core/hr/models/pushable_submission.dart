/// Bordroya itilebilir (onaylı) avans/masraf başvurusu.
///
/// Web `PayrollService.getPushableSubmissions` istemci-okumasının aynası:
/// `form_submissions` (entity_type `hr_advance`/`hr_expense`, active) satırları,
/// zaten bir `payroll_adjustments` ile eşlenmiş (source_ref) olanlar ELENEREK.
/// Statü literaline göre filtre YOK — statü rozet olarak gösterilir, itme
/// kararını admin verir (`fn_hr_push_to_payroll` entity_type + amount>0 + staff
/// dışında statü kontrol etmez). Salt-okuma (mobil v1).
class PushableSubmission {
  final String id;

  /// `hr_advance` (avans) | `hr_expense` (masraf).
  final String entityType;
  final String status;
  final String? code;
  final String? subject;

  /// `metadata.amount` (num) — başvuru tutarı.
  final num amount;

  /// Başvuran personel görünen adı (staffs eşlemesinden); yoksa null.
  final String? submitterName;

  const PushableSubmission({
    required this.id,
    this.entityType = 'hr_advance',
    this.status = 'pending',
    this.code,
    this.subject,
    this.amount = 0,
    this.submitterName,
  });

  bool get isExpense => entityType == 'hr_expense';
}
