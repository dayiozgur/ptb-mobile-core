/// Yönetim (İK admin) performans değerlendirmesi — `performance_reviews`
/// tablosunun bir satırı; tenant'taki **tüm** değerlendirmeleri kapsar.
///
/// Web PHR yönetim (`PerformanceService.getReviews` / `REVIEW_SELECT`) ile aynı
/// sözleşme. ESS [PerformanceReview]'den farkı: değerlendirilen (reviewee) adını
/// da taşır — admin listesi hem değerlendirilen hem değerlendiren adını gösterir.
///
/// Embed'ler:
///   `performance_cycles(name)`                          → [cycleName] (dönem)
///   `staffs!performance_reviews_staff_id_fkey(...)`     → [revieweeName]
///   `reviewer:staffs!…reviewer_staff_id_fkey(...)`      → [reviewerName]
///
/// Durum self → yönetici → nihai akışında ilerler:
/// `pending` | `self_submitted` | `manager_submitted` | `finalized`.
class AdminPerformanceReview {
  final String id;
  final String? cycleId;

  /// Bağlı dönem adı — embed'den çözülür.
  final String? cycleName;

  /// Değerlendirilen (reviewee) görünen adı — embed'den çözülür.
  final String? revieweeName;

  /// Değerlendiren (yönetici) görünen adı — embed'den çözülür.
  final String? reviewerName;

  final num? selfRating;
  final num? managerRating;

  /// Nihai/genel puan — listede öne çıkan skor.
  final num? overallRating;

  /// `pending` | `self_submitted` | `manager_submitted` | `finalized`.
  final String status;

  /// Karar tarihi (yönetici sonlandırınca) — yoksa [createdAt]'e düşülür.
  final DateTime? decidedAt;
  final DateTime? createdAt;

  const AdminPerformanceReview({
    required this.id,
    this.cycleId,
    this.cycleName,
    this.revieweeName,
    this.reviewerName,
    this.selfRating,
    this.managerRating,
    this.overallRating,
    this.status = 'pending',
    this.decidedAt,
    this.createdAt,
  });

  /// Gösterilecek tarih — karar tarihi öncelikli, yoksa oluşturulma tarihi.
  DateTime? get displayDate => decidedAt ?? createdAt;

  factory AdminPerformanceReview.fromJson(Map<String, dynamic> json) {
    return AdminPerformanceReview(
      id: json['id'] as String,
      cycleId: json['cycle_id'] as String?,
      cycleName: _embeddedName(json['performance_cycles']),
      revieweeName: _staffFullName(json['staffs']),
      reviewerName: _staffFullName(json['reviewer']),
      selfRating: json['self_rating'] as num?,
      managerRating: json['manager_rating'] as num?,
      overallRating: json['overall_rating'] as num?,
      status: (json['status'] as String?) ?? 'pending',
      decidedAt: _parseDate(json['decided_at']),
      createdAt: _parseDate(json['created_at']),
    );
  }

  static DateTime? _parseDate(dynamic v) =>
      v is String ? DateTime.tryParse(v) : null;

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

  /// Embed edilmiş staff ilişkisinden görünen ad (ad+soyad, yoksa `name`).
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
