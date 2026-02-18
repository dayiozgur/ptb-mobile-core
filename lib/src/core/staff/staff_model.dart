/// Staff modeli
///
/// staffs tablosunu temsil eder. Personel bilgilerini icerir.
class Staff {
  final String id;
  final String? tenantId;
  final String? profileId;
  final String? userId;
  final String? organizationId;
  final String? staffTypeId;
  final String? contractorId;
  final String? subContractorId;
  final String? ratingId;
  final String? routeLocationId;
  final String? name;
  final String? code;
  final String? description;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? fax;
  final String? address;
  final String? town;
  final int? cityId;
  final String? countryId;
  final String? website;
  final bool? active;
  final String? createdBy;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;

  const Staff({
    required this.id,
    this.tenantId,
    this.profileId,
    this.userId,
    this.organizationId,
    this.staffTypeId,
    this.contractorId,
    this.subContractorId,
    this.ratingId,
    this.routeLocationId,
    this.name,
    this.code,
    this.description,
    this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.fax,
    this.address,
    this.town,
    this.cityId,
    this.countryId,
    this.website,
    this.active,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
  });

  // ============================================
  // COMPUTED PROPERTIES
  // ============================================

  /// Tam ad
  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return name ?? firstName ?? lastName ?? '';
  }

  /// Bas harfler
  String get initials {
    final n = fullName;
    if (n.isEmpty) return '';
    final parts = n.split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return n.substring(0, n.length >= 2 ? 2 : 1).toUpperCase();
  }

  /// Aktif mi?
  bool get isActive => active == true;

  // ============================================
  // JSON SERIALIZATION
  // ============================================

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String?,
      profileId: json['profile_id'] as String?,
      userId: json['user_id'] as String?,
      organizationId: json['organization_id'] as String?,
      staffTypeId: json['staff_type_id'] as String?,
      contractorId: json['contractor_id'] as String?,
      subContractorId: json['sub_contractor_id'] as String?,
      ratingId: json['rating_id'] as String?,
      routeLocationId: json['route_location_id'] as String?,
      name: json['name'] as String?,
      code: json['code'] as String?,
      description: json['description'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      fax: json['fax'] as String?,
      address: json['address'] as String?,
      town: json['town'] as String?,
      cityId: json['city_id'] as int?,
      countryId: json['country_id'] as String?,
      website: json['website'] as String?,
      active: json['active'] as bool?,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedBy: json['updated_by'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'profile_id': profileId,
      'user_id': userId,
      'organization_id': organizationId,
      'staff_type_id': staffTypeId,
      'contractor_id': contractorId,
      'sub_contractor_id': subContractorId,
      'rating_id': ratingId,
      'route_location_id': routeLocationId,
      'name': name,
      'code': code,
      'description': description,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'fax': fax,
      'address': address,
      'town': town,
      'city_id': cityId,
      'country_id': countryId,
      'website': website,
      'active': active,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_by': updatedBy,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // ============================================
  // COPY WITH
  // ============================================

  Staff copyWith({
    String? id,
    String? tenantId,
    String? profileId,
    String? userId,
    String? organizationId,
    String? staffTypeId,
    String? contractorId,
    String? subContractorId,
    String? ratingId,
    String? routeLocationId,
    String? name,
    String? code,
    String? description,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? fax,
    String? address,
    String? town,
    int? cityId,
    String? countryId,
    String? website,
    bool? active,
    String? createdBy,
    DateTime? createdAt,
    String? updatedBy,
    DateTime? updatedAt,
  }) {
    return Staff(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      profileId: profileId ?? this.profileId,
      userId: userId ?? this.userId,
      organizationId: organizationId ?? this.organizationId,
      staffTypeId: staffTypeId ?? this.staffTypeId,
      contractorId: contractorId ?? this.contractorId,
      subContractorId: subContractorId ?? this.subContractorId,
      ratingId: ratingId ?? this.ratingId,
      routeLocationId: routeLocationId ?? this.routeLocationId,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      fax: fax ?? this.fax,
      address: address ?? this.address,
      town: town ?? this.town,
      cityId: cityId ?? this.cityId,
      countryId: countryId ?? this.countryId,
      website: website ?? this.website,
      active: active ?? this.active,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'Staff($id, $fullName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Staff && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Staff Type modeli
///
/// staff_types tablosunu temsil eder.
class StaffType {
  final String id;
  final String? name;
  final String? description;
  final bool? active;
  final String? createdBy;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;

  const StaffType({
    required this.id,
    this.name,
    this.description,
    this.active,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
  });

  factory StaffType.fromJson(Map<String, dynamic> json) {
    return StaffType(
      id: json['id'] as String,
      name: json['name'] as String?,
      description: json['description'] as String?,
      active: json['active'] as bool?,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedBy: json['updated_by'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'active': active,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_by': updatedBy,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  String toString() => 'StaffType($id, $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is StaffType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Department modeli
///
/// departments tablosunu temsil eder.
class Department {
  final String id;
  final String? tenantId;
  final String? name;
  final String? code;
  final String? description;
  final bool? active;
  final String? createdBy;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;

  const Department({
    required this.id,
    this.tenantId,
    this.name,
    this.code,
    this.description,
    this.active,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
  });

  bool get isActive => active == true;

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String?,
      name: json['name'] as String?,
      code: json['code'] as String?,
      description: json['description'] as String?,
      active: json['active'] as bool?,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedBy: json['updated_by'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'name': name,
      'code': code,
      'description': description,
      'active': active,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_by': updatedBy,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  String toString() => 'Department($id, $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Department && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
