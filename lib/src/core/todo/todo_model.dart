/// Todo durumu
enum TodoStatus {
  pending('pending', 'Beklemede'),
  inProgress('in_progress', 'Devam Ediyor'),
  completed('completed', 'Tamamlandi'),
  cancelled('cancelled', 'Iptal Edildi');

  final String value;
  final String label;
  const TodoStatus(this.value, this.label);

  static TodoStatus fromString(String? value) {
    return TodoStatus.values.firstWhere(
      (e) => e.value == value || e.name == value,
      orElse: () => TodoStatus.pending,
    );
  }

  bool get isOpen => this == pending || this == inProgress;
  bool get isDone => this == completed || this == cancelled;
}

/// Todo onceligi
enum TodoPriority {
  low('low', 'Dusuk'),
  medium('medium', 'Orta'),
  high('high', 'Yuksek'),
  urgent('urgent', 'Acil');

  final String value;
  final String label;
  const TodoPriority(this.value, this.label);

  static TodoPriority fromString(String? value) {
    return TodoPriority.values.firstWhere(
      (e) => e.value == value || e.name == value,
      orElse: () => TodoPriority.medium,
    );
  }
}

/// Todo Item modeli
///
/// todo_items tablosunu temsil eder.
class TodoItem {
  final String id;
  final String tenantId;
  final String title;
  final String? description;
  final TodoStatus status;
  final TodoPriority priority;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final String createdBy;
  final String? assignedTo;
  final String? assignedToName; // joined
  final String? linkedEventId;
  final bool active;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? updatedBy;

  const TodoItem({
    required this.id,
    required this.tenantId,
    required this.title,
    this.description,
    this.status = TodoStatus.pending,
    this.priority = TodoPriority.medium,
    this.dueDate,
    this.completedAt,
    required this.createdBy,
    this.assignedTo,
    this.assignedToName,
    this.linkedEventId,
    this.active = true,
    required this.createdAt,
    this.updatedAt,
    this.updatedBy,
  });

  // ============================================
  // COMPUTED PROPERTIES
  // ============================================

  /// Suresi gecmis mi?
  bool get isOverdue =>
      dueDate != null &&
      status.isOpen &&
      dueDate!.isBefore(DateTime.now());

  /// Bugun mu?
  bool get isDueToday {
    if (dueDate == null) return false;
    final now = DateTime.now();
    return dueDate!.year == now.year &&
        dueDate!.month == now.month &&
        dueDate!.day == now.day;
  }

  /// Atanmis mi?
  bool get isAssigned => assignedTo != null;

  /// Tamamlanmis mi?
  bool get isCompleted => status == TodoStatus.completed;

  // ============================================
  // JSON SERIALIZATION
  // ============================================

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    // assigned_to join desteği: staffs(name)
    String? assignedName;
    if (json['staffs'] is Map<String, dynamic>) {
      assignedName = json['staffs']['name'] as String?;
    }

    return TodoItem(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: TodoStatus.fromString(json['status'] as String?),
      priority: TodoPriority.fromString(json['priority'] as String?),
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
      createdBy: json['created_by'] as String,
      assignedTo: json['assigned_to'] as String?,
      assignedToName: assignedName,
      linkedEventId: json['linked_event_id'] as String?,
      active: json['active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      updatedBy: json['updated_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'title': title,
      'description': description,
      'status': status.value,
      'priority': priority.value,
      'due_date': dueDate?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'created_by': createdBy,
      'assigned_to': assignedTo,
      'linked_event_id': linkedEventId,
      'active': active,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'updated_by': updatedBy,
    };
  }

  /// Insert icin JSON (id ve timestamps haric)
  Map<String, dynamic> toInsertJson() {
    return {
      'tenant_id': tenantId,
      'title': title,
      'description': description,
      'status': status.value,
      'priority': priority.value,
      'due_date': dueDate?.toIso8601String(),
      'created_by': createdBy,
      'assigned_to': assignedTo,
      'linked_event_id': linkedEventId,
    };
  }

  // ============================================
  // COPY WITH
  // ============================================

  TodoItem copyWith({
    String? id,
    String? tenantId,
    String? title,
    String? description,
    TodoStatus? status,
    TodoPriority? priority,
    DateTime? dueDate,
    DateTime? completedAt,
    String? createdBy,
    String? assignedTo,
    String? assignedToName,
    String? linkedEventId,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return TodoItem(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      completedAt: completedAt ?? this.completedAt,
      createdBy: createdBy ?? this.createdBy,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      linkedEventId: linkedEventId ?? this.linkedEventId,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  @override
  String toString() => 'TodoItem($id, $title, ${status.value})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TodoItem && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Todo Share modeli
///
/// todo_shares tablosunu temsil eder.
class TodoShare {
  final String id;
  final String todoId;
  final String sharedBy;
  final String? sharedWithUser;
  final String? sharedWithTeam;
  final String? sharedWithDepartment;
  final bool canEdit;
  final bool canDelete;
  final DateTime sharedAt;

  const TodoShare({
    required this.id,
    required this.todoId,
    required this.sharedBy,
    this.sharedWithUser,
    this.sharedWithTeam,
    this.sharedWithDepartment,
    this.canEdit = false,
    this.canDelete = false,
    required this.sharedAt,
  });

  factory TodoShare.fromJson(Map<String, dynamic> json) {
    return TodoShare(
      id: json['id'] as String,
      todoId: json['todo_id'] as String,
      sharedBy: json['shared_by'] as String,
      sharedWithUser: json['shared_with_user'] as String?,
      sharedWithTeam: json['shared_with_team'] as String?,
      sharedWithDepartment: json['shared_with_department'] as String?,
      canEdit: json['can_edit'] as bool? ?? false,
      canDelete: json['can_delete'] as bool? ?? false,
      sharedAt: json['shared_at'] != null
          ? DateTime.parse(json['shared_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'todo_id': todoId,
      'shared_by': sharedBy,
      'shared_with_user': sharedWithUser,
      'shared_with_team': sharedWithTeam,
      'shared_with_department': sharedWithDepartment,
      'can_edit': canEdit,
      'can_delete': canDelete,
      'shared_at': sharedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'todo_id': todoId,
      'shared_by': sharedBy,
      'shared_with_user': sharedWithUser,
      'shared_with_team': sharedWithTeam,
      'shared_with_department': sharedWithDepartment,
      'can_edit': canEdit,
      'can_delete': canDelete,
    };
  }

  @override
  String toString() => 'TodoShare($id, todo=$todoId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TodoShare && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Todo istatistikleri
class TodoStats {
  final int total;
  final int pending;
  final int inProgress;
  final int completed;
  final int overdue;

  const TodoStats({
    this.total = 0,
    this.pending = 0,
    this.inProgress = 0,
    this.completed = 0,
    this.overdue = 0,
  });

  @override
  String toString() =>
      'TodoStats(total=$total, pending=$pending, inProgress=$inProgress, completed=$completed, overdue=$overdue)';
}
