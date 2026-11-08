import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'fixflow_models.dart';
import 'fixflow_session.dart';

/// FixFlow iş talebi (work request) + bakım (maintenance) okuma/oluşturma
/// servisi — web `work-request.service.ts` / `maintenance.service.ts` ile
/// aynı kolonlar.
///
/// NOT: eski mobil `WorkRequestService` (`lib/src/core/work_request/`) canlı
/// şemayla UYUMSUZ (`title`/`type`/`requested_by_id`/`assigned_to_id` gibi
/// olmayan kolonlar, BÜYÜK harf sabit durum enum'u, doğrudan durum yazımı).
/// FixFlow ekranları bu servisi kullanır.
class FixflowWorkRequestService {
  final SupabaseClient _supabase;
  final FixflowSession _session;

  FixflowWorkRequestService({
    required SupabaseClient supabase,
    FixflowSession? session,
  })  : _supabase = supabase,
        _session = session ?? AppFixflowSession(supabase);

  /// İş talepleri (en yeni önce). [mineOnly] → `created_by = auth.uid()`.
  /// Hata fırlatır.
  Future<List<FixflowWorkRequest>> listWorkRequests({
    List<String>? statuses,
    bool mineOnly = false,
    int limit = 100,
  }) async {
    var query =
        _supabase.from('work_requests').select('*').eq('active', true);
    final tenantId = _session.tenantId;
    if (tenantId != null) query = query.eq('tenant_id', tenantId);
    if (mineOnly) {
      final uid = _session.userId;
      if (uid == null) return const [];
      query = query.eq('created_by', uid);
    }
    if (statuses != null && statuses.isNotEmpty) {
      query = statuses.length == 1
          ? query.eq('status', statuses.first)
          : query.inFilter('status', statuses);
    }
    final res = await query.order('created_at', ascending: false).limit(limit);
    return (res as List)
        .map((r) =>
            FixflowWorkRequest.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Yeni iş talebi (web `insertItem` ile aynı satır). [initialStatus]
  /// `status_definitions.is_initial` kodundan gelir (sabit kod YOK); null ise
  /// kolon gönderilmez. [priorityCode] `priorities.code` → web gibi BÜYÜK
  /// harfe çevrilir. `code` DB trigger'ı (`trg_auto_code_work_requests`)
  /// tarafından üretilir. Hata fırlatır.
  Future<FixflowWorkRequest> createWorkRequest({
    required String subject,
    String? description,
    String? priorityCode,
    String? initialStatus,
    String? siteId,
  }) async {
    final s = subject.trim();
    if (s.isEmpty) throw ArgumentError.value(subject, 'subject');
    final payload = <String, dynamic>{
      'id': const Uuid().v4(),
      'subject': s,
      'description': (description ?? '').trim(),
      if (initialStatus != null && initialStatus.isNotEmpty)
        'status': initialStatus,
      'priority': (priorityCode == null || priorityCode.trim().isEmpty)
          ? null
          : priorityCode.trim().toUpperCase(),
      'site_id': siteId,
      'created_by': _session.userId,
      'tenant_id': _session.tenantId,
      'organization_id': await _session.organizationId(),
      'active': true,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    final row = await _supabase
        .from('work_requests')
        .insert(payload)
        .select('*')
        .single();
    return FixflowWorkRequest.fromJson(Map<String, dynamic>.from(row));
  }

  /// Bakım planları/iş emirleri (salt-okuma). Varsayılan sıra: planlanan tarih
  /// artan (yakın tarih önce). Hata fırlatır.
  Future<List<FixflowMaintenance>> listMaintenances({
    List<String>? statuses,
    int limit = 100,
  }) async {
    var query =
        _supabase.from('maintenances').select('*').eq('active', true);
    final tenantId = _session.tenantId;
    if (tenantId != null) query = query.eq('tenant_id', tenantId);
    if (statuses != null && statuses.isNotEmpty) {
      query = statuses.length == 1
          ? query.eq('status', statuses.first)
          : query.inFilter('status', statuses);
    }
    final res = await query
        .order('scheduled_date', ascending: true, nullsFirst: false)
        .limit(limit);
    return (res as List)
        .map((r) =>
            FixflowMaintenance.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Açık iş talebi / bakım sayısı (pano). Hata → 0.
  Future<int> countOpen(String table, List<String> openStatuses) async {
    try {
      var query = _supabase.from(table).select('id').eq('active', true);
      final tenantId = _session.tenantId;
      if (tenantId != null) query = query.eq('tenant_id', tenantId);
      if (openStatuses.isNotEmpty) {
        query = query.inFilter('status', openStatuses);
      }
      final res = await query.count(CountOption.exact);
      return res.count;
    } catch (_) {
      return 0;
    }
  }
}
