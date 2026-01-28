/// Unit durumu
enum UnitStatus {
  /// Aktif
  active,

  /// Pasif
  inactive,

  /// Bakımda
  maintenance,

  /// Askıda
  suspended,

  /// Kapalı
  closed,

  /// Silinmiş
  deleted;

  /// String'den UnitStatus'a dönüştür
  static UnitStatus fromString(String? value) {
    return UnitStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => UnitStatus.active,
    );
  }
}

/// Unit kategorileri
enum UnitCategory {
  main('MAIN', 'Ana Alan'),
  floor('FLOOR', 'Kat'),
  section('SECTION', 'Bölüm'),
  room('ROOM', 'Oda'),
  zone('ZONE', 'Zon'),
  production('PRODUCTION', 'Üretim'),
  storage('STORAGE', 'Depolama'),
  service('SERVICE', 'Servis'),
  common('COMMON', 'Ortak Alan'),
  technical('TECHNICAL', 'Teknik'),
  outdoor('OUTDOOR', 'Dış Mekan'),
  custom('CUSTOM', 'Özel');

  final String value;
  final String label;
  const UnitCategory(this.value, this.label);

  static UnitCategory? fromString(String? value) {
    if (value == null) return null;
    return UnitCategory.values.cast<UnitCategory?>().firstWhere(
      (e) => e?.value == value,
      orElse: () => null,
    );
  }
}

/// Unit tipi modeli
class UnitType {
  final String id;
  final String name;
  final String? code;
  final String? description;
  final UnitCategory? category;
  final bool isMainArea;
  final bool isSystemType;
  final List<String>? allowedSiteTypes;
  final bool active;
  final DateTime? createdAt;

  UnitType({
    required this.id,
    required this.name,
    this.code,
    this.description,
    this.category,
    this.isMainArea = false,
    this.isSystemType = false,
    this.allowedSiteTypes,
    this.active = true,
    this.createdAt,
  });

