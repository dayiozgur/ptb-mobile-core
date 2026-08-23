import '../di/service_locator.dart';
import '../notification/local_notification_service.dart';
import '../realtime/realtime_service.dart';
import '../utils/logger.dart';
import 'announcement_model.dart';

/// **Duyuru bildiricisi** — `announcements` tablosuna Supabase Realtime ile
/// abone olur; tenant'a ait YENİ + yayınlanmış bir duyuru eklendiğinde
/// [LocalNotificationService] ile yerel bildirim tetikler.
///
/// Uygulama ön-planda/açıkken anında çalışır (realtime + local-notif). Arka-plan
/// veya kapalıyken push (FCM) gerekir — o ayrı bir iş (Firebase kurulumu bekliyor).
/// Login sonrası (tenant biliniyorken) [start] edilir; logout/tenant-değişiminde
/// [stop].
class AnnouncementNotifier {
  RealtimeSubscription? _sub;
  String? _tenantId;

  bool get isActive => _sub != null;

  LocalNotificationService get _notif => sl<LocalNotificationService>();
  RealtimeService get _realtime => sl<RealtimeService>();

  /// Tenant için aboneliği başlat (aynı tenant zaten aktifse no-op).
  void start(String tenantId) {
    if (_sub != null && _tenantId == tenantId) return;
    stop();
    _tenantId = tenantId;
    try {
      _sub = _realtime.subscribe<Announcement>(
        table: 'announcements',
        filter: 'tenant_id=eq.$tenantId',
        fromJson: (json) => Announcement.fromJson(json),
        onInsert: (a) {
          if (!a.published) return;
          _notif.show(
            title: 'Yeni Duyuru',
            body: (a.category ?? '').isNotEmpty ? '${a.category} • ${a.title}' : a.title,
            channelId: 'announcements',
            channelName: 'Duyurular',
            id: a.id.hashCode & 0x7fffffff,
          );
          Logger.info('Duyuru bildirimi tetiklendi: ${a.title}');
        },
        onError: (e) => Logger.warning('Duyuru realtime hatası: $e'),
      );
      Logger.info('AnnouncementNotifier started (tenant=$tenantId)');
    } catch (e) {
      Logger.warning('AnnouncementNotifier start başarısız: $e');
      _sub = null;
    }
  }

  /// Aboneliği durdur.
  void stop() {
    final s = _sub;
    _sub = null;
    _tenantId = null;
    if (s != null) {
      _realtime.unsubscribe(s.id).ignore();
    }
  }
}

/// Convenience getter.
AnnouncementNotifier get announcementNotifier => sl<AnnouncementNotifier>();
