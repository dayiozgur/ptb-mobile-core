/// İş talebi durumu
enum WorkRequestStatus {
  /// Taslak
  draft('DRAFT', 'Taslak'),

  /// Gönderildi (onay bekliyor)
  submitted('SUBMITTED', 'Gönderildi'),

  /// Onaylandı
  approved('APPROVED', 'Onaylandı'),

  /// Reddedildi
  rejected('REJECTED', 'Reddedildi'),

  /// Atandı
  assigned('ASSIGNED', 'Atandı'),

  /// Devam ediyor
  inProgress('IN_PROGRESS', 'Devam Ediyor'),

  /// Beklemede
  onHold('ON_HOLD', 'Beklemede'),

  /// Tamamlandı
  completed('COMPLETED', 'Tamamlandı'),

  /// İptal edildi
  cancelled('CANCELLED', 'İptal Edildi'),

  /// Kapatıldı
  closed('CLOSED', 'Kapatıldı');

  final String value;
  final String label;
  const WorkRequestStatus(this.value, this.label);

  static WorkRequestStatus fromString(String? value) {
    return WorkRequestStatus.values.firstWhere(
      (e) => e.value == value || e.name == value,
      orElse: () => WorkRequestStatus.draft,
    );
  }

  /// Düzenlenebilir mi?
  bool get isEditable => this == draft || this == submitted || this == rejected;

  /// İşlem yapılabilir mi?
  bool get isActionable => this == approved || this == assigned || this == inProgress;

  /// Tamamlanmış mı?
  bool get isFinished => this == completed || this == cancelled || this == closed;
}

/// İş talebi tipi
enum WorkRequestType {
  /// Arıza bildirimi
  breakdown('BREAKDOWN', 'Arıza Bildirimi'),

  /// Bakım talebi
  maintenance('MAINTENANCE', 'Bakım Talebi'),

  /// Servis talebi
  service('SERVICE', 'Servis Talebi'),

  /// Denetim talebi
  inspection('INSPECTION', 'Denetim Talebi'),

  /// Kurulum talebi
  installation('INSTALLATION', 'Kurulum Talebi'),

  /// Değişiklik talebi
  modification('MODIFICATION', 'Değişiklik Talebi'),

  /// Genel talep
  general('GENERAL', 'Genel Talep');

  final String value;
  final String label;
  const WorkRequestType(this.value, this.label);

  static WorkRequestType fromString(String? value) {
    return WorkRequestType.values.firstWhere(
      (e) => e.value == value || e.name == value,
      orElse: () => WorkRequestType.general,
    );
  }
}

/// İş talebi önceliği
enum WorkRequestPriority {
  /// Düşük
  low('LOW', 'Düşük', 1),

  /// Normal
  normal('NORMAL', 'Normal', 2),

  /// Yüksek
  high('HIGH', 'Yüksek', 3),

  /// Acil
  urgent('URGENT', 'Acil', 4),

  /// Kritik
  critical('CRITICAL', 'Kritik', 5);

  final String value;
  final String label;
  final int level;
  const WorkRequestPriority(this.value, this.label, this.level);

  static WorkRequestPriority fromString(String? value) {
    return WorkRequestPriority.values.firstWhere(
      (e) => e.value == value || e.name == value,
      orElse: () => WorkRequestPriority.normal,
    );
  }

  /// Bu öncelik verilen öncelikten yüksek mi?
  bool isHigherThan(WorkRequestPriority other) => level > other.level;
}

/// İş Talebi (Work Request) modeli
///
/// Bakım, arıza, servis taleplerini temsil eder.
/// İş emirlerine (Work Order) dönüştürülebilir.
class WorkRequest {
  /// Benzersiz ID
  final String id;

  /// Talep numarası (otomatik oluşturulur)
  final String? requestNumber;

  /// Talep başlığı
  final String title;

  /// Detaylı açıklama
  final String? description;

  /// Talep tipi
  final WorkRequestType type;

  /// Durum
  final WorkRequestStatus status;

  /// Öncelik
  final WorkRequestPriority priority;

  // ============================================
  // TALEP BİLGİLERİ
  // ============================================

  /// Talep eden kullanıcı ID
  final String requestedById;

