/// KVKK org-geneli rıza özeti satırı — bir rıza tipi (`kvkk_consent_types`) +
/// o tip için org genelinde rıza veren personel sayısı / toplam personel.
///
/// Web `KvkkService` / `KvkkAdminService` (@ptb/hr-management) ile aynı
/// tablolara dayanır: rıza kataloğu `kvkk_consent_types`, kayıtlar
/// `kvkk_consents` (granted). Mobil v1 SALT-OKUMA: yönetici org-geneli özet.
library;

/// Bir rıza tipi için org-geneli rıza kapsama satırı.
class KvkkOverviewRow {
  final String consentTypeId;
  final String code;
  final String name;
  final String? description;
  final bool required;
  final bool active;
  final String? version;

  /// Bu rıza tipi için rıza vermiş (granted) tekil personel sayısı.
  final int grantedCount;

  /// Kapsamdaki toplam (aktif) personel sayısı.
  final int totalStaff;

  const KvkkOverviewRow({
    required this.consentTypeId,
    required this.code,
    required this.name,
    required this.description,
    required this.required,
    required this.active,
    required this.version,
    required this.grantedCount,
    required this.totalStaff,
  });

  /// Rıza tipi meta'sı + hesaplanmış sayımlardan bir özet satırı kurar.
  factory KvkkOverviewRow.fromType(
    Map<String, dynamic> type, {
    required int grantedCount,
    required int totalStaff,
  }) {
    return KvkkOverviewRow(
      consentTypeId: type['id'].toString(),
      code: (type['code'] as String?) ?? '',
      name: (type['name'] as String?) ?? '',
      description: type['description'] as String?,
      required: type['required'] == true,
      active: type['active'] != false,
      version: type['version'] as String?,
      grantedCount: grantedCount,
      totalStaff: totalStaff,
    );
  }

  /// Rıza kapsama oranı (0..1); toplam personel 0 ise 0.
  double get coverageRatio =>
      totalStaff > 0 ? (grantedCount / totalStaff).clamp(0, 1).toDouble() : 0;
}
