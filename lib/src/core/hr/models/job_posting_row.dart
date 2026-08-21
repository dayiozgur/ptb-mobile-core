/// İş ilanı (requisition) — `job_postings` tablosunun bir satırı.
///
/// Web PHR ATS (`AtsService.POSTING_SELECT` / `JobPosting`) ile birebir okuma
/// sözleşmesi. `departments!job_postings_department_id_fkey(name)` embed'inden
/// [departmentName] çözülür; başvuru sayısı PostgREST `job_applications(count)`
/// aggregate embed'inden [applicantCount] olarak okunur.
///
/// Salt-okuma viewer (v1) — yazma yok.
class JobPostingRow {
  final String id;
  final String? organizationId;
  final String? departmentId;

  /// Bağlı departman adı — embed'den çözülür.
  final String? departmentName;

  final String title;
  final String? description;

  /// `full_time` | `part_time` | `contract` | `intern` (serbest metin de olabilir).
  final String? employmentType;
  final String? location;

  /// Açık pozisyon sayısı (kaç kişi alınacak).
  final int openings;

  /// İlan durumu: `draft` | `open` | `on_hold` | `closed`.
  final String status;

  final bool active;
  final DateTime? createdAt;

  /// İlana yapılan başvuru sayısı — `job_applications(count)` embed'inden.
  final int applicantCount;

  const JobPostingRow({
    required this.id,
    this.organizationId,
    this.departmentId,
    this.departmentName,
    required this.title,
    this.description,
    this.employmentType,
    this.location,
    this.openings = 0,
    this.status = 'draft',
    this.active = true,
    this.createdAt,
    this.applicantCount = 0,
  });

  factory JobPostingRow.fromJson(Map<String, dynamic> json) {
    return JobPostingRow(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String?,
      departmentId: json['department_id'] as String?,
      departmentName: _embeddedName(json['departments']),
      title: (json['title'] as String?) ?? '',
      description: json['description'] as String?,
      employmentType: json['employment_type'] as String?,
      location: json['location'] as String?,
      openings: _toInt(json['openings']),
      status: (json['status'] as String?) ?? 'draft',
      active: json['active'] != false,
      createdAt: _parseDate(json['created_at']),
      applicantCount: _embeddedCount(json['job_applications']),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
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

  /// PostgREST `job_applications(count)` aggregate embed'i `[{count: N}]`
  /// (bazı yapılarda `{count: N}`) döndürür.
  static int _embeddedCount(dynamic rel) {
    if (rel is List) {
      if (rel.isEmpty) return 0;
      final first = rel.first;
      return first is Map ? _toInt(first['count']) : 0;
    }
    if (rel is Map) return _toInt(rel['count']);
    return 0;
  }
}
