/// PMS alarm → FixFlow iş emri (ticket) modelleri.
///
/// Sunucu yolu web ile aynı (protoolbag-platform
/// `supabase/migrations/20261022150000_pms_alarm_ticket_routing.sql`):
///  * `fn_pms_alarm_create_ticket(p_alarm_uid, p_subject, p_description,
///    p_priority_id DEFAULT NULL)` → `{id, code}` — SECURITY DEFINER; kiracı +
///    org görünürlüğü, FixFlow yetkisi, disiplin, SLA ve bakım firması
///    yönlendirmesi SUNUCUDA belirlenir. Öncelik: `p_priority_id` NULL →
///    alarmın platform önceliği; dolu → platform önceliği olmalı
///    (`vendor IS NULL AND active = true`, aksi halde `invalid priority`).
///    SLA bitiş tarihi seçilen önceliği izler.
///  * `fn_pms_alarm_linked_ticket(p_alarm_uid)` → alarmdan açılmış iş emirleri
///    (firmanın FixFlow kiracısındakiler dahil), yeniden eskiye.
///  * `fn_pms_alarm_ticket_route_preview(p_alarm_uid)` → iş emri nereye gider.
library;

/// `fn_pms_alarm_create_ticket` FixFlow üyeliği olmayan kiracıda bu mesajla
/// hata verir (web `PMS_FIXFLOW_NOT_ENTITLED`).
const String kFixflowNotEntitled = 'fixflow_not_entitled';

/// Hata (PostgrestException / String / herhangi) FixFlow-yetkisiz mi?
bool isFixflowNotEntitled(Object? error) {
  // PostgrestException.toString() mesajı içerir.
  return error != null && error.toString().contains(kFixflowNotEntitled);
}

/// `fn_pms_alarm_create_ticket` platform dışı / pasif `p_priority_id` için bu
/// mesajla hata verir.
const String kInvalidPriority = 'invalid priority';

/// Hata seçilen önceliğin geçersiz olmasından mı (`invalid priority`)?
bool isInvalidPriority(Object? error) {
  return error != null &&
      error.toString().toLowerCase().contains(kInvalidPriority);
}

/// Yeni oluşturulan iş emri (`{id, code}`).
class AlarmCreatedTicket {
  final String id;
  final String? code;

  const AlarmCreatedTicket({required this.id, this.code});

  /// Kullanıcıya gösterilecek numara (kod yoksa id).
  String get displayCode => (code != null && code!.isNotEmpty) ? code! : id;
}

/// Alarma bağlı iş emri (`fn_pms_alarm_linked_ticket` satırı).
class AlarmLinkedTicket {
  final String ticketId;
  final String? code;
  final String? subject;
  final String? status;

  /// `status_definitions.is_final` — kapanmış iş emri.
  final bool statusFinal;

  /// `external` / `internal` / `none` (+ `:ambiguous`).
  final String? routing;
  final String? handledBy;
  final String? contractorName;
  final DateTime? dueDate;
  final DateTime? createdAt;

  const AlarmLinkedTicket({
    required this.ticketId,
    this.code,
    this.subject,
    this.status,
    this.statusFinal = false,
    this.routing,
    this.handledBy,
    this.contractorName,
    this.dueDate,
    this.createdAt,
  });

  bool get isOpen => !statusFinal;

  String get displayCode =>
      (code != null && code!.isNotEmpty) ? code! : ticketId;

  factory AlarmLinkedTicket.fromJson(Map<String, dynamic> json) {
    return AlarmLinkedTicket(
      ticketId: json['ticket_id'] as String,
      code: json['code'] as String?,
      subject: json['subject'] as String?,
      status: json['status'] as String?,
      statusFinal: json['status_final'] == true,
      routing: json['routing'] as String?,
      handledBy: json['handled_by'] as String?,
      contractorName: json['contractor_name'] as String?,
      dueDate: _date(json['due_date']),
      createdAt: _date(json['created_at']),
    );
  }
}

/// İş emri yönlendirme modu.
enum AlarmTicketRouteMode { external, internal, none }

/// `fn_pms_alarm_ticket_route_preview` satırı.
class AlarmTicketRoutePreview {
  final AlarmTicketRouteMode mode;
  final String? contractorName;
  final String? disciplineCode;

  /// Alarmın PLATFORM öncelik kodu (critical/high/...) — iş emrine sunucu yazar.
  final String? priorityCode;
  final String? targetName;
  final String? teamName;
  final bool ambiguous;

  const AlarmTicketRoutePreview({
    required this.mode,
    this.contractorName,
    this.disciplineCode,
    this.priorityCode,
    this.targetName,
    this.teamName,
    this.ambiguous = false,
  });

  factory AlarmTicketRoutePreview.fromJson(Map<String, dynamic> json) {
    final m = json['mode'];
    return AlarmTicketRoutePreview(
      mode: m == 'external'
          ? AlarmTicketRouteMode.external
          : m == 'internal'
              ? AlarmTicketRouteMode.internal
              : AlarmTicketRouteMode.none,
      contractorName: json['contractor_name'] as String?,
      disciplineCode: json['discipline_code'] as String?,
      priorityCode: json['priority_code'] as String?,
      targetName: json['target_name'] as String?,
      teamName: json['team_name'] as String?,
      ambiguous: json['ambiguous'] == true,
    );
  }
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;
