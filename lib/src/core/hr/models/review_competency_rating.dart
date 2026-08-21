/// Bir değerlendirmeye bağlı tek bir yetkinlik puanı — `review_competency_ratings`.
///
/// Web `PerformanceService.getCompetencyRatings` ile birebir sözleşme:
///   `review_id = <değerlendirme id>` ile çekilir, `created_at` sıralanır.
/// Salt-okuma; detay alt-sayfasında yetkinlik kırılımını gösterir.
class ReviewCompetencyRating {
  final String id;
  final String? competencyId;
  final String competencyLabel;
  final num rating;
  final String? comment;

  const ReviewCompetencyRating({
    required this.id,
    this.competencyId,
    required this.competencyLabel,
    this.rating = 0,
    this.comment,
  });

  factory ReviewCompetencyRating.fromJson(Map<String, dynamic> json) {
    return ReviewCompetencyRating(
      id: json['id'] as String,
      competencyId: json['competency_id'] as String?,
      competencyLabel: (json['competency_label'] as String?) ?? '',
      rating: (json['rating'] as num?) ?? 0,
      comment: json['comment'] as String?,
    );
  }
}