  factory UnitType.fromJson(Map<String, dynamic> json) {
    return UnitType(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      description: json['description'] as String?,
      category: UnitCategory.fromString(json['category'] as String?),
      isMainArea: json['is_main_area'] as bool? ?? false,
      isSystemType: json['is_system_type'] as bool? ?? false,
      allowedSiteTypes: json['allowed_site_types'] != null
          ? List<String>.from(json['allowed_site_types'] as List)
          : null,
      active: json['active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'description': description,
        'category': category?.value,
        'is_main_area': isMainArea,
        'is_system_type': isSystemType,
        'allowed_site_types': allowedSiteTypes,
        'active': active,
        'created_at': createdAt?.toIso8601String(),
      };

  /// Kategori ikonunu döndür
  String get categoryIcon {
    switch (category) {
      case UnitCategory.main:
        return 'home';
      case UnitCategory.floor:
        return 'layers';
      case UnitCategory.section:
        return 'view_module';
      case UnitCategory.room:
        return 'meeting_room';
      case UnitCategory.zone:
        return 'grid_view';
      case UnitCategory.production:
        return 'precision_manufacturing';
      case UnitCategory.storage:
        return 'warehouse';
      case UnitCategory.service:
        return 'engineering';
      case UnitCategory.common:
        return 'groups';
      case UnitCategory.technical:
        return 'electrical_services';
      case UnitCategory.outdoor:
        return 'park';
      case UnitCategory.custom:
      case null:
        return 'square_foot';
    }
  }
}

/// Unit (Alan/Bölüm) modeli
///
/// Site altındaki alan/bölüm temsili.
/// Hiyerarşi: Tenant → Organization → Site → Unit (self-referencing)
class Unit {
  /// Benzersiz ID
  final String id;

  /// Unit adı
  final String name;

  /// Unit kodu
  final String? code;

  /// Açıklama
  final String? description;

  /// Alan boyutu (m²)
  final double? areaSize;

  /// Görsel bucket path
  final String? imageBucket;

  /// Aktif mi? (geriye uyumluluk için korundu)
  final bool active;

  /// Unit durumu
  final UnitStatus status;

  /// Askıya alınma tarihi
  final DateTime? suspendedAt;

  /// Askıya alınma nedeni
  final String? suspendedReason;

  /// Silinme tarihi (soft delete)
  final DateTime? deletedAt;

  // ============================================
  // HİYERARŞİ
  // ============================================

  /// Üst unit ID (self-reference)
  final String? parentUnitId;

  /// Üst unit (eager loaded)
  final Unit? parentUnit;

  /// Alt unitler (eager loaded)
  final List<Unit> children;

  // ============================================
  // İLİŞKİLER
  // ============================================

  /// Bağlı olduğu Site ID
  final String? siteId;

  /// Bağlı olduğu Organization ID
  final String? organizationId;

  /// Bağlı olduğu Tenant ID
  final String? tenantId;

  /// Contractor ID
  final String? contractorId;

  /// Sub-contractor ID
  final String? subContractorId;

  /// Unit tip ID
  final String? unitTypeId;

  /// Unit tipi (eager loaded)
  final UnitType? unitType;

  /// Area ID
  final String? areaId;

  /// Financial ID (1:1)
  final String? financialId;

  /// Location ID (1:1)
  final String? locationId;

  /// Yetkili personel ID
  final String? authorizedStaffId;

  // ============================================
  // ÖZEL ALANLAR
  // ============================================

  /// Ana alan mı?
  final bool isMainArea;

  /// Silinebilir mi?
  final bool isDeletable;

  /// Orijinal ana alan mı?
  final bool originalMainArea;

  // ============================================
  // ÇALIŞMA SAATLERİ
  // ============================================

  /// Genel açılış saati
  final String? generalOpenTime;

  /// Genel kapanış saati
  final String? generalCloseTime;

  /// Çalışma saati aktif mi?
  final bool workingTimeActive;

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

  Unit({
    required this.id,
    required this.name,
    this.code,
    this.description,
    this.areaSize,
    this.imageBucket,
    this.active = true,
    this.status = UnitStatus.active,
    this.suspendedAt,
    this.suspendedReason,
    this.deletedAt,
    this.parentUnitId,
    this.parentUnit,
    this.children = const [],
    this.siteId,
    this.organizationId,
    this.tenantId,
    this.contractorId,
    this.subContractorId,
    this.unitTypeId,
    this.unitType,
    this.areaId,
    this.financialId,
    this.locationId,
    this.authorizedStaffId,
    this.isMainArea = false,
    this.isDeletable = true,
    this.originalMainArea = false,
    this.generalOpenTime,
    this.generalCloseTime,
    this.workingTimeActive = false,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.rowId,
  });

  // ============================================
  // JSON SERIALIZATION
  // ============================================

  factory Unit.fromJson(Map<String, dynamic> json) {
    return Unit(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      description: json['description'] as String?,
      areaSize: (json['area_size'] as num?)?.toDouble(),
      imageBucket: json['image_bucket'] as String?,
      active: json['active'] as bool? ?? true,
      status: UnitStatus.fromString(json['status'] as String?),
      suspendedAt: json['suspended_at'] != null
          ? DateTime.tryParse(json['suspended_at'] as String)
          : null,
      suspendedReason: json['suspended_reason'] as String?,
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'] as String)
          : null,
      parentUnitId: json['parent_unit_id'] as String?,
      parentUnit: json['parent_unit'] != null
          ? Unit.fromJson(json['parent_unit'] as Map<String, dynamic>)
          : null,
      children: json['children'] != null
          ? (json['children'] as List)
              .map((e) => Unit.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
      siteId: json['site_id'] as String?,
      organizationId: json['organization_id'] as String?,
      tenantId: json['tenant_id'] as String?,
      contractorId: json['contractor_id'] as String?,
      subContractorId: json['sub_contractor_id'] as String?,
      unitTypeId: json['unit_type_id'] as String?,
      unitType: json['unit_type'] != null
          ? UnitType.fromJson(json['unit_type'] as Map<String, dynamic>)
          : null,
      areaId: json['area_id'] as String?,
      financialId: json['financial_id'] as String?,
      locationId: json['location_id'] as String?,
      authorizedStaffId: json['authorized_staff'] as String?,
      isMainArea: json['is_main_area'] as bool? ?? false,
      isDeletable: json['is_deletable'] as bool? ?? true,
      originalMainArea: json['original_main_area'] as bool? ?? false,
      generalOpenTime: json['general_open_time'] as String?,
      generalCloseTime: json['general_close_time'] as String?,
      workingTimeActive: json['working_time_active'] as bool? ?? false,
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'description': description,
        'area_size': areaSize,
        'image_bucket': imageBucket,
        'active': active,
        'status': status.name,
        'suspended_at': suspendedAt?.toIso8601String(),
        'suspended_reason': suspendedReason,
        'deleted_at': deletedAt?.toIso8601String(),
        'parent_unit_id': parentUnitId,
        'site_id': siteId,
        'organization_id': organizationId,
        'tenant_id': tenantId,
        'contractor_id': contractorId,
        'sub_contractor_id': subContractorId,
        'unit_type_id': unitTypeId,
        'area_id': areaId,
        'financial_id': financialId,
        'location_id': locationId,
        'authorized_staff': authorizedStaffId,
        'is_main_area': isMainArea,
        'is_deletable': isDeletable,
        'original_main_area': originalMainArea,
        'general_open_time': generalOpenTime,
        'general_close_time': generalCloseTime,
        'working_time_active': workingTimeActive,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'created_by': createdBy,
        'updated_by': updatedBy,
        'row_id': rowId,
      };

  // ============================================
  // COPY WITH
  // ============================================

  Unit copyWith({
    String? id,
    String? name,
    String? code,
    String? description,
    double? areaSize,
    String? imageBucket,
    bool? active,
    UnitStatus? status,
    DateTime? suspendedAt,
    String? suspendedReason,
    DateTime? deletedAt,
    String? parentUnitId,
    Unit? parentUnit,
    List<Unit>? children,
    String? siteId,
    String? organizationId,
    String? tenantId,
    String? contractorId,
    String? subContractorId,
    String? unitTypeId,
    UnitType? unitType,
    String? areaId,
    String? financialId,
    String? locationId,
    String? authorizedStaffId,
    bool? isMainArea,
    bool? isDeletable,
    bool? originalMainArea,
    String? generalOpenTime,
    String? generalCloseTime,
    bool? workingTimeActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    int? rowId,
  }) {
    return Unit(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      areaSize: areaSize ?? this.areaSize,
      imageBucket: imageBucket ?? this.imageBucket,
      active: active ?? this.active,
      status: status ?? this.status,
      suspendedAt: suspendedAt ?? this.suspendedAt,
      suspendedReason: suspendedReason ?? this.suspendedReason,
      deletedAt: deletedAt ?? this.deletedAt,
      parentUnitId: parentUnitId ?? this.parentUnitId,
      parentUnit: parentUnit ?? this.parentUnit,
      children: children ?? this.children,
      siteId: siteId ?? this.siteId,
      organizationId: organizationId ?? this.organizationId,
      tenantId: tenantId ?? this.tenantId,
      contractorId: contractorId ?? this.contractorId,
      subContractorId: subContractorId ?? this.subContractorId,
      unitTypeId: unitTypeId ?? this.unitTypeId,
      unitType: unitType ?? this.unitType,
      areaId: areaId ?? this.areaId,
      financialId: financialId ?? this.financialId,
      locationId: locationId ?? this.locationId,
      authorizedStaffId: authorizedStaffId ?? this.authorizedStaffId,
      isMainArea: isMainArea ?? this.isMainArea,
      isDeletable: isDeletable ?? this.isDeletable,
      originalMainArea: originalMainArea ?? this.originalMainArea,
      generalOpenTime: generalOpenTime ?? this.generalOpenTime,
      generalCloseTime: generalCloseTime ?? this.generalCloseTime,
      workingTimeActive: workingTimeActive ?? this.workingTimeActive,
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
  bool get isActive => active && status == UnitStatus.active;

  /// Bakımda mı?
  bool get isUnderMaintenance => status == UnitStatus.maintenance;

  /// Askıda mı?
  bool get isSuspended => status == UnitStatus.suspended;

  /// Kapalı mı?
  bool get isClosed => status == UnitStatus.closed;

  /// Silinmiş mi?
  bool get isDeleted => status == UnitStatus.deleted;

  /// Kullanılabilir mi? (aktif veya bakımda)
  bool get isUsable => status == UnitStatus.active || status == UnitStatus.maintenance;

  // ============================================
  // HELPERS
  // ============================================

  /// Kök unit mi? (parent yok)
  bool get isRoot => parentUnitId == null;

  /// Alt unitleri var mı?
  bool get hasChildren => children.isNotEmpty;

  /// Hiyerarşi derinliği (parent chain uzunluğu)
  int get depth {
    int d = 0;
    Unit? current = parentUnit;
    while (current != null) {
      d++;
      current = current.parentUnit;
    }
    return d;
  }

  /// Kategori (unit type üzerinden)
  UnitCategory? get category => unitType?.category;

  /// Kategori etiketi
  String get categoryLabel => category?.label ?? 'Bilinmiyor';

  /// Tam hiyerarşi yolu
  String get fullPath {
    final parts = <String>[];
    Unit? current = this;
    while (current != null) {
      parts.insert(0, current.name);
      current = current.parentUnit;
    }
    return parts.join(' > ');
  }

  /// Alan boyutu formatlanmış
  String get areaSizeFormatted {
    if (areaSize == null) return '-';
    return '${areaSize!.toStringAsFixed(areaSize! % 1 == 0 ? 0 : 1)} m²';
  }

  /// Bu unit'in altındaki toplam alan
  double get totalAreaWithChildren {
    double total = areaSize ?? 0;
    for (final child in children) {
      total += child.totalAreaWithChildren;
    }
    return total;
  }

  /// Bu unit'in altındaki toplam alt unit sayısı
  int get totalChildCount {
    int count = children.length;
    for (final child in children) {
      count += child.totalChildCount;
    }
    return count;
  }

  @override
  String toString() => 'Unit(id: $id, name: $name, siteId: $siteId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Unit && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Unit hiyerarşi ağacı yardımcı sınıfı
class UnitTree {
  final List<Unit> rootUnits;
  final Map<String, Unit> unitMap;

  UnitTree({
    required this.rootUnits,
    required this.unitMap,
  });

  /// Flat listeden ağaç yapısı oluştur
  factory UnitTree.fromList(List<Unit> units) {
    final Map<String, Unit> unitMap = {};
    final Map<String, List<Unit>> childrenMap = {};
    final List<Unit> rootUnits = [];

    // İlk geçiş: map oluştur
    for (final unit in units) {
      unitMap[unit.id] = unit;
      childrenMap[unit.id] = [];
    }

    // İkinci geçiş: parent-child ilişkilerini kur
    for (final unit in units) {
      if (unit.parentUnitId != null && unitMap.containsKey(unit.parentUnitId)) {
        childrenMap[unit.parentUnitId]!.add(unit);
      } else {
        rootUnits.add(unit);
      }
    }

    // Üçüncü geçiş: children listelerini doldur
    for (final entry in childrenMap.entries) {
      if (unitMap.containsKey(entry.key)) {
        final unit = unitMap[entry.key]!;
        unitMap[entry.key] = unit.copyWith(children: entry.value);
      }
    }

    // Root unitlerı güncellenmiş hallerıyle değiştir
    final updatedRoots = rootUnits
        .map((u) => unitMap[u.id] ?? u)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return UnitTree(
      rootUnits: updatedRoots,
      unitMap: unitMap,
    );
  }

  /// ID ile unit bul
  Unit? findById(String id) => unitMap[id];

  /// Belirli kategorideki unitleri bul
  List<Unit> findByCategory(UnitCategory category) {
    return unitMap.values
        .where((u) => u.category == category)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Ağacı düz listeye çevir (depth-first)
  List<Unit> flatten() {
    final result = <Unit>[];
    void traverse(List<Unit> units) {
      for (final unit in units) {
        result.add(unit);
        if (unit.hasChildren) {
          traverse(unit.children);
        }
      }
    }
    traverse(rootUnits);
    return result;
  }

  /// Toplam unit sayısı
  int get totalCount => unitMap.length;

  /// Toplam alan
  double get totalArea {
    return rootUnits.fold(0.0, (sum, unit) => sum + unit.totalAreaWithChildren);
  }
}
