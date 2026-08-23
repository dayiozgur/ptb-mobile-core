import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../tenant/tenant_service.dart';
import '../utils/logger.dart';
import 'orgchart_models.dart';

export 'orgchart_models.dart';

/// **Org-chart servisi** — organizasyon ve departman hiyerarşilerini client-side
/// ağaç olarak kurar (web `OrgChartService.getOrgTree` deseniyle aynı: iki düz
/// select → JS/Dart'ta ağaç). Salt-okuma; hata durumunda [] döner (UI'a fırlatmaz).
///
/// - Organizasyon ağacı: `organizations.parent_organization_id`, personel
///   `staffs.organization_id` ile gruplanır.
/// - Departman ağacı: `departments.parent_id`, personel `staffs.department_id`.
class OrgChartService {
  final SupabaseClient _supabase;

  OrgChartService({required SupabaseClient supabase}) : _supabase = supabase;

  TenantService get _tenant => sl<TenantService>();

  String _staffName(Map<String, dynamic> r) {
    final n = (r['name'] ?? '').toString().trim();
    if (n.isNotEmpty) return n;
    final fn = (r['first_name'] ?? '').toString().trim();
    final ln = (r['last_name'] ?? '').toString().trim();
    final full = '$fn $ln'.trim();
    return full.isEmpty ? 'İsimsiz' : full;
  }

  Future<List<Map<String, dynamic>>> _fetchStaffs() async {
    var q = _supabase
        .from('staffs')
        .select('id, name, first_name, last_name, title, '
            'organization_id, department_id')
        .eq('active', true);
    final tid = _tenant.currentTenantId;
    if (tid != null) q = q.eq('tenant_id', tid);
    final res = await q;
    return (res as List).cast<Map<String, dynamic>>();
  }

  /// Organizasyon ağacı (root'lar = parent'ı olmayan org'lar).
  Future<List<OrgTreeNode>> organizationTree() async {
    try {
      var oq = _supabase
          .from('organizations')
          .select('id, name, parent_organization_id')
          .neq('active', false);
      final tid = _tenant.currentTenantId;
      if (tid != null) oq = oq.eq('tenant_id', tid);
      final orgs = (await oq as List).cast<Map<String, dynamic>>();
      final staffs = await _fetchStaffs();
      return _buildTree(
        rows: orgs,
        parentKey: 'parent_organization_id',
        staffs: staffs,
        staffGroupKey: 'organization_id',
      );
    } catch (e) {
      Logger.error('Organizasyon ağacı yüklenemedi', e);
      return const [];
    }
  }

  /// Departman ağacı (root'lar = parent'ı olmayan departmanlar).
  Future<List<OrgTreeNode>> departmentTree() async {
    try {
      var dq = _supabase
          .from('departments')
          .select('id, name, parent_id')
          .neq('active', false);
      final tid = _tenant.currentTenantId;
      if (tid != null) dq = dq.eq('tenant_id', tid);
      final depts = (await dq as List).cast<Map<String, dynamic>>();
      final staffs = await _fetchStaffs();
      return _buildTree(
        rows: depts,
        parentKey: 'parent_id',
        staffs: staffs,
        staffGroupKey: 'department_id',
      );
    } catch (e) {
      Logger.error('Departman ağacı yüklenemedi', e);
      return const [];
    }
  }

  /// Düz satırlardan ([rows]) parent-key ile ağaç kurar; personeli
  /// [staffGroupKey] ile ilgili düğüme yerleştirir.
  List<OrgTreeNode> _buildTree({
    required List<Map<String, dynamic>> rows,
    required String parentKey,
    required List<Map<String, dynamic>> staffs,
    required String staffGroupKey,
  }) {
    final nodeMap = <String, OrgTreeNode>{};
    for (final r in rows) {
      final id = r['id']?.toString();
      if (id == null) continue;
      nodeMap[id] = OrgTreeNode(
        id: id,
        name: (r['name'] ?? '—').toString(),
      );
    }
    // Personeli düğümlere dağıt.
    for (final s in staffs) {
      final key = s[staffGroupKey]?.toString();
      if (key == null) continue;
      final node = nodeMap[key];
      if (node == null) continue;
      node.members.add(OrgMember(
        id: s['id']?.toString() ?? '',
        name: _staffName(s),
        title: (s['title'] ?? '').toString().isEmpty
            ? null
            : s['title'].toString(),
      ));
    }
    // Ağacı bağla; root'ları topla.
    final roots = <OrgTreeNode>[];
    for (final r in rows) {
      final id = r['id']?.toString();
      if (id == null) continue;
      final node = nodeMap[id]!;
      final parentId = r[parentKey]?.toString();
      if (parentId != null && nodeMap.containsKey(parentId)) {
        nodeMap[parentId]!.children.add(node);
      } else {
        roots.add(node);
      }
    }
    return roots;
  }
}

/// Convenience getter.
OrgChartService get orgChartService => sl<OrgChartService>();
