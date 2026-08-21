import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';

/// Admin staff-roster / departman görüntüleyici için salt-okuma servis.
///
/// Web portalındaki `OrgChartService` / `DepartmentService` okuma-yollarını
/// birebir aynalar (aynı Supabase projesi). Yazma YOK — v1 salt-okuma viewer.
///
/// Tenant kapsamı RLS ile sağlanır; ek olarak elde `tenantId` varsa
/// `tenant_id` eşitliği ile daraltılır (web ile aynı davranış). Personel
/// listesi `staffs` satırından okunur; ünvan/departman adları PostgREST embed
/// ile açık constraint-hint üzerinden çözülür (`positions!staffs_position_id_fkey`),
/// çünkü `staffs`'ta ikili profil FK'si (user_id + profile_id) belirsizliğe
/// yol açar. Organizasyon adı ayrı bir sorgu ile id→ad haritalanır (web de
/// böyle yapar; embed belirsizliğinden kaçınmak için).
///
/// GÜVENLİK: Hassas kolonlar (gross_salary, tc_kimlik_no, iban, ...) SELECT
/// için kolon-kilitli — bunları ASLA `staffs` select'ine eklemeyin.
class AdminStaffService {
  final SupabaseClient _supabase;

  AdminStaffService({required SupabaseClient supabase}) : _supabase = supabase;

  /// Personelleri (aktif) getirir. Web `org-chart.service.ts` select'inin
  /// aynası + organizasyon adı id→ad haritası.
  Future<List<AdminStaffRow>> listStaff({String? tenantId}) async {
    try {
      var query = _supabase.from('staffs').select(
            'id,name,first_name,last_name,email,phone,title,code,description,'
            'address,town,position_id,department_id,organization_id,manager_id,'
            'positions!staffs_position_id_fkey(name),'
            'departments!staffs_department_id_fkey(name)',
          );

      // Aktif olmayanları dışla (web: .not('active','is',false)).
      query = query.not('active', 'is', false);
      if (tenantId != null && tenantId.isNotEmpty) {
        query = query.eq('tenant_id', tenantId);
      }

      final response = await query.order('name');
      final rows = response as List;

      // Organizasyon adlarını ayrı sorguyla çöz (embed belirsizliğinden kaçın).
      final orgNames = await _organizationNames(tenantId: tenantId);

      final result = rows
          .map((e) => AdminStaffRow.fromJson(
                e as Map<String, dynamic>,
                organizationNames: orgNames,
              ))
          .toList();

      Logger.debug('AdminStaffService.listStaff → ${result.length} kayıt');
      return result;
    } catch (e) {
      Logger.error('AdminStaffService.listStaff hata: $e');
      rethrow;
    }
  }

  /// Departmanları (aktif) getirir. Web `department.service.ts` select'inin
  /// aynası (`*, organizations(name)`) + aktif personelden hesaplanan headcount.
  Future<List<AdminDepartmentRow>> listDepartments({String? tenantId}) async {
    try {
      var query = _supabase
          .from('departments')
          .select('*, organizations(name)')
          .eq('active', true);
      if (tenantId != null && tenantId.isNotEmpty) {
        query = query.eq('tenant_id', tenantId);
      }

      final response = await query.order('name');
      final rows = response as List;

      final headcounts = await _departmentHeadcounts(tenantId: tenantId);

      final result = rows.map((e) {
        final json = e as Map<String, dynamic>;
        final id = json['id'] as String;
        return AdminDepartmentRow.fromJson(
          json,
          headcount: headcounts[id] ?? 0,
        );
      }).toList();

      Logger.debug('AdminStaffService.listDepartments → ${result.length} kayıt');
      return result;
    } catch (e) {
      Logger.error('AdminStaffService.listDepartments hata: $e');
      rethrow;
    }
  }

  // ============================================
  // PRIVATE
  // ============================================

  /// organizations id→name haritası (aktif, tenant-kapsamlı).
  Future<Map<String, String>> _organizationNames({String? tenantId}) async {
    try {
      var query = _supabase
          .from('organizations')
          .select('id,name')
          .not('active', 'is', false);
      if (tenantId != null && tenantId.isNotEmpty) {
        query = query.eq('tenant_id', tenantId);
      }
      final rows = await query as List;
      final map = <String, String>{};
      for (final r in rows) {
        final m = r as Map<String, dynamic>;
        final id = m['id'] as String?;
        final name = m['name'] as String?;
        if (id != null && name != null) map[id] = name;
      }
      return map;
    } catch (e) {
      Logger.warning('AdminStaffService._organizationNames hata: $e');
      return const {};
    }
  }