  /// Talep eden kullanıcı adı (denormalized)
  final String? requestedByName;

  /// Talep tarihi
  final DateTime requestedAt;

  /// Beklenen tamamlanma tarihi
  final DateTime? expectedCompletionDate;

  /// Gerçek tamamlanma tarihi
  final DateTime? actualCompletionDate;

  // ============================================
  // ATAMA BİLGİLERİ
  // ============================================

  /// Atanan kullanıcı ID
  final String? assignedToId;

  /// Atanan kullanıcı adı (denormalized)
  final String? assignedToName;

  /// Atanan ekip ID
  final String? assignedTeamId;

  /// Atama tarihi
  final DateTime? assignedAt;

  /// Atayan kullanıcı ID
  final String? assignedById;

  // ============================================
  // ONAY BİLGİLERİ
  // ============================================

  /// Onaylayan kullanıcı ID
  final String? approvedById;

  /// Onaylayan kullanıcı adı
  final String? approvedByName;

  /// Onay tarihi
  final DateTime? approvedAt;

  /// Onay notu
  final String? approvalNote;

  /// Red nedeni
  final String? rejectionReason;

  // ============================================
  // KONUM BİLGİLERİ
  // ============================================

  /// Tenant ID
  final String tenantId;

  /// Organization ID
  final String? organizationId;

  /// Site ID
  final String? siteId;

  /// Site adı (denormalized)
  final String? siteName;

  /// Unit ID
  final String? unitId;

  /// Unit adı (denormalized)
  final String? unitName;

  /// Controller ID (ilişkili cihaz)
  final String? controllerId;

  /// Controller adı (denormalized)
  final String? controllerName;

  // ============================================
  // EK BİLGİLER
  // ============================================

  /// Kategori ID
  final String? categoryId;

  /// Alt kategori ID
  final String? subCategoryId;

  /// Tahmini süre (dakika)
  final int? estimatedDuration;

  /// Gerçek süre (dakika)
  final int? actualDuration;

  /// Maliyet tahmini
  final double? estimatedCost;

  /// Gerçek maliyet
  final double? actualCost;

  /// Para birimi
  final String? currency;

  // ============================================
  // EKLER VE NOTLAR
  // ============================================

  /// Ekli dosyalar
  final List<WorkRequestAttachment> attachments;

  /// Notlar/Yorumlar
  final List<WorkRequestNote> notes;

  /// Etiketler
  final List<String> tags;

  /// Ek özellikler (JSON)
  final Map<String, dynamic> metadata;

  // ============================================
  // İLİŞKİLİ KAYITLAR
  // ============================================

  /// İlişkili iş emri ID (Work Order)
  final String? workOrderId;

  /// Üst talep ID (bağımlı talepler için)
  final String? parentRequestId;

  /// İlişkili alarm ID
  final String? alarmId;

  // ============================================
  // ZAMAN DAMGALARI
  // ============================================

  /// Oluşturulma tarihi
  final DateTime createdAt;

  /// Güncellenme tarihi
  final DateTime? updatedAt;

  /// Oluşturan kullanıcı
  final String? createdBy;

  /// Güncelleyen kullanıcı
  final String? updatedBy;

