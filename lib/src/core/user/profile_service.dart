import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../utils/logger.dart';
import 'user_profile.dart';

/// Profile Service
///
/// Kullanici profil bilgilerini yonetir. Profil okuma, guncelleme,
/// avatar ve tercih yonetimi saglar.
class ProfileService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  /// Profil stream
  final _profileController = StreamController<UserProfile?>.broadcast();

  /// Cache TTL
  static const _cacheTtl = Duration(minutes: 10);

  ProfileService({
    required SupabaseClient supabase,
    required CacheManager cacheManager,
  })  : _supabase = supabase,
        _cacheManager = cacheManager;

  // ============================================
  // GETTERS
  // ============================================

  /// Profil stream
  Stream<UserProfile?> get profileStream => _profileController.stream;

  // ============================================
  // PROFILE OPERATIONS
  // ============================================

  /// Mevcut kullanicinin profilini getir
  Future<UserProfile?> getCurrentProfile({bool forceRefresh = false}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      Logger.warning('No authenticated user for getCurrentProfile');
      return null;
    }
    return getProfile(userId, forceRefresh: forceRefresh);
  }

  /// Belirtilen kullanicinin profilini getir
  Future<UserProfile?> getProfile(
    String userId, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'profile_$userId';

    if (!forceRefresh) {
      final cached = await _cacheManager.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        try {
          final profile = UserProfile.fromJson(cached);
          _profileController.add(profile);
          return profile;
        } catch (cacheError) {
          Logger.warning('Failed to parse profile from cache: $cacheError');
          await _cacheManager.delete(cacheKey);
        }
      }
    }

    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;

      final profile = UserProfile.fromJson(response);

      await _cacheManager.set(cacheKey, response, ttl: _cacheTtl);

      _profileController.add(profile);
      return profile;
    } catch (e) {
      Logger.error('Error fetching profile: $e');
      rethrow;
    }
  }

  /// Profil guncelle
  Future<UserProfile> updateProfile(UserProfile profile) async {
    try {
      final response = await _supabase
          .from('profiles')
          .update(profile.toUpdateJson())
          .eq('id', profile.id)
          .select()
          .single();

      final updated = UserProfile.fromJson(response);

      await _cacheManager.set(
        'profile_${profile.id}',
        response,
        ttl: _cacheTtl,
      );

      _profileController.add(updated);

      Logger.info('Updated profile: ${profile.id}');
      return updated;
    } catch (e) {
      Logger.error('Error updating profile: $e');
      rethrow;
    }
  }

  /// Avatar guncelle
  Future<UserProfile> updateAvatar(String userId, String avatarUrl) async {
    try {
      final response = await _supabase
          .from('profiles')
          .update({
            'avatar_url': avatarUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId)
          .select()
          .single();

      final updated = UserProfile.fromJson(response);

      await _cacheManager.set(
        'profile_$userId',
        response,
        ttl: _cacheTtl,
      );

      _profileController.add(updated);

      Logger.info('Updated avatar for user: $userId');
      return updated;
    } catch (e) {
      Logger.error('Error updating avatar: $e');
      rethrow;
    }
  }

  /// Tercih guncelle
  Future<UserProfile> updatePreferences({
    required String userId,
    String? language,
    String? theme,
    String? timezone,
  }) async {
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (language != null) data['preferred_language'] = language;
      if (theme != null) data['preferred_theme'] = theme;
      if (timezone != null) data['preferred_timezone'] = timezone;

      final response = await _supabase
          .from('profiles')
          .update(data)
          .eq('id', userId)
          .select()
          .single();

      final updated = UserProfile.fromJson(response);

      await _cacheManager.set(
        'profile_$userId',
        response,
        ttl: _cacheTtl,
      );

      _profileController.add(updated);

      Logger.info('Updated preferences for user: $userId');
      return updated;
    } catch (e) {
      Logger.error('Error updating preferences: $e');
      rethrow;
    }
  }

  /// Bildirim tercihlerini guncelle
  Future<UserProfile> updateNotificationPreferences({
    required String userId,
    required NotificationPreferences prefs,
  }) async {
    try {
      final response = await _supabase
          .from('profiles')
          .update({
            'notification_preferences': prefs.toJson(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId)
          .select()
          .single();

      final updated = UserProfile.fromJson(response);

      await _cacheManager.set(
        'profile_$userId',
        response,
        ttl: _cacheTtl,
      );

      _profileController.add(updated);

      Logger.info('Updated notification preferences for user: $userId');
      return updated;
    } catch (e) {
      Logger.error('Error updating notification preferences: $e');
      rethrow;
    }
  }

  /// Cache temizle
  Future<void> invalidateCache(String userId) async {
    await _cacheManager.delete('profile_$userId');
  }

  /// Temizle
  void dispose() {
    _profileController.close();
  }
}
