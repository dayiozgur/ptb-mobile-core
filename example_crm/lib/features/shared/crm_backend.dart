import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// CRM ekranlarının veri kapısı (seam). Servis mantığı (eşleme, süzme,
/// sıralama, hata→boş) bu arayüz üzerinden çalışır → birim testlerde sahte
/// bir backend ile Supabase'siz sınanır. Varsayılan gerçekleme
/// [SupabaseCrmBackend]'dir.
///
/// Yazma yolları web ile BİREBİR:
///   • durum/aşama değişimi → `status-transition` Edge Function (çekirdek
///     [EntityDataService.updateStatus]; `form_submissions.status` doğrudan
///     YAZILMAZ — web `PtbStatusService.executeTransition` ile aynı),
///   • RPC'ler (`fn_crm_*`) web servisleriyle aynı imza/parametrelerle.
abstract class CrmBackend {
  /// Bir entity tipinin bağımsız (standalone) kayıtları — en yeni önce.
  Future<List<Map<String, dynamic>>> listSubmissions(String entityType,
      {int limit = 200});

  /// `status_definitions` satırları (platform filtreli, sort_order sıralı).
  Future<List<Map<String, dynamic>>> statusDefinitionRows(String entityType);

  /// `status_transitions` satırları (from/to kodları gömülü).
  Future<List<Map<String, dynamic>>> statusTransitionRows(String entityType);

  /// Satır döndüren bir RPC (TABLE/SETOF) — sonuç her zaman liste.
  Future<List<Map<String, dynamic>>> rpcRows(String fn,
      [Map<String, dynamic>? params]);

  /// Skaler döndüren bir RPC (uuid/void/jsonb).
  Future<dynamic> rpc(String fn, [Map<String, dynamic>? params]);

  /// Bir firmaya bağlı kişiler (`contacts.company_id`).
  Future<List<Map<String, dynamic>>> contactsOfCompany(String companyId);

  /// Durum geçişi — `status-transition` EF (web ile aynı sözleşme).
  Future<void> executeTransition({
    required String entityType,
    required String entityId,
    required String toStatus,
    String? comment,
  });

  /// Oturumdaki kullanıcının kaba rolü (`ROLE_ADMIN` …) — geçiş rol süzgeci.
  Future<String?> currentRole();
}

/// [CrmBackend]'in Supabase gerçeklemesi.
class SupabaseCrmBackend implements CrmBackend {
  SupabaseCrmBackend({SupabaseClient? supabase}) : _client = supabase;

  final SupabaseClient? _client;
  SupabaseClient get _sb => _client ?? sl<SupabaseClient>();

  String? get _tenantId => sl.isRegistered<TenantService>()
      ? sl<TenantService>().currentTenantId
      : null;

  String? get _platformId => sl.isRegistered<PlatformContext>()
      ? sl<PlatformContext>().activePlatformId
      : null;

  static List<Map<String, dynamic>> _rows(dynamic res) =>
      ((res as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  @override
  Future<List<Map<String, dynamic>>> listSubmissions(String entityType,
      {int limit = 200}) async {
    final tenantId = _tenantId;
    if (tenantId == null) throw Exception('Tenant context is not set');
    // Çekirdek EntityDataService.listEntities ile aynı kapsam (tenant +
    // entity_type + standalone + active + platform/NULL); ek olarak
    // `metadata` okunur (web liste projeksiyonları metadata'dan türetir).
    var q = _sb
        .from('form_submissions')
        .select('id, code, subject, status, metadata, created_at, '
            'organization_id')
        .eq('tenant_id', tenantId)
        .eq('entity_type', entityType)
        .eq('is_standalone', true)
        .eq('active', true);
    final pid = _platformId;
    if (pid != null) q = q.or('platform_id.is.null,platform_id.eq.$pid');
    final res = await q.order('created_at', ascending: false).limit(limit);
    return _rows(res);
  }

  @override
  Future<List<Map<String, dynamic>>> statusDefinitionRows(
      String entityType) async {
    var q = _sb
        .from('status_definitions')
        .select('id, code, name, color, icon, is_initial, is_final, '
            'sort_order, is_system, metadata')
        .eq('entity_type', entityType)
        .eq('active', true);
    q = BuilderPlatformFilter.apply(q, _platformId);
    final res = await q.order('sort_order', ascending: true);
    return _rows(res);
  }

  @override
  Future<List<Map<String, dynamic>>> statusTransitionRows(
      String entityType) async {
    // Web PtbStatusService.fetchTransitionRows ile aynı seçim.
    final res = await _sb
        .from('status_transitions')
        .select('id, name, tenant_id, required_roles, requires_comment, '
            'requires_confirmation, required_form_template_id, sort_order, '
            'from_status:status_definitions!from_status_id(code), '
            'to_status:status_definitions!to_status_id(code)')
        .eq('entity_type', entityType)
        .eq('active', true)
        .order('sort_order', ascending: true);
    return _rows(res);
  }

  @override
  Future<List<Map<String, dynamic>>> rpcRows(String fn,
      [Map<String, dynamic>? params]) async {
    final res = await _sb.rpc(fn, params: params);
    return _rows(res);
  }

  @override
  Future<dynamic> rpc(String fn, [Map<String, dynamic>? params]) =>
      _sb.rpc(fn, params: params);

  @override
  Future<List<Map<String, dynamic>>> contactsOfCompany(
      String companyId) async {
    final res = await _sb
        .from('contacts')
        .select('id, first_name, last_name, email, phone, title, company_id, '
            'notes')
        .eq('company_id', companyId)
        .eq('active', true)
        .order('first_name', ascending: true);
    return _rows(res);
  }

  @override
  Future<void> executeTransition({
    required String entityType,
    required String entityId,
    required String toStatus,
    String? comment,
  }) =>
      sl<EntityDataService>().updateStatus(
        entityType: entityType,
        entityId: entityId,
        toStatus: toStatus,
        comment: comment,
      );

  @override
  Future<String?> currentRole() async {
    try {
      if (!sl.isRegistered<ProfileService>()) return null;
      final p = await sl<ProfileService>().getCurrentProfile();
      return p?.coarseRole;
    } catch (_) {
      return null;
    }
  }
}
