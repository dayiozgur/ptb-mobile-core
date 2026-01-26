import 'dart:async';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../tenant/tenant_model.dart';
import '../utils/logger.dart';
import 'invitation_model.dart';

/// Davet Servisi
///
/// Kullanıcı davet işlemlerini yönetir.
/// Email ile davet gönderme, kabul/red işlemleri.
///
/// Örnek kullanım:
/// ```dart
/// final invitationService = InvitationService(
///   supabase: Supabase.instance.client,
/// );
///
/// // Davet gönder
/// final invitation = await invitationService.createInvitation(
///   email: 'user@example.com',
///   tenantId: 'tenant-id',
///   role: TenantRole.member,
///   invitedBy: 'current-user-id',
/// );
///
/// // Daveti kabul et
/// await invitationService.acceptInvitation(token);
/// ```
class InvitationService {
  final SupabaseClient _supabase;

  // Table names
  static const String _invitationsTable = 'tenant_invitations';
  static const String _tenantUsersTable = 'tenant_users';

  InvitationService({
    required SupabaseClient supabase,
  }) : _supabase = supabase;

  // ============================================
  // CREATE INVITATION
  // ============================================

  /// Yeni davet oluştur
  Future<Invitation?> createInvitation({
    required String email,
    required String tenantId,
    required String invitedBy,
    TenantRole role = TenantRole.member,
    String? message,
    int expirationDays = 7,
  }) async {
    try {
      // Email zaten bu tenant'ta mı kontrol et
      final existingMember = await _checkExistingMember(email, tenantId);
      if (existingMember) {
        Logger.warning('User is already a member of this tenant: $email');
        throw InvitationException('Bu kullanıcı zaten tenant üyesi');
      }

      // Bekleyen davet var mı kontrol et
      final existingInvitation = await _checkExistingInvitation(email, tenantId);
      if (existingInvitation != null) {
        Logger.warning('Pending invitation already exists for: $email');
        throw InvitationException('Bu email için zaten bekleyen bir davet var');
      }

      // Token oluştur
      final token = _generateToken();
      final now = DateTime.now();
      final expiresAt = now.add(Duration(days: expirationDays));

      final data = {
        'email': email.toLowerCase().trim(),
        'tenant_id': tenantId,
        'role': role.value,
        'status': InvitationStatus.pending.value,
        'token': token,
        'message': message,
        'invited_by': invitedBy,
        'created_at': now.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
      };

      final response = await _supabase
          .from(_invitationsTable)
          .insert(data)
          .select('*, tenant:tenants(name), inviter:profiles!invited_by(full_name)')
          .single();

      final invitation = Invitation.fromJson(response);

      Logger.info('Invitation created for: $email to tenant: $tenantId');

      // TODO: Email gönderme işlemi (Edge Function veya harici servis)
      // await _sendInvitationEmail(invitation);

      return invitation;
    } on InvitationException {
      rethrow;
    } catch (e) {
      Logger.error('Failed to create invitation', e);
      return null;
    }
  }

  /// Toplu davet oluştur
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
  // ACCEPT/REJECT INVITATION
  // ============================================

