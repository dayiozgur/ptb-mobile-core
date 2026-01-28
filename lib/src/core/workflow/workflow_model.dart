/// Workflow durumu
enum WorkflowStatus {
  /// Taslak
  draft('DRAFT', 'Taslak'),

  /// Aktif
  active('ACTIVE', 'Aktif'),

  /// Pasif
  inactive('INACTIVE', 'Pasif'),

  /// Askıda
  suspended('SUSPENDED', 'Askıda'),

  /// Arşivlenmiş
  archived('ARCHIVED', 'Arşivlenmiş');

  final String value;
  final String label;
  const WorkflowStatus(this.value, this.label);

  static WorkflowStatus fromString(String? value) {
    return WorkflowStatus.values.firstWhere(
      (e) => e.value == value || e.name == value,
      orElse: () => WorkflowStatus.draft,
    );
  }
}

/// Workflow tipi
enum WorkflowType {
  /// Otomasyon (trigger-action)
  automation('AUTOMATION', 'Otomasyon'),

  /// Zamanlayıcı (scheduled)
  scheduled('SCHEDULED', 'Zamanlayıcı'),

  /// Manuel (user-triggered)
  manual('MANUAL', 'Manuel'),

  /// Olay tabanlı (event-driven)
  eventDriven('EVENT_DRIVEN', 'Olay Tabanlı'),

  /// Onay akışı (approval)
  approval('APPROVAL', 'Onay Akışı');

  final String value;
  final String label;
  const WorkflowType(this.value, this.label);

  static WorkflowType fromString(String? value) {
    return WorkflowType.values.firstWhere(
      (e) => e.value == value || e.name == value,
      orElse: () => WorkflowType.automation,
    );
  }
}

/// Workflow önceliği
enum WorkflowPriority {
  /// Düşük
  low('LOW', 'Düşük', 1),

  /// Normal
  normal('NORMAL', 'Normal', 2),

  /// Yüksek
  high('HIGH', 'Yüksek', 3),

  /// Kritik
  critical('CRITICAL', 'Kritik', 4);

  final String value;
  final String label;
  final int level;
  const WorkflowPriority(this.value, this.label, this.level);

  static WorkflowPriority fromString(String? value) {
    return WorkflowPriority.values.firstWhere(
      (e) => e.value == value || e.name == value,
      orElse: () => WorkflowPriority.normal,
    );
  }
}

/// Workflow (İş Akışı) modeli
///
/// IoT otomasyon ve iş akışlarını temsil eder.
class Workflow {
  /// Benzersiz ID
  final String id;

  /// Workflow adı
  final String name;

  /// Workflow kodu
  final String? code;

  /// Açıklama
  final String? description;

  /// Workflow tipi
  final WorkflowType type;

  /// Durum
  final WorkflowStatus status;

  /// Öncelik
  final WorkflowPriority priority;

  /// Aktif mi?
  final bool active;

  // ============================================
  // ZAMANLAMA
  // ============================================

  /// Cron ifadesi (scheduled tip için)
  final String? cronExpression;

  /// Başlangıç tarihi
  final DateTime? startDate;

  /// Bitiş tarihi
  final DateTime? endDate;

  /// Timezone
  final String? timezone;

  // ============================================
  // TETİKLEYİCİLER
  // ============================================

  /// Tetikleyici listesi
  final List<WorkflowTrigger> triggers;

  // ============================================
  // EYLEMLER
  // ============================================

  /// Eylem listesi
  final List<WorkflowAction> actions;

  // ============================================
  // KOŞULLAR
  // ============================================

  /// Koşul listesi
  final List<WorkflowCondition> conditions;

  /// Koşullar AND mi OR mu?
  final bool conditionsAreAnd;

  // ============================================
  // ÇALIŞTIRMA GEÇMİŞİ
  // ============================================

  /// Son çalıştırma tarihi
  final DateTime? lastRunAt;

  /// Son çalıştırma sonucu
  final WorkflowRunResult? lastRunResult;

