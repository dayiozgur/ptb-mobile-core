import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../storage/secure_storage.dart';
import '../utils/logger.dart';

/// Push notification token türleri
enum PushTokenType {
  /// Firebase Cloud Messaging
  fcm('fcm', 'Firebase Cloud Messaging'),

  /// Apple Push Notification Service
  apns('apns', 'Apple Push Notification Service');

  final String value;
  final String label;

  const PushTokenType(this.value, this.label);

  static PushTokenType get current {
    if (Platform.isIOS || Platform.isMacOS) {
      return PushTokenType.apns;
    }
    return PushTokenType.fcm;
  }
}

/// Push bildirim önceliği (Android notification channels için)
enum PushPushNotificationPriority {
  /// Düşük öncelik - sessiz bildirim
  low('low'),

  /// Normal öncelik
  normal('normal'),

  /// Yüksek öncelik - hemen göster
  high('high');

  final String value;

  const PushPushNotificationPriority(this.value);
}

/// Bildirim kanalı (Android)
class NotificationChannel {
  final String id;
  final String name;
  final String? description;
  final PushNotificationPriority priority;
  final bool playSound;
  final bool enableVibration;
  final bool showBadge;

  const NotificationChannel({
    required this.id,
    required this.name,
    this.description,
    this.priority = PushNotificationPriority.normal,
    this.playSound = true,
    this.enableVibration = true,
    this.showBadge = true,
  });

  /// Varsayılan kanal
  static const NotificationChannel defaultChannel = NotificationChannel(
    id: 'default',
    name: 'Genel Bildirimler',
    description: 'Genel uygulama bildirimleri',
  );

  /// Önemli bildirimler kanalı
  static const NotificationChannel importantChannel = NotificationChannel(
    id: 'important',
    name: 'Önemli Bildirimler',
    description: 'Acil ve önemli bildirimler',
    priority: PushNotificationPriority.high,
  );

  /// Sessiz bildirimler kanalı
  static const NotificationChannel silentChannel = NotificationChannel(
    id: 'silent',
    name: 'Sessiz Bildirimler',
    description: 'Ses çıkarmayan bildirimler',
    priority: PushNotificationPriority.low,
    playSound: false,
    enableVibration: false,
  );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'priority': priority.value,
        'playSound': playSound,
        'enableVibration': enableVibration,
        'showBadge': showBadge,
      };
}

/// Push bildirim verisi
class PushNotificationData {
  /// Bildirim ID
  final String? id;

  /// Başlık
  final String? title;

  /// İçerik
  final String? body;

  /// Resim URL
  final String? imageUrl;

  /// Ek veri
  final Map<String, dynamic>? data;

  /// Kanal ID (Android)
  final String? channelId;

  /// Alındığı zaman
  final DateTime receivedAt;

  /// Foreground'da mı alındı
  final bool receivedInForeground;

  PushNotificationData({
    this.id,
    this.title,
    this.body,
    this.imageUrl,
    this.data,
    this.channelId,
    DateTime? receivedAt,
    this.receivedInForeground = false,
  }) : receivedAt = receivedAt ?? DateTime.now();

