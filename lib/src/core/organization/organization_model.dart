/// Organization durumu
enum OrganizationStatus {
  /// Aktif
  active,

  /// Pasif
  inactive,

  /// Askıda
  suspended,

  /// Kapatılmış
  closed,

  /// Silinmiş
  deleted;

  /// String'den OrganizationStatus'a dönüştür
  static OrganizationStatus fromString(String? value) {
    return OrganizationStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => OrganizationStatus.active,
    );
  }
}

/// Organization (Alt Organizasyon) modeli
///
/// Tenant altındaki departman/bölüm temsili.
/// Hiyerarşi: Tenant → Organization → Site → Unit
class Organization {
  /// Benzersiz ID
  final String id;

  /// Organization adı
  final String name;

  /// Organization kodu (unique identifier)
  final String? code;

  /// Açıklama
  final String? description;

  /// Renk (UI için)
  final String? color;

  /// Görsel yolu
  final String? imagePath;

  /// Aktif mi? (geriye uyumluluk için korundu)
  final bool active;

  /// Organization durumu
  final OrganizationStatus status;

  /// Askıya alınma tarihi
  final DateTime? suspendedAt;

  /// Askıya alınma nedeni
  final String? suspendedReason;

  /// Silinme tarihi (soft delete)
  final DateTime? deletedAt;

  // ============================================
  // AUDIT BİLGİLERİ
  // ============================================

  /// Audit versiyonu (optimistic locking için)
  final int version;

  /// Son audit tarihi
  final DateTime? lastAuditAt;

  /// Son audit yapan kullanıcı
  final String? lastAuditBy;

  /// Audit notları
  final String? auditNotes;

  // ============================================
  // KONUM BİLGİLERİ
  // ============================================

  /// Adres
  final String? address;

  /// Şehir
  final String? city;

  /// İlçe
  final String? town;

  /// Ülke
  final String? country;

  /// Enlem
  final double? latitude;

  /// Boylam
  final double? longitude;

  /// Zoom seviyesi (harita için)
  final int? zoom;

  // ============================================
  // İLİŞKİLER
  // ============================================

  /// Bağlı olduğu Tenant ID
  final String tenantId;

  /// Finansal bilgi ID (1:1)
  final String? financialId;

  /// Harita marker ID
  final String? markerId;

  // ============================================
  // ZAMAN DAMGALARI
  // ============================================

  /// Oluşturulma tarihi
  final DateTime? createdAt;

  /// Güncellenme tarihi
  final DateTime? updatedAt;

  /// Oluşturan kullanıcı
  final String? createdBy;

  /// Güncelleyen kullanıcı
  final String? updatedBy;

  /// Row ID (sıralama için)
  final int? rowId;

  // ============================================
  // CONSTRUCTOR
  // ============================================

  Organization({
    required this.id,
    required this.name,
    required this.tenantId,
    this.code,
    this.description,
    this.color,
    this.imagePath,
    this.active = true,
    this.status = OrganizationStatus.active,
    this.suspendedAt,
    this.suspendedReason,
    this.deletedAt,
    this.version = 1,
    this.lastAuditAt,
    this.lastAuditBy,
    this.auditNotes,
    this.address,
    this.city,
    this.town,
    this.country,
    this.latitude,
    this.longitude,
    this.zoom,
    this.financialId,
    this.markerId,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.rowId,
  });

