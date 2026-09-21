import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';

/// Sprint yaşam-döngüsü durumu (web `SprintState` ile birebir).
enum SprintState { future, active, closed, unknown }

SprintState _stateFromDb(Object? v) {
  switch (v as String?) {
    case 'active':
      return SprintState.active;
    case 'closed':
      return SprintState.closed;
    case 'future':
      return SprintState.future;
    default:
      return SprintState.unknown;
  }
}

/// Bir sprint kaydı (`public.sprints`). Web `Sprint` arayüzünün mobil karşılığı;
/// yalnız yönetim ekranının ihtiyaç duyduğu alanlar.
class Sprint {
  final String id;
  /// Sahip proje (form_submissions id). Jira-style: sprint tam 1 projeye ait.
  final String projectId;
  final String name;
  final String? goal;
  final SprintState state;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? entityType;

  const Sprint({
    required this.id,
    this.projectId = '',
    required this.name,
    this.goal,
    this.state = SprintState.unknown,
    this.startDate,
    this.endDate,
    this.entityType,
  });

  factory Sprint.fromJson(Map<String, dynamic> j) => Sprint(
        id: j['id'] as String,
        projectId: (j['project_id'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        goal: j['goal'] as String?,
        state: _stateFromDb(j['state']),
        startDate: DateTime.tryParse((j['start_date'] as String?) ?? ''),
        endDate: DateTime.tryParse((j['end_date'] as String?) ?? ''),
        entityType: j['entity_type'] as String?,
      );
}

/// **Sprint yaşam-döngüsü servisi** — web `PtbSprintService`'in mobil write-
/// paritesi. `sprints.state` alan-geçişini (future→active→closed) ve sprint
/// kapanışında biten-olmayan issue'ların backlog'a dönüşünü kurar. Tenant,
/// mobil kalıbı gereği **RLS'e** (`tenant_id = get_my_tenant_id()`) bırakılır —
/// web'in aksine explicit `tenant_id` geçilmez.
///
/// Yazma sözleşmesi: hata → `false` (UI'a ASLA fırlatmaz), diğer mobil write-
/// servisleriyle (CrmActionsService / WorklogService) aynı.
class SprintService {
  final SupabaseClient _supabase;

  SprintService({required SupabaseClient supabase}) : _supabase = supabase;

  /// Bir projenin sprint'lerini `sort_order`'a göre listeler (RLS + proje scope).
  /// Jira-style: sprint tam 1 projeye ait, o yüzden [projectId] zorunlu. Hata → [].
  Future<List<Sprint>> listSprints(String projectId) async {
    final pid = projectId.trim();
    if (pid.isEmpty) return const [];
    try {
      final rows = await _supabase
          .from('sprints')
          .select('id, project_id, name, goal, start_date, end_date, state, entity_type, sort_order')
          .eq('project_id', pid)
          .order('sort_order', ascending: true);
      return (rows as List)
          .map((r) => Sprint.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      Logger.error('listSprints hata', e);
      return const [];
    }
  }

  /// Sprint'i başlat (state='active'). Aynı anda tek aktif sprint kısıtı varsa
  /// unique-violation → `false` (UI "zaten aktif sprint var" der). Etkilenen
  /// satır yoksa (RLS/eşleşme) → `false`.
  Future<bool> startSprint(String id) async {
    final sid = id.trim();
    if (sid.isEmpty) return false;
    try {
      final rows = await _supabase
          .from('sprints')
          .update({'state': 'active'})
          .eq('id', sid)
          .select('id');
      return (rows as List).isNotEmpty;
    } catch (e) {
      Logger.error('startSprint ($id) hata', e);
      return false;
    }
  }

  /// Sprint'i tamamla — web `_completeSprint` deseni: (1) `entity_type` oku,
  /// (2) state='closed', (3) o tipin final ("done") status kodlarını çöz,
  /// (4) biten-OLMAYAN issue'ları backlog'a döndür (`sprint_id=null`). Final
  /// tanımı yoksa sprint'teki tüm issue'lar döner (web ile aynı). Hata → `false`.
  Future<bool> completeSprint(String id) async {
    final sid = id.trim();
    if (sid.isEmpty) return false;
    try {
      final sprintRow = await _supabase
          .from('sprints')
          .select('entity_type')
          .eq('id', sid)
          .maybeSingle();
      final entityType = sprintRow?['entity_type'] as String?;

      await _supabase.from('sprints').update({'state': 'closed'}).eq('id', sid);

      var finalCodes = <String>[];
      if (entityType != null && entityType.isNotEmpty) {
        final defs = await _supabase
            .from('status_definitions')
            .select('code')
            .eq('entity_type', entityType)
            .eq('is_final', true)
            .eq('active', true);
        finalCodes = (defs as List)
            .map((d) => (d as Map)['code'] as String)
            .toList();
      }

      var q = _supabase
          .from('form_submissions')
          .update({'sprint_id': null, 'updated_by': _supabase.auth.currentUser?.id})
          .eq('sprint_id', sid);
      if (finalCodes.isNotEmpty) {
        q = q.not('status', 'in', '(${finalCodes.join(',')})');
      }
      await q;
      return true;
    } catch (e) {
      Logger.error('completeSprint ($id) hata', e);
      return false;
    }
  }
}
