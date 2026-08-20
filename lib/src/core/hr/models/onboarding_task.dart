/// A single onboarding task from `fn_hr_my_onboarding_tasks`.
class OnboardingTask {
  final String? taskId;
  final String? instanceId;
  final String? title;
  final String? status;
  final DateTime? dueDate;
  final String? notes;
  final String? type;
  final String? subjectName;
  final String? templateName;
  final bool overdue;

  const OnboardingTask({
    this.taskId,
    this.instanceId,
    this.title,
    this.status,
    this.dueDate,
    this.notes,
    this.type,
    this.subjectName,
    this.templateName,
    this.overdue = false,
  });

  factory OnboardingTask.fromJson(Map<String, dynamic> json) {
    return OnboardingTask(
      taskId: json['task_id'] as String?,
      instanceId: json['instance_id'] as String?,
      title: json['title'] as String?,
      status: json['status'] as String?,
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'] as String)
          : null,
      notes: json['notes'] as String?,
      type: json['type'] as String?,
      subjectName: json['subject_name'] as String?,
      templateName: json['template_name'] as String?,
      overdue: json['overdue'] as bool? ?? false,
    );
  }
}
