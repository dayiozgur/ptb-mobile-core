import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../tenant/tenant_service.dart';
import '../utils/logger.dart';
import 'models/admin_organization.dart';
import 'models/admin_position.dart';
import 'models/onboarding_instance_row.dart';
import 'models/org_rollup_row.dart';

export 'models/admin_organization.dart';
export 'models/admin_position.dart';
export 'models/onboarding_instance_row.dart';
export 'models/org_rollup_row.dart';

/// Admin PHR org-yapısı + oryantasyon görüntüleyicileri için salt-okuma servis.
///
/// Web portalının okuma yollarını birebir aynalar (aynı Supabase projesi):
///  * [positions]              → web `PositionService.list`
///  * [organizations]          → web `OrganizationService.getOrganizations`
///  * [orgRollup]              → RPC yok; `staffs`/`organizations` istemcide toplanır
///  * [onboardingInstances]    → web `OnboardingService.listInstances('onboarding')`
///  * [offboardingInstances]   → web `OnboardingService.listInstances('offboarding')`
///
/// Yazma YOK — v1 salt-okuma viewer. Tenant kapsamı RLS ile sağlanır; ek olarak
/// elde `tenant_id` varsa eşitlikle daraltılır (web ile aynı davranış). Tüm
/// metodlar hata durumunda **rethrow** eder (ekranlar gerçek hatayı gösterir).
class AdminOrgService {
  final SupabaseClient _supabase;

  AdminOrgService({required SupabaseClient supabase}) : _supabase = supabase;

  TenantService get _tenant => sl<TenantService>();

  // ============================================
  // POZİSYONLAR
  // ============================================

  /// Aktif pozisyonlar — web `positions` select'inin aynası (level, name sıralı).
  Future<List<AdminPosition>> positions() async {
    try {
      final tenantId = _tenant.currentTenantId;
      var query = _supabase
          .from('positions')
          .select('id,tenant_id,code,name,description,level,active')
          .eq('active', true);
      if (tenantId != null && tenantId.isNotEmpty) {
        query = query.eq('tenant_id', tenantId);
      }
      final rows = await query.order('level').order('name') as List;
      final result = rows
          .map((e) => AdminPosition.fromJson(e as Map<String, dynamic>))
          .toList();
      Logger.debug('AdminOrgService.positions → ${result.length} kayıt');
      return result;
    } catch (e) {
      Logger.error('AdminOrgService.positions hata: $e');
      rethrow;
    }
  }

  // ============================================
  // ORGANİZASYONLAR
  // ============================================

  /// Aktif organizasyonlar — web `organizations` select'inin aynası (ad sıralı).
  Future<List<AdminOrganization>> organizations() async {
    try {
      final tenantId = _tenant.currentTenantId;
      var query = _supabase
          .from('organizations')
          .select(
            'id,tenant_id,code,name,description,city,'
            'parent_organization_id,hierarchy_level,active',
          )
          .eq('active', true);
      if (tenantId != null && tenantId.isNotEmpty) {
        query = query.eq('tenant_id', tenantId);
      }
      final rows = await query.order('name') as List;
      final result = rows
          .map((e) => AdminOrganization.fromJson(e as Map<String, dynamic>))
          .toList();
      Logger.debug('AdminOrgService.organizations → ${result.length} kayıt');
      return result;
    } catch (e) {
      Logger.error('AdminOrgService.organizations hata: $e');
      rethrow;
    }
  }

  // ============================================
  // ORGANİZASYON KIRILIMI (HEADCOUNT ROLLUP)
  // ============================================

