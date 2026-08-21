/// Performans dönemi — `performance_cycles` tablosunun bir satırı.
///
/// Web PHR yönetim (`PerformanceService.getCycles` / `CYCLE_SELECT`) ile aynı
/// sözleşme: satır tenant kapsamlıdır (RLS + sorgu `tenant_id`). Dönem
/// self → yönetici → nihai değerlendirme akışının kapsayıcısıdır.
///
/// Durum: `draft` (taslak) | `active` (aktif) | `closed` (kapalı).
class PerformanceCycle {
  final String id;
  final String? tenantId;
  final String name;
  final String? description;

  /// Dönem başlangıcı (`period_start`).
  final DateTime? periodStart;

  /// Dönem bitişi (`period_end`).
  final DateTime? periodEnd;

  /// `draft` | `active` | `closed`.
  final String status;

  /// Yumuşak-silme bayrağı (`active=false` → pasif).
  final bool active;

  const PerformanceCycle({
    required this.id,
    this.tenantId,
    required this.name,
    this.description,
    this.periodStart,
    this.periodEnd,
    this.status = 'draft',
    this.active = true,
  });

  factory PerformanceCycle.fromJson(Map<String, dynamic> json) {
    return PerformanceCycle(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String?,
      name: (json['name'] as String?) ?? '',
      description: json['description'] as String?,
      periodStart: _parseDate(json['period_start']),
      periodEnd: _parseDate(json['period_end']),
      status: (json['status'] as String?) ?? 'draft',
      active: json['active'] != false,
    );
  }

  static DateTime? _parseDate(dynamic v) =>
      v is String ? DateTime.tryParse(v) : null;
}
