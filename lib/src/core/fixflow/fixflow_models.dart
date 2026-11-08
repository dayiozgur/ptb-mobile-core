import 'dart:ui' show Color;

import '../entity/entity_status_labels.dart';

/// FixFlow sabitleri — web `libs/domains/fixflow-core` ile aynı değerler.
class FixflowConstants {
  FixflowConstants._();

  /// `platforms.code = 'FIXFLOW'` satırının id'si (canlı DB'den doğrulandı).
  static const String platformId = 'b1f1f10f-0000-4000-8000-000000000001';

  /// `status_definitions.entity_type` / `status-transition` EF `entityType`
  /// değerleri (EF `ENTITY_TABLE_FALLBACK`: ticket→tickets,
  /// work_request→work_requests, maintenance→maintenances).
  static const String ticketEntity = 'ticket';
  static const String workRequestEntity = 'work_request';
  static const String maintenanceEntity = 'maintenance';
}

DateTime? _date(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString());

String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

Map<String, dynamic>? _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

/// Bir `status_definitions` satırı (platform-filtreli, tekilleştirilmiş,
/// çevrilmiş). Web `PtbStatusDefinition` karşılığı.
class FixflowStatus {
  final String code;
  final String name;
  final String? colorHex;
  final bool isInitial;
  final bool isFinal;
  final int sortOrder;

  const FixflowStatus({
    required this.code,
    required this.name,
    this.colorHex,
    this.isInitial = false,
    this.isFinal = false,
    this.sortOrder = 0,
  });

  Color? get color => EntityStatusLabels.parseHex(colorHex);
}

/// Bir entity tipi için durum tanımları kataloğu (code → tanım).
class FixflowStatusCatalog {
  final List<FixflowStatus> statuses;

  FixflowStatusCatalog(List<FixflowStatus> statuses)
      : statuses = List.unmodifiable(statuses);

  static final FixflowStatusCatalog empty = FixflowStatusCatalog(const []);

  FixflowStatus? byCode(String? code) {
    if (code == null) return null;
    for (final s in statuses) {
      if (s.code == code) return s;
    }
    return null;
  }

  /// Görünen ad — tanım yoksa okunur hale getirilmiş kod (ham kod ASLA).
  String nameOf(String? code) {
    if (code == null || code.isEmpty) return '';
    final s = byCode(code);
    if (s != null && s.name.isNotEmpty) return s.name;
    return EntityStatusLabels.humanize(code);
  }

  Color? colorOf(String? code) => byCode(code)?.color;

  /// `is_final = false` kodlar (açık işler).
  List<String> get openCodes =>
      statuses.where((s) => !s.isFinal).map((s) => s.code).toList();

  /// `is_final = true` kodlar (kapalı işler).
  List<String> get finalCodes =>
      statuses.where((s) => s.isFinal).map((s) => s.code).toList();

  /// `is_initial = true` ilk kod (yeni kayıt varsayılan durumu).
  String? get initialCode {
    for (final s in statuses) {
      if (s.isInitial) return s.code;
    }
    return null;
  }

  bool isFinal(String? code) => byCode(code)?.isFinal ?? false;
}

/// İzinli bir durum geçişi (`status_transitions`, hedef tanımı ile).
class FixflowTransition {
  final String id;
  final String? name;
  final FixflowStatus toStatus;
  final List<String> requiredRoles;
  final bool requiresComment;
  final bool requiresConfirmation;

  /// Bir form gönderimi gerektiriyorsa mobil bunu SUNMAZ (form sihirbazı yok);
  /// filtre aşamasında elenir.
  final bool requiresForm;

  const FixflowTransition({
    required this.id,
    required this.toStatus,
    this.name,
    this.requiredRoles = const [],
    this.requiresComment = false,
    this.requiresConfirmation = false,
    this.requiresForm = false,
  });
}

/// `status-transition` EF başarısızlığı (EF zarfı `{error:{code,message}}`).
class FixflowTransitionException implements Exception {
  final String code;
  final String message;

  const FixflowTransitionException(this.code, this.message);

  bool get commentRequired => code == 'ERR_COMMENT_REQUIRED';
  bool get forbidden => code == 'ERR_FORBIDDEN';
  bool get invalidTransition => code == 'ERR_INVALID_TRANSITION';

  @override
  String toString() => 'FixflowTransitionException($code): $message';
}

/// Bilet listesi kapsamı.
enum FixflowTicketScope {
  /// `assigned_to = auth.uid()`.
  mine,