  /// Daveti kabul et
  Future<bool> acceptInvitation(String token, String userId) async {
    try {
      // Daveti getir
      final invitation = await getInvitationByToken(token);
      if (invitation == null) {
        throw InvitationException('Davet bulunamadı');
      }

      // Geçerlilik kontrol
      if (!invitation.isValid) {
        if (invitation.isExpired) {
          await _updateInvitationStatus(invitation.id, InvitationStatus.expired);
          throw InvitationException('Davet süresi dolmuş');
        }
        throw InvitationException('Davet geçersiz: ${invitation.status.displayName}');
      }

      // Kullanıcıyı tenant'a ekle
      await _supabase.from(_tenantUsersTable).insert({
        'user_id': userId,
        'tenant_id': invitation.tenantId,
        'role': invitation.role.value,
        'status': TenantMemberStatus.active.value,
        'is_default': false,
        'invited_by': invitation.invitedBy,
        'invited_at': invitation.createdAt.toIso8601String(),
        'joined_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

      // Davet durumunu güncelle
      await _supabase.from(_invitationsTable).update({
        'status': InvitationStatus.accepted.value,
        'responded_at': DateTime.now().toIso8601String(),
        'accepted_user_id': userId,
      }).eq('id', invitation.id);

      Logger.info('Invitation accepted: ${invitation.email} joined tenant: ${invitation.tenantId}');
      return true;
    } on InvitationException {
      rethrow;
    } catch (e) {
      Logger.error('Failed to accept invitation', e);
      return false;
    }
  }

  /// Daveti reddet
  Future<bool> rejectInvitation(String token, {String? reason}) async {
    try {
      final invitation = await getInvitationByToken(token);
      if (invitation == null) {
        throw InvitationException('Davet bulunamadı');
      }

      if (!invitation.isValid) {
        throw InvitationException('Davet geçersiz');
      }

      await _supabase.from(_invitationsTable).update({
        'status': InvitationStatus.rejected.value,
        'responded_at': DateTime.now().toIso8601String(),
        'metadata': reason != null ? {'rejection_reason': reason} : null,
      }).eq('id', invitation.id);

      Logger.info('Invitation rejected: ${invitation.email}');
      return true;
    } on InvitationException {
      rethrow;
    } catch (e) {
      Logger.error('Failed to reject invitation', e);
      return false;
    }
  }

  /// Daveti iptal et (davet eden tarafından)
  Future<bool> cancelInvitation(String invitationId, String cancelledBy) async {
    try {
      await _supabase.from(_invitationsTable).update({
        'status': InvitationStatus.cancelled.value,
        'responded_at': DateTime.now().toIso8601String(),
        'metadata': {'cancelled_by': cancelledBy},
      }).eq('id', invitationId);

      Logger.info('Invitation cancelled: $invitationId');
      return true;
    } catch (e) {
      Logger.error('Failed to cancel invitation', e);
      return false;
    }
  }

  /// Daveti yeniden gönder
  Future<Invitation?> resendInvitation(String invitationId, String resendBy) async {
    try {
      // Eski daveti getir
      final oldInvitation = await getInvitation(invitationId);
      if (oldInvitation == null) {
        throw InvitationException('Davet bulunamadı');
      }

      // Eski daveti iptal et
      await cancelInvitation(invitationId, resendBy);

      // Yeni davet oluştur
      return await createInvitation(
        email: oldInvitation.email,
        tenantId: oldInvitation.tenantId,
        invitedBy: resendBy,
        role: oldInvitation.role,
        message: oldInvitation.message,
      );
    } catch (e) {
      Logger.error('Failed to resend invitation', e);
      return null;
    }
  }

  // ============================================
  // READ OPERATIONS
  // ============================================

  /// Token ile davet getir
  Future<Invitation?> getInvitationByToken(String token) async {
    try {
      final response = await _supabase
          .from(_invitationsTable)
          .select('*, tenant:tenants(name), inviter:profiles!invited_by(full_name)')
          .eq('token', token)
          .maybeSingle();

      if (response == null) return null;
      return Invitation.fromJson(response);
    } catch (e) {
      Logger.error('Failed to get invitation by token', e);
      return null;
    }
  }

  /// ID ile davet getir
  Future<Invitation?> getInvitation(String invitationId) async {
    try {
      final response = await _supabase
          .from(_invitationsTable)
          .select('*, tenant:tenants(name), inviter:profiles!invited_by(full_name)')
          .eq('id', invitationId)
          .maybeSingle();

      if (response == null) return null;
      return Invitation.fromJson(response);
    } catch (e) {
      Logger.error('Failed to get invitation', e);
      return null;
    }
  }

  /// Tenant'ın davetlerini getir
  Future<List<Invitation>> getTenantInvitations(
    String tenantId, {
    InvitationStatus? status,
    int limit = 50,
  }) async {
    try {
      var query = _supabase
          .from(_invitationsTable)
          .select('*, tenant:tenants(name), inviter:profiles!invited_by(full_name)')
          .eq('tenant_id', tenantId);

      if (status != null) {
        query = query.eq('status', status.value);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      return response
          .map<Invitation>((json) => Invitation.fromJson(json))
          .toList();
    } catch (e) {
      Logger.error('Failed to get tenant invitations', e);
      return [];
    }
  }

  /// Kullanıcının bekleyen davetlerini getir (email ile)
  Future<List<Invitation>> getPendingInvitationsForEmail(String email) async {
    try {
      final response = await _supabase
          .from(_invitationsTable)
          .select('*, tenant:tenants(name), inviter:profiles!invited_by(full_name)')
          .eq('email', email.toLowerCase().trim())
          .eq('status', InvitationStatus.pending.value)
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      return response
          .map<Invitation>((json) => Invitation.fromJson(json))
          .toList();
    } catch (e) {
      Logger.error('Failed to get pending invitations for email', e);
      return [];
    }
  }

  // ============================================
  // VALIDATION HELPERS
  // ============================================

  /// Email zaten tenant üyesi mi?
  Future<bool> _checkExistingMember(String email, String tenantId) async {
    try {
      // Önce profile'ı bul
      final profileResponse = await _supabase
          .from('profiles')
          .select('id')
          .eq('email', email.toLowerCase().trim())
          .maybeSingle();

      if (profileResponse == null) return false;

      // tenant_users'da kontrol et
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

  /// Bekleyen davet var mı?
  Future<Invitation?> _checkExistingInvitation(String email, String tenantId) async {
    try {
      final response = await _supabase
          .from(_invitationsTable)
          .select()
          .eq('email', email.toLowerCase().trim())
          .eq('tenant_id', tenantId)
          .eq('status', InvitationStatus.pending.value)
          .gt('expires_at', DateTime.now().toIso8601String())
          .maybeSingle();

      if (response == null) return null;
      return Invitation.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Davet durumunu güncelle
  Future<void> _updateInvitationStatus(
    String invitationId,
    InvitationStatus status,
  ) async {
    await _supabase.from(_invitationsTable).update({
      'status': status.value,
    }).eq('id', invitationId);
  }

  /// Benzersiz token oluştur
  String _generateToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }

  // ============================================
  // CLEANUP
  // ============================================

  /// Süresi dolmuş davetleri temizle
  Future<int> cleanupExpiredInvitations() async {
    try {
      final response = await _supabase
          .from(_invitationsTable)
          .update({'status': InvitationStatus.expired.value})
          .eq('status', InvitationStatus.pending.value)
          .lt('expires_at', DateTime.now().toIso8601String())
          .select();

      final count = response.length;
      if (count > 0) {
        Logger.info('Cleaned up $count expired invitations');
      }
      return count;
    } catch (e) {
      Logger.error('Failed to cleanup expired invitations', e);
      return 0;
    }
  }
}

/// Davet işlemi hatası
class InvitationException implements Exception {
  final String message;
  InvitationException(this.message);

  @override
  String toString() => message;
}
