import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../utils/logger.dart';
import 'activity_model.dart';

/// Aktivite servisi
///
/// Audit log yönetimi ve aktivite takibi için servis.
class ActivityService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  static const String _tableName = 'audit_logs';
  static const String _cacheKey = 'activities';
  static const Duration _cacheDuration = Duration(minutes: 5);

  ActivityService({
    required SupabaseClient supabase,
    required CacheManager cacheManager,
  })  : _supabase = supabase,
        _cacheManager = cacheManager;

  /// Tenant'ın son aktivitelerini getir
  Future<List<ActivityLog>> getRecentActivities(
    String tenantId, {
    int limit = 10,
    int offset = 0,
    EntityType? entityType,
    ActivityAction? action,
    bool useCache = true,
  }) async {
    final cacheKey = '${_cacheKey}_${tenantId}_${limit}_$offset';

    // Cache kontrolü
    if (useCache) {
      final cached = _cacheManager.getList<ActivityLog>(
        cacheKey,
        (json) => ActivityLog.fromJson(json),
      );
      if (cached != null) {
        return cached;
      }
    }

    try {
      var query = _supabase
          .from(_tableName)
          .select('''
            *,
            profiles:created_by(full_name, avatar_url)
          ''')
          .eq('tenant_id', tenantId);

      if (entityType != null) {
        query = query.eq('entity_type', entityType.value);
      }

      if (action != null) {
        query = query.eq('action', action.value);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      final activities = (response as List)
          .map((json) => ActivityLog.fromJson(json as Map<String, dynamic>))
          .toList();

      // Cache'e kaydet
      _cacheManager.setList(
        cacheKey,
        activities,
        (item) => item.toJson(),
        ttl: _cacheDuration,
      );

      return activities;
    } catch (e) {
      Logger.error('Failed to get recent activities', e);
      return [];
    }
  }

  /// Kullanıcının aktivitelerini getir
  Future<List<ActivityLog>> getUserActivities(
    String userId, {
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => ActivityLog.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('Failed to get user activities', e);
      return [];
    }
  }

  /// Entity'nin aktivitelerini getir
  Future<List<ActivityLog>> getEntityActivities(
    String entityId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('''
            *,
            profiles:created_by(full_name, avatar_url)
          ''')
          .eq('entity_id', entityId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => ActivityLog.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('Failed to get entity activities', e);
      return [];
    }
  }

  /// Aktivite logla
  Future<ActivityLog?> logActivity({
    required String tenantId,
    required String userId,
    required EntityType entityType,
    required String entityId,
    required ActivityAction action,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    String? entityName,
  }) async {
    try {
      final data = {
        'tenant_id': tenantId,
        'user_id': userId,
        'entity_type': entityType.value,
        'entity_id': entityId,
        'action': action.value,
        'old_values': oldValues,
        'new_values': newValues,
        'created_by': userId,
      };

      final response = await _supabase
          .from(_tableName)
          .insert(data)
          .select()
          .single();

      // Cache'i temizle
      _invalidateCache(tenantId);

      return ActivityLog.fromJson(response);
    } catch (e) {
      Logger.error('Failed to log activity', e);
      return null;
    }
  }

  /// Login aktivitesi logla
  Future<void> logLogin(String userId, String? tenantId) async {
    if (tenantId == null) return;

    await logActivity(
      tenantId: tenantId,
      userId: userId,
      entityType: EntityType.user,
      entityId: userId,
      action: ActivityAction.login,
    );
  }

  /// Logout aktivitesi logla
  Future<void> logLogout(String userId, String? tenantId) async {
    if (tenantId == null) return;

    await logActivity(
      tenantId: tenantId,
      userId: userId,
      entityType: EntityType.user,
      entityId: userId,
      action: ActivityAction.logout,
    );
  }

  /// Aktivite sayısını getir
  Future<int> getActivityCount(
    String tenantId, {
    EntityType? entityType,
    ActivityAction? action,
    DateTime? since,
  }) async {
    try {
      var query = _supabase
          .from(_tableName)
          .select('id')
          .eq('tenant_id', tenantId);

      if (entityType != null) {
        query = query.eq('entity_type', entityType.value);
      }

      if (action != null) {
        query = query.eq('action', action.value);
      }

      if (since != null) {
        query = query.gte('created_at', since.toIso8601String());
      }

      final response = await query;
      return (response as List).length;
    } catch (e) {
      Logger.error('Failed to get activity count', e);
      return 0;
    }
  }

  /// Cache'i temizle
  void _invalidateCache(String tenantId) {
    // Tenant'a ait tüm cache'leri temizle
    _cacheManager.delete('${_cacheKey}_$tenantId');
  }

  /// Tüm cache'i temizle
  void clearCache() {
    _cacheManager.delete(_cacheKey);
  }
}
