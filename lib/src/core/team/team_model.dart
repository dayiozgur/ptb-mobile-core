/// Team modeli
///
/// teams tablosunu temsil eder.
class Team {
  final String id;
  final String? tenantId;
  final String? name;
  final String? code;
  final String? description;
  final bool? active;
  final bool? independent;
  final String? ratingId;
  final String? routeLocationsId;
  final String? createdBy;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;

  /// Joined: uye sayisi (count sorgusu ile)
  final int? memberCount;

  const Team({
    required this.id,
    this.tenantId,
    this.name,
    this.code,
    this.description,
    this.active,
    this.independent,
    this.ratingId,
    this.routeLocationsId,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
    this.memberCount,
  });

  bool get isActive => active == true;

  factory Team.fromJson(Map<String, dynamic> json) {
    // memberCount: team_staffs count join destegi
    int? count;
    if (json['team_staffs'] is List) {
      count = (json['team_staffs'] as List).length;
    }

    return Team(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String?,
      name: json['name'] as String?,
      code: json['code'] as String?,
      description: json['description'] as String?,
      active: json['active'] as bool?,
      independent: json['independent'] as bool?,
      ratingId: json['rating_id'] as String?,
      routeLocationsId: json['route_locations_id'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedBy: json['updated_by'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      memberCount: count,
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
      'independent': independent,
      'rating_id': ratingId,
      'route_locations_id': routeLocationsId,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_by': updatedBy,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Team copyWith({
    String? id,
    String? tenantId,
    String? name,
    String? code,
    String? description,
    bool? active,
    bool? independent,
    String? ratingId,
    String? routeLocationsId,
    String? createdBy,
    DateTime? createdAt,
    String? updatedBy,
    DateTime? updatedAt,
    int? memberCount,
  }) {
    return Team(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      active: active ?? this.active,
      independent: independent ?? this.independent,
      ratingId: ratingId ?? this.ratingId,
      routeLocationsId: routeLocationsId ?? this.routeLocationsId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      memberCount: memberCount ?? this.memberCount,
    );
  }

  @override
  String toString() => 'Team($id, $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Team && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Team Member modeli
///
/// team_staffs junction tablosunu temsil eder.
class TeamMember {
  final String teamId;
  final String staffId;
  final bool? active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Joined: personel bilgileri
  final String? staffName;
  final String? staffEmail;

  const TeamMember({
    required this.teamId,
    required this.staffId,
    this.active,
    this.createdAt,
    this.updatedAt,
    this.staffName,
    this.staffEmail,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    // staffs join destegi
    String? staffName;
    String? staffEmail;
    if (json['staffs'] is Map<String, dynamic>) {
      final staff = json['staffs'] as Map<String, dynamic>;
      staffName = staff['name'] as String?;
      staffEmail = staff['email'] as String?;
    }

    return TeamMember(
      teamId: json['team_id'] as String,
      staffId: json['staff_id'] as String,
      active: json['active'] as bool?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      staffName: staffName,
      staffEmail: staffEmail,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'team_id': teamId,
      'staff_id': staffId,
      'active': active,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  String toString() => 'TeamMember(team=$teamId, staff=$staffId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeamMember &&
          teamId == other.teamId &&
          staffId == other.staffId;

  @override
  int get hashCode => Object.hash(teamId, staffId);
}