  /// `assigned_team_id ∈ (team_staffs ⋈ staffs.profile_id = auth.uid())`.
  team,

  /// RLS'in gösterdiği tüm biletler (tenant + org izolasyonu).
  all,
}

/// `tickets` satırı (web `Ticket` arayüzü ile aynı kolonlar).
class FixflowTicket {
  final String id;
  final String? code;
  final String subject;
  final String? description;
  final String status;
  final String? priorityId;
  final String? priorityCode;
  final String? priorityName;
  final String? priorityColor;
  final String? categoryName;
  final String? locationName;
  final String? assignedTo;
  final String? assignedToName;
  final String? assignedTeamId;
  final String? reportedBy;
  final String? siteId;
  final String? organizationId;
  final DateTime? dueDate;
  final DateTime? resolutionDate;
  final String? resolutionNote;
  final DateTime? firstResponseAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;

  const FixflowTicket({
    required this.id,
    required this.subject,
    required this.status,
    this.code,
    this.description,
    this.priorityId,
    this.priorityCode,
    this.priorityName,
    this.priorityColor,
    this.categoryName,
    this.locationName,
    this.assignedTo,
    this.assignedToName,
    this.assignedTeamId,
    this.reportedBy,
    this.siteId,
    this.organizationId,
    this.dueDate,
    this.resolutionDate,
    this.resolutionNote,
    this.firstResponseAt,
    this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  /// Görünen kod (`TKT-0001`); trigger üretmediyse id'nin başı.
  String get displayCode =>
      (code != null && code!.isNotEmpty) ? code! : id.split('-').first;

  /// Due date geçmiş mi? (yalnız açık biletler için anlamlı — çağıran
  /// final durumu kendisi kontrol eder).
  bool isOverdueAt(DateTime now) =>
      dueDate != null && dueDate!.isBefore(now);

  factory FixflowTicket.fromJson(Map<String, dynamic> j) {
    final pr = _map(j['priorities']);
    final cat = _map(j['categories']);
    final loc = _map(j['locations']);
    final assignee = _map(j['assignedTo']);
    String? assigneeName;
    if (assignee != null) {
      final full = _str(assignee['full_name'])?.trim();
      assigneeName = (full != null && full.isNotEmpty)
          ? full
          : _str(assignee['username']);
    }
    return FixflowTicket(
      id: j['id'].toString(),
      code: _str(j['code']),
      subject: _str(j['subject']) ?? '—',
      description: _str(j['description']),
      status: _str(j['status']) ?? '',
      priorityId: _str(j['priority_id']),
      priorityCode: _str(pr?['code']),
      priorityName: _str(pr?['name']),
      priorityColor: _str(pr?['color']),
      categoryName: _str(cat?['name']),
      locationName: _str(loc?['name']),
      assignedTo: _str(j['assigned_to']),
      assignedToName: assigneeName,
      assignedTeamId: _str(j['assigned_team_id']),
      reportedBy: _str(j['reported_by']),
      siteId: _str(j['site_id']),
      organizationId: _str(j['organization_id']),
      dueDate: _date(j['due_date']),
      resolutionDate: _date(j['resolution_date']),
      resolutionNote: _str(j['resolution_note']),
      firstResponseAt: _date(j['first_response_at']),
      createdAt: _date(j['created_at']),
      updatedAt: _date(j['updated_at']),
      metadata: _map(j['metadata']),
    );
  }
}

/// `work_requests` satırı (web `WorkRequest` arayüzü — `subject`, `staff_id`,
/// `team_id`, metin `priority` kodu BÜYÜK harf: `HIGH`).
class FixflowWorkRequest {
  final String id;
  final String? code;
  final String subject;
  final String? description;
  final String status;
  final String? priority;
  final String? reason;
  final String? staffId;
  final String? teamId;
  final String? siteId;
  final String? locationId;
  final String? organizationId;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FixflowWorkRequest({
    required this.id,
    required this.subject,
    required this.status,
    this.code,
    this.description,
    this.priority,
    this.reason,
    this.staffId,
    this.teamId,
    this.siteId,
    this.locationId,
    this.organizationId,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  String get displayCode =>
      (code != null && code!.isNotEmpty) ? code! : id.split('-').first;

  factory FixflowWorkRequest.fromJson(Map<String, dynamic> j) =>
      FixflowWorkRequest(
        id: j['id'].toString(),
        code: _str(j['code']),
        subject: _str(j['subject']) ?? '—',
        description: _str(j['description']),
        status: _str(j['status']) ?? '',
        priority: _str(j['priority']),
        reason: _str(j['reason']),
        staffId: _str(j['staff_id']),
        teamId: _str(j['team_id']),
        siteId: _str(j['site_id']),
        locationId: _str(j['location_id']),
        organizationId: _str(j['organization_id']),
        createdBy: _str(j['created_by']),
        createdAt: _date(j['created_at']),
        updatedAt: _date(j['updated_at']),
      );
}

/// `maintenances` satırı (bakım planı/iş emri — salt-okuma).
class FixflowMaintenance {
  final String id;
  final String? code;
  final String name;
  final String? description;
  final String status;
  final String? priority;
  final String? maintenanceType;
  final String? assignedStaffId;
  final String? siteId;
  final DateTime? scheduledDate;
  final DateTime? dueDate;
  final DateTime? completedDate;
  final int? estimatedDurationHours;

  const FixflowMaintenance({
    required this.id,
    required this.name,
    required this.status,
    this.code,
    this.description,
    this.priority,
    this.maintenanceType,
    this.assignedStaffId,
    this.siteId,
    this.scheduledDate,
    this.dueDate,
    this.completedDate,
    this.estimatedDurationHours,
  });

  String get displayCode =>
      (code != null && code!.isNotEmpty) ? code! : id.split('-').first;

  factory FixflowMaintenance.fromJson(Map<String, dynamic> j) =>
      FixflowMaintenance(
        id: j['id'].toString(),
        code: _str(j['code']),
        name: _str(j['name']) ?? '—',
        description: _str(j['description']),
        status: _str(j['status']) ?? '',
        priority: _str(j['priority']),
        maintenanceType: _str(j['maintenance_type']),
        assignedStaffId: _str(j['assigned_staff_id']),
        siteId: _str(j['site_id']),
        scheduledDate: _date(j['scheduled_date']),
        dueDate: _date(j['due_date']),
        completedDate: _date(j['completed_date']),
        estimatedDurationHours: (j['estimated_duration_hours'] as num?)?.toInt(),
      );
}

/// `worklogs` satırı (kanonik birim DAKİKA — web `WorklogService`).
class FixflowWorklog {
  final String id;
  final String? description;
  final int minutes;
  final DateTime? workDate;
  final String? createdBy;
  final DateTime? createdAt;

  const FixflowWorklog({
    required this.id,
    required this.minutes,
    this.description,
    this.workDate,
    this.createdBy,
    this.createdAt,
  });

  factory FixflowWorklog.fromJson(Map<String, dynamic> j) => FixflowWorklog(
        id: j['id'].toString(),
        description: _str(j['description']),
        minutes: (j['time_spent'] as num?)?.toInt() ?? 0,
        workDate: _date(j['work_date']),
        createdBy: _str(j['created_by']),
        createdAt: _date(j['created_at']),
      );
}

/// `attachments` satırı (dosya `platform-private` bucket'ında).
class FixflowAttachment {
  final String id;
  final String fileName;
  final String filePath;
  final String? mimeType;
  final int? fileSize;
  final String? createdBy;
  final DateTime? createdAt;

  const FixflowAttachment({
    required this.id,
    required this.fileName,
    required this.filePath,
    this.mimeType,
    this.fileSize,
    this.createdBy,
    this.createdAt,
  });

  bool get isImage => (mimeType ?? '').startsWith('image/');

  factory FixflowAttachment.fromJson(Map<String, dynamic> j) =>
      FixflowAttachment(
        id: j['id'].toString(),
        fileName: _str(j['original_filename']) ?? _str(j['filename']) ?? '—',
        filePath: _str(j['file_path']) ?? '',
        mimeType: _str(j['mime_type']),
        fileSize: (j['file_size'] as num?)?.toInt(),
        createdBy: _str(j['created_by']),
        createdAt: _date(j['created_at']),
      );
}

/// FixFlow pano sayaçları.
class FixflowDashboardCounts {
  final int myOpenTickets;
  final int teamOpenTickets;
  final int overdueTickets;
  final int openWorkRequests;
  final int upcomingMaintenance;

  const FixflowDashboardCounts({
    this.myOpenTickets = 0,
    this.teamOpenTickets = 0,
    this.overdueTickets = 0,
    this.openWorkRequests = 0,
    this.upcomingMaintenance = 0,
  });
}