  // ============================================
  // JSON SERIALIZATION
  // ============================================

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      tenantId: json['tenant_id'] as String,
      code: json['code'] as String?,
      description: json['description'] as String?,
      color: json['color'] as String?,
      imagePath: json['image_path'] as String?,
      active: json['active'] as bool? ?? true,
      status: OrganizationStatus.fromString(json['status'] as String?),
      suspendedAt: json['suspended_at'] != null
          ? DateTime.tryParse(json['suspended_at'] as String)
          : null,
      suspendedReason: json['suspended_reason'] as String?,
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'] as String)
          : null,
      version: json['version'] as int? ?? 1,
      lastAuditAt: json['last_audit_at'] != null
          ? DateTime.tryParse(json['last_audit_at'] as String)
          : null,
      lastAuditBy: json['last_audit_by'] as String?,
      auditNotes: json['audit_notes'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      town: json['town'] as String?,
      country: json['country'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      zoom: json['zoom'] as int?,
      financialId: json['financial_id'] as String?,
      markerId: json['marker_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      rowId: json['row_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'tenant_id': tenantId,
      'code': code,
      'description': description,
      'color': color,
      'image_path': imagePath,
      'active': active,
      'status': status.name,
      'suspended_at': suspendedAt?.toIso8601String(),
      'suspended_reason': suspendedReason,
      'deleted_at': deletedAt?.toIso8601String(),
      'version': version,
      'last_audit_at': lastAuditAt?.toIso8601String(),
      'last_audit_by': lastAuditBy,
      'audit_notes': auditNotes,
      'address': address,
      'city': city,
      'town': town,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'zoom': zoom,
      'financial_id': financialId,
      'marker_id': markerId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
      'row_id': rowId,
    };
  }

  // ============================================
  // COPY WITH
  // ============================================

  Organization copyWith({
    String? id,
    String? name,
    String? tenantId,
    String? code,
    String? description,
    String? color,
    String? imagePath,
    bool? active,
    OrganizationStatus? status,
    DateTime? suspendedAt,
    String? suspendedReason,
    DateTime? deletedAt,
    int? version,
    DateTime? lastAuditAt,
    String? lastAuditBy,
    String? auditNotes,
    String? address,
    String? city,
    String? town,
    String? country,
    double? latitude,
    double? longitude,
    int? zoom,
    String? financialId,
    String? markerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    int? rowId,
  }) {
    return Organization(
      id: id ?? this.id,
      name: name ?? this.name,
      tenantId: tenantId ?? this.tenantId,
      code: code ?? this.code,
      description: description ?? this.description,
      color: color ?? this.color,
      imagePath: imagePath ?? this.imagePath,
      active: active ?? this.active,
      status: status ?? this.status,
      suspendedAt: suspendedAt ?? this.suspendedAt,
      suspendedReason: suspendedReason ?? this.suspendedReason,
      deletedAt: deletedAt ?? this.deletedAt,
      version: version ?? this.version,
      lastAuditAt: lastAuditAt ?? this.lastAuditAt,
      lastAuditBy: lastAuditBy ?? this.lastAuditBy,
      auditNotes: auditNotes ?? this.auditNotes,
      address: address ?? this.address,
      city: city ?? this.city,
      town: town ?? this.town,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      zoom: zoom ?? this.zoom,
      financialId: financialId ?? this.financialId,
      markerId: markerId ?? this.markerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      rowId: rowId ?? this.rowId,
    );
  }

  // ============================================
  // STATUS HELPERS
  // ============================================

  /// Gerçekten aktif mi? (active flag ve status kontrolü)
  bool get isActive => active && status == OrganizationStatus.active;

  /// Askıda mı?
  bool get isSuspended => status == OrganizationStatus.suspended;

  /// Kapatılmış mı?
  bool get isClosed => status == OrganizationStatus.closed;

  /// Silinmiş mi?
  bool get isDeleted => status == OrganizationStatus.deleted;

  /// Audit gerekli mi? (son audit 1 yıldan eski)
  bool get needsAudit {
    if (lastAuditAt == null) return true;
    final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
    return lastAuditAt!.isBefore(oneYearAgo);
  }

  /// Son audit'ten bu yana geçen gün sayısı
  int? get daysSinceLastAudit {
    if (lastAuditAt == null) return null;
    return DateTime.now().difference(lastAuditAt!).inDays;
  }

  // ============================================
  // HELPERS
  // ============================================

  /// Tam adres
  String get fullAddress {
    final parts = <String>[];
    if (address != null && address!.isNotEmpty) parts.add(address!);
    if (town != null && town!.isNotEmpty) parts.add(town!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (country != null && country!.isNotEmpty) parts.add(country!);
    return parts.join(', ');
  }

  /// Konum var mı?
  bool get hasLocation => latitude != null && longitude != null;

  @override
  String toString() => 'Organization(id: $id, name: $name, tenantId: $tenantId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Organization && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
