/// Bir `leave_types` satırı (izin türü) — admin salt-okuma görünümü.
///
/// Web `LeaveService.fetchTypes` sözleşmesiyle birebir kolonlar:
///   `id,tenant_id,code,name,description,default_days,is_paid,allows_half_day,active`.
/// [tenantId] `null` ise satır global (tüm tenant'lar için ortak) izin türüdür.
class LeaveTypeRow {
  final String id;
  final String? tenantId;
  final String? code;
  final String? name;
  final String? description;

  /// `default_days` — varsayılan/yıllık hak (gün).
  final num defaultDays;

  /// `is_paid` — ücretli izin mi?
  final bool isPaid;

  /// `allows_half_day` — yarım gün destekler mi?
  final bool allowsHalfDay;
  final bool active;

  const LeaveTypeRow({
    required this.id,
    this.tenantId,
    this.code,
    this.name,
    this.description,
    this.defaultDays = 0,
    this.isPaid = true,
    this.allowsHalfDay = false,
    this.active = true,
  });

  /// Global (tenant'a bağlı olmayan, ortak) tür mü?
  bool get isGlobal => tenantId == null;

  factory LeaveTypeRow.fromJson(Map<String, dynamic> json) {
    return LeaveTypeRow(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String?,
      code: json['code'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      defaultDays: (json['default_days'] as num?) ?? 0,
      isPaid: json['is_paid'] as bool? ?? true,
      allowsHalfDay: json['allows_half_day'] as bool? ?? false,
      active: json['active'] as bool? ?? true,
    );
  }
}
