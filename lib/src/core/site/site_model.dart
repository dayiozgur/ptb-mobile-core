/// Enerji sertifikası sınıfı
enum EnergyCertificateClass {
  aPlus('A+'),
  a('A'),
  b('B'),
  c('C'),
  d('D'),
  e('E'),
  f('F'),
  g('G');

  final String value;
  const EnergyCertificateClass(this.value);

  static EnergyCertificateClass? fromString(String? value) {
    if (value == null) return null;
    return EnergyCertificateClass.values.cast<EnergyCertificateClass?>().firstWhere(
      (e) => e?.value == value,
      orElse: () => null,
    );
  }
}

/// Çalışma saatleri modeli
class WorkingHours {
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;

  WorkingHours({this.startTime, this.endTime});

  bool get isSet => startTime != null && endTime != null;

  factory WorkingHours.fromJson(String? start, String? end) {
    return WorkingHours(
      startTime: _parseTime(start),
      endTime: _parseTime(end),
    );
  }

  static TimeOfDay? _parseTime(String? time) {
    if (time == null) return null;
    final parts = time.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }
}

/// Basit TimeOfDay (Flutter bağımsız)
class TimeOfDay {
  final int hour;
  final int minute;

  TimeOfDay({required this.hour, required this.minute});

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// Site (Fiziksel Lokasyon) modeli
///
/// Organization altındaki bina/tesis temsili.
/// Hiyerarşi: Tenant → Organization → Site → Unit
class Site {
  /// Benzersiz ID
  final String id;

  /// Site adı
  final String name;

  /// Site kodu
  final String? code;

  /// Açıklama
  final String? description;

  /// Renk (UI için)
  final String? color;

  /// Görsel yolu
  final String? imagePath;

  /// Aktif mi?
  final bool active;

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

  /// Zoom seviyesi
  final int? zoom;

  // ============================================
  // FİZİKSEL ÖZELLİKLER
  // ============================================

  /// Brüt alan (m²)
  final double? grossAreaSqm;

  /// Net alan (m²)
  final double? netAreaSqm;

  /// Kat sayısı
  final int? floorCount;

  /// Yapım yılı
  final int? yearBuilt;

  /// Faaliyet başlangıcı
  final DateTime? operatingSince;

  /// İklim bölgesi
  final String? climateZone;

  /// Enerji sertifikası sınıfı
  final EnergyCertificateClass? energyCertificateClass;

  /// Ana unit var mı?
  final bool hasMainUnit;

  // ============================================
  // ÇALIŞMA SAATLERİ
  // ============================================

  /// Genel açılış saati
  final String? generalOpenTime;

  /// Genel kapanış saati
  final String? generalCloseTime;

  /// Çalışma saati aktif mi?
  final bool workingTimeActive;

  /// Haftalık çalışma saatleri
  final Map<String, WorkingHours> weeklyHours;

  // ============================================
  // İLİŞKİLER
  // ============================================

  /// Bağlı olduğu Tenant ID (redundant, organization üzerinden de ulaşılabilir)
  final String? tenantId;

  /// Bağlı olduğu Organization ID (ZORUNLU)
  final String organizationId;

  /// Harita marker ID
  final String markerId;

  /// Site grup ID
  final String? siteGroupId;

  /// Site tip ID
  final String? siteTypeId;

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

  /// Row ID
  final int? rowId;

  // ============================================
  // CONSTRUCTOR
  // ============================================

  Site({
    required this.id,
    required this.name,
    required this.organizationId,
    required this.markerId,
    this.code,
    this.description,
    this.color,
    this.imagePath,
    this.active = true,
    this.address,
    this.city,
    this.town,
    this.country,
    this.latitude,
    this.longitude,
    this.zoom,
    this.grossAreaSqm,
    this.netAreaSqm,
    this.floorCount,
    this.yearBuilt,
    this.operatingSince,
    this.climateZone,
    this.energyCertificateClass,
    this.hasMainUnit = false,
    this.generalOpenTime,
    this.generalCloseTime,
    this.workingTimeActive = false,
    this.weeklyHours = const {},
    this.tenantId,
    this.siteGroupId,
    this.siteTypeId,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.rowId,
  });

  // ============================================
  // JSON SERIALIZATION
  // ============================================

