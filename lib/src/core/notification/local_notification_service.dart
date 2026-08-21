import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../utils/logger.dart';

/// **Cihaz (local) bildirimleri** — sunucu/push gerektirmez. PDKS giriş/çıkış
/// gibi olaylarda anında yerel bildirim gösterir.
///
/// iOS'ta izin çalışma-zamanında istenir ([requestPermission]); Android 13+ için
/// de bildirim izni istenir. Uygulama açılışında [init] çağrılmalı.
class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Eklentiyi başlat (idempotent). iOS izinleri burada İSTENMEZ — [requestPermission].
  Future<void> init() async {
    if (_initialized) return;
    try {
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const android =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(
        const InitializationSettings(iOS: ios, android: android),
      );
      _initialized = true;
    } catch (e) {
      Logger.warning('LocalNotification init hata: $e');
    }
  }

  /// Bildirim iznini iste (iOS runtime prompt / Android 13+). Sonuç: verildi mi.
  Future<bool> requestPermission() async {
    await init();
    try {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.requestPermissions(
            alert: true, badge: true, sound: true);
        return granted ?? false;
      }
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? false;
      }
    } catch (e) {
      Logger.warning('LocalNotification izin hata: $e');
    }
    return false;
  }

  /// Bir yerel bildirim göster.
  Future<void> show({
    required String title,
    required String body,
    int id = 0,
    String channelId = 'pdks',
    String channelName = 'PDKS',
  }) async {
    await init();
    try {
      final android = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'Giriş/çıkış ve konum bildirimleri',
        importance: Importance.high,
        priority: Priority.high,
      );
      const ios = DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true, // iOS 14+ ÖN-PLAN banner (presentAlert tek başına yetmez)
        presentList: true,   // iOS 14+ bildirim merkezinde listelenir
        presentBadge: true,
        presentSound: true,
      );
      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(android: android, iOS: ios),
      );
    } catch (e) {
      Logger.warning('LocalNotification göster hata: $e');
    }
  }
}
