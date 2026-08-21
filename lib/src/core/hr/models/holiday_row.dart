/// Bir `holidays` satırı (resmi/şirket tatili) — admin salt-okuma görünümü.
///
/// Web `LeaveService.fetchHolidays` sözleşmesiyle birebir kolonlar:
///   `id,tenant_id,holiday_date,name,is_recurring,active`.
/// [isRecurring] `true` ise tatil her yıl aynı tarihte tekrarlar.
class HolidayRow {
  final String id;
  final String? tenantId;

  /// `holiday_date` (yyyy-MM-dd) — tatilin tarihi.
  final DateTime? holidayDate;
  final String? name;

  /// `is_recurring` — her yıl tekrarlayan mı?
  final bool isRecurring;
  final bool active;

  const HolidayRow({
    required this.id,
    this.tenantId,
    this.holidayDate,
    this.name,
    this.isRecurring = false,
    this.active = true,
  });

  factory HolidayRow.fromJson(Map<String, dynamic> json) {
    final raw = json['holiday_date'];
    return HolidayRow(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String?,
      holidayDate:
          raw is String && raw.isNotEmpty ? DateTime.tryParse(raw) : null,
      name: json['name'] as String?,
      isRecurring: json['is_recurring'] as bool? ?? false,
      active: json['active'] as bool? ?? true,
    );
  }
}
