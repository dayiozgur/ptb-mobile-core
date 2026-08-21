/// Çalışana atanmış tek bir İK belgesi (zimmet / sözleşme / eğitim).
///
/// Kaynak: SECDEF, `auth.uid()`-kapsamlı RPC `fn_hr_my_documents` (web
/// `EssService.getMyDocuments` ile birebir sözleşme). Satırlar entity
/// kayıtlarıdır (dosya/storage-path İÇERMEZ) → salt-görüntüleme.
class MyHrDocument {
  /// Belge tipi: `hr_asset` | `hr_contract` | `hr_training` (veya ham string).
  final String docType;
  final String id;
  final String code;
  final String title;
  final String subtitle;
  final String status;

  /// Kayıt/olay tarihi (varsa).
  final DateTime? recordDate;
  final DateTime? createdAt;

  const MyHrDocument({
    required this.docType,
    required this.id,
    required this.code,
    required this.title,
    required this.subtitle,
    required this.status,
    this.recordDate,
    this.createdAt,
  });

  factory MyHrDocument.fromJson(Map<String, dynamic> json) {
    return MyHrDocument(
      docType: (json['doc_type'] as String?) ?? '',
      id: (json['id']?.toString()) ?? '',
      code: (json['code'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      subtitle: (json['subtitle'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      recordDate: json['record_date'] != null
          ? DateTime.tryParse(json['record_date'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}
