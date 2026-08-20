import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../tenant/tenant_model.dart';
import '../utils/logger.dart';
import 'invitation_model.dart';

/// Davet Servisi
///
/// M3 (invite-only) sonrası bu servis **web ile aynı arka uca** bağlanır:
///
/// - **Davet gönderme** artık client-side satır oluşturmaz. `invite-user`
///   Edge Function'ı çağrılır (admin-only, rol-kademe korumalı). EF Supabase
///   Auth `inviteUserByEmail` çalıştırır ve `tenant_users` üzerinde
///   `invitation_token` + `invitation_expires_at` alanlarını doldurur.
/// - **Bekleyen davetler** artık `tenant_users` (status='invited' veya
///   `invitation_token` dolu) satırlarından okunur — e-posta/ad için
///   `profiles` ayrı sorgu ile eşlenir.
/// - **Kabul etme** mobilde deep-link + `AuthService.verifyOtp(OtpType.invite)`
///   akışıyla yapılır (bkz. accept-invite ekranı); bu servisteki eski
///   `acceptInvitation`/`rejectInvitation` yöntemleri artık kullanılmaz.
///
/// NOT: Nonexistent `tenant_invitations` tablosuna yapılan tüm referanslar
/// kaldırılmıştır.
class InvitationService {
  final SupabaseClient _supabase;

  // Table names
  static const String _tenantUsersTable = 'tenant_users';
  static const String _profilesTable = 'profiles';

  /// Sunucu tarafı davet Edge Function'ı (web ile aynı).
  static const String _inviteFunction = 'invite-user';

  InvitationService({
    required SupabaseClient supabase,
  }) : _supabase = supabase;

  // ============================================
  // CREATE INVITATION (invite-user Edge Function)
  // ============================================

  /// Yeni davet gönder.
  ///
  /// Web akışını birebir yansıtır: davet oluşturma **sunucuda** olur; burada
  /// yalnızca `invite-user` Edge Function'ı tetiklenir. EF admin yetkisi ve
  /// rol-kademesini kendisi doğrular.
  ///
  /// Dönüş: EF başarılıysa girdi alanlarından türetilmiş sentetik bir
  /// [Invitation] (tüketiciler yalnızca null-değil kontrolü yapıp listeyi
  /// yeniler); başarısızsa `null`.
  Future<Invitation?> createInvitation({
    required String email,
    required String tenantId,
    required String invitedBy,
    TenantRole role = TenantRole.member,
    String? message,
    int expirationDays = 7,
    String? organizationId,
    String? departmentId,
    String? positionId,
  }) async {
    final normalizedEmail = email.toLowerCase().trim();
    try {
      // Zaten aktif üye mi? (EF de kontrol eder; burada daha net hata veririz)
      final existingMember = await _checkExistingMember(normalizedEmail, tenantId);
      if (existingMember) {
        Logger.warning('User is already a member of this tenant: $normalizedEmail');
        throw InvitationException('Bu kullanıcı zaten tenant üyesi');
      }

      final response = await _supabase.functions.invoke(
        _inviteFunction,
        body: {
          'email': normalizedEmail,
          'role': _dbRoleFromTenantRole(role),
          if (organizationId != null) 'organization_id': organizationId,
          if (departmentId != null) 'department_id': departmentId,
          if (positionId != null) 'position_id': positionId,
        },
      );

      // FunctionResponse: 2xx dışı zaten FunctionException fırlatır.
      if (response.status >= 200 && response.status < 300) {
        Logger.info('invite-user succeeded for: $normalizedEmail (tenant: $tenantId)');
        return _syntheticInvitation(
          email: normalizedEmail,
          tenantId: tenantId,
          invitedBy: invitedBy,
          role: role,
          message: message,
          expirationDays: expirationDays,
          data: response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : null,
        );
      }

      Logger.warning('invite-user returned ${response.status} for: $normalizedEmail');
      return null;
    } on InvitationException {
      rethrow;
    } on FunctionException catch (e) {
      // EF'in döndürdüğü hata gövdesinden anlamlı mesaj çıkar.
      final msg = _messageFromFunctionError(e) ?? 'Davet gönderilemedi';
      Logger.error('invite-user failed for: $normalizedEmail ($msg)');
      throw InvitationException(msg);
    } catch (e) {
      Logger.error('Failed to create invitation', e);
      return null;
    }
  }

