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

  /// Cold-start profil bundle'ı — tek round-trip.
  ///
  /// `fn_my_profile_bundle` RPC'si profil + tenant_name + organization_id +
  /// coarse_role döner. Bounded timeout (~6s) + sınırlı retry (2x); hata/timeout
  /// halinde düz [getProfile]'a düşer (boş ekran yerine).
  Future<UserProfile?> getProfileBundle({bool forceRefresh = false}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      Logger.warning('No authenticated user for getProfileBundle');
      return null;
    }

    final cacheKey = 'profile_bundle_$userId';

    if (!forceRefresh) {
      final cached = await _cacheManager.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        try {
          final profile = UserProfile.fromBundle(cached);
          _profileController.add(profile);
          return profile;
        } catch (cacheError) {
          Logger.warning('Failed to parse profile bundle from cache: $cacheError');
          await _cacheManager.delete(cacheKey);
        }
      }
    }

    const maxAttempts = 3; // ilk deneme + 2 retry
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await _supabase
            .rpc('fn_my_profile_bundle')
            .timeout(const Duration(seconds: 6));

        if (response == null) return getProfile(userId, forceRefresh: forceRefresh);

        // RPC jsonb tek obje döner
        final map = response is Map
            ? Map<String, dynamic>.from(response)
            : (response is List && response.isNotEmpty
                ? Map<String, dynamic>.from(response.first as Map)
                : null);

        if (map == null) return getProfile(userId, forceRefresh: forceRefresh);

        final profile = UserProfile.fromBundle(map);
        await _cacheManager.set(cacheKey, map, ttl: _cacheTtl);
        _profileController.add(profile);
        return profile;
      } catch (e) {
        Logger.warning('getProfileBundle attempt $attempt/$maxAttempts failed: $e');
        if (attempt >= maxAttempts) {
          Logger.error('getProfileBundle exhausted retries, falling back to getProfile');
          try {
            return await getProfile(userId, forceRefresh: forceRefresh);
          } catch (fallbackError) {
            Logger.error('getProfile fallback also failed: $fallbackError');
            return null;
          }
        }
      }
    }
    return null;
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

      // Yalnızca preferred_language GERÇEK bir kolon. preferred_theme /
      // preferred_timezone DROP edildi → yazılırsa 400. `theme`/`timezone`
      // parametreleri geriye-uyumluluk için korunuyor ama DB'ye yazılmıyor
      // (artık uygulama-yerel tercihler: ThemeService / OS timezone).
      if (language != null) data['preferred_language'] = language;

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
  ///
  /// NOT: `notification_preferences` kolonu DROP edildi → DB'ye yazılmaz
  /// (aksi halde 400). Tercihler artık uygulama-yerel taşınır.
  /// TODO(M4): yerel storage (SecureStorage/CacheManager) ile persist et.
  Future<UserProfile> updateNotificationPreferences({
    required String userId,
    required NotificationPreferences prefs,
  }) async {
    Logger.warning(
      'updateNotificationPreferences: notification_preferences kolonu yok; '
      'DB write atlandı (app-local pref).',
    );
    final profile = await getProfile(userId);
    if (profile != null) return profile;
    return UserProfile(id: userId);
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
