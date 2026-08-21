import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';

/// Admin — Bildirim Merkezi (notifications-hub) görüntüleyici (salt-okuma) servis.
///
/// Web portal `NotificationsHubComponent` + `NotificationService.getSentNotifications()`
/// okuma-yolunu aynalar (aynı Supabase projesi, `notifications` tablosu).
///
/// GAP / TASARIM NOTU: Bu projede ayrı `notification_workflows` veya
/// `notification_templates` tablosu **YOKTUR**. Web hub'ı da bunları listelemez;
/// bir gönderim formu (send-bulk-notification EF) + "gönderilen geçmişi" gösterir.
/// Mobil v1 salt-okuma karşılığı yalnız **gönderilen yayınları (broadcasts)**
/// listeler — gönderim/işlem mobilde sunulmaz. Yayınlar `sender_id = geçerli
/// kullanıcı` ile RLS-scoped okunur; web ile aynı toplu-gönderim gruplaması
/// (başlık + dakika + tür) uygulanır, böylece bir toplu gönderim tek satırda
/// alıcı sayısıyla görünür.
class AdminNotificationsHubService {
  final SupabaseClient _supabase;

  static const String _table = 'notifications';

  AdminNotificationsHubService({required SupabaseClient supabase})
      : _supabase = supabase;

  /// Geçerli kullanıcının gönderdiği son yayınları (en yeni önce) getirir.
  /// Web `getSentNotifications` + `groupNotifications` davranışını aynalar.
  Future<List<SentBroadcastRow>> listRecentBroadcasts({int limit = 30}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        Logger.debug('AdminNotificationsHubService: oturum yok');
        return [];
      }

      final rows = await _supabase
          .from(_table)
          .select(
            '*, recipient:profiles!notifications_recipient_id_fkey'
            '(full_name, username, email)',
          )
          .eq('sender_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      final flat = (rows as List)
          .map((e) => _RawSent.fromJson(e as Map<String, dynamic>))
          .toList();

      final grouped = _groupBulk(flat);
      Logger.debug(
          'AdminNotificationsHubService.listRecentBroadcasts → ${grouped.length}');
      return grouped;
    } catch (e, st) {
      Logger.error('AdminNotificationsHubService.listRecentBroadcasts hata', e, st);
      rethrow;
    }
  }

  /// Web `groupNotifications`: (başlık, dakikaya yuvarlanmış zaman, tür) anahtarı
  /// ile toplu gönderimleri tek satırda birleştirir; alıcı sayısını sayar.
  List<SentBroadcastRow> _groupBulk(List<_RawSent> items) {
    final groups = <String, SentBroadcastRow>{};
    for (final n in items) {
      final t = n.createdAt;
      final rounded = t == null
          ? 0
          : DateTime(t.year, t.month, t.day, t.hour, t.minute)
              .millisecondsSinceEpoch;
      final key = '${n.title}_${rounded}_${n.notificationType}';

      final existing = groups[key];
      if (existing == null) {
        groups[key] = SentBroadcastRow(
          id: n.id,
          title: n.title,
          message: n.message,
          notificationType: n.notificationType,
          priority: n.priority,
          createdAt: n.createdAt,
          recipientCount: 1,
          firstRecipientName: n.recipientName,
        );
      } else {
        groups[key] = existing.copyWithIncrement(n.recipientName);
      }
    }
    return groups.values.toList();
  }
}

/// Ham gönderilen bildirim satırı (gruplama öncesi iç model).
class _RawSent {
  final String id;
  final String? title;
  final String? message;
  final String? notificationType;
  final int? priority;
  final DateTime? createdAt;
  final String? recipientName;

  const _RawSent({
    required this.id,
    this.title,
    this.message,
    this.notificationType,
    this.priority,
    this.createdAt,
    this.recipientName,
  });

  static String? _name(dynamic embed) {
    Map<String, dynamic>? m;
    if (embed is Map<String, dynamic>) {
      m = embed;
    } else if (embed is List && embed.isNotEmpty && embed.first is Map) {
      m = (embed.first as Map).cast<String, dynamic>();
    }
    if (m == null) return null;
    final full = (m['full_name'] as String?)?.trim();
    if (full != null && full.isNotEmpty) return full;
    final username = (m['username'] as String?)?.trim();
    if (username != null && username.isNotEmpty) return username;
    final email = (m['email'] as String?)?.trim();
    if (email != null && email.isNotEmpty) return email;
    return null;
  }

  factory _RawSent.fromJson(Map<String, dynamic> json) {
    // description en güvenilir mesaj kaynağı; message kolonu yoksa description.
    final desc = json['description'] as String?;
    final msg = json['message'] as String?;
    return _RawSent(
      id: json['id'] as String,
      title: json['title'] as String?,
      message: (desc != null && desc.isNotEmpty) ? desc : msg,
      notificationType: json['notification_type'] as String?,
      priority: (json['priority'] as num?)?.toInt(),
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
      recipientName: _name(json['recipient']),
    );
  }
}

/// Gönderilen yayın satırı görüntü-modeli (salt-okuma, toplu-gruplu).
class SentBroadcastRow {
  final String id;
  final String? title;
  final String? message;

  /// `INFO | SUCCESS | WARNING | ERROR | SYSTEM | ALERT | REMINDER` gibi.
  final String? notificationType;
  final int? priority;
  final DateTime? createdAt;

  /// Bu toplu gönderimdeki alıcı sayısı (gruplama sonucu).
  final int recipientCount;

  /// İlk alıcının görünen adı (tekil gönderimlerde faydalı).
  final String? firstRecipientName;

  const SentBroadcastRow({
    required this.id,
    this.title,
    this.message,
    this.notificationType,
    this.priority,
    this.createdAt,
    this.recipientCount = 1,
    this.firstRecipientName,
  });

  SentBroadcastRow copyWithIncrement(String? nextRecipientName) {
    return SentBroadcastRow(
      id: id,
      title: title,
      message: message,
      notificationType: notificationType,
      priority: priority,
      createdAt: createdAt,
      recipientCount: recipientCount + 1,
      firstRecipientName: firstRecipientName ?? nextRecipientName,
    );
  }
}