  factory Site.fromJson(Map<String, dynamic> json) {
    return Site(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      organizationId: json['organization_id'] as String,
      markerId: json['marker_id'] as String? ?? '',
      code: json['code'] as String?,
      description: json['description'] as String?,
      color: json['color'] as String?,
      imagePath: json['image_path'] as String?,
      active: json['active'] as bool? ?? true,
      address: json['address'] as String?,
      city: json['city'] as String?,
      town: json['town'] as String?,
      country: json['country'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      zoom: json['zoom'] as int?,
      grossAreaSqm: (json['gross_area_sqm'] as num?)?.toDouble(),
      netAreaSqm: (json['net_area_sqm'] as num?)?.toDouble(),
      floorCount: json['floor_count'] as int?,
      yearBuilt: json['year_built'] as int?,
      operatingSince: json['operating_since'] != null
          ? DateTime.tryParse(json['operating_since'] as String)
          : null,
      climateZone: json['climate_zone'] as String?,
      energyCertificateClass:
          EnergyCertificateClass.fromString(json['energy_certificate_class'] as String?),
      hasMainUnit: json['has_main_unit'] as bool? ?? false,
      generalOpenTime: json['general_open_time'] as String?,
      generalCloseTime: json['general_close_time'] as String?,
      workingTimeActive: json['working_time_active'] as bool? ?? false,
      weeklyHours: _parseWeeklyHours(json),
      tenantId: json['tenant_id'] as String?,
      siteGroupId: json['site_group_id'] as String?,
      siteTypeId: json['site_type_id'] as String?,
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

  static Map<String, WorkingHours> _parseWeeklyHours(Map<String, dynamic> json) {
    final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final result = <String, WorkingHours>{};

    for (final day in days) {
      result[day] = WorkingHours.fromJson(
        json['${day}_start_time'] as String?,
        json['${day}_end_time'] as String?,
      );
    }

    return result;
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'name': name,
      'organization_id': organizationId,
      'marker_id': markerId,
      'code': code,
      'description': description,
      'color': color,
      'image_path': imagePath,
      'active': active,
      'address': address,
      'city': city,
      'town': town,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'zoom': zoom,
      'gross_area_sqm': grossAreaSqm,
      'net_area_sqm': netAreaSqm,
      'floor_count': floorCount,
      'year_built': yearBuilt,
      'operating_since': operatingSince?.toIso8601String(),
      'climate_zone': climateZone,
      'energy_certificate_class': energyCertificateClass?.value,
      'has_main_unit': hasMainUnit,
      'general_open_time': generalOpenTime,
      'general_close_time': generalCloseTime,
      'working_time_active': workingTimeActive,
      'tenant_id': tenantId,
      'site_group_id': siteGroupId,
      'site_type_id': siteTypeId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
      'row_id': rowId,
    };

    // Haftalık saatleri ekle
    final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    for (final day in days) {
      final hours = weeklyHours[day];
      json['${day}_start_time'] = hours?.startTime?.toString();
      json['${day}_end_time'] = hours?.endTime?.toString();
    }

    return json;
  }

  // ============================================
  // COPY WITH
  // ============================================

  Site copyWith({
    String? id,
    String? name,
    String? organizationId,
    String? markerId,
    String? code,
    String? description,
    String? color,
    String? imagePath,
    bool? active,
    String? address,
    String? city,
    String? town,
    String? country,
    double? latitude,
    double? longitude,
    int? zoom,
    double? grossAreaSqm,
    double? netAreaSqm,
    int? floorCount,
    int? yearBuilt,
    DateTime? operatingSince,
    String? climateZone,
    EnergyCertificateClass? energyCertificateClass,
    bool? hasMainUnit,
    String? generalOpenTime,
    String? generalCloseTime,
    bool? workingTimeActive,
    Map<String, WorkingHours>? weeklyHours,
    String? tenantId,
    String? siteGroupId,
    String? siteTypeId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    int? rowId,
  }) {
    return Site(
      id: id ?? this.id,
      name: name ?? this.name,
      organizationId: organizationId ?? this.organizationId,
      markerId: markerId ?? this.markerId,
      code: code ?? this.code,
      description: description ?? this.description,
      color: color ?? this.color,
      imagePath: imagePath ?? this.imagePath,
      active: active ?? this.active,
      address: address ?? this.address,
      city: city ?? this.city,
      town: town ?? this.town,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      zoom: zoom ?? this.zoom,
      grossAreaSqm: grossAreaSqm ?? this.grossAreaSqm,
      netAreaSqm: netAreaSqm ?? this.netAreaSqm,
      floorCount: floorCount ?? this.floorCount,
      yearBuilt: yearBuilt ?? this.yearBuilt,
      operatingSince: operatingSince ?? this.operatingSince,
      climateZone: climateZone ?? this.climateZone,
      energyCertificateClass: energyCertificateClass ?? this.energyCertificateClass,
      hasMainUnit: hasMainUnit ?? this.hasMainUnit,
      generalOpenTime: generalOpenTime ?? this.generalOpenTime,
      generalCloseTime: generalCloseTime ?? this.generalCloseTime,
      workingTimeActive: workingTimeActive ?? this.workingTimeActive,
      weeklyHours: weeklyHours ?? this.weeklyHours,
      tenantId: tenantId ?? this.tenantId,
      siteGroupId: siteGroupId ?? this.siteGroupId,
      siteTypeId: siteTypeId ?? this.siteTypeId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      rowId: rowId ?? this.rowId,
    );
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

  /// Toplam alan
  double? get totalArea => grossAreaSqm ?? netAreaSqm;

  /// Bina yaşı
  int? get buildingAge {
    if (yearBuilt == null) return null;
    return DateTime.now().year - yearBuilt!;
  }

  /// Bugün açık mı?
  bool get isOpenToday {
    if (!workingTimeActive) return true;
    final today = _getDayName(DateTime.now().weekday);
    final hours = weeklyHours[today];
    return hours?.isSet ?? false;
  }

  String _getDayName(int weekday) {
    const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    return days[weekday - 1];
  }

  @override
  String toString() => 'Site(id: $id, name: $name, organizationId: $organizationId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Site && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Site tipi modeli
class SiteType {
  final String id;
  final String name;
  final String? description;
  final bool active;

  SiteType({
    required this.id,
    required this.name,
    this.description,
    this.active = true,
  });

  factory SiteType.fromJson(Map<String, dynamic> json) {
    return SiteType(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'active': active,
      };
}

/// Site grubu modeli
class SiteGroup {
  final String id;
  final String name;
  final String? description;
  final String? color;
  final bool active;

  SiteGroup({
    required this.id,
    required this.name,
    this.description,
    this.color,
    this.active = true,
  });

  factory SiteGroup.fromJson(Map<String, dynamic> json) {
    return SiteGroup(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      color: json['color'] as String?,
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'color': color,
        'active': active,
      };
}
