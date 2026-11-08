import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../permission/permission_service.dart';
import 'status_transition_rules.dart';

/// The current user's role set exactly as the `status-transition` Edge
/// Function resolves it: JWT `app_metadata.roles`, or — when the token carries
/// none — the coarse RBAC role ([PermissionService.getCoarseRole]). Normalized
/// (`ROLE_ADMIN` → `admin`). Never throws; an unresolvable role yields an empty
/// set (role-restricted transitions are then hidden).
Future<Set<String>> currentStatusTransitionRoles(SupabaseClient supabase) async {
  final meta = supabase.auth.currentUser?.appMetadata['roles'];
  final jwt = meta is List ? meta : const <dynamic>[];
  String? coarse;
  if (jwt.isEmpty && sl.isRegistered<PermissionService>()) {
    try {
      coarse = await sl<PermissionService>().getCoarseRole();
    } catch (_) {/* role unknown → restricted transitions hidden */}
  }
  return StatusTransitionRules.effectiveRoles(jwtRoles: jwt, coarseRole: coarse);
}
