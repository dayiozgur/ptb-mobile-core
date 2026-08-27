import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../tenant/tenant_service.dart';
import '../utils/logger.dart';
import 'push_notification_service.dart';

/// **APNs kayıt yöneticisi** — saf Apple push (Firebase/FCM YOK).
///
/// iOS native `ptb/apns` MethodChannel'ıyla konuşur: `register` → izin iste +
/// `registerForRemoteNotifications`; native `onToken` ile APNs device-token'ı
/// geri gelir → `user_devices` tablosuna upsert edilir (gönderim EF buradan okur).
///
/// Android'de kanal yoktur → `register` sessizce no-op (ileride FCM eklenebilir).
/// Login sonrası (tenant biliniyorken) [register] çağrılır.
class ApnsRegistrar {
  static const _channel = MethodChannel('ptb/apns');
  final SupabaseClient _supabase;
  bool _handlerSet = false;

  ApnsRegistrar({required SupabaseClient supabase}) : _supabase = supabase;

  /// Push iznini iste + APNs kaydını başlat. Token native'den `onToken` ile gelir.
  Future<void> register() async {
    if (!_handlerSet) {
      _channel.setMethodCallHandler(_onNativeCall);
      _handlerSet = true;
    }
    try {
      final granted = await _channel.invokeMethod<bool>('register');
      Logger.info('APNs register izni: $granted');
    } on MissingPluginException {
      // iOS-dışı platform (kanal yok) → sessiz.
    } catch (e) {
      Logger.warning('APNs register hata: $e');
    }
  }

  Future<void> _onNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onToken':
        // Yeni format: {token, bundleId}. Eski format (düz String) geriye-uyumlu.
        String? token;
        String? bundleId;
        final args = call.arguments;
        if (args is Map) {
          token = args['token'] as String?;
          bundleId = args['bundleId'] as String?;
        } else if (args is String) {
          token = args;
        }
        if (token != null && token.isNotEmpty) await _saveToken(token, bundleId);
        break;
      case 'onNotificationTap':
        // Kullanıcı bildirime tıkladı → payload'ı (aps + custom route/entityId)
        // PushNotificationService'e ilet; deep-link köprüsü ekranı açar.
        final args = call.arguments;
        if (args is Map) {
          _dispatchTap(
              args.map((k, v) => MapEntry(k.toString(), v)).cast<String, dynamic>());
        }
        break;
      case 'onError':
        Logger.warning('APNs kayıt hatası (native): ${call.arguments}');
        break;
    }
  }

  /// Native APNs userInfo'sunu [PushNotificationData]'ya çevirip tap'i dağıtır.
  /// Başlık/gövde `aps.alert`'ten; yönlendirme verisi (`route`/`entityId`/
  /// `type`) top-level custom anahtarlardan (`data`'ya konur → deep-link).
  void _dispatchTap(Map<String, dynamic> userInfo) {
    String? title;
    String? body;
    final aps = userInfo['aps'];
    if (aps is Map) {
      final alert = aps['alert'];
      if (alert is Map) {
        title = alert['title']?.toString();
        body = alert['body']?.toString();
      } else if (alert is String) {
        body = alert;
      }
    }
    final data = <String, dynamic>{};
    userInfo.forEach((k, v) {
      if (k != 'aps') data[k] = v;
    });

    final n = PushNotificationData(
      id: userInfo['id']?.toString() ?? '',
      title: title ?? '',
      body: body ?? '',
      data: data,
    );
    sl<PushNotificationService>().handleNotificationTap(n);
  }

  /// Token'ı user_devices'a upsert (token benzersiz → aynı cihaz güncellenir).
  Future<void> _saveToken(String token, [String? bundleId]) async {
    final userId = authService.currentUser?.id;
    if (userId == null) return;
    final tenantId = sl<TenantService>().currentTenantId;
    try {
      await _supabase.from('user_devices').upsert({
        'user_id': userId,
        'tenant_id': tenantId,
        'token': token,
        'platform': 'ios',
        'environment': 'production',
        if (bundleId != null && bundleId.isNotEmpty) 'bundle_id': bundleId,
        'active': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'token');
      Logger.info('APNs token kaydedildi (user_devices)');
    } catch (e) {
      Logger.warning('APNs token kaydı başarısız: $e');
    }
  }
}

/// Convenience getter.
ApnsRegistrar get apnsRegistrar => sl<ApnsRegistrar>();
