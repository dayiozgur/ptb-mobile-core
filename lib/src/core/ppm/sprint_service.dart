import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../errors/write_outcome.dart';
import '../platform/builder_platform_filter.dart';
import '../platform/platform_context.dart';
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
/// Yazma sözleşmesi: UI'a ASLA fırlatmaz; [WriteOutcome] döner. Since the PPM
/// permission scheme (2026-11-13) the `sprints` update policy requires
/// `fn_ppm_can_manage_sprint(project_id)`: a refused update is filtered by RLS
/// and changes no row although the sprint is readable — that is reported as
/// [WriteOutcome.denied], like a `42501` raised by the issue trigger.
class SprintService {
  final SupabaseClient _supabase;

  SprintService({required SupabaseClient supabase}) : _supabase = supabase;

  /// Bir projenin sprint'lerini `sort_order`'a göre listeler (RLS + proje scope).
  /// Jira-style: sprint tam 1 projeye ait, o yüzden [projectId] zorunlu. A failed
  /// read is rethrown (the screen says "could not load", not "no sprints").
  Future<List<Sprint>> listSprints(String projectId) async {
    final pid = projectId.trim();
    if (pid.isEmpty) return const [];
    try {
      final rows = await _supabase
          .from('sprints')
          .select(
              'id, project_id, name, goal, start_date, end_date, state, entity_type, sort_order')
          .eq('project_id', pid)
          .order('sort_order', ascending: true);
      return (rows as List)
          .map((r) => Sprint.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      Logger.error('listSprints hata', e);
      rethrow;
    }
  }

  /// Sprint'i başlat (state='active'). Aynı anda tek aktif sprint kısıtı varsa
  /// unique-violation → [WriteOutcome.failed]. No row changed although the
  /// sprint was listed → [WriteOutcome.denied] (RLS refused the update).
  Future<WriteOutcome> startSprint(String id) async {
    final sid = id.trim();
    if (sid.isEmpty) return WriteOutcome.failed;
    try {
      final rows = await _supabase
          .from('sprints')
          .update({'state': 'active'})
          .eq('id', sid)
          .select('id');
      return (rows as List).isNotEmpty ? WriteOutcome.ok : WriteOutcome.denied;
    } catch (e) {
      Logger.error('startSprint ($id) hata', e);
      return WriteOutcome.fromError(e);
    }
  }

  /// Sprint'i tamamla — web `_completeSprint` deseni: (1) state='closed'
  /// (returning `entity_type`), (2) o tipin final ("done") status kodlarını çöz,
  /// (3) biten-OLMAYAN issue'ları backlog'a döndür (`sprint_id=null`). Final
  /// tanımı yoksa sprint'teki tüm issue'lar döner (web ile aynı).
  ///
  /// The close is checked: no row changed → [WriteOutcome.denied] and nothing
  /// else is written (before, a refused close still reported success). Moving
  /// the issues back can be refused by the issue trigger (`42501`,
  /// `backlog.rank` / `sprint.manage`) → [WriteOutcome.denied]. Other errors →
  /// [WriteOutcome.failed].
  Future<WriteOutcome> completeSprint(String id) async {
    final sid = id.trim();
    if (sid.isEmpty) return WriteOutcome.failed;
    try {
      final closed = await _supabase
          .from('sprints')
          .update({'state': 'closed'})
          .eq('id', sid)
          .select('id, entity_type');
      final closedRows = closed as List;
      if (closedRows.isEmpty) return WriteOutcome.denied;
      final entityType =
          (closedRows.first as Map)['entity_type'] as String?;

      var finalCodes = <String>[];
      if (entityType != null && entityType.isNotEmpty) {
        // Builder tablosu → platform kapsamı (web applyPlatformFilter ile aynı).
        final pid = sl.isRegistered<PlatformContext>()
            ? sl<PlatformContext>().activePlatformId
            : null;
        final defs = await BuilderPlatformFilter.apply(
          _supabase
              .from('status_definitions')
              .select('code')
              .eq('entity_type', entityType)
              .eq('is_final', true)
              .eq('active', true),
          pid,
        );
        finalCodes =
            (defs as List).map((d) => (d as Map)['code'] as String).toList();
      }

      var q = _supabase.from('form_submissions').update({
        'sprint_id': null,
        'updated_by': _supabase.auth.currentUser?.id
      }).eq('sprint_id', sid);
      if (finalCodes.isNotEmpty) {
        q = q.not('status', 'in', '(${finalCodes.join(',')})');
      }
      await q;
      return WriteOutcome.ok;
    } catch (e) {
      Logger.error('completeSprint ($id) hata', e);
      return WriteOutcome.fromError(e);
    }
  }
}