  factory PushNotificationData.fromJson(Map<String, dynamic> json) {
    return PushNotificationData(
      id: json['id'] as String?,
      title: json['title'] as String? ?? json['notification']?['title'] as String?,
      body: json['body'] as String? ?? json['notification']?['body'] as String?,
      imageUrl: json['imageUrl'] as String? ?? json['notification']?['image'] as String?,
      data: json['data'] as Map<String, dynamic>?,
      channelId: json['channelId'] as String?,
      receivedAt: json['receivedAt'] != null
          ? DateTime.tryParse(json['receivedAt'] as String)
          : null,
      receivedInForeground: json['receivedInForeground'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'imageUrl': imageUrl,
        'data': data,
        'channelId': channelId,
        'receivedAt': receivedAt.toIso8601String(),
        'receivedInForeground': receivedInForeground,
      };

  /// Navigasyon verisi var mı
  bool get hasNavigationData => data?['route'] != null || data?['screen'] != null;

  /// Navigasyon rotası
  String? get navigationRoute => data?['route'] as String? ?? data?['screen'] as String?;

  /// Entity ID (varsa)
  String? get entityId => data?['entityId'] as String? ?? data?['entity_id'] as String?;

  /// Entity tipi (varsa)
  String? get entityType => data?['entityType'] as String? ?? data?['entity_type'] as String?;

  @override
  String toString() => 'PushNotificationData(id: $id, title: $title, body: $body)';
}

/// Push bildirim ayarları
class PushNotificationSettings {
  /// Bildirimler etkin mi
  final bool enabled;

  /// Ses etkin mi
  final bool soundEnabled;

  /// Titreşim etkin mi
  final bool vibrationEnabled;

  /// Badge göster
  final bool badgeEnabled;

  /// Önizleme göster
  final bool previewEnabled;

  /// Sessiz saatler başlangıcı (saat)
  final int? quietHoursStart;

  /// Sessiz saatler bitişi (saat)
  final int? quietHoursEnd;

  /// Etkin bildirim türleri
  final List<String> enabledTypes;

  const PushNotificationSettings({
    this.enabled = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.badgeEnabled = true,
    this.previewEnabled = true,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.enabledTypes = const [],
  });

  factory PushNotificationSettings.fromJson(Map<String, dynamic> json) {
    return PushNotificationSettings(
      enabled: json['enabled'] as bool? ?? true,
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
      badgeEnabled: json['badgeEnabled'] as bool? ?? true,
      previewEnabled: json['previewEnabled'] as bool? ?? true,
      quietHoursStart: json['quietHoursStart'] as int?,
      quietHoursEnd: json['quietHoursEnd'] as int?,
      enabledTypes: (json['enabledTypes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'soundEnabled': soundEnabled,
        'vibrationEnabled': vibrationEnabled,
        'badgeEnabled': badgeEnabled,
        'previewEnabled': previewEnabled,
        'quietHoursStart': quietHoursStart,
        'quietHoursEnd': quietHoursEnd,
        'enabledTypes': enabledTypes,
      };

  PushNotificationSettings copyWith({
    bool? enabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? badgeEnabled,
    bool? previewEnabled,
    int? quietHoursStart,
    int? quietHoursEnd,
    List<String>? enabledTypes,
  }) {
    return PushNotificationSettings(
      enabled: enabled ?? this.enabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      badgeEnabled: badgeEnabled ?? this.badgeEnabled,
      previewEnabled: previewEnabled ?? this.previewEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      enabledTypes: enabledTypes ?? this.enabledTypes,
    );
  }

  /// Sessiz saatler aktif mi
  bool get isInQuietHours {
    if (quietHoursStart == null || quietHoursEnd == null) return false;

    final now = DateTime.now().hour;

    if (quietHoursStart! <= quietHoursEnd!) {
      return now >= quietHoursStart! && now < quietHoursEnd!;
    } else {
      // Gece yarısını geçen sessiz saatler (örn: 22-07)
      return now >= quietHoursStart! || now < quietHoursEnd!;
    }
  }

  /// Varsayılan ayarlar
  static const PushNotificationSettings defaultSettings = PushNotificationSettings();
}

/// Push Bildirim Servisi
///
/// FCM ve APNs entegrasyonu için temel servis.
/// Bu servis, platform-specific implementasyonlarla birlikte kullanılmalıdır.
///
/// Örnek kullanım:
/// ```dart
/// final pushService = PushNotificationService(storage: SecureStorage());
/// await pushService.initialize();
///
/// // Token al
/// final token = await pushService.getToken();
///
/// // Bildirim dinle
/// pushService.onNotificationReceived.listen((notification) {
///   print('Bildirim: ${notification.title}');
/// });
/// ```
class PushNotificationService {
  final SecureStorage _storage;

  // State
  String? _token;
  PushNotificationSettings _settings = PushNotificationSettings.defaultSettings;
  bool _isInitialized = false;
  bool _hasPermission = false;

  // Stream controllers
  final _notificationController = StreamController<PushNotificationData>.broadcast();
  final _tokenController = StreamController<String>.broadcast();
  final _permissionController = StreamController<bool>.broadcast();

  // Storage keys
  static const String _tokenKey = 'push_token';
  static const String _settingsKey = 'push_settings';

  // Callbacks
  void Function(PushNotificationData)? onNotificationTap;
  void Function(PushNotificationData)? onBackgroundMessage;

  PushNotificationService({
    required SecureStorage storage,
  }) : _storage = storage;

  // ============================================
  // GETTERS
  // ============================================

  /// Push token
  String? get token => _token;

  /// Ayarlar
  PushNotificationSettings get settings => _settings;

  /// Başlatıldı mı
  bool get isInitialized => _isInitialized;

  /// İzin var mı
  bool get hasPermission => _hasPermission;

  /// Token tipi
  PushTokenType get tokenType => PushTokenType.current;

  /// Bildirim stream'i
  Stream<PushNotificationData> get onNotificationReceived => _notificationController.stream;

  /// Token değişiklik stream'i
  Stream<String> get onTokenRefresh => _tokenController.stream;

  /// İzin değişiklik stream'i
  Stream<bool> get onPermissionChange => _permissionController.stream;

  // ============================================
  // INITIALIZATION
  // ============================================

  /// Servisi başlat
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Kayıtlı ayarları yükle
      await _loadSettings();

      // Kayıtlı token'ı yükle
      _token = await _storage.read(_tokenKey);

      _isInitialized = true;
      Logger.info('PushNotificationService initialized');
    } catch (e) {
      Logger.error('Failed to initialize PushNotificationService', e);
      _isInitialized = true; // Devam et
    }
  }

  /// Ayarları yükle
  Future<void> _loadSettings() async {
    try {
      final settingsJson = await _storage.read(_settingsKey);
      if (settingsJson != null) {
        _settings = PushNotificationSettings.fromJson(
          jsonDecode(settingsJson) as Map<String, dynamic>,
        );
      }
    } catch (e) {
      Logger.error('Failed to load push settings', e);
    }
  }

  /// Ayarları kaydet
  Future<void> _saveSettings() async {
    try {
      await _storage.write(
        key: _settingsKey,
        value: jsonEncode(_settings.toJson()),
      );
    } catch (e) {
      Logger.error('Failed to save push settings', e);
    }
  }

  // ============================================
  // PERMISSIONS
  // ============================================

  /// Bildirim izni iste
  Future<bool> requestPermission() async {
    // Platform-specific implementation gerekli
    // Bu metot override edilmeli veya mixin kullanılmalı
    Logger.warning('requestPermission() should be implemented for platform');
    return false;
  }

  /// İzin durumunu kontrol et
  Future<bool> checkPermission() async {
    // Platform-specific implementation gerekli
    Logger.warning('checkPermission() should be implemented for platform');
    return false;
  }

  /// İzin durumunu güncelle
  @protected
  void updatePermission(bool hasPermission) {
    _hasPermission = hasPermission;
    _permissionController.add(hasPermission);
  }

  // ============================================
  // TOKEN MANAGEMENT
  // ============================================

  /// Push token'ı al
  Future<String?> getToken() async {
    // Platform-specific implementation gerekli
    Logger.warning('getToken() should be implemented for platform');
    return _token;
  }

  /// Token'ı güncelle
  @protected
  Future<void> updateToken(String token) async {
    if (_token == token) return;

    _token = token;
    await _storage.write(key: _tokenKey, value: token);
    _tokenController.add(token);

    Logger.info('Push token updated');
  }

  /// Token'ı sil
  Future<void> deleteToken() async {
    _token = null;
    await _storage.delete(_tokenKey);
    Logger.info('Push token deleted');
  }

  /// Token'ı sunucuya kaydet
  Future<void> registerToken({
    required String userId,
    required String token,
    Map<String, dynamic>? metadata,
  }) async {
    // API çağrısı yapılmalı
    Logger.info('Token registered for user: $userId');
  }

  /// Token'ı sunucudan sil
  Future<void> unregisterToken({
    required String userId,
    required String token,
  }) async {
    // API çağrısı yapılmalı
    Logger.info('Token unregistered for user: $userId');
  }

  // ============================================
  // NOTIFICATION HANDLING
  // ============================================

  /// Bildirim al (foreground)
  @protected
  void handleNotification(PushNotificationData notification) {
    if (!_settings.enabled) return;

    // Sessiz saatlerde bildirim gösterme
    if (_settings.isInQuietHours) {
      Logger.debug('Notification suppressed (quiet hours)');
      return;
    }

    _notificationController.add(notification);
    Logger.info('Notification received: ${notification.title}');
  }

  /// Bildirime tıklandığında
  @protected
  void handleNotificationTap(PushNotificationData notification) {
    onNotificationTap?.call(notification);
    Logger.info('Notification tapped: ${notification.title}');
  }

  /// Background mesaj
  @protected
  void handleBackgroundMessage(PushNotificationData notification) {
    onBackgroundMessage?.call(notification);
    Logger.info('Background message: ${notification.title}');
  }

  // ============================================
  // LOCAL NOTIFICATIONS
  // ============================================

  /// Lokal bildirim göster
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? imageUrl,
    Map<String, dynamic>? data,
    NotificationChannel channel = NotificationChannel.defaultChannel,
  }) async {
    // Platform-specific implementation gerekli
    Logger.warning('showLocalNotification() should be implemented for platform');
  }

  /// Zamanlanmış bildirim oluştur
  Future<void> scheduleNotification({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    Map<String, dynamic>? data,
    NotificationChannel channel = NotificationChannel.defaultChannel,
  }) async {
    // Platform-specific implementation gerekli
    Logger.warning('scheduleNotification() should be implemented for platform');
  }

  /// Zamanlanmış bildirimi iptal et
  Future<void> cancelScheduledNotification(String id) async {
    // Platform-specific implementation gerekli
    Logger.warning('cancelScheduledNotification() should be implemented for platform');
  }

  /// Tüm zamanlanmış bildirimleri iptal et
  Future<void> cancelAllScheduledNotifications() async {
    // Platform-specific implementation gerekli
    Logger.warning('cancelAllScheduledNotifications() should be implemented for platform');
  }

  // ============================================
  // BADGE MANAGEMENT
  // ============================================

  /// Badge sayısını güncelle
  Future<void> setBadgeCount(int count) async {
    if (!_settings.badgeEnabled) return;
    // Platform-specific implementation gerekli
    Logger.warning('setBadgeCount() should be implemented for platform');
  }

  /// Badge'i temizle
  Future<void> clearBadge() async {
    await setBadgeCount(0);
  }

  // ============================================
  // SETTINGS
  // ============================================

  /// Ayarları güncelle
  Future<void> updateSettings(PushNotificationSettings settings) async {
    _settings = settings;
    await _saveSettings();
    Logger.info('Push settings updated');
  }

  /// Bildirimleri etkinleştir/devre dışı bırak
  Future<void> setEnabled(bool enabled) async {
    await updateSettings(_settings.copyWith(enabled: enabled));
  }

  /// Sesi etkinleştir/devre dışı bırak
  Future<void> setSoundEnabled(bool enabled) async {
    await updateSettings(_settings.copyWith(soundEnabled: enabled));
  }

  /// Titreşimi etkinleştir/devre dışı bırak
  Future<void> setVibrationEnabled(bool enabled) async {
    await updateSettings(_settings.copyWith(vibrationEnabled: enabled));
  }

  /// Sessiz saatleri ayarla
  Future<void> setQuietHours(int? start, int? end) async {
    await updateSettings(_settings.copyWith(
      quietHoursStart: start,
      quietHoursEnd: end,
    ));
  }

  // ============================================
  // TOPICS (FCM)
  // ============================================

  /// Topic'e abone ol
  Future<void> subscribeToTopic(String topic) async {
    // Platform-specific implementation gerekli
    Logger.info('Subscribed to topic: $topic');
  }

  /// Topic aboneliğini iptal et
  Future<void> unsubscribeFromTopic(String topic) async {
    // Platform-specific implementation gerekli
    Logger.info('Unsubscribed from topic: $topic');
  }

  // ============================================
  // CLEANUP
  // ============================================

  /// Servisi kapat
  void dispose() {
    _notificationController.close();
    _tokenController.close();
    _permissionController.close();
    Logger.debug('PushNotificationService disposed');
  }
}
