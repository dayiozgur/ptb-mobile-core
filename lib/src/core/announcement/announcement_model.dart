/// Duyuru (announcement) modeli — `public.announcements` tablosu.
///
/// Web + mobil ortak kaynak (RLS: okuma=tenant, yazma=admin). Mobil salt-okuma
/// tüketir (liste + detay).
class Announcement {
  final String id;
  final String title;
  final String? body;
  final String? category;
  final String? imageUrl;
  final DateTime? publishDate;
  final bool published;

  const Announcement({
    required this.id,
    required this.title,
    this.body,
    this.category,
    this.imageUrl,
    this.publishDate,
    this.published = true,
  });

  /// Liste özeti için HTML-etiketsiz düz metin (body HTML olabilir).
  String get bodyPreview {
    final b = body ?? '';
    if (b.isEmpty) return '';
    return b
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString(),
      category: json['category']?.toString(),
      imageUrl: json['image_url']?.toString(),
      publishDate: json['publish_date'] != null
          ? DateTime.tryParse(json['publish_date'].toString())
          : null,
      published: json['published'] as bool? ?? true,
    );
  }
}
