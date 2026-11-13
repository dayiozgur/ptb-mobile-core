import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';

/// PPM project permission scheme — action codes (same catalogue as the web
/// `PpmAction` and `ppm_scheme_grants.action_code`).
abstract final class PpmAction {
  static const issueCreate = 'issue.create';
  static const issueEdit = 'issue.edit';
  static const issueTransition = 'issue.transition';
  static const issueAssign = 'issue.assign';
  static const issueDelete = 'issue.delete';
  static const backlogRank = 'backlog.rank';
  static const sprintManage = 'sprint.manage';
  static const memberManage = 'member.manage';
  static const boardConfigure = 'board.configure';
}

/// Entity types the scheme applies to (the server's `v_ppm` list).
const Set<String> kPpmIssueTypes = {'epic', 'story', 'task', 'sub_task', 'bug'};

/// Permission snapshot for one project (`fn_ppm_my_effective_permissions`).
///
/// `enforced == false` (no team, no effective scheme, tenant admin, or the
/// function is missing) means every action is allowed — exactly what the
/// database allows. Mirrors the web `PpmPermissions` / `ppmAllows`.
class PpmPermissions {
  final bool enforced;
  final Set<String> actions;

  const PpmPermissions({required this.enforced, this.actions = const {}});

  /// Nothing hidden (not loaded / not enforced / unknown).
  static const PpmPermissions open = PpmPermissions(enforced: false);

  /// Parse the RPC payload `{enforced, actions}`; anything malformed → [open].
  factory PpmPermissions.fromJson(Object? data) {
    if (data is! Map) return open;
    final raw = data['actions'];
    final actions = raw is List ? raw.whereType<String>().toSet() : <String>{};
    return PpmPermissions(enforced: data['enforced'] == true, actions: actions);
  }

  bool allows(String action) => !enforced || actions.contains(action);

  /// Re-ranking the backlog or moving issues between sprints: the server
  /// accepts either right (`fn_ppm_scheme_guard_update`).
  bool get canRank =>
      allows(PpmAction.backlogRank) || allows(PpmAction.sprintManage);
}

/// Client gate for the PPM permission scheme — used only to HIDE or pre-check
/// actions. The server (RLS / triggers / Edge Functions) stays the real
/// protection; on any read error nothing is hidden (like the web
/// `PtbProjectPermissionService.loadPermissions`).
class PpmPermissionService {
  final SupabaseClient _supabase;
  final Map<String, PpmPermissions> _cache = {};

  PpmPermissionService({required SupabaseClient supabase})
      : _supabase = supabase;

  /// Snapshot for [projectId], cached for this service's lifetime.
  Future<PpmPermissions> load(String projectId) async {
    final pid = projectId.trim();
    if (pid.isEmpty) return PpmPermissions.open;
    final hit = _cache[pid];
    if (hit != null) return hit;
    try {
      final data = await _supabase.rpc(
        'fn_ppm_my_effective_permissions',
        params: {'p_project_id': pid},
      );
      final perms = PpmPermissions.fromJson(data);
      _cache[pid] = perms;
      return perms;
    } catch (e) {
      // Missing function (PGRST202 / 42883) = the server does not enforce
      // either → cache "open"; a transient error retries next time.
      final code = e is PostgrestException ? e.code : null;
      if (code == 'PGRST202' || code == '42883') {
        _cache[pid] = PpmPermissions.open;
      } else {
        Logger.warning('PPM permissions could not be read; nothing hidden');
      }
      return PpmPermissions.open;
    }
  }

  void invalidate([String? projectId]) =>
      projectId == null ? _cache.clear() : _cache.remove(projectId.trim());
}
