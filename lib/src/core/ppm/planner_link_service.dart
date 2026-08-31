import 'package:supabase_flutter/supabase_flutter.dart';

import '../integration/microsoft_integration_service.dart';
import '../utils/logger.dart';

/// A Microsoft Planner plan the user can link a PPM project to (GET /me/planner/plans).
class PlannerPlan {
  final String id;
  final String title;
  const PlannerPlan({required this.id, required this.title});
}

/// A PPM-project → Planner-plan link (public.planner_plan_links, tenant-scoped RLS).
class PlannerLink {
  final String id;
  final String projectEntityId;
  final String planId;
  final String? planTitle;
  final String bucketBy;
  final String? connectionId;

  const PlannerLink({
    required this.id,
    required this.projectEntityId,
    required this.planId,
    required this.planTitle,
    required this.bucketBy,
    required this.connectionId,
  });

  factory PlannerLink.fromMap(Map<String, dynamic> m) => PlannerLink(
        id: m['id'] as String,
        projectEntityId: m['project_entity_id'] as String,
        planId: m['plan_id'] as String,
        planTitle: m['plan_title'] as String?,
        bucketBy: (m['bucket_by'] ?? 'status') as String,
        connectionId: m['connection_id'] as String?,
      );
}

/// Aggregate counts returned by a Planner "sync now".
class PlannerSyncResult {
  final int pushed;
  final int pulled;
  final int errors;
  const PlannerSyncResult(this.pushed, this.pulled, this.errors);
}

/// **PPM ↔ Microsoft Planner link management (mobile)** — the client parity of the web
/// `PtbPlannerLinkService`. Link CRUD goes straight to `planner_plan_links` (tenant-scoped RLS —
/// `tenant_id` defaults to `get_my_tenant_id()`, `created_by` set to the caller); plan listing and
/// "sync now" flow through the isolated `graph-proxy` / `ppm-planner-sync` Edge Functions via
/// [MicrosoftIntegrationService]. The service never touches a token. Errors are logged and
/// surfaced as null/empty; the caller decides how to present them.
class PlannerLinkService {
  final SupabaseClient _supabase;
  final MicrosoftIntegrationService _ms;

  PlannerLinkService({required SupabaseClient supabase, required MicrosoftIntegrationService ms})
      : _supabase = supabase,
        _ms = ms;

  /// The classic Planner web deep-link for a plan (opens the board in the browser).
  String plannerUrl(String planId) => 'https://planner.cloud.microsoft/webui/plan/$planId/view/board';

  /// The caller's connected Microsoft account (or null). Used to gate the panel.
  Future<IntegrationConnection?> getConnection() => _ms.getConnected();

  /// List the Planner plans the connected user can see (member of).
  Future<List<PlannerPlan>> listPlans() async {
    final res = await _ms.graphCall('GET', '/me/planner/plans');
    if (res == null || !res.ok) return const <PlannerPlan>[];
    final value = (res.data is Map ? res.data['value'] : null);
    if (value is! List) return const <PlannerPlan>[];
    return value
        .whereType<Map>()
        .map((p) => PlannerPlan(id: p['id'] as String, title: (p['title'] ?? '') as String))
        .toList();
  }

  /// The active Planner link for a project, or null.
  Future<PlannerLink?> getLink(String projectEntityId) async {
    try {
      final row = await _supabase
          .from('planner_plan_links')
          .select('id,project_entity_id,plan_id,plan_title,bucket_by,connection_id,active')
          .eq('project_entity_id', projectEntityId)
          .eq('active', true)
          .maybeSingle();
      if (row == null) return null;
      return PlannerLink.fromMap(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      Logger.error('[planner] getLink failed', e);
      return null;
    }
  }

  /// Link a project to a Planner plan. `tenant_id` is DB-defaulted; `created_by` = caller.
  Future<PlannerLink?> link({
    required String projectEntityId,
    required PlannerPlan plan,
    required String bucketBy,
    String? connectionId,
  }) async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      final row = await _supabase
          .from('planner_plan_links')
          .insert(<String, dynamic>{
            'project_entity_id': projectEntityId,
            'plan_id': plan.id,
            'plan_title': plan.title,
            'bucket_by': bucketBy,
            'connection_id': connectionId,
            'active': true,
            if (uid != null) 'created_by': uid,
          })
          .select('id,project_entity_id,plan_id,plan_title,bucket_by,connection_id,active')
          .single();
      return PlannerLink.fromMap(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      Logger.error('[planner] link failed', e);
      return null;
    }
  }

  /// Deactivate a project's Planner link (soft-remove; keeps sync history).
  Future<bool> unlink(String linkId) async {
    try {
      await _supabase.from('planner_plan_links').update(<String, dynamic>{'active': false}).eq('id', linkId);
      return true;
    } catch (e) {
      Logger.error('[planner] unlink failed', e);
      return false;
    }
  }

  /// The caller's last Planner sync timestamp (ISO string), or null.
  Future<String?> getLastSyncedAt() async {
    try {
      final row = await _supabase
          .from('planner_sync_state')
          .select('last_synced_at')
          .order('last_synced_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return row == null ? null : row['last_synced_at'] as String?;
    } catch (e) {
      Logger.error('[planner] getLastSyncedAt failed', e);
      return null;
    }
  }

  /// Trigger a "sync now" for the caller's connection (ppm-planner-sync user mode).
  Future<PlannerSyncResult?> syncNow() async {
    try {
      final res = await _supabase.functions.invoke('ppm-planner-sync', body: const <String, dynamic>{});
      final body = res.data;
      if (body is! Map) return null;
      final conns = (body['connections'] as List?) ?? const [];
      int pushed = 0, pulled = 0, errors = 0;
      for (final c in conns.whereType<Map>()) {
        pushed += (c['pushed'] as int?) ?? 0;
        pulled += (c['pulled'] as int?) ?? 0;
        errors += (c['errors'] as int?) ?? 0;
      }
      return PlannerSyncResult(pushed, pulled, errors);
    } catch (e) {
      Logger.error('[planner] syncNow failed', e);
      return null;
    }
  }
}
