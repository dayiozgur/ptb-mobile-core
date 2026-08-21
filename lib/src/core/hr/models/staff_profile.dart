/// Çalışanın kendi personel kaydı (ESS "İK Profilim" görünüm modeli).
///
/// Web `MyStaffProfile` (staff-profile.service.ts) ile birebir aynı sözleşme:
/// hassas-olmayan kolonlar `staffs` tablosundan (tenant-geneli SELECT, RLS
/// altında) doğrudan okunur; pozisyon / departman adları embed ile, organizasyon
/// ve yönetici adları küçük takip sorgularıyla çözülür. Hassas (kilitli) blok
/// yalnızca `fn_staff_personnel_get` RPC'siyle gelir → [PersonnelData].
class StaffProfile {
  final String id;
  final String? name;
  final String? firstName;
  final String? lastName;
  final String? title;

  // İletişim
  final String? email;
  final String? phone;
  final String? address;
  final String? town;

  // İstihdam
  final DateTime? hireDate;
  final String? positionName;
  final String? departmentName;
  final String? organizationName;
  final String? managerName;

  // Kişisel (kilitli-olmayan) — çalışanın kendisi okuyabilir.
  final String? gender;
  final String? maritalStatus;
  final String? bloodType;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? emergencyContactRelation;
  final String? educationLevel;
  final String? militaryStatus;

  /// Hassas personel bloğu (`fn_staff_personnel_get`). Erişim reddedilirse veya
  /// çözülemezse `null` kalır (profilin geri kalanı yine gösterilir).
  final PersonnelData? personnel;

  const StaffProfile({
    required this.id,
    this.name,
    this.firstName,
    this.lastName,
    this.title,
    this.email,
    this.phone,
    this.address,
    this.town,
    this.hireDate,
    this.positionName,
    this.departmentName,
    this.organizationName,
    this.managerName,
    this.gender,
    this.maritalStatus,
    this.bloodType,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.emergencyContactRelation,
    this.educationLevel,
    this.militaryStatus,
    this.personnel,
  });

  /// Görünen ad — ad+soyad, yoksa `name`, o da yoksa em-dash.
  String get displayName {
    final full = [firstName, lastName]
        .where((e) => e != null && e.trim().isNotEmpty)
        .join(' ');
    if (full.isNotEmpty) return full;
    return (name != null && name!.trim().isNotEmpty) ? name! : '—';
  }

  /// `staffs` satırından (positions/departments embed'li) profil kurar.
  /// Organizasyon ve yönetici adları serviste ayrı sorgularla çözülüp geçirilir.
  factory StaffProfile.fromJson(
    Map<String, dynamic> json, {
    String? organizationName,
    String? managerName,
    PersonnelData? personnel,
  }) {
    return StaffProfile(
      id: json['id'] as String,
      name: json['name'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      title: json['title'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      town: json['town'] as String?,
      hireDate: _parseDate(json['hire_date']),
      positionName: _embeddedName(json['positions']),
      departmentName: _embeddedName(json['departments']),
      organizationName: organizationName,
      managerName: managerName,
      gender: json['gender'] as String?,
      maritalStatus: json['marital_status'] as String?,
      bloodType: json['blood_type'] as String?,
      emergencyContactName: json['emergency_contact_name'] as String?,
      emergencyContactPhone: json['emergency_contact_phone'] as String?,
      emergencyContactRelation: json['emergency_contact_relation'] as String?,
      educationLevel: json['education_level'] as String?,
      militaryStatus: json['military_status'] as String?,
      personnel: personnel,
    );
  }

  static DateTime? _parseDate(dynamic v) =>
      v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

  /// PostgREST embed adı — dizi (`[{name}]`) veya nesne (`{name}`) olabilir.
  static String? _embeddedName(dynamic rel) {
    if (rel == null) return null;
    if (rel is List) {
      if (rel.isEmpty) return null;
      final first = rel.first;
      return first is Map ? first['name'] as String? : null;
    }
    if (rel is Map) return rel['name'] as String?;
    return null;
  }
}

/// Kolon-kilitli hassas personel verisi — yalnızca `fn_staff_personnel_get`
/// (admin VEYA kayıt sahibine izin veren SECURITY DEFINER RPC) ile erişilir.
/// Bu kolonlar ASLA doğrudan SELECT edilemez (PostgREST admin'e bile reddeder).
class PersonnelData {
  final num? grossSalary;
  final String? tcKimlikNo;
  final String? iban;
  final String? sgkSicilNo;
  final DateTime? birthDate;

  const PersonnelData({
    this.grossSalary,
    this.tcKimlikNo,
    this.iban,
    this.sgkSicilNo,
    this.birthDate,
  });

  factory PersonnelData.fromJson(Map<String, dynamic> json) {
    return PersonnelData(
      grossSalary: json['gross_salary'] as num?,
      tcKimlikNo: json['tc_kimlik_no'] as String?,
      iban: json['iban'] as String?,
      sgkSicilNo: json['sgk_sicil_no'] as String?,
      birthDate: json['birth_date'] is String &&
              (json['birth_date'] as String).isNotEmpty
          ? DateTime.tryParse(json['birth_date'] as String)
          : null,
    );
  }
}
