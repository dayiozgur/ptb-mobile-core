import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';

/// Realtime event türleri
enum RealtimeEventType {
  /// Yeni kayıt eklendi
  insert('INSERT'),

  /// Kayıt güncellendi
  update('UPDATE'),

  /// Kayıt silindi
  delete('DELETE'),

  /// Tüm değişiklikler
  all('*');

  final String value;

  const RealtimeEventType(this.value);

  static RealtimeEventType fromString(String? value) {
    return RealtimeEventType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => RealtimeEventType.all,
    );
  }
}

/// Realtime abonelik durumu
enum SubscriptionStatus {
  /// Bağlantı kuruluyor
  connecting,

  /// Bağlı
  connected,

  /// Bağlantı kesildi
  disconnected,

  /// Hata
  error,
}

/// Realtime değişiklik verisi
class RealtimeChange<T> {
  /// Event türü
  final RealtimeEventType eventType;

  /// Yeni veri (INSERT, UPDATE için)
  final T? newRecord;

  /// Eski veri (UPDATE, DELETE için)
  final T? oldRecord;

  /// Tablo adı
  final String table;

  /// Schema adı
  final String schema;

  /// Zaman damgası
  final DateTime timestamp;

  RealtimeChange({
    required this.eventType,
    this.newRecord,
    this.oldRecord,
    required this.table,
    this.schema = 'public',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Insert mi?
  bool get isInsert => eventType == RealtimeEventType.insert;

  /// Update mi?
  bool get isUpdate => eventType == RealtimeEventType.update;

  /// Delete mi?
  bool get isDelete => eventType == RealtimeEventType.delete;

  @override
  String toString() =>
      'RealtimeChange(table: $table, event: ${eventType.value}, hasNew: ${newRecord != null}, hasOld: ${oldRecord != null})';
}

/// Realtime abonelik bilgisi
class RealtimeSubscription {
  /// Benzersiz ID
  final String id;

  /// Tablo adı
  final String table;

  /// Schema
  final String schema;

  /// Event türleri
  final List<RealtimeEventType> events;

  /// Filtre (örn: 'tenant_id=eq.xxx')
  final String? filter;

  /// Supabase channel
  final RealtimeChannel channel;

  /// Durum
  SubscriptionStatus status;

  /// Oluşturulma zamanı
  final DateTime createdAt;

  RealtimeSubscription({
    required this.id,
    required this.table,
    this.schema = 'public',
    this.events = const [RealtimeEventType.all],
    this.filter,
    required this.channel,
    this.status = SubscriptionStatus.connecting,
  }) : createdAt = DateTime.now();

  /// Aktif mi?
  bool get isActive => status == SubscriptionStatus.connected;
}

/// Realtime Servisi
///
/// Supabase Realtime üzerinden veritabanı değişikliklerini dinler.
///
/// Örnek kullanım:
/// ```dart
/// final realtimeService = RealtimeService(supabase: Supabase.instance.client);
///
/// // Tablo değişikliklerini dinle
/// final subscription = realtimeService.subscribe<Organization>(
///   table: 'organizations',
///   filter: 'tenant_id=eq.$tenantId',
///   fromJson: Organization.fromJson,
///   onInsert: (org) => print('Yeni organizasyon: ${org.name}'),
///   onUpdate: (org) => print('Güncellenen: ${org.name}'),
///   onDelete: (org) => print('Silinen: ${org?.id}'),
/// );
///
/// // Aboneliği iptal et
/// await realtimeService.unsubscribe(subscription.id);
/// ```
class RealtimeService {
  final SupabaseClient _supabase;

  // Aktif abonelikler
  final Map<String, RealtimeSubscription> _subscriptions = {};

  // Stream controllers
  final _statusController = StreamController<SubscriptionStatus>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  // Bağlantı durumu
  bool _isConnected = false;

  RealtimeService({
    required SupabaseClient supabase,
  }) : _supabase = supabase;

  // ============================================
  // GETTERS
  // ============================================

  /// Bağlı mı?
  bool get isConnected => _isConnected;

  /// Aktif abonelik sayısı
  int get subscriptionCount => _subscriptions.length;

  /// Aktif abonelikler
  List<RealtimeSubscription> get subscriptions => _subscriptions.values.toList();

  /// Durum stream'i
  Stream<SubscriptionStatus> get statusStream => _statusController.stream;

  /// Hata stream'i
  Stream<String> get errorStream => _errorController.stream;

  // ============================================
  // SUBSCRIPTION MANAGEMENT
  // ============================================

  /// Tabloya abone ol
  RealtimeSubscription subscribe<T>({
    required String table,
    String schema = 'public',
    List<RealtimeEventType> events = const [RealtimeEventType.all],
    String? filter,
    required T Function(Map<String, dynamic>) fromJson,
    void Function(T newRecord)? onInsert,
    void Function(T newRecord, T? oldRecord)? onUpdate,
    void Function(T? oldRecord)? onDelete,
    void Function(RealtimeChange<T> change)? onChange,
    void Function(String error)? onError,
  }) {
    final subscriptionId = _generateSubscriptionId(table, schema, filter);

    // Mevcut abonelik varsa döndür
    if (_subscriptions.containsKey(subscriptionId)) {
      Logger.debug('Subscription already exists: $subscriptionId');
      return _subscriptions[subscriptionId]!;
    }

    // Channel oluştur
    final channelName = 'realtime:$schema:$table:${filter ?? 'all'}';
    final channel = _supabase.channel(channelName);

    // Event türünü belirle
    final postgresEvent = events.length == 1
        ? _mapToPostgresChangeEvent(events.first)
        : PostgresChangeEvent.all;

    // Değişiklikleri dinle
    channel.onPostgresChanges(
      event: postgresEvent,
      schema: schema,
      table: table,
      filter: filter != null ? PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: filter.split('=eq.').first,
        value: filter.split('=eq.').length > 1 ? filter.split('=eq.').last : '',
      ) : null,
      callback: (payload) {
        try {
          final eventType = _mapFromPostgresChangeEvent(payload.eventType);

          T? newRecord;
          T? oldRecord;

          if (payload.newRecord.isNotEmpty) {
            newRecord = fromJson(payload.newRecord);
          }

          if (payload.oldRecord.isNotEmpty) {
            oldRecord = fromJson(payload.oldRecord);
          }

          final change = RealtimeChange<T>(
            eventType: eventType,
            newRecord: newRecord,
            oldRecord: oldRecord,
            table: table,
            schema: schema,
          );

          // Callback'leri çağır
          onChange?.call(change);

          switch (eventType) {
            case RealtimeEventType.insert:
              if (newRecord != null) onInsert?.call(newRecord);
              break;
            case RealtimeEventType.update:
              if (newRecord != null) onUpdate?.call(newRecord, oldRecord);
              break;
            case RealtimeEventType.delete:
              onDelete?.call(oldRecord);
              break;
            case RealtimeEventType.all:
              break;
          }

          Logger.debug('Realtime change: $change');
        } catch (e) {
          final error = 'Failed to process realtime change: $e';
          Logger.error(error);
          onError?.call(error);
          _errorController.add(error);
        }
      },
    );

    // Subscribe
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        _subscriptions[subscriptionId]?.status = SubscriptionStatus.connected;
        _statusController.add(SubscriptionStatus.connected);
        _isConnected = true;
        Logger.info('Realtime subscribed: $subscriptionId');
      } else if (status == RealtimeSubscribeStatus.closed) {
        Logger.debug('Realtime channel closed: $subscriptionId');
        _subscriptions[subscriptionId]?.status = SubscriptionStatus.disconnected;
        _statusController.add(SubscriptionStatus.disconnected);
      } else if (status == RealtimeSubscribeStatus.channelError) {
        Logger.error('Realtime channel error: $error');
        _subscriptions[subscriptionId]?.status = SubscriptionStatus.error;
        _statusController.add(SubscriptionStatus.error);
        onError?.call(error?.toString() ?? 'Unknown error');
      }
    });

    // Subscription oluştur ve kaydet
    final subscription = RealtimeSubscription(
      id: subscriptionId,
      table: table,
      schema: schema,
      events: events,
      filter: filter,
      channel: channel,
    );

    _subscriptions[subscriptionId] = subscription;

    Logger.info('Realtime subscription created: $subscriptionId');
    return subscription;
  }

  /// Aboneliği iptal et
  Future<void> unsubscribe(String subscriptionId) async {
    final subscription = _subscriptions[subscriptionId];
    if (subscription == null) {
      Logger.warning('Subscription not found: $subscriptionId');
      return;
    }

    try {
      await subscription.channel.unsubscribe();
      await _supabase.removeChannel(subscription.channel);
      _subscriptions.remove(subscriptionId);

      Logger.info('Realtime unsubscribed: $subscriptionId');

      if (_subscriptions.isEmpty) {
        _isConnected = false;
      }
    } catch (e) {
      Logger.error('Failed to unsubscribe: $e');
    }
  }

  /// Tüm abonelikleri iptal et
  Future<void> unsubscribeAll() async {
    final ids = _subscriptions.keys.toList();
    for (final id in ids) {
      await unsubscribe(id);
    }

    _isConnected = false;
    Logger.info('All realtime subscriptions removed');
  }

  /// Subscription ID oluştur
  String _generateSubscriptionId(String table, String schema, String? filter) {
    return '$schema:$table:${filter ?? 'all'}';
  }

  /// RealtimeEventType'dan PostgresChangeEvent'e çevir
  PostgresChangeEvent _mapToPostgresChangeEvent(RealtimeEventType type) {
    switch (type) {
      case RealtimeEventType.insert:
        return PostgresChangeEvent.insert;
      case RealtimeEventType.update:
        return PostgresChangeEvent.update;
      case RealtimeEventType.delete:
        return PostgresChangeEvent.delete;
      case RealtimeEventType.all:
        return PostgresChangeEvent.all;
    }
  }

  /// PostgresChangeEvent'den RealtimeEventType'a çevir
  RealtimeEventType _mapFromPostgresChangeEvent(PostgresChangeEvent event) {
    switch (event) {
      case PostgresChangeEvent.insert:
        return RealtimeEventType.insert;
      case PostgresChangeEvent.update:
        return RealtimeEventType.update;
      case PostgresChangeEvent.delete:
        return RealtimeEventType.delete;
      case PostgresChangeEvent.all:
        return RealtimeEventType.all;
    }
  }

  // ============================================
  // CONVENIENCE METHODS
  // ============================================

  /// Organizasyon değişikliklerini dinle
  RealtimeSubscription subscribeToOrganizations<T>({
    required String tenantId,
    required T Function(Map<String, dynamic>) fromJson,
    void Function(T)? onInsert,
    void Function(T, T?)? onUpdate,
    void Function(T?)? onDelete,
  }) {
    return subscribe<T>(
      table: 'organizations',
      filter: 'tenant_id=eq.$tenantId',
      fromJson: fromJson,
      onInsert: onInsert,
      onUpdate: onUpdate,
      onDelete: onDelete,
    );
  }

  /// Site değişikliklerini dinle
  RealtimeSubscription subscribeToSites<T>({
    required String organizationId,
    required T Function(Map<String, dynamic>) fromJson,
    void Function(T)? onInsert,
    void Function(T, T?)? onUpdate,
    void Function(T?)? onDelete,
  }) {
    return subscribe<T>(
      table: 'sites',
      filter: 'organization_id=eq.$organizationId',
      fromJson: fromJson,
      onInsert: onInsert,
      onUpdate: onUpdate,
      onDelete: onDelete,
    );
  }

  /// Unit değişikliklerini dinle
  RealtimeSubscription subscribeToUnits<T>({
    required String siteId,
    required T Function(Map<String, dynamic>) fromJson,
    void Function(T)? onInsert,
    void Function(T, T?)? onUpdate,
    void Function(T?)? onDelete,
  }) {
    return subscribe<T>(
      table: 'units',
      filter: 'site_id=eq.$siteId',
      fromJson: fromJson,
      onInsert: onInsert,
      onUpdate: onUpdate,
      onDelete: onDelete,
    );
  }

  /// Bildirim değişikliklerini dinle
  RealtimeSubscription subscribeToNotifications<T>({
    required String profileId,
    required T Function(Map<String, dynamic>) fromJson,
    void Function(T)? onInsert,
    void Function(T, T?)? onUpdate,
    void Function(T?)? onDelete,
  }) {
    return subscribe<T>(
      table: 'notifications',
      filter: 'profile_id=eq.$profileId',
      fromJson: fromJson,
      onInsert: onInsert,
      onUpdate: onUpdate,
      onDelete: onDelete,
    );
  }

  // ============================================
  // PRESENCE (Kullanıcı Durumu)
  // ============================================

  /// Presence channel'a katıl
  RealtimeChannel joinPresence({
    required String channelName,
    required Map<String, dynamic> userState,
    void Function(List<Map<String, dynamic>> users)? onSync,
    void Function(Map<String, dynamic> user)? onJoin,
    void Function(Map<String, dynamic> user)? onLeave,
  }) {
    final channel = _supabase.channel(channelName);

    channel.onPresenceSync((payload) {
      final presenceList = channel.presenceState();
      final userList = presenceList
          .map((u) => Map<String, dynamic>.from(u.state))
          .toList();
      onSync?.call(userList);
    });

    channel.onPresenceJoin((payload) {
      for (final presence in payload.newPresences) {
        onJoin?.call(Map<String, dynamic>.from(presence.state));
      }
    });

    channel.onPresenceLeave((payload) {
      for (final presence in payload.leftPresences) {
        onLeave?.call(Map<String, dynamic>.from(presence.state));
      }
    });

    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        channel.track(userState);
        Logger.info('Presence joined: $channelName');
      }
    });

    return channel;
  }

  /// Presence'den ayrıl
  Future<void> leavePresence(RealtimeChannel channel) async {
    await channel.untrack();
    await channel.unsubscribe();
    await _supabase.removeChannel(channel);
  }

  // ============================================
  // BROADCAST (Anlık Mesajlaşma)
  // ============================================

  /// Broadcast channel oluştur
  RealtimeChannel createBroadcastChannel({
    required String channelName,
    void Function(Map<String, dynamic> message)? onMessage,
  }) {
    final channel = _supabase.channel(channelName);

    channel.onBroadcast(
      event: '*',
      callback: (payload) {
        onMessage?.call(payload);
      },
    );

    channel.subscribe();

    return channel;
  }

  /// Broadcast mesajı gönder
  Future<void> broadcastMessage({
    required RealtimeChannel channel,
    required String event,
    required Map<String, dynamic> payload,
  }) async {
    await channel.sendBroadcastMessage(
      event: event,
      payload: payload,
    );
  }

  // ============================================
  // CLEANUP
  // ============================================

  /// Servisi kapat
  Future<void> dispose() async {
    await unsubscribeAll();
    await _statusController.close();
    await _errorController.close();
    Logger.debug('RealtimeService disposed');
  }
}