  /// Organizasyon başına aktif personel sayısı (headcount).
  ///
  /// Canlı şemada özel bir rollup RPC bulunmadığından, `organizations` (id→ad)
  /// ile `staffs.organization_id` sayımı istemcide birleştirilir. 0 personelli
  /// organizasyonlar da listelenir. Sonuç headcount azalan (eşitlikte ad) sıralı.
  Future<List<OrgRollupRow>> orgRollup() async {
    try {
      final tenantId = _tenant.currentTenantId;

      // 1) Organizasyonlar (id → ad).
      var orgQuery = _supabase
          .from('organizations')
          .select('id,name')
          .eq('active', true);
      if (tenantId != null && tenantId.isNotEmpty) {
        orgQuery = orgQuery.eq('tenant_id', tenantId);
      }
      final orgRows = await orgQuery.order('name') as List;

      // 2) Personel org sayımı.
      var staffQuery =
          _supabase.from('staffs').select('organization_id').not('active', 'is', false);
      if (tenantId != null && tenantId.isNotEmpty) {
        staffQuery = staffQuery.eq('tenant_id', tenantId);
      }
      final staffRows = await staffQuery as List;

      final counts = <String, int>{};
      for (final r in staffRows) {
        final orgId = (r as Map<String, dynamic>)['organization_id'] as String?;
        if (orgId != null) counts[orgId] = (counts[orgId] ?? 0) + 1;
      }

      final result = orgRows.map((e) {
        final m = e as Map<String, dynamic>;
        final id = m['id'] as String;
        return OrgRollupRow(
          organizationId: id,
          organizationName: m['name'] as String?,
          headcount: counts[id] ?? 0,
        );
      }).toList()
        ..sort((a, b) {
          final byCount = b.headcount.compareTo(a.headcount);
          if (byCount != 0) return byCount;
          return (a.organizationName ?? '').compareTo(b.organizationName ?? '');
        });

      Logger.debug('AdminOrgService.orgRollup → ${result.length} kayıt');
      return result;
    } catch (e) {
      Logger.error('AdminOrgService.orgRollup hata: $e');
      rethrow;
    }
  }

  // ============================================
  // ORYANTASYON / İŞTEN ÇIKIŞ SÜREÇLERİ
  // ============================================

  /// Oryantasyon süreç örnekleri (`type='onboarding'`).
  Future<List<OnboardingInstanceRow>> onboardingInstances() =>
      _instances('onboarding');

  /// İşten-çıkış süreç örnekleri (`type='offboarding'`).
  ///
  /// NOT: İşten-çıkış AYRI bir tablo değildir — aynı `staff_onboarding_*`
  /// tabloları `type` kolonu ile ayrılır (web `OffboardingAdminComponent`
  /// da böyle çalışır).
  Future<List<OnboardingInstanceRow>> offboardingInstances() =>
      _instances('offboarding');

  /// `staff_onboarding_instances` (kind-filtreli) + `staff_onboarding_tasks`
  /// üzerinden istemcide toplanan ilerleme. Web `listInstances` aynası.
  Future<List<OnboardingInstanceRow>> _instances(String kind) async {
    try {
      final tenantId = _tenant.currentTenantId;
      var query = _supabase
          .from('staff_onboarding_instances')
          .select(
            'id,tenant_id,staff_id,template_id,type,status,'
            'started_at,due_date,completed_at,'
            'staffs(name,first_name,last_name),'
            'staff_onboarding_templates(name)',
          )
          .eq('type', kind);
      if (tenantId != null && tenantId.isNotEmpty) {
        query = query.eq('tenant_id', tenantId);
      }
      final rows =
          await query.order('started_at', ascending: false) as List;
      final maps = rows.cast<Map<String, dynamic>>();
      if (maps.isEmpty) return [];

      // İlerleme — tek düz sorgu, istemcide gruplanır.
      final ids = maps.map((m) => m['id'] as String).toList();
      final progress = await _taskProgress(ids);

      final result = maps.map((m) {
        final id = m['id'] as String;
        final p = progress[id];
        return OnboardingInstanceRow.fromJson(
          m,
          doneCount: p?.$1 ?? 0,
          totalCount: p?.$2 ?? 0,
        );
      }).toList();

      Logger.debug('AdminOrgService._instances($kind) → ${result.length} kayıt');
      return result;
    } catch (e) {
      Logger.error('AdminOrgService._instances($kind) hata: $e');
      rethrow;
    }
  }

  /// instance_id → (done, total). `staff_onboarding_tasks.status='done'` tamamlanmış.
  Future<Map<String, (int, int)>> _taskProgress(List<String> instanceIds) async {
    if (instanceIds.isEmpty) return const {};
    final rows = await _supabase
        .from('staff_onboarding_tasks')
        .select('instance_id,status')
        .inFilter('instance_id', instanceIds) as List;
    final done = <String, int>{};
    final total = <String, int>{};
    for (final r in rows) {
      final m = r as Map<String, dynamic>;
      final iid = m['instance_id'] as String?;
      if (iid == null) continue;
      total[iid] = (total[iid] ?? 0) + 1;
      if (m['status'] == 'done') done[iid] = (done[iid] ?? 0) + 1;
    }
    final out = <String, (int, int)>{};
    for (final iid in total.keys) {
      out[iid] = (done[iid] ?? 0, total[iid] ?? 0);
    }
    return out;
  }
}

/// DI kısayolu — barrel üzerinden `adminOrgService.positions()` gibi kullanılır.
AdminOrgService get adminOrgService => sl<AdminOrgService>();
