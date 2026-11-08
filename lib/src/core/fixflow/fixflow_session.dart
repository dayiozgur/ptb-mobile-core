import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../permission/permission_service.dart';
import '../tenant/tenant_service.dart';
import '../user/profile_service.dart';

/// FixFlow servislerinin ihtiyaç duyduğu oturum bağlamı — web
/// `TenantContextService.getContext()` (`tenantId/organizationId/userId`)
/// karşılığı. YENİ bir kopya tutmaz: uygulamanın mevcut kaynaklarını okur
/// ([TenantService.currentTenantId], [ProfileService] (org staffs'tan),
/// `auth.currentUser`, [PermissionService.getCoarseRole]).
///
/// Testlerde [FixflowSession.fixed] ile sabit değer verilir.
abstract class FixflowSession {
  const FixflowSession();

  /// Oturumdaki kullanıcının `profiles.id` (= `auth.uid()`).
  String? get userId;

  /// Aktif tenant.
  String? get tenantId;

  /// Kullanıcının organizasyonu (insert'lerde `organization_id`).
  Future<String?> organizationId();

  /// `status-transition` EF'inin rol kontrolüyle aynı rol kümesi:
  /// JWT `app_metadata.roles` + kaba rol (`ROLE_ADMIN` → `admin`), normalize.
  Future<Set<String>> roles();

  factory FixflowSession.fixed({
    String? userId,
    String? tenantId,
    String? organizationId,
    Set<String> roles,
  }) = _FixedSession;
}

/// `ROLE_ADMIN` → `admin` (EF `normalizeRole` ile aynı).
String normalizeFixflowRole(String r) =>
    r.replaceFirst(RegExp(r'^ROLE_', caseSensitive: false), '').toLowerCase();

class _FixedSession extends FixflowSession {
  @override
  final String? userId;
  @override
  final String? tenantId;
  final String? _org;
  final Set<String> _roles;

  const _FixedSession({
    this.userId,
    this.tenantId,
    String? organizationId,
    Set<String> roles = const {},
  })  : _org = organizationId,
        _roles = roles;

  @override
  Future<String?> organizationId() async => _org;

  @override
  Future<Set<String>> roles() async => _roles;
}

/// Uygulamanın mevcut tenant/profil/izin servislerinden okuyan bağlam.
class AppFixflowSession extends FixflowSession {
  final SupabaseClient _supabase;

  const AppFixflowSession(this._supabase);

  @override
  String? get userId => _supabase.auth.currentUser?.id;

  @override
  String? get tenantId => sl.isRegistered<TenantService>()
      ? sl<TenantService>().currentTenantId
      : null;

  @override
  Future<String?> organizationId() async {
    if (!sl.isRegistered<ProfileService>()) return null;
    try {
      return (await sl<ProfileService>().getCurrentProfile())?.organizationId;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Set<String>> roles() async {
    final out = <String>{};
    final meta = _supabase.auth.currentUser?.appMetadata['roles'];
    if (meta is List) {
      for (final r in meta) {
        if (r != null) out.add(normalizeFixflowRole(r.toString()));
      }
    }
    if (sl.isRegistered<PermissionService>()) {
      try {
        final coarse = await sl<PermissionService>().getCoarseRole();
        if (coarse != null && coarse.isNotEmpty) {
          out.add(normalizeFixflowRole(coarse));
        }
      } catch (_) {/* rol çözülemezse yalnız JWT rolleri */}
    }
    return out;
  }
}
