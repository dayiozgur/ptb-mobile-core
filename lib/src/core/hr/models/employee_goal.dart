/// Çalışan performans hedefi — `employee_goals` tablosunun bir satırı.
///
/// Web PHR performans self-servisi (`PerformanceService.getMyGoals`) ile aynı
/// sözleşme: satır `staff_id = benim staff'ım` (RLS + sorgu) ile kapsanır ve
/// `performance_cycles(name)` embed'i dönem adını ([cycleName]) taşır.
///
/// NOT: DB'de ayrı bir `due_date` / hedef-tarih kolonu YOKTUR; "dönem" bilgisi
/// bağlı performans döngüsünün adıdır ([cycleName]).
class EmployeeGoal {
  final String id;
  final String? cycleId;

  /// Bağlı performans döngüsünün adı (dönem) — embed'den çözülür.
  final String? cycleName;
  final String title;
  final String? description;

  /// Ağırlık (yüzde) — `numeric`.
  final num weight;

  /// İlerleme 0–100 (DB CHECK) — `integer`.
  final int progress;

  /// `active` | `done` | `cancelled`.
  final String status;

  const EmployeeGoal({
    required this.id,
    this.cycleId,
    this.cycleName,
    this.title = '',
    this.description,
    this.weight = 0,
    this.progress = 0,
    this.status = 'active',
  });

  factory EmployeeGoal.fromJson(Map<String, dynamic> json) {
    return EmployeeGoal(
      id: json['id'] as String,
      cycleId: json['cycle_id'] as String?,
      cycleName: _embeddedName(json['performance_cycles']),
      title: (json['title'] as String?) ?? '',
      description: json['description'] as String?,
      weight: (json['weight'] as num?) ?? 0,
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      status: (json['status'] as String?) ?? 'active',
    );
  }

  /// PostgREST many-to-one embed'i obje (bazı yapılarda dizi) döndürür.
  static String? _embeddedName(dynamic rel) {
    if (rel == null) return null;
    if (rel is List) {
      if (rel.isEmpty) return null;
      final first = rel.first;
      return first is Map ? first['name'] as String? : null;
    }
    if (rel is Map) return rel['name'] as String?;
    return null;
  }
}