  const WorkRequest({
    required this.id,
    this.requestNumber,
    required this.title,
    this.description,
    this.type = WorkRequestType.general,
    this.status = WorkRequestStatus.draft,
    this.priority = WorkRequestPriority.normal,
    required this.requestedById,
    this.requestedByName,
    required this.requestedAt,
    this.expectedCompletionDate,
    this.actualCompletionDate,
    this.assignedToId,
    this.assignedToName,
    this.assignedTeamId,
    this.assignedAt,
    this.assignedById,
    this.approvedById,
    this.approvedByName,
    this.approvedAt,
    this.approvalNote,
    this.rejectionReason,
    required this.tenantId,
    this.organizationId,
    this.siteId,
    this.siteName,
    this.unitId,
    this.unitName,
    this.controllerId,
    this.controllerName,
    this.categoryId,
    this.subCategoryId,
    this.estimatedDuration,
    this.actualDuration,
    this.estimatedCost,
    this.actualCost,
    this.currency = 'TRY',
    this.attachments = const [],
    this.notes = const [],
    this.tags = const [],
    this.metadata = const {},
    this.workOrderId,
    this.parentRequestId,
    this.alarmId,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  // ============================================
  // COMPUTED PROPERTIES
  // ============================================

  /// Düzenlenebilir mi?
  bool get isEditable => status.isEditable;

  /// İşlem yapılabilir mi?
  bool get isActionable => status.isActionable;

  /// Tamamlanmış mı?
  bool get isFinished => status.isFinished;

  /// Atanmış mı?
  bool get isAssigned => assignedToId != null || assignedTeamId != null;

  /// Onaylanmış mı?
  bool get isApproved => status == WorkRequestStatus.approved;

  /// Gecikmiş mi?
  bool get isOverdue {
    if (expectedCompletionDate == null || isFinished) return false;
    return DateTime.now().isAfter(expectedCompletionDate!);
  }

  /// Gecikme süresi
  Duration? get overdueBy {
    if (!isOverdue) return null;
    return DateTime.now().difference(expectedCompletionDate!);
  }

  /// Konum özeti
  String get locationSummary {
    final parts = <String>[];
    if (siteName != null) parts.add(siteName!);
    if (unitName != null) parts.add(unitName!);
    if (controllerName != null) parts.add(controllerName!);
    return parts.isEmpty ? '-' : parts.join(' > ');
  }

  /// Tahmini süre formatlanmış
  String get estimatedDurationFormatted {
    if (estimatedDuration == null) return '-';
    final hours = estimatedDuration! ~/ 60;
    final minutes = estimatedDuration! % 60;
    if (hours > 0) return '${hours}s ${minutes}dk';
    return '${minutes}dk';
  }

  /// Gerçek süre formatlanmış
  String get actualDurationFormatted {
    if (actualDuration == null) return '-';
    final hours = actualDuration! ~/ 60;
    final minutes = actualDuration! % 60;
    if (hours > 0) return '${hours}s ${minutes}dk';
    return '${minutes}dk';
  }

  /// Maliyet özeti
  String get costSummary {
    if (actualCost != null) {
      return '${actualCost!.toStringAsFixed(2)} ${currency ?? "TRY"}';
    }
    if (estimatedCost != null) {
      return '~${estimatedCost!.toStringAsFixed(2)} ${currency ?? "TRY"}';
    }
    return '-';
  }

  /// İş emrine dönüştürülmüş mü?
  bool get hasWorkOrder => workOrderId != null;

  /// Eki var mı?
  bool get hasAttachments => attachments.isNotEmpty;

  /// Notu var mı?
  bool get hasNotes => notes.isNotEmpty;

  // ============================================
  // STATUS TRANSITIONS
  // ============================================

  /// Bu durumdan geçilebilecek durumlar
  List<WorkRequestStatus> get allowedTransitions {
    switch (status) {
      case WorkRequestStatus.draft:
        return [WorkRequestStatus.submitted, WorkRequestStatus.cancelled];
      case WorkRequestStatus.submitted:
        return [WorkRequestStatus.approved, WorkRequestStatus.rejected, WorkRequestStatus.cancelled];
      case WorkRequestStatus.approved:
        return [WorkRequestStatus.assigned, WorkRequestStatus.cancelled];
      case WorkRequestStatus.rejected:
        return [WorkRequestStatus.draft, WorkRequestStatus.cancelled];
      case WorkRequestStatus.assigned:
        return [WorkRequestStatus.inProgress, WorkRequestStatus.onHold, WorkRequestStatus.cancelled];
      case WorkRequestStatus.inProgress:
        return [WorkRequestStatus.completed, WorkRequestStatus.onHold, WorkRequestStatus.cancelled];
      case WorkRequestStatus.onHold:
        return [WorkRequestStatus.inProgress, WorkRequestStatus.cancelled];
      case WorkRequestStatus.completed:
        return [WorkRequestStatus.closed];
      case WorkRequestStatus.cancelled:
        return [];
      case WorkRequestStatus.closed:
        return [];
    }
  }

  /// Belirtilen duruma geçiş yapılabilir mi?
  bool canTransitionTo(WorkRequestStatus newStatus) {
    return allowedTransitions.contains(newStatus);
  }

  // ============================================
  // JSON SERIALIZATION
  // ============================================

  factory WorkRequest.fromJson(Map<String, dynamic> json) {
    return WorkRequest(
      id: json['id'] as String,
      requestNumber: json['request_number'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      type: WorkRequestType.fromString(json['type'] as String?),
      status: WorkRequestStatus.fromString(json['status'] as String?),
      priority: WorkRequestPriority.fromString(json['priority'] as String?),
      requestedById: json['requested_by_id'] as String? ?? json['created_by'] as String? ?? '',
      requestedByName: json['requested_by_name'] as String?,
      requestedAt: json['requested_at'] != null
          ? DateTime.parse(json['requested_at'] as String)
          : DateTime.now(),
      expectedCompletionDate: json['expected_completion_date'] != null
          ? DateTime.tryParse(json['expected_completion_date'] as String)
          : null,
      actualCompletionDate: json['actual_completion_date'] != null
          ? DateTime.tryParse(json['actual_completion_date'] as String)
          : null,
      assignedToId: json['assigned_to_id'] as String?,
      assignedToName: json['assigned_to_name'] as String?,
      assignedTeamId: json['assigned_team_id'] as String?,
      assignedAt: json['assigned_at'] != null
          ? DateTime.tryParse(json['assigned_at'] as String)
          : null,
      assignedById: json['assigned_by_id'] as String?,
      approvedById: json['approved_by_id'] as String?,
      approvedByName: json['approved_by_name'] as String?,
      approvedAt: json['approved_at'] != null
          ? DateTime.tryParse(json['approved_at'] as String)
          : null,
      approvalNote: json['approval_note'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      tenantId: json['tenant_id'] as String,
      organizationId: json['organization_id'] as String?,
      siteId: json['site_id'] as String?,
      siteName: json['site_name'] as String?,
      unitId: json['unit_id'] as String?,
      unitName: json['unit_name'] as String?,
      controllerId: json['controller_id'] as String?,
      controllerName: json['controller_name'] as String?,
      categoryId: json['category_id'] as String?,
      subCategoryId: json['sub_category_id'] as String?,
      estimatedDuration: json['estimated_duration'] as int?,
      actualDuration: json['actual_duration'] as int?,
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble(),
      actualCost: (json['actual_cost'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'TRY',
      attachments: json['attachments'] != null
          ? (json['attachments'] as List)
              .map((e) => WorkRequestAttachment.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
      notes: json['notes'] != null
          ? (json['notes'] as List)
              .map((e) => WorkRequestNote.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
      tags: json['tags'] != null ? List<String>.from(json['tags'] as List) : const [],
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
      workOrderId: json['work_order_id'] as String?,
      parentRequestId: json['parent_request_id'] as String?,
      alarmId: json['alarm_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_number': requestNumber,
      'title': title,
      'description': description,
      'type': type.value,
      'status': status.value,
      'priority': priority.value,
      'requested_by_id': requestedById,
      'requested_by_name': requestedByName,
      'requested_at': requestedAt.toIso8601String(),
      'expected_completion_date': expectedCompletionDate?.toIso8601String(),
      'actual_completion_date': actualCompletionDate?.toIso8601String(),
      'assigned_to_id': assignedToId,
      'assigned_to_name': assignedToName,
      'assigned_team_id': assignedTeamId,
      'assigned_at': assignedAt?.toIso8601String(),
      'assigned_by_id': assignedById,
      'approved_by_id': approvedById,
      'approved_by_name': approvedByName,
      'approved_at': approvedAt?.toIso8601String(),
      'approval_note': approvalNote,
      'rejection_reason': rejectionReason,
      'tenant_id': tenantId,
      'organization_id': organizationId,
      'site_id': siteId,
      'site_name': siteName,
      'unit_id': unitId,
      'unit_name': unitName,
      'controller_id': controllerId,
      'controller_name': controllerName,
      'category_id': categoryId,
      'sub_category_id': subCategoryId,
      'estimated_duration': estimatedDuration,
      'actual_duration': actualDuration,
      'estimated_cost': estimatedCost,
      'actual_cost': actualCost,
      'currency': currency,
      'attachments': attachments.map((e) => e.toJson()).toList(),
      'notes': notes.map((e) => e.toJson()).toList(),
      'tags': tags,
      'metadata': metadata,
      'work_order_id': workOrderId,
      'parent_request_id': parentRequestId,
      'alarm_id': alarmId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
    };
  }

  // ============================================
  // COPY WITH
  // ============================================

  WorkRequest copyWith({
    String? id,
    String? requestNumber,
    String? title,
    String? description,
    WorkRequestType? type,
    WorkRequestStatus? status,
    WorkRequestPriority? priority,
    String? requestedById,
    String? requestedByName,
    DateTime? requestedAt,
    DateTime? expectedCompletionDate,
    DateTime? actualCompletionDate,
    String? assignedToId,
    String? assignedToName,
    String? assignedTeamId,
    DateTime? assignedAt,
    String? assignedById,
    String? approvedById,
    String? approvedByName,
    DateTime? approvedAt,
    String? approvalNote,
    String? rejectionReason,
    String? tenantId,
    String? organizationId,
    String? siteId,
    String? siteName,
    String? unitId,
    String? unitName,
    String? controllerId,
    String? controllerName,
    String? categoryId,
    String? subCategoryId,
    int? estimatedDuration,
    int? actualDuration,
    double? estimatedCost,
    double? actualCost,
    String? currency,
    List<WorkRequestAttachment>? attachments,
    List<WorkRequestNote>? notes,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    String? workOrderId,
    String? parentRequestId,
    String? alarmId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return WorkRequest(
      id: id ?? this.id,
      requestNumber: requestNumber ?? this.requestNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      requestedById: requestedById ?? this.requestedById,
      requestedByName: requestedByName ?? this.requestedByName,
      requestedAt: requestedAt ?? this.requestedAt,
      expectedCompletionDate: expectedCompletionDate ?? this.expectedCompletionDate,
      actualCompletionDate: actualCompletionDate ?? this.actualCompletionDate,
      assignedToId: assignedToId ?? this.assignedToId,
      assignedToName: assignedToName ?? this.assignedToName,
      assignedTeamId: assignedTeamId ?? this.assignedTeamId,
      assignedAt: assignedAt ?? this.assignedAt,
      assignedById: assignedById ?? this.assignedById,
      approvedById: approvedById ?? this.approvedById,
      approvedByName: approvedByName ?? this.approvedByName,
      approvedAt: approvedAt ?? this.approvedAt,
      approvalNote: approvalNote ?? this.approvalNote,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      tenantId: tenantId ?? this.tenantId,
      organizationId: organizationId ?? this.organizationId,
      siteId: siteId ?? this.siteId,
      siteName: siteName ?? this.siteName,
      unitId: unitId ?? this.unitId,
      unitName: unitName ?? this.unitName,
      controllerId: controllerId ?? this.controllerId,
      controllerName: controllerName ?? this.controllerName,
      categoryId: categoryId ?? this.categoryId,
      subCategoryId: subCategoryId ?? this.subCategoryId,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      actualDuration: actualDuration ?? this.actualDuration,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      actualCost: actualCost ?? this.actualCost,
      currency: currency ?? this.currency,
      attachments: attachments ?? this.attachments,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
      workOrderId: workOrderId ?? this.workOrderId,
      parentRequestId: parentRequestId ?? this.parentRequestId,
      alarmId: alarmId ?? this.alarmId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  @override
  String toString() => 'WorkRequest($id, $title, ${status.label})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is WorkRequest && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// İş talebi eki
class WorkRequestAttachment {
  /// Ek ID
  final String id;

  /// Dosya adı
  final String fileName;

  /// Dosya URL'i
  final String fileUrl;

  /// Dosya boyutu (bytes)
  final int? fileSize;

  /// MIME tipi
  final String? mimeType;

  /// Açıklama
  final String? description;

  /// Yükleyen kullanıcı ID
  final String? uploadedById;

  /// Yüklenme tarihi
  final DateTime uploadedAt;

  const WorkRequestAttachment({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    this.fileSize,
    this.mimeType,
    this.description,
    this.uploadedById,
    required this.uploadedAt,
  });

  /// Dosya boyutu formatlanmış
  String get fileSizeFormatted {
    if (fileSize == null) return '-';
    if (fileSize! < 1024) return '${fileSize}B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)}KB';
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// Resim mi?
  bool get isImage {
    if (mimeType == null) return false;
    return mimeType!.startsWith('image/');
  }

  factory WorkRequestAttachment.fromJson(Map<String, dynamic> json) {
    return WorkRequestAttachment(
      id: json['id'] as String,
      fileName: json['file_name'] as String,
      fileUrl: json['file_url'] as String,
      fileSize: json['file_size'] as int?,
      mimeType: json['mime_type'] as String?,
      description: json['description'] as String?,
      uploadedById: json['uploaded_by_id'] as String?,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'file_name': fileName,
      'file_url': fileUrl,
      'file_size': fileSize,
      'mime_type': mimeType,
      'description': description,
      'uploaded_by_id': uploadedById,
      'uploaded_at': uploadedAt.toIso8601String(),
    };
  }
}

/// İş talebi notu
class WorkRequestNote {
  /// Not ID
  final String id;

  /// Not içeriği
  final String content;

  /// Not tipi
  final WorkRequestNoteType type;

  /// Yazan kullanıcı ID
  final String authorId;

  /// Yazan kullanıcı adı
  final String? authorName;

  /// Oluşturulma tarihi
  final DateTime createdAt;

  /// Güncellenme tarihi
  final DateTime? updatedAt;

  const WorkRequestNote({
    required this.id,
    required this.content,
    this.type = WorkRequestNoteType.comment,
    required this.authorId,
    this.authorName,
    required this.createdAt,
    this.updatedAt,
  });

  factory WorkRequestNote.fromJson(Map<String, dynamic> json) {
    return WorkRequestNote(
      id: json['id'] as String,
      content: json['content'] as String,
      type: WorkRequestNoteType.fromString(json['type'] as String?),
      authorId: json['author_id'] as String,
      authorName: json['author_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'type': type.value,
      'author_id': authorId,
      'author_name': authorName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

/// Not tipi
enum WorkRequestNoteType {
  /// Yorum
  comment('COMMENT', 'Yorum'),

  /// Sistem notu
  system('SYSTEM', 'Sistem'),

  /// Durum değişikliği
  statusChange('STATUS_CHANGE', 'Durum Değişikliği'),

  /// Atama
  assignment('ASSIGNMENT', 'Atama'),

  /// Onay
  approval('APPROVAL', 'Onay');

  final String value;
  final String label;
  const WorkRequestNoteType(this.value, this.label);

  static WorkRequestNoteType fromString(String? value) {
    return WorkRequestNoteType.values.firstWhere(
      (e) => e.value == value || e.name == value,
      orElse: () => WorkRequestNoteType.comment,
    );
  }
}

/// İş talebi özet istatistikleri
class WorkRequestStats {
  /// Toplam talep sayısı
  final int totalCount;

  /// Bekleyen (draft + submitted)
  final int pendingCount;

  /// Devam eden (approved + assigned + in_progress)
  final int activeCount;

  /// Tamamlanan
  final int completedCount;

  /// Geciken
  final int overdueCount;

  /// Önceliğe göre dağılım
  final Map<WorkRequestPriority, int> byPriority;

  /// Tipe göre dağılım
  final Map<WorkRequestType, int> byType;

  const WorkRequestStats({
    this.totalCount = 0,
    this.pendingCount = 0,
    this.activeCount = 0,
    this.completedCount = 0,
    this.overdueCount = 0,
    this.byPriority = const {},
    this.byType = const {},
  });

  /// Tamamlanma oranı
  double get completionRate {
    if (totalCount == 0) return 0;
    return (completedCount / totalCount) * 100;
  }

  factory WorkRequestStats.fromJson(Map<String, dynamic> json) {
    return WorkRequestStats(
      totalCount: json['total_count'] as int? ?? 0,
      pendingCount: json['pending_count'] as int? ?? 0,
      activeCount: json['active_count'] as int? ?? 0,
      completedCount: json['completed_count'] as int? ?? 0,
      overdueCount: json['overdue_count'] as int? ?? 0,
    );
  }
}