  /// Toplu davet gönder (her biri için [createInvitation]).
  Future<List<Invitation>> createBulkInvitations({
    required List<String> emails,
    required String tenantId,
    required String invitedBy,
    TenantRole role = TenantRole.member,
    String? message,
    int expirationDays = 7,
  }) async {
    final results = <Invitation>[];

    for (final email in emails) {
      try {
        final invitation = await createInvitation(
          email: email,
          tenantId: tenantId,
          invitedBy: invitedBy,
          role: role,
          message: message,
          expirationDays: expirationDays,
        );
        if (invitation != null) {
          results.add(invitation);
        }
      } catch (e) {
        Logger.warning('Failed to create invitation for: $email - $e');
      }
    }

    Logger.info('Bulk invitations created: ${results.length}/${emails.length}');
    return results;
  }

  // ============================================
  // RESEND / REVOKE (tenant_users)
  // ============================================

  /// Daveti yeniden gönder.
  ///
  /// Bekleyen `tenant_users` satırından e-posta/rolü çözer ve `invite-user`
  /// Edge Function'ını yeniden tetikler (Supabase davet e-postasını yeniden
  /// yollar). Public imza [MembersScreen] tüketicisiyle uyumlu kalır.
  Future<Invitation?> resendInvitation(String invitationId, String resendBy) async {
    try {
      final row = await _supabase
          .from(_tenantUsersTable)
          .select('id, user_id, tenant_id, role, invitation_token')
          .eq('id', invitationId)
          .maybeSingle();

      if (row == null) {
        throw InvitationException('Davet bulunamadı');
      }

      final userId = row['user_id'] as String?;
      final tenantId = row['tenant_id'] as String? ?? '';
      final dbRole = row['role'] as String?;

      final email = userId != null ? await _emailForUser(userId) : null;
      if (email == null || email.isEmpty) {
        throw InvitationException('Davet için e-posta bulunamadı');
      }

      return await createInvitation(
        email: email,
        tenantId: tenantId,
        invitedBy: resendBy,
        role: _tenantRoleFromDb(dbRole),
      );
    } on InvitationException catch (e) {
      Logger.error('Failed to resend invitation: ${e.message}');
      return null;
    } catch (e) {
      Logger.error('Failed to resend invitation', e);
      return null;
    }
  }

  /// Daveti iptal et (revoke).
  ///
  /// Bekleyen `tenant_users` satırını (davet token'ı dolu olanı) siler.
  /// Yalnızca henüz kabul edilmemiş (token dolu) davetleri etkiler.
  Future<bool> cancelInvitation(String invitationId, String cancelledBy) async {
    try {
      await _supabase
          .from(_tenantUsersTable)
          .delete()
          .eq('id', invitationId)
          .not('invitation_token', 'is', null);

      Logger.info('Invitation revoked: $invitationId (by $cancelledBy)');
      return true;
    } catch (e) {
      Logger.error('Failed to cancel invitation', e);
      return false;
    }
  }

  // ============================================
  // READ OPERATIONS (tenant_users + profiles)
  // ============================================