  /// department_id → aktif personel sayısı.
  Future<Map<String, int>> _departmentHeadcounts({String? tenantId}) async {
    try {
      var query = _supabase
          .from('staffs')
          .select('department_id')
          .not('active', 'is', false);
      if (tenantId != null && tenantId.isNotEmpty) {
        query = query.eq('tenant_id', tenantId);
      }
      final rows = await query as List;
      final counts = <String, int>{};
      for (final r in rows) {
        final deptId = (r as Map<String, dynamic>)['department_id'] as String?;
        if (deptId != null) {
          counts[deptId] = (counts[deptId] ?? 0) + 1;
        }
      }
      return counts;
    } catch (e) {
      Logger.warning('AdminStaffService._departmentHeadcounts hata: $e');
      return const {};
    }
  }
}

/// Personel satırı görüntü-modeli (salt-okuma).
class AdminStaffRow {
  final String id;
  final String? name;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;

  /// `staffs.title` (serbest metin ünvan).
  final String? title;
  final String? code;
  final String? description;
  final String? address;
  final String? town;

  /// Embed `positions.name`.
  final String? positionName;

  /// Embed `departments.name`.
  final String? departmentName;
  final String? organizationName;
  final String? organizationId;
  final String? departmentId;
  final String? positionId;
  final String? managerId;

  const AdminStaffRow({
    required this.id,
    this.name,
    this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.title,
    this.code,
    this.description,
    this.address,
    this.town,
    this.positionName,
    this.departmentName,
    this.organizationName,
    this.organizationId,
    this.departmentId,
    this.positionId,
    this.managerId,
  });

  /// Görüntülenen tam ad: first+last, yoksa `name`.
  String get fullName {
    final f = firstName?.trim() ?? '';
    final l = lastName?.trim() ?? '';
    final combined = [f, l].where((s) => s.isNotEmpty).join(' ');
    if (combined.isNotEmpty) return combined;
    return name?.trim() ?? '';
  }

  /// Kartta "ünvan" olarak gösterilecek en iyi değer.
  String? get displayTitle {
    final t = title?.trim();
    if (t != null && t.isNotEmpty) return t;
    final p = positionName?.trim();
    if (p != null && p.isNotEmpty) return p;
    return null;
  }

  static String? _embedName(dynamic embed) {
    if (embed is Map<String, dynamic>) return embed['name'] as String?;
    if (embed is List && embed.isNotEmpty) {
      final first = embed.first;
      if (first is Map<String, dynamic>) return first['name'] as String?;
    }
    return null;
  }

  factory AdminStaffRow.fromJson(
    Map<String, dynamic> json, {
    Map<String, String> organizationNames = const {},
  }) {
    final orgId = json['organization_id'] as String?;
    return AdminStaffRow(
      id: json['id'] as String,
      name: json['name'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      title: json['title'] as String?,
      code: json['code'] as String?,
      description: json['description'] as String?,
      address: json['address'] as String?,
      town: json['town'] as String?,
      positionName: _embedName(json['positions']),
      departmentName: _embedName(json['departments']),
      organizationName: orgId != null ? organizationNames[orgId] : null,
      organizationId: orgId,
      departmentId: json['department_id'] as String?,
      positionId: json['position_id'] as String?,
      managerId: json['manager_id'] as String?,
    );
  }
}

/// Departman satırı görüntü-modeli (salt-okuma).
class AdminDepartmentRow {
  final String id;
  final String? name;
  final String? code;
  final String? description;
  final String? parentId;
  final String? organizationName;
  final String? managerStaffId;
  final int headcount;

  const AdminDepartmentRow({
    required this.id,
    this.name,
    this.code,
    this.description,
    this.parentId,
    this.organizationName,
    this.managerStaffId,
    this.headcount = 0,
  });

  factory AdminDepartmentRow.fromJson(
    Map<String, dynamic> json, {
    int headcount = 0,
  }) {
    final org = json['organizations'];
    String? orgName;
    if (org is Map<String, dynamic>) orgName = org['name'] as String?;
    return AdminDepartmentRow(
      id: json['id'] as String,
      name: json['name'] as String?,
      code: json['code'] as String?,
      description: json['description'] as String?,
      parentId: json['parent_id'] as String?,
      organizationName: orgName,
      managerStaffId: json['manager_staff_id'] as String?,
      headcount: headcount,
    );
  }
}