  /// Toplam çalıştırma sayısı
  final int runCount;

  /// Başarılı çalıştırma sayısı
  final int successCount;

  /// Başarısız çalıştırma sayısı
  final int failureCount;

  // ============================================
  // İLİŞKİLER
  // ============================================

  /// Bağlı olduğu Tenant ID
  final String tenantId;

  /// Site ID (opsiyonel)
  final String? siteId;

  /// Unit ID (opsiyonel)
  final String? unitId;

  // ============================================
  // METADATA
  // ============================================

  /// Etiketler
  final List<String> tags;

  /// Ek özellikler
  final Map<String, dynamic> metadata;

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

  const Workflow({
    required this.id,
    required this.name,
    required this.tenantId,
    this.code,
    this.description,
    this.type = WorkflowType.automation,
    this.status = WorkflowStatus.draft,
    this.priority = WorkflowPriority.normal,
    this.active = true,
    this.cronExpression,
    this.startDate,
    this.endDate,
    this.timezone,
    this.triggers = const [],
    this.actions = const [],
    this.conditions = const [],
    this.conditionsAreAnd = true,
    this.lastRunAt,
    this.lastRunResult,
    this.runCount = 0,
    this.successCount = 0,
    this.failureCount = 0,
    this.siteId,
    this.unitId,
    this.tags = const [],
    this.metadata = const {},
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  // ============================================
  // COMPUTED PROPERTIES
  // ============================================

  /// Aktif ve çalışır durumda mı?
  bool get isRunnable => active && status == WorkflowStatus.active;

  /// Taslak mı?
  bool get isDraft => status == WorkflowStatus.draft;

  /// Zamanlanmış mı?
  bool get isScheduled => type == WorkflowType.scheduled;

  /// Tetikleyici var mı?
  bool get hasTriggers => triggers.isNotEmpty;

  /// Eylem var mı?
  bool get hasActions => actions.isNotEmpty;

  /// Geçerli mi? (en az bir tetikleyici ve bir eylem)
  bool get isValid => hasTriggers && hasActions;

  /// Başarı oranı
  double get successRate {
    if (runCount == 0) return 0;
    return (successCount / runCount) * 100;
  }

  /// Tarih aralığında mı?
  bool get isInDateRange {
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }

  // ============================================
  // JSON SERIALIZATION
  // ============================================

  factory Workflow.fromJson(Map<String, dynamic> json) {
    return Workflow(
      id: json['id'] as String,
      name: json['name'] as String,
      tenantId: json['tenant_id'] as String,
      code: json['code'] as String?,
      description: json['description'] as String?,
      type: WorkflowType.fromString(json['type'] as String?),
      status: WorkflowStatus.fromString(json['status'] as String?),
      priority: WorkflowPriority.fromString(json['priority'] as String?),
      active: json['active'] as bool? ?? true,
      cronExpression: json['cron_expression'] as String?,
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'] as String)
          : null,
      timezone: json['timezone'] as String?,
      triggers: json['triggers'] != null
          ? (json['triggers'] as List)
              .map((e) => WorkflowTrigger.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
      actions: json['actions'] != null
          ? (json['actions'] as List)
              .map((e) => WorkflowAction.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
      conditions: json['conditions'] != null
          ? (json['conditions'] as List)
              .map((e) => WorkflowCondition.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
      conditionsAreAnd: json['conditions_are_and'] as bool? ?? true,
      lastRunAt: json['last_run_at'] != null
          ? DateTime.tryParse(json['last_run_at'] as String)
          : null,
      lastRunResult: json['last_run_result'] != null
          ? WorkflowRunResult.fromString(json['last_run_result'] as String?)
          : null,
      runCount: json['run_count'] as int? ?? 0,
      successCount: json['success_count'] as int? ?? 0,
      failureCount: json['failure_count'] as int? ?? 0,
      siteId: json['site_id'] as String?,
      unitId: json['unit_id'] as String?,
      tags: json['tags'] != null
          ? List<String>.from(json['tags'] as List)
          : const [],
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
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
      'name': name,
      'tenant_id': tenantId,
      'code': code,
      'description': description,
      'type': type.value,
      'status': status.value,
      'priority': priority.value,
      'active': active,
      'cron_expression': cronExpression,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'timezone': timezone,
      'triggers': triggers.map((e) => e.toJson()).toList(),
      'actions': actions.map((e) => e.toJson()).toList(),
      'conditions': conditions.map((e) => e.toJson()).toList(),
      'conditions_are_and': conditionsAreAnd,
      'last_run_at': lastRunAt?.toIso8601String(),
      'last_run_result': lastRunResult?.value,
      'run_count': runCount,
      'success_count': successCount,
      'failure_count': failureCount,
      'site_id': siteId,
      'unit_id': unitId,
      'tags': tags,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
    };
  }

  // ============================================
  // COPY WITH
  // ============================================

  Workflow copyWith({
    String? id,
    String? name,
    String? tenantId,
    String? code,
    String? description,
    WorkflowType? type,
    WorkflowStatus? status,
    WorkflowPriority? priority,
    bool? active,
    String? cronExpression,
    DateTime? startDate,
    DateTime? endDate,
    String? timezone,
    List<WorkflowTrigger>? triggers,
    List<WorkflowAction>? actions,
    List<WorkflowCondition>? conditions,
    bool? conditionsAreAnd,
    DateTime? lastRunAt,
    WorkflowRunResult? lastRunResult,
    int? runCount,
    int? successCount,
    int? failureCount,
    String? siteId,
    String? unitId,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return Workflow(
      id: id ?? this.id,
      name: name ?? this.name,
      tenantId: tenantId ?? this.tenantId,
      code: code ?? this.code,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      active: active ?? this.active,
      cronExpression: cronExpression ?? this.cronExpression,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      timezone: timezone ?? this.timezone,
      triggers: triggers ?? this.triggers,
      actions: actions ?? this.actions,
      conditions: conditions ?? this.conditions,
      conditionsAreAnd: conditionsAreAnd ?? this.conditionsAreAnd,
      lastRunAt: lastRunAt ?? this.lastRunAt,
      lastRunResult: lastRunResult ?? this.lastRunResult,
      runCount: runCount ?? this.runCount,
      successCount: successCount ?? this.successCount,
      failureCount: failureCount ?? this.failureCount,
      siteId: siteId ?? this.siteId,
      unitId: unitId ?? this.unitId,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  @override
  String toString() => 'Workflow($id, $name, ${status.label})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Workflow && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Workflow çalıştırma sonucu
enum WorkflowRunResult {
  /// Başarılı
  success('SUCCESS', 'Başarılı'),

  /// Başarısız
  failure('FAILURE', 'Başarısız'),

  /// Kısmi başarılı
  partial('PARTIAL', 'Kısmi Başarılı'),

  /// İptal edildi
  cancelled('CANCELLED', 'İptal Edildi'),

  /// Timeout
  timeout('TIMEOUT', 'Zaman Aşımı');

  final String value;
  final String label;
  const WorkflowRunResult(this.value, this.label);

  static WorkflowRunResult? fromString(String? value) {
    if (value == null) return null;
    return WorkflowRunResult.values.firstWhere(
      (e) => e.value == value || e.name == value,
      orElse: () => WorkflowRunResult.failure,
    );
  }
}

/// Workflow tetikleyici tipi
enum TriggerType {
  /// Variable değer değişikliği
  variableChange('VARIABLE_CHANGE', 'Değişken Değişikliği'),

  /// Variable eşik geçişi
  variableThreshold('VARIABLE_THRESHOLD', 'Eşik Geçişi'),

  /// Zamanlayıcı
  schedule('SCHEDULE', 'Zamanlayıcı'),

  /// Manuel
  manual('MANUAL', 'Manuel'),

  /// Webhook
  webhook('WEBHOOK', 'Webhook'),

  /// Diğer workflow
  workflow('WORKFLOW', 'Workflow'),

  /// Alarm
  alarm('ALARM', 'Alarm');

  final String value;
  final String label;
  const TriggerType(this.value, this.label);

  static TriggerType fromString(String? value) {
    return TriggerType.values.firstWhere(
      (e) => e.value == value || e.name == value,
      orElse: () => TriggerType.manual,
    );
  }
}

/// Workflow tetikleyici
class WorkflowTrigger {
  /// Tetikleyici ID
  final String id;

  /// Tetikleyici tipi
  final TriggerType type;

  /// Kaynak ID (variable, workflow, vb.)
  final String? sourceId;

  /// Koşul (eq, gt, lt, gte, lte, changed, vb.)
  final String? condition;

  /// Hedef değer
  final dynamic targetValue;

  /// Aktif mi?
  final bool enabled;

  /// Ek parametreler
  final Map<String, dynamic> params;

  const WorkflowTrigger({
    required this.id,
    required this.type,
    this.sourceId,
    this.condition,
    this.targetValue,
    this.enabled = true,
    this.params = const {},
  });

  factory WorkflowTrigger.fromJson(Map<String, dynamic> json) {
    return WorkflowTrigger(
      id: json['id'] as String,
      type: TriggerType.fromString(json['type'] as String?),
      sourceId: json['source_id'] as String?,
      condition: json['condition'] as String?,
      targetValue: json['target_value'],
      enabled: json['enabled'] as bool? ?? true,
      params: json['params'] as Map<String, dynamic>? ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.value,
      'source_id': sourceId,
      'condition': condition,
      'target_value': targetValue,
      'enabled': enabled,
      'params': params,
    };
  }
}

/// Workflow eylem tipi
enum ActionType {
  /// Variable değer yaz
  writeVariable('WRITE_VARIABLE', 'Değişkene Yaz'),

  /// Bildirim gönder
  sendNotification('SEND_NOTIFICATION', 'Bildirim Gönder'),

  /// Email gönder
  sendEmail('SEND_EMAIL', 'Email Gönder'),

  /// SMS gönder
  sendSms('SEND_SMS', 'SMS Gönder'),

  /// Webhook çağır
  callWebhook('CALL_WEBHOOK', 'Webhook Çağır'),

  /// Başka workflow başlat
  triggerWorkflow('TRIGGER_WORKFLOW', 'Workflow Başlat'),

  /// Log yaz
  writeLog('WRITE_LOG', 'Log Yaz'),

  /// Alarm oluştur
  createAlarm('CREATE_ALARM', 'Alarm Oluştur'),

  /// Gecikme
  delay('DELAY', 'Gecikme');

  final String value;
  final String label;
  const ActionType(this.value, this.label);

  static ActionType fromString(String? value) {
    return ActionType.values.firstWhere(
      (e) => e.value == value || e.name == value,
      orElse: () => ActionType.writeLog,
    );
  }
}

/// Workflow eylem
class WorkflowAction {
  /// Eylem ID
  final String id;

  /// Eylem tipi
  final ActionType type;

  /// Hedef ID (variable, workflow, vb.)
  final String? targetId;

  /// Değer
  final dynamic value;

  /// Sıra
  final int order;

  /// Aktif mi?
  final bool enabled;

  /// Ek parametreler
  final Map<String, dynamic> params;

  const WorkflowAction({
    required this.id,
    required this.type,
    this.targetId,
    this.value,
    this.order = 0,
    this.enabled = true,
    this.params = const {},
  });

  factory WorkflowAction.fromJson(Map<String, dynamic> json) {
    return WorkflowAction(
      id: json['id'] as String,
      type: ActionType.fromString(json['type'] as String?),
      targetId: json['target_id'] as String?,
      value: json['value'],
      order: json['order'] as int? ?? 0,
      enabled: json['enabled'] as bool? ?? true,
      params: json['params'] as Map<String, dynamic>? ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.value,
      'target_id': targetId,
      'value': value,
      'order': order,
      'enabled': enabled,
      'params': params,
    };
  }
}

/// Koşul operatörü
enum ConditionOperator {
  /// Eşit
  eq('EQ', '='),

  /// Eşit değil
  neq('NEQ', '≠'),

  /// Büyük
  gt('GT', '>'),

  /// Büyük veya eşit
  gte('GTE', '≥'),

  /// Küçük
  lt('LT', '<'),

  /// Küçük veya eşit
  lte('LTE', '≤'),

  /// İçerir
  contains('CONTAINS', 'içerir'),

  /// Boş
  isEmpty('IS_EMPTY', 'boş'),

  /// Boş değil
  isNotEmpty('IS_NOT_EMPTY', 'boş değil');

  final String value;
  final String symbol;
  const ConditionOperator(this.value, this.symbol);

  static ConditionOperator fromString(String? value) {
    return ConditionOperator.values.firstWhere(
      (e) => e.value == value || e.name == value,
      orElse: () => ConditionOperator.eq,
    );
  }
}

/// Workflow koşul
class WorkflowCondition {
  /// Koşul ID
  final String id;

  /// Kaynak (variable, metadata, vb.)
  final String sourceType;

  /// Kaynak ID
  final String? sourceId;

  /// Operatör
  final ConditionOperator operator;

  /// Hedef değer
  final dynamic targetValue;

  /// Aktif mi?
  final bool enabled;

  const WorkflowCondition({
    required this.id,
    required this.sourceType,
    this.sourceId,
    required this.operator,
    this.targetValue,
    this.enabled = true,
  });

  factory WorkflowCondition.fromJson(Map<String, dynamic> json) {
    return WorkflowCondition(
      id: json['id'] as String,
      sourceType: json['source_type'] as String,
      sourceId: json['source_id'] as String?,
      operator: ConditionOperator.fromString(json['operator'] as String?),
      targetValue: json['target_value'],
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source_type': sourceType,
      'source_id': sourceId,
      'operator': operator.value,
      'target_value': targetValue,
      'enabled': enabled,
    };
  }
}

/// Workflow çalıştırma kaydı
class WorkflowRun {
  /// Çalıştırma ID
  final String id;

  /// Workflow ID
  final String workflowId;

  /// Başlangıç zamanı
  final DateTime startedAt;

  /// Bitiş zamanı
  final DateTime? completedAt;

  /// Sonuç
  final WorkflowRunResult result;

  /// Hata mesajı
  final String? errorMessage;

  /// Tetikleyici bilgisi
  final Map<String, dynamic>? triggerInfo;

  /// Eylem sonuçları
  final List<Map<String, dynamic>> actionResults;

  const WorkflowRun({
    required this.id,
    required this.workflowId,
    required this.startedAt,
    this.completedAt,
    required this.result,
    this.errorMessage,
    this.triggerInfo,
    this.actionResults = const [],
  });

  /// Süre
  Duration? get duration {
    if (completedAt == null) return null;
    return completedAt!.difference(startedAt);
  }

  /// Süre formatlanmış
  String get durationFormatted {
    final d = duration;
    if (d == null) return '-';
    if (d.inSeconds < 1) return '${d.inMilliseconds}ms';
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    return '${d.inMinutes}dk ${d.inSeconds % 60}s';
  }

  factory WorkflowRun.fromJson(Map<String, dynamic> json) {
    return WorkflowRun(
      id: json['id'] as String,
      workflowId: json['workflow_id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
      result: WorkflowRunResult.fromString(json['result'] as String?) ??
          WorkflowRunResult.failure,
      errorMessage: json['error_message'] as String?,
      triggerInfo: json['trigger_info'] as Map<String, dynamic>?,
      actionResults: json['action_results'] != null
          ? List<Map<String, dynamic>>.from(json['action_results'] as List)
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workflow_id': workflowId,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'result': result.value,
      'error_message': errorMessage,
      'trigger_info': triggerInfo,
      'action_results': actionResults,
    };
  }
}
