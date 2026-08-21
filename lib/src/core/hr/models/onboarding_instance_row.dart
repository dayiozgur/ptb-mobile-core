/// Oryantasyon / işten-çıkış süreç örneği (instance) satırı — salt-okuma.
///
/// Web `OnboardingService`
/// (`libs/@ptb/admin-management/src/lib/onboarding/onboarding.service.ts`)
/// `listInstances(kind)` yolunun aynası. Aynı dört `staff_onboarding_*` tablo
/// hem oryantasyon (`type='onboarding'`) hem işten-çıkış (`type='offboarding'`)
/// süreçlerini besler; ekran ayrımı `type` kolonu ile yapılır.
///
/// İlerleme (`doneCount`/`totalCount`) `staff_onboarding_tasks` üzerinden
/// toplanır ve dışarıdan enjekte edilir (tek düz sorgu, istemcide gruplanır).
class OnboardingInstanceRow {
  final String id;
  final String? staffName;
  final String? templateName;

  /// `onboarding` | `offboarding`.
  final String type;
  final String? status;
  final DateTime? startedAt;
  final DateTime? dueDate;
  final DateTime? completedAt;

  final int doneCount;
  final int totalCount;

  const OnboardingInstanceRow({
    required this.id,
    this.staffName,
    this.templateName,
    this.type = 'onboarding',
    this.status,
    this.startedAt,
    this.dueDate,
    this.completedAt,
    this.doneCount = 0,
    this.totalCount = 0,
  });

  /// İlerleme oranı 0..1 (görev yoksa 0).
  double get ratio =>
      totalCount > 0 ? (doneCount / totalCount).clamp(0.0, 1.0).toDouble() : 0.0;

  static DateTime? _date(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString())?.toLocal();
  }

  static String? _embeddedName(dynamic embed) {
    if (embed is Map<String, dynamic>) {
      final name = embed['name'] as String?;
      if (name != null && name.trim().isNotEmpty) return name;
    }
    if (embed is List && embed.isNotEmpty) {
      final first = embed.first;
      if (first is Map<String, dynamic>) return first['name'] as String?;
    }
    return null;
  }

  /// `staffs` embed'inden ad çöz: `name`, yoksa `first_name last_name`.
  static String? _staffName(dynamic embed) {
    Map<String, dynamic>? m;
    if (embed is Map<String, dynamic>) {
      m = embed;
    } else if (embed is List && embed.isNotEmpty && embed.first is Map) {
      m = (embed.first as Map).cast<String, dynamic>();
    }
    if (m == null) return null;
    final name = m['name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    final fn = (m['first_name'] as String? ?? '').trim();
    final ln = (m['last_name'] as String? ?? '').trim();
    final joined = [fn, ln].where((s) => s.isNotEmpty).join(' ');
    return joined.isNotEmpty ? joined : null;
  }

  factory OnboardingInstanceRow.fromJson(
    Map<String, dynamic> json, {
    int doneCount = 0,
    int totalCount = 0,
  }) {
    return OnboardingInstanceRow(
      id: json['id'] as String,
      staffName: _staffName(json['staffs']),
      templateName: _embeddedName(json['staff_onboarding_templates']),
      type: json['type'] as String? ?? 'onboarding',
      status: json['status'] as String?,
      startedAt: _date(json['started_at']),
      dueDate: _date(json['due_date']),
      completedAt: _date(json['completed_at']),
      doneCount: doneCount,
      totalCount: totalCount,
    );
  }
}
