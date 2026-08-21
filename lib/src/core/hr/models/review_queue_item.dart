/// Yöneticinin değerlendirme kuyruğundaki bir satır — `performance_reviews`
/// tablosundan, `reviewer_staff_id = benim staff'ım` kapsamıyla.
///
/// Web `PerformanceService.getReviewQueue` ile birebir sözleşme: satırlar
///   `reviewer_staff_id = <benim staff id>`  (RLS + sorgu)
/// ile çekilir, `created_at DESC` sıralanır. Embed'ler:
///   `performance_cycles(name)`                        → [cycleName]
///   `staffs!performance_reviews_staff_id_fkey`        → [staffName] (değerlendirilen)
///
/// Değerlendirme durumu self → yönetici → nihai akışında ilerler:
/// `pending` | `self_submitted` | `manager_submitted` | `finalized`.
class ReviewQueueItem {
  final String id;
  final String? cycleId;

  /// Dönem adı — embed'den çözülür.
  final String? cycleName;

  final String? staffId;

  /// Değerlendirilen kişinin görünen adı — embed'den çözülür.
  final String? staffName;

  final num? selfRating;
  final num? managerRating;
  final num? overallRating;
  final String? selfComments;
  final String? managerComments;

  /// `pending` | `self_submitted` | `manager_submitted` | `finalized`.
  final String status;

  final DateTime? decidedAt;
  final DateTime? createdAt;

  const ReviewQueueItem({
    required this.id,
    this.cycleId,
    this.cycleName,
    this.staffId,
    this.staffName,
    this.selfRating,
    this.managerRating,
    this.overallRating,
    this.selfComments,
    this.managerComments,
    this.status = 'pending',
    this.decidedAt,
    this.createdAt,
  });

  /// Gösterilecek tarih — karar tarihi öncelikli, yoksa oluşturulma tarihi.
  DateTime? get displayDate => decidedAt ?? createdAt;

  factory ReviewQueueItem.fromJson(Map<String, dynamic> json) {
    return ReviewQueueItem(
      id: json['id'] as String,
      cycleId: json['cycle_id'] as String?,
      cycleName: _embeddedName(json['performance_cycles']),
      staffId: json['staff_id'] as String?,
      staffName: _staffFullName(json['staffs']),
      selfRating: json['self_rating'] as num?,
      managerRating: json['manager_rating'] as num?,
      overallRating: json['overall_rating'] as num?,
      selfComments: json['self_comments'] as String?,
      managerComments: json['manager_comments'] as String?,
      status: (json['status'] as String?) ?? 'pending',
      decidedAt: _parseDate(json['decided_at']),
      createdAt: _parseDate(json['created_at']),
    );
  }

  static DateTime? _parseDate(dynamic v) =>
      v is String ? DateTime.tryParse(v) : null;

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

  static String? _staffFullName(dynamic rel) {
    final s = rel is List ? (rel.isEmpty ? null : rel.first) : rel;
    if (s is! Map) return null;
    final first = s['first_name'] as String?;
    final last = s['last_name'] as String?;
    final full = [first, last].where((e) => e != null && e.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;
    return s['name'] as String?;
  }
}
