import 'dart:async';

import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Bildirimler gelen kutusu ekranı.
///
/// Mobil uygulamada sabit alt-navigasyon sekmesi olarak kullanılır.
/// Gerçek [NotificationService] API'sini tüketir: mevcut kullanıcının
/// (`authService.currentUser`) bildirimlerini listeler, okundu işaretler ve
/// realtime akışıyla canlı günceller.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _loading = true;
  String? _profileId;

  StreamSubscription<List<AppNotification>>? _notificationsSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Profil kimliği = mevcut oturum açmış kullanıcı id'si.
    var id = authService.currentUser?.id;
    id ??= (await profileService.getCurrentProfile())?.id;

    if (!mounted) return;

    if (id == null) {
      setState(() => _loading = false);
      return;
    }

    _profileId = id;

    // Liste değişikliklerini canlı yakala (okundu işaretleme + yeni bildirim).
    _notificationsSub =
        notificationService.notificationsStream.listen((notifications) {
      if (!mounted) return;
      setState(() => _notifications = notifications);
    });

    // Realtime insert dinlemeyi başlat.
    unawaited(notificationService.startListening(id));

    await _load();
  }

  Future<void> _load() async {
    final id = _profileId;
    if (id == null) return;

    if (mounted) setState(() => _loading = true);

    final notifications =
        await notificationService.getNotifications(id, forceRefresh: true);

    if (!mounted) return;
    setState(() {
      _notifications = notifications;
      _loading = false;
    });
  }

  Future<void> _handleRefresh() async {
    await _load();
  }

  Future<void> _handleMarkAllRead() async {
    final id = _profileId;
    if (id == null) return;

    await notificationService.markAllAsRead(id);
    // markAllAsRead local state'i günceller ve stream'e yayınlar; yine de
    // sunucu ile tam senkron için yeniden yükle.
    await _load();
  }

  Future<void> _handleTap(AppNotification notification) async {
    if (notification.isRead) return;

    await notificationService.markAsRead(notification.id);
    if (!mounted) return;
    // Yerel state'i anında güncelle (stream de yayınlar, ama optimistik).
    setState(() {
      final index =
          _notifications.indexWhere((n) => n.id == notification.id);
      if (index != -1) {
        _notifications[index] =
            _notifications[index].copyWith(isRead: true);
      }
    });
  }

  @override
  void dispose() {
    unawaited(_notificationsSub?.cancel());
    unawaited(notificationService.stopListening());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _notifications.any((n) => !n.isRead);

    return AppScaffold(
      title: 'Bildirimler',
      showBackButton: false,
      actions: [
        if (hasUnread)
          IconButton(
            icon: const Icon(Icons.done_all),
            color: AppColors.primary,
            tooltip: 'Tümünü okundu işaretle',
            onPressed: _handleMarkAllRead,
          ),
      ],
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _handleRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            AppEmptyState(
              icon: Icons.notifications_none,
              title: 'Bildirim yok',
              message: 'Henüz bildiriminiz bulunmuyor.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.screenPadding,
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _NotificationTile(
              notification: notification,
              onTap: () => _handleTap(notification),
            ),
          );
        },
      ),
    );
  }
}

/// Tek bir bildirim kartı — okunmamışsa kalın başlık + okunmamış nokta.
class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    final title = notification.title ?? 'Bildirim';
    final body = notification.description ?? '';
    final color = _typeColor(notification.type);

    final subtitleParts = <String>[
      if (body.isNotEmpty) body,
      notification.timeAgo,
    ];

    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_typeIcon(notification.type), color: color),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.body.copyWith(
                      fontWeight:
                          unread ? FontWeight.w700 : FontWeight.w400,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitleParts.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitleParts.join('  •  '),
                      style: AppTypography.subhead.copyWith(
                        color: AppColors.secondaryLabel(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (unread) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(NotificationType? type) {
    switch (type) {
      case NotificationType.alert:
        return Icons.warning_amber_rounded;
      case NotificationType.reminder:
        return Icons.alarm;
      case NotificationType.info:
        return Icons.info_outline;
      case null:
        return Icons.notifications_none;
    }
  }

  Color _typeColor(NotificationType? type) {
    switch (type) {
      case NotificationType.alert:
        return AppColors.error;
      case NotificationType.reminder:
        return Colors.orange;
      case NotificationType.info:
      case null:
        return AppColors.primary;
    }
  }
}
