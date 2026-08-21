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
        final cached = await _cacheManager.getList<AppNotification>(
          key: cacheKey,
          fromJson: (json) => AppNotification.fromJson(json),
        );
        if (cached != null && cached.isNotEmpty) {
          _notifications = cached;
          _notificationsController.add(_notifications);
          return cached;
        }
      }

      // KANONİK alıcı = `recipient_id` (web `notification.service.ts` ile
      // birebir); eski `profile_id` yalnız ~34 legacy satırda dolu → onu
      // sorgulamak çoğu kullanıcıda bildirimleri GİZLİYORDU (drift). Gönderen
      // bilgisi `sender_id` FK'siyle embed edilir (model bunu `profile` olarak
      // okur).
      var query = _supabase
          .from(_tableName)
          .select('''
            *,
            profile:profiles!notifications_sender_id_fkey(id, full_name, avatar_url)
          ''')
          .eq('recipient_id', profileId)
          // `active` çoğu satırda NULL (varsayılan, hedeflenmemiş değil) —
          // yalnız AÇIKÇA false olanı (mobil soft-delete) gizle. `.eq(active,
          // true)` NULL'ları da eleyip gerçek bildirimleri gizliyordu.
          .or('active.is.null,active.eq.true');

      if (unreadOnly) {
        query = query.eq('is_read', false);
      }

      if (type != null) {
        query = query.eq('notification_type', type.value);
      }

      final response = await query
          .order('priority', ascending: false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final notifications = (response as List)
          .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
          .toList();

      // Cache'e kaydet
      if (!unreadOnly && type == null) {
        await _cacheManager.setList(
          key: cacheKey,
          value: notifications,
          toJson: (item) => item.toJson(),
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
          .eq('recipient_id', profileId)
          .or('active.is.null,active.eq.true')
          .eq('is_read', false);

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
          .select('id, notification_type, is_read, acknowledged')
          .eq('recipient_id', profileId)
          .or('active.is.null,active.eq.true');

      final notifications = allResponse as List;
      final total = notifications.length;
      final unread = notifications.where((n) => n['is_read'] == false).length;
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
        // Kanonik alıcı = recipient_id (+ legacy profile_id geriye-uyum için).
        'recipient_id': profileId,
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
        'is_read': false,
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
        'is_read': true,
        'read_at': DateTime.now().toIso8601String(),
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
        'is_read': true,
        'read_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('recipient_id', profileId).eq('is_read', false);

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
      }).eq('recipient_id', profileId);

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
  Future<void> startListening(String profileId) async {
    // Önceki kanalı tam olarak kapat (unsubscribe + removeChannel).
    // Sadece unsubscribe() çağırmak kanal referansını client içinde bırakır
    // (realtime_service.dart:326-327 ile aynı doğru teardown deseni).
    await _teardownChannel();

    _realtimeChannel = _supabase
        .channel('notifications_$profileId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: _tableName,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
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
  Future<void> stopListening() async {
    await _teardownChannel();
    Logger.debug('Stopped listening for notifications');
  }

  /// Realtime kanalını tam olarak kapat: unsubscribe + removeChannel.
  /// removeChannel olmadan sadece unsubscribe çağırmak kanalı client'ın
  /// dahili listesinde bırakır ve sızıntıya yol açar.
  Future<void> _teardownChannel() async {
    final channel = _realtimeChannel;
    if (channel == null) return;
    _realtimeChannel = null;
    try {
      await channel.unsubscribe();
      await _supabase.removeChannel(channel);
    } catch (e) {
      Logger.warning('Failed to tear down notification channel: $e');
    }
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
    unawaited(stopListening());
    _notificationsController.close();
    _unreadCountController.close();
    _newNotificationController.close();
    Logger.debug('NotificationService disposed');
  }
}
