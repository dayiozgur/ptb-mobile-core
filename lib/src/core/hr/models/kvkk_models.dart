/// KVKK (kişisel verilerin korunması) rıza modelleri.
///
/// Web `KvkkService` ile birebir sözleşme:
/// - `kvkk_consent_types` → rıza kataloğu (global tenant_id=null + tenant'a özel).
/// - `kvkk_consents`      → kullanıcının kendi (staff bazlı) rıza kayıtları.
///
/// Mobil v1 SALT-OKUMA: katalog + kullanıcının rıza durumu görüntülenir
/// (grant/revoke web'de vardır; mobilde v1'de bağlanmaz).
library;

/// Tenant'ın tanımladığı bir KVKK rıza kategorisi. Global satırlar
/// (`tenantId == null`) paylaşılan varsayılanlardır.
class KvkkConsentType {
  final String id;
  final String? tenantId;
  final String code;
  final String name;
  final String? description;
  final bool required;
  final String? version;
  final bool active;

  const KvkkConsentType({
    required this.id,
    required this.tenantId,
    required this.code,
    required this.name,
    required this.description,
    required this.required,
    required this.version,
    required this.active,
  });

  factory KvkkConsentType.fromJson(Map<String, dynamic> json) {
    return KvkkConsentType(
      id: json['id'].toString(),
      tenantId: json['tenant_id'] as String?,
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      description: json['description'] as String?,
      required: json['required'] == true,
      version: json['version'] as String?,
      active: json['active'] != false,
    );
  }
}

/// Kullanıcının bir rıza tipi için kayıtlı kararı.
class KvkkConsent {
  final String id;
  final String consentTypeId;
  final bool granted;
  final DateTime? grantedAt;
  final DateTime? revokedAt;
  final String? version;

  const KvkkConsent({
    required this.id,
    required this.consentTypeId,
    required this.granted,
    required this.grantedAt,
    required this.revokedAt,
    required this.version,
  });

  factory KvkkConsent.fromJson(Map<String, dynamic> json) {
    return KvkkConsent(
      id: json['id'].toString(),
      consentTypeId: json['consent_type_id'].toString(),
      granted: json['granted'] == true,
      grantedAt: json['granted_at'] != null
          ? DateTime.tryParse(json['granted_at'].toString())
          : null,
      revokedAt: json['revoked_at'] != null
          ? DateTime.tryParse(json['revoked_at'].toString())
          : null,
      version: json['version'] as String?,
    );
  }
}

/// Kullanıcının bir kategori için nihai rıza durumu.
enum ConsentState { granted, revoked, none }

/// Rıza tipi + kullanıcının kendi kararı (görüntüleme için birleştirilmiş satır).
/// Web `KvkkConsentRow` ile aynı `merge` mantığı.
class KvkkConsentRow {
  final KvkkConsentType type;
  final KvkkConsent? consent;
  final ConsentState state;

  const KvkkConsentRow({
    required this.type,
    required this.consent,
    required this.state,
  });
}

/// "Verilerim" (KVKK kişisel-veri) genel bakışı — rıza satırlarından türetilir.
/// Salt-okuma özet + kategori listesi.
class MyDataOverview {
  final List<KvkkConsentRow> categories;
  final int totalCategories;
  final int grantedCount;
  final int requiredCount;
  final int optionalCount;

  const MyDataOverview({
    required this.categories,
    required this.totalCategories,
    required this.grantedCount,
    required this.requiredCount,
    required this.optionalCount,
  });

  factory MyDataOverview.fromRows(List<KvkkConsentRow> rows) {
    var granted = 0;
    var required = 0;
    for (final r in rows) {
      if (r.state == ConsentState.granted) granted++;
      if (r.type.required) required++;
    }
    return MyDataOverview(
      categories: rows,
      totalCategories: rows.length,
      grantedCount: granted,
      requiredCount: required,
      optionalCount: rows.length - required,
    );
  }
}
