import 'package:supabase_flutter/supabase_flutter.dart';

import '../user/user_profile.dart';
import '../utils/logger.dart';

/// Admin kullanıcı yönetimi servisi.
///
/// Web portal `UserManagementService` + `PtbRbacService` okuma-yolunu birebir
/// yansıtır: `profiles` tablosunu listeler, ardından her satırın **coarse
/// rolünü** RBAC'tan (`fn_coarse_roles_of` batch RPC) türetir — böylece
/// legacy `profiles.role` kolonu drop edilse bile rozetler doğru kalır.
///
/// Tenant kapsamı **RLS/JWT** ile uygulanır; sorguya tenant parametresi
/// GEÇİLMEZ (kullanıcı yalnız kendi tenant'ının profillerini görür).
///
/// NOT: Rol atama (yazma) MOBİLDE UYGULANMAZ. Web'de rol atama tek bir RPC
/// değil, `rbac_user_roles` tablosuna çok-adımlı upsert (role_id + org-scope +
/// primary temizleme) ile yapılır; mobilde salt-okunur tutulur.
class AdminUserService {
  final SupabaseClient _supabase;

  static const String _table = 'profiles';

  AdminUserService({required SupabaseClient supabase}) : _supabase = supabase;

  /// Tenant'ın kullanıcılarını listeler (RLS-scoped).
  ///
  /// 1. `profiles`'ı çeker (RLS = kendi tenant'ı), created_at DESC.
  /// 2. `fn_coarse_roles_of` batch RPC ile her profilin coarse rolünü çözer
  ///    ve `coarseRole` alanına yazar (web `enrichRolesFromRbac` ile aynı).
  ///
  /// [search] verilirse ad/email/username üzerinde ilike filtreler (PostgREST
  /// metakarakterleri temizlenir — enjeksiyon guard'ı web ile aynı).
  Future<List<UserProfile>> listUsers({String? search}) async {
    try {
      var query = _supabase.from(_table).select('*');

      final s = (search ?? '').replaceAll(RegExp(r'[%,()"\\]'), ' ').trim();
      if (s.isNotEmpty) {
        final term = '%$s%';
        query = query.or(
          'full_name.ilike.$term,email.ilike.$term,username.ilike.$term',
        );
      }

      final rows = await query.order('created_at', ascending: false);

      final users = (rows as List)
          .map((r) => UserProfile.fromJson(r as Map<String, dynamic>))
          .toList();

      return _enrichCoarseRoles(users);
    } catch (e, st) {
      Logger.error('AdminUserService.listUsers failed', e, st);
      rethrow;
    }
  }

  /// Her profilin coarse rolünü RBAC'tan türet (batch, tek RPC).
  ///
  /// `fn_coarse_roles_of(uuid[]) -> (profile_id, role)`. Hata/eksik satırda
  /// mevcut `coarseRole` fallback olarak korunur (web davranışı ile aynı).
  Future<List<UserProfile>> _enrichCoarseRoles(List<UserProfile> users) async {
    final ids = users.map((u) => u.id).where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return users;

    try {
      final data = await _supabase.rpc(
        'fn_coarse_roles_of',
        params: {'p_ids': ids},
      );

      final roleById = <String, String>{};
      for (final row in (data as List)) {
        final m = row as Map<String, dynamic>;
        final pid = m['profile_id'] as String?;
        final role = m['role'] as String?;
        if (pid != null && role != null) roleById[pid] = role;
      }

      return users
          .map((u) => u.copyWith(coarseRole: roleById[u.id] ?? u.coarseRole))
          .toList();
    } catch (e) {
      // RPC başarısızsa mevcut coarseRole fallback'te kalır.
      Logger.warning('AdminUserService coarse-role enrich skipped: $e');
      return users;
    }
  }
}
