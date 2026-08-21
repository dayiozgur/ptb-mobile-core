/// Aday başvurusu — `job_applications` tablosunun bir satırı.
///
/// Web PHR ATS (`AtsService.APPLICATION_SELECT` / `JobApplication`) ile birebir
/// okuma sözleşmesi. İki FK-hint embed'i:
///   `job_postings!job_applications_job_posting_id_fkey(title)`   → [postingTitle]
///   `job_candidates!job_applications_candidate_id_fkey(...)`     → [candidateName]
///
/// (Aday bilgisi ayrı bir `candidates` tablosunda DEĞİL; `job_candidates`
/// üzerinden embed edilir.) Salt-okuma viewer (v1).
class JobApplicationRow {
  final String id;
  final String jobPostingId;

  /// Başvurulan ilan başlığı — embed'den çözülür.
  final String? postingTitle;

  final String candidateId;

  /// Aday görünen adı (ad + soyad) — `job_candidates` embed'inden çözülür.
  final String? candidateName;

  final String? organizationId;

  /// Hat aşaması: `applied` | `screening` | `interview` | `offer` |
  /// `hired` | `rejected`.
  final String stage;

  /// 1–5 değerlendirme puanı (varsa).
  final int? rating;

  final String? recruiterStaffId;
  final DateTime? appliedAt;
  final DateTime? decidedAt;
  final String? notes;
  final bool active;
  final DateTime? createdAt;

  const JobApplicationRow({
    required this.id,
    required this.jobPostingId,
    this.postingTitle,
    required this.candidateId,
    this.candidateName,
    this.organizationId,
    this.stage = 'applied',
    this.rating,
    this.recruiterStaffId,
    this.appliedAt,
    this.decidedAt,
    this.notes,
    this.active = true,
    this.createdAt,
  });

  /// Listede gösterilecek tarih — başvuru tarihi öncelikli, yoksa oluşturulma.
  DateTime? get displayDate => appliedAt ?? createdAt;

  /// Boş adı `—` ile güvene alan görünen ad.
  String get displayName =>
      (candidateName != null && candidateName!.isNotEmpty)
          ? candidateName!
          : '—';

  factory JobApplicationRow.fromJson(Map<String, dynamic> json) {
    return JobApplicationRow(
      id: json['id'] as String,
      jobPostingId: (json['job_posting_id'] as String?) ?? '',
      postingTitle: _embeddedTitle(json['job_postings']),
      candidateId: (json['candidate_id'] as String?) ?? '',
      candidateName: _staffFullName(json['job_candidates']),
      organizationId: json['organization_id'] as String?,
      stage: (json['stage'] as String?) ?? 'applied',
      rating: _toIntOrNull(json['rating']),
      recruiterStaffId: json['recruiter_staff_id'] as String?,
      appliedAt: _parseDate(json['applied_at']),
      decidedAt: _parseDate(json['decided_at']),
      notes: json['notes'] as String?,
      active: json['active'] != false,
      createdAt: _parseDate(json['created_at']),
    );
  }

  static int? _toIntOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static DateTime? _parseDate(dynamic v) =>
      v is String ? DateTime.tryParse(v) : null;

  /// Embed edilmiş ilan ilişkisinden `title` (obje veya dizi).
  static String? _embeddedTitle(dynamic rel) {
    if (rel == null) return null;
    if (rel is List) {
      if (rel.isEmpty) return null;
      final first = rel.first;
      return first is Map ? first['title'] as String? : null;
    }
    if (rel is Map) return rel['title'] as String?;
    return null;
  }

  /// Embed edilmiş aday ilişkisinden görünen ad (ad + soyad, yoksa `name`).
  static String? _staffFullName(dynamic rel) {
    final s = rel is List ? (rel.isEmpty ? null : rel.first) : rel;
    if (s is! Map) return null;
    final first = s['first_name'] as String?;
    final last = s['last_name'] as String?;
    final full =
        [first, last].where((e) => e != null && e.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;
    return s['name'] as String?;
  }
}
