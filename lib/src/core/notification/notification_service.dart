import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../utils/logger.dart';
import 'notification_model.dart';

/// Bildirim servisi (mevcut notifications tablosuna uygun)
///
/// Uygulama içi bildirimleri yönetir.
/// Supabase realtime ile anlık bildirim desteği sağlar.
class NotificationService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  static const String _tableName = 'notifications';
  static const String _cacheKey = 'notifications';
  static const Duration _cacheDuration = Duration(minutes: 5);

  // State
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  RealtimeChannel? _realtimeChannel;

  // Stream controllers
  final _notificationsController =
      StreamController<List<AppNotification>>.broadcast();
  final _unreadCountController = StreamController<int>.broadcast();
  final _newNotificationController = StreamController<AppNotification>.broadcast();

  NotificationService({
    required SupabaseClient supabase,
    required CacheManager cacheManager,
  })  : _supabase = supabase,
        _cacheManager = cacheManager;

  // ============================================
  // GETTERS
  // ============================================

  /// Bildirim listesi
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  /// Okunmamış bildirim sayısı
  int get unreadCount => _unreadCount;

  /// Okunmamış bildirim var mı?
  bool get hasUnread => _unreadCount > 0;

  /// Bildirim listesi stream'i
  Stream<List<AppNotification>> get notificationsStream =>
      _notificationsController.stream;

  /// Okunmamış sayısı stream'i
  Stream<int> get unreadCountStream => _unreadCountController.stream;

  /// Yeni bildirim stream'i
  Stream<AppNotification> get newNotificationStream =>
      _newNotificationController.stream;

  // ============================================
  // READ OPERATIONS
  // ============================================

  /// Kullanıcının bildirimlerini getir (profile_id ile)
  Future<List<AppNotification>> getNotifications(
    String profileId, {
    int limit = 50,
    int offset = 0,
    bool unreadOnly = false,
    NotificationType? type,
    bool forceRefresh = false,
  }) async {
    try {
      final cacheKey = '${_cacheKey}_${profileId}_${limit}_$offset';

      // Cache kontrolü
      if (!forceRefresh && !unreadOnly && type == null) {
        final cached = _cacheManager.getList<AppNotification>(
          cacheKey,
          (json) => AppNotification.fromJson(json),
        );
        if (cached != null && cached.isNotEmpty) {
          _notifications = cached;
          _notificationsController.add(_notifications);
          return cached;
        }
      }

      var query = _supabase
          .from(_tableName)
          .select('''
            *,
            profile:profile_id(id, full_name, avatar_url)
          ''')
          .eq('profile_id', profileId)
          .eq('active', true);

      if (unreadOnly) {
        query = query.eq('read', false);
      }

      if (type != null) {
        query = query.eq('notification_type', type.value);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final notifications = (response as List)
          .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
          .toList();

      // Cache'e kaydet
      if (!unreadOnly && type == null) {
        _cacheManager.setList(
          cacheKey,
          notifications,
          (item) => item.toJson(),
          ttl: _cacheDuration,
        );
      }

      _notifications = notifications;
      _notificationsController.add(_notifications);

      return notifications;
    } catch (e) {
      Logger.error('Failed to get notifications', e);
      return [];
    }
  }

  /// Okunmamış bildirim sayısını getir
  Future<int> getUnreadCount(String profileId) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('id')
          .eq('profile_id', profileId)
          .eq('active', true)
          .eq('read', false);

      _unreadCount = (response as List).length;
      _unreadCountController.add(_unreadCount);
      return _unreadCount;
    } catch (e) {
      Logger.error('Failed to get unread count', e);
      return 0;
    }
  }

  /// Bildirim özetini getir
  Future<NotificationSummary> getSummary(String profileId) async {
    try {
      final allResponse = await _supabase
          .from(_tableName)
          .select('id, notification_type, read, acknowledged')
          .eq('profile_id', profileId)
          .eq('active', true);

      final notifications = allResponse as List;
      final total = notifications.length;
      final unread = notifications.where((n) => n['read'] == false).length;
      final unacknowledged =
          notifications.where((n) => n['acknowledged'] == false).length;

      final byType = <NotificationType, int>{};
      for (final n in notifications) {
        final type = NotificationType.fromString(n['notification_type'] as String?);
        if (type != null) {
          byType[type] = (byType[type] ?? 0) + 1;
        }
      }

      return NotificationSummary(
        total: total,
        unread: unread,
        unacknowledged: unacknowledged,
        byType: byType,
      );
    } catch (e) {
      Logger.error('Failed to get notification summary', e);
      return NotificationSummary.empty();
    }
  }

  /// Tek bildirim getir
  Future<AppNotification?> getNotification(String notificationId) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('''
            *,
            profile:profile_id(id, full_name, avatar_url)
          ''')
          .eq('id', notificationId)
          .maybeSingle();

      if (response == null) return null;
      return AppNotification.fromJson(response);
    } catch (e) {
      Logger.error('Failed to get notification: $notificationId', e);
      return null;
    }
  }

  // ============================================
  // WRITE OPERATIONS
  // ============================================

  /// Bildirim oluştur
  Future<AppNotification?> createNotification({
    required String profileId,
    required String title,
    String? description,
    NotificationType type = NotificationType.info,
    int priority = 5,
    String? platformId,
    NotificationEntityType? entityType,
    String? entityId,
    String? meta,
    String? createdBy,
  }) async {
    try {
      final insertData = {
        'profile_id': profileId,
        'title': title,
        'description': description,
        'notification_type': type.value,
        'priority': priority,
        'platform_id': platformId,
        'entity_type': entityType?.value,
        'entity_id': entityId,
        'meta': meta,
        'active': true,
        'read': false,
        'sent': false,
        'acknowledged': false,
        'date_time': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'created_by': createdBy,
      };

      final response = await _supabase
          .from(_tableName)
          .insert(insertData)
          .select('''
            *,
            profile:profile_id(id, full_name, avatar_url)
          ''')
          .single();

      final notification = AppNotification.fromJson(response);

      // Cache'i temizle
      _invalidateCache(profileId);

      Logger.info('Notification created: ${notification.title}');
      return notification;
    } catch (e) {
      Logger.error('Failed to create notification', e);
      return null;
    }
  }

  /// Bildirimi okundu olarak işaretle
  Future<bool> markAsRead(String notificationId) async {
    try {
      await _supabase.from(_tableName).update({
        'read': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', notificationId);

      // Local state güncelle
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        _notificationsController.add(_notifications);
      }

      _unreadCount = (_unreadCount > 0) ? _unreadCount - 1 : 0;
      _unreadCountController.add(_unreadCount);

      Logger.debug('Notification marked as read: $notificationId');
      return true;
    } catch (e) {
      Logger.error('Failed to mark notification as read', e);
      return false;
    }
  }

  /// Tüm bildirimleri okundu olarak işaretle
  Future<bool> markAllAsRead(String profileId) async {
    try {
      await _supabase.from(_tableName).update({
        'read': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('profile_id', profileId).eq('read', false);

      // Local state güncelle
      _notifications = _notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();
      _notificationsController.add(_notifications);

      _unreadCount = 0;
      _unreadCountController.add(_unreadCount);

      // Cache'i temizle
      _invalidateCache(profileId);

      Logger.info('All notifications marked as read for profile: $profileId');
      return true;
    } catch (e) {
      Logger.error('Failed to mark all notifications as read', e);
      return false;
    }
  }

  /// Bildirimi onayla (acknowledge)
  Future<bool> acknowledgeNotification(
    String notificationId,
    String acknowledgedBy,
  ) async {
    try {
      await _supabase.from(_tableName).update({
        'acknowledged': true,
        'acknowledged_at': DateTime.now().toIso8601String(),
        'acknowledged_by': acknowledgedBy,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', notificationId);

      // Local state güncelle
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(
          acknowledged: true,
          acknowledgedAt: DateTime.now(),
          acknowledgedBy: acknowledgedBy,
        );
        _notificationsController.add(_notifications);
      }

      Logger.debug('Notification acknowledged: $notificationId');
      return true;
    } catch (e) {
      Logger.error('Failed to acknowledge notification', e);
      return false;
    }
  }

  /// Bildirim sil (soft delete)
  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _supabase.from(_tableName).update({
        'active': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', notificationId);

      // Local state güncelle
      final notification = _notifications.firstWhere(
        (n) => n.id == notificationId,
        orElse: () => throw Exception('Not found'),
      );

      _notifications.removeWhere((n) => n.id == notificationId);
      _notificationsController.add(_notifications);

      if (!notification.isRead) {
        _unreadCount = (_unreadCount > 0) ? _unreadCount - 1 : 0;
        _unreadCountController.add(_unreadCount);
      }

      Logger.debug('Notification deleted: $notificationId');
      return true;
    } catch (e) {
      Logger.error('Failed to delete notification', e);
      return false;
    }
  }

  /// Tüm bildirimleri sil (soft delete)
  Future<bool> deleteAllNotifications(String profileId) async {
    try {
      await _supabase.from(_tableName).update({
        'active': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('profile_id', profileId);

      _notifications = [];
      _notificationsController.add(_notifications);

      _unreadCount = 0;
      _unreadCountController.add(_unreadCount);

      // Cache'i temizle
      _invalidateCache(profileId);

      Logger.info('All notifications deleted for profile: $profileId');
      return true;
    } catch (e) {
      Logger.error('Failed to delete all notifications', e);
      return false;
    }
  }

  // ============================================
  // REALTIME
  // ============================================

  /// Realtime bildirim dinlemeyi başlat
  void startListening(String profileId) {
    _realtimeChannel?.unsubscribe();

    _realtimeChannel = _supabase
        .channel('notifications_$profileId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: _tableName,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'profile_id',
            value: profileId,
          ),
          callback: (payload) {
            Logger.debug('New notification received');
            _handleNewNotification(payload.newRecord);
          },
        )
        .subscribe();

    Logger.info('Started listening for notifications: $profileId');
  }

  /// Realtime dinlemeyi durdur
  void stopListening() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    Logger.debug('Stopped listening for notifications');
  }

  void _handleNewNotification(Map<String, dynamic> data) {
    try {
      final notification = AppNotification.fromJson(data);

      // Liste başına ekle
      _notifications.insert(0, notification);
      _notificationsController.add(_notifications);

      // Okunmamış sayısını artır
      if (!notification.isRead) {
        _unreadCount++;
        _unreadCountController.add(_unreadCount);
      }

      // Yeni bildirim event'i
      _newNotificationController.add(notification);

      Logger.debug('New notification processed: ${notification.title}');
    } catch (e) {
      Logger.error('Failed to handle new notification', e);
    }
  }

  // ============================================
  // HELPERS
  // ============================================

  /// Cache'i temizle
  void _invalidateCache(String profileId) {
    _cacheManager.delete('${_cacheKey}_$profileId');
  }

  /// Tüm cache'i temizle
  void clearCache() {
    _cacheManager.delete(_cacheKey);
  }

  /// State'i temizle
  void clearState() {
    _notifications = [];
    _unreadCount = 0;
    _notificationsController.add(_notifications);
    _unreadCountController.add(_unreadCount);
  }

  /// Servisi kapat
  void dispose() {
    stopListening();
    _notificationsController.close();
    _unreadCountController.close();
    _newNotificationController.close();
    Logger.debug('NotificationService disposed');
  }
}