  /// Tenant'ın bekleyen davetlerini getir.
  ///
  /// `tenant_users` üzerinden `invitation_token` dolu (henüz kabul edilmemiş)
  /// satırları okur; e-posta/ad için `profiles` ayrı sorgu ile eşlenir.
  /// [status] verilirse yalnız [InvitationStatus.pending] anlamlıdır (bekleyen
  /// davetler); farklı bir değer için boş liste döner.
  Future<List<Invitation>> getTenantInvitations(
    String tenantId, {
    InvitationStatus? status,
    int limit = 50,
  }) async {
    if (status != null && status != InvitationStatus.pending) {
      return [];
    }
    try {
      final rows = await _supabase
          .from(_tenantUsersTable)
          .select(
            'id, user_id, tenant_id, role, status, invited_by, '
            'invited_at, invitation_token, invitation_expires_at, created_at',
          )
          .eq('tenant_id', tenantId)
          .not('invitation_token', 'is', null)
          .order('created_at', ascending: false)
          .limit(limit);

      return _mapRowsWithProfiles(List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      Logger.error('Failed to get tenant invitations', e);
      return [];
    }
  }

  /// Token ile davet getir (`tenant_users.invitation_token`).
  Future<Invitation?> getInvitationByToken(String token) async {
    try {
      final row = await _supabase
          .from(_tenantUsersTable)
          .select(
            'id, user_id, tenant_id, role, status, invited_by, '
            'invited_at, invitation_token, invitation_expires_at, created_at',
          )
          .eq('invitation_token', token)
          .maybeSingle();

      if (row == null) return null;
      final mapped = await _mapRowsWithProfiles([Map<String, dynamic>.from(row)]);
      return mapped.isEmpty ? null : mapped.first;
    } catch (e) {
      Logger.error('Failed to get invitation by token', e);
      return null;
    }
  }

  /// ID ile davet getir (`tenant_users.id`).
  Future<Invitation?> getInvitation(String invitationId) async {
    try {
      final row = await _supabase
          .from(_tenantUsersTable)
          .select(
            'id, user_id, tenant_id, role, status, invited_by, '
            'invited_at, invitation_token, invitation_expires_at, created_at',
          )
          .eq('id', invitationId)
          .maybeSingle();

      if (row == null) return null;
      final mapped = await _mapRowsWithProfiles([Map<String, dynamic>.from(row)]);
      return mapped.isEmpty ? null : mapped.first;
    } catch (e) {
      Logger.error('Failed to get invitation', e);
      return null;
    }
  }

  /// Bir e-posta için bekleyen davetleri getir.
  Future<List<Invitation>> getPendingInvitationsForEmail(String email) async {
    try {
      final profile = await _supabase
          .from(_profilesTable)
          .select('id')
          .eq('email', email.toLowerCase().trim())
          .maybeSingle();

      if (profile == null) return [];
      final userId = profile['id'] as String;

      final rows = await _supabase
          .from(_tenantUsersTable)
          .select(
            'id, user_id, tenant_id, role, status, invited_by, '
            'invited_at, invitation_token, invitation_expires_at, created_at',
          )
          .eq('user_id', userId)
          .not('invitation_token', 'is', null)
          .order('created_at', ascending: false);

      return _mapRowsWithProfiles(List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      Logger.error('Failed to get pending invitations for email', e);
      return [];
    }
  }

  // ============================================
  // DEPRECATED (eski tenant_invitations akışı)
  // ============================================

  /// @deprecated Mobil kabul akışı artık deep-link + Supabase Auth
  /// `verifyOtp(OtpType.invite)` ile yapılır (accept-invite ekranı). Bu yöntem
  /// artık hiçbir DB yazması yapmaz.
  @Deprecated('Kabul, deep-link + AuthService.verifyOtp(OtpType.invite) ile yapılır')
  Future<bool> acceptInvitation(String token, String userId) async {
    Logger.warning(
      'InvitationService.acceptInvitation is deprecated — '
      'use the accept-invite deep-link + verifyOtp flow instead.',
    );
    return false;
  }

  /// @deprecated Davet reddi mobil akışta desteklenmez.
  @Deprecated('Davet reddi mobil akışta desteklenmez')
  Future<bool> rejectInvitation(String token, {String? reason}) async {
    Logger.warning('InvitationService.rejectInvitation is deprecated (no-op).');
    return false;
  }

  // ============================================
  // VALIDATION HELPERS
  // ============================================

  /// Email zaten aktif tenant üyesi mi?
  Future<bool> _checkExistingMember(String email, String tenantId) async {
    try {
      final profileResponse = await _supabase
          .from(_profilesTable)
          .select('id')
          .eq('email', email.toLowerCase().trim())
          .maybeSingle();

      if (profileResponse == null) return false;

      final memberResponse = await _supabase
          .from(_tenantUsersTable)
          .select('id')
          .eq('user_id', profileResponse['id'])
          .eq('tenant_id', tenantId)
          .eq('status', 'active')
          .maybeSingle();

      return memberResponse != null;
    } catch (e) {
      return false;
    }
  }

  // ============================================
  // MAPPING HELPERS
  // ============================================

  /// `tenant_users` satırlarını e-posta/ad için `profiles` ile eşleyip
  /// [Invitation] listesine dönüştürür.
  Future<List<Invitation>> _mapRowsWithProfiles(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return [];

    // İlgili user_id'ler için profilleri tek sorguda çek.
    final userIds = rows
        .map((r) => r['user_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    final profilesById = <String, Map<String, dynamic>>{};
    if (userIds.isNotEmpty) {
      try {
        final profiles = await _supabase
            .from(_profilesTable)
            .select('id, email, full_name')
            .inFilter('id', userIds);
        for (final p in List<Map<String, dynamic>>.from(profiles)) {
          profilesById[p['id'] as String] = p;
        }
      } catch (e) {
        Logger.warning('Failed to enrich invitations with profiles', e);
      }
    }

    return rows.map((row) {
      final userId = row['user_id'] as String?;
      final profile = userId != null ? profilesById[userId] : null;
      return _invitationFromTenantUser(row, profile);
    }).toList();
  }

  /// Tek bir `tenant_users` satırını (+opsiyonel profil) [Invitation]'a çevirir.
  Invitation _invitationFromTenantUser(
    Map<String, dynamic> row,
    Map<String, dynamic>? profile,
  ) {
    final createdAt = _parseDate(row['created_at']) ??
        _parseDate(row['invited_at']) ??
        DateTime.now();
    final expiresAt = _parseDate(row['invitation_expires_at']) ??
        createdAt.add(const Duration(days: 7));

    return Invitation(
      id: row['id'] as String,
      email: (profile?['email'] as String?) ?? '',
      tenantId: row['tenant_id'] as String? ?? '',
      role: _tenantRoleFromDb(row['role'] as String?),
      // Bekleyen davetler UI'da "pending" olarak listelenir.
      status: InvitationStatus.pending,
      token: (row['invitation_token'] as String?) ?? '',
      invitedBy: row['invited_by'] as String? ?? '',
      invitedByName: null,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }

  /// EF başarılı olduğunda girdi alanlarından sentetik davet üretir.
  Invitation _syntheticInvitation({
    required String email,
    required String tenantId,
    required String invitedBy,
    required TenantRole role,
    String? message,
    required int expirationDays,
    Map<String, dynamic>? data,
  }) {
    final now = DateTime.now();
    return Invitation(
      id: (data?['id'] as String?) ?? '',
      email: email,
      tenantId: tenantId,
      role: role,
      status: InvitationStatus.pending,
      token: '',
      message: message,
      invitedBy: invitedBy,
      createdAt: now,
      expiresAt: now.add(Duration(days: expirationDays)),
    );
  }

  Future<String?> _emailForUser(String userId) async {
    try {
      final profile = await _supabase
          .from(_profilesTable)
          .select('email')
          .eq('id', userId)
          .maybeSingle();
      return profile?['email'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// TenantRole → `tenant_users.role` (DB CHECK: ROLE_ADMIN|MANAGER|USER|CUSTOMER).
  String _dbRoleFromTenantRole(TenantRole role) {
    switch (role) {
      case TenantRole.owner:
      case TenantRole.admin:
        return 'ROLE_ADMIN';
      case TenantRole.manager:
        return 'ROLE_MANAGER';
      case TenantRole.member:
        return 'ROLE_USER';
      case TenantRole.viewer:
        return 'ROLE_CUSTOMER';
    }
  }

  /// `tenant_users.role` → TenantRole (görüntüleme için).
  TenantRole _tenantRoleFromDb(String? dbRole) {
    switch (dbRole) {
      case 'ROLE_ADMIN':
        return TenantRole.admin;
      case 'ROLE_MANAGER':
        return TenantRole.manager;
      case 'ROLE_CUSTOMER':
        return TenantRole.viewer;
      case 'ROLE_USER':
      default:
        return TenantRole.member;
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  String? _messageFromFunctionError(FunctionException e) {
    final details = e.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    if (details is Map && details['message'] is String) {
      return details['message'] as String;
    }
    if (details is String && details.isNotEmpty) return details;
    return e.reasonPhrase;
  }
}

/// Davet işlemi hatası
class InvitationException implements Exception {
  final String message;
  InvitationException(this.message);

  @override
  String toString() => message;
}
