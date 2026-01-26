import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Profile ID kullanıcının auth ID'si ile aynı
      final profileId = authService.currentUser?.id;
      if (profileId == null) {
        setState(() {
          _error = 'Oturum bilgisi bulunamadı';
          _isLoading = false;
        });
        return;
      }

      final notifications = await notificationService.getNotifications(
        profileId,
        forceRefresh: true,
      );

      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Failed to load notifications', e);
      setState(() {
        _error = 'Bildirimler yüklenemedi';
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(AppNotification notification) async {
    if (notification.isRead) return;

    final success = await notificationService.markAsRead(notification.id);
    if (success && mounted) {
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          _notifications[index] = notification.copyWith(
            isRead: true,
            readAt: DateTime.now(),
          );
        }
      });
    }
  }

  Future<void> _markAllAsRead() async {
    final profileId = authService.currentUser?.id;
    if (profileId == null) return;

    final success = await notificationService.markAllAsRead(profileId);
    if (success && mounted) {
      setState(() {
        _notifications = _notifications
            .map((n) => n.copyWith(isRead: true))
            .toList();
      });
      AppSnackbar.showSuccess(context, message: 'Tüm bildirimler okundu işaretlendi');
    }
  }

  Future<void> _deleteNotification(AppNotification notification) async {
    final success = await notificationService.deleteNotification(notification.id);
    if (success && mounted) {
      setState(() {
        _notifications.removeWhere((n) => n.id == notification.id);
      });
      AppSnackbar.showSuccess(context, message: 'Bildirim silindi');
    }
  }

  void _handleNotificationTap(AppNotification notification) {
    _markAsRead(notification);

    // Navigate based on action URL or entity type
    if (notification.actionUrl != null) {
      context.push(notification.actionUrl!);
    } else if (notification.entityType != null && notification.entityId != null) {
      switch (notification.entityType) {
        case 'unit':
          context.push('/units/${notification.entityId}');
          break;
        case 'site':
          context.push('/sites');
          break;
        case 'organization':
          context.push('/organizations');
          break;
        default:
          // Show notification details
          _showNotificationDetail(notification);
      }
    } else {
      _showNotificationDetail(notification);
    }
  }

  void _showNotificationDetail(AppNotification notification) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.6,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.separator(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  _NotificationIcon(type: notification.type),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      notification.title,
                      style: AppTypography.title3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                notification.message,
                style: AppTypography.body,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppColors.secondaryLabel(context),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    notification.timeAgo,
                    style: AppTypography.caption1.copyWith(
                      color: AppColors.secondaryLabel(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Kapat',
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _notifications.any((n) => !n.isRead);

    return AppScaffold(
      title: 'Bildirimler',
      showBackButton: true,
      onBack: () => context.go('/home'),
      actions: [
        if (hasUnread)
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text('Tümünü Oku'),
          ),
      ],
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: AppLoadingIndicator());
    }

    if (_error != null) {
      return AppErrorView(
        title: 'Hata',
        message: _error!,
        actionLabel: 'Tekrar Dene',
        onAction: _loadNotifications,
      );
    }

    if (_notifications.isEmpty) {
      return const AppEmptyState(
        icon: Icons.notifications_off_outlined,
        title: 'Bildirim Yok',
        message: 'Henüz bildiriminiz bulunmuyor.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        padding: AppSpacing.screenPadding,
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return _NotificationListItem(
            notification: notification,
            onTap: () => _handleNotificationTap(notification),
            onDismiss: () => _deleteNotification(notification),
          );
        },
      ),
    );
  }
}

class _NotificationListItem extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationListItem({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      child: AppCard(
        onTap: onTap,
        child: Container(
          padding: AppSpacing.cardInsets,
          decoration: BoxDecoration(
            border: notification.isRead
                ? null
                : Border(
                    left: BorderSide(
                      color: AppColors.primary,
                      width: 3,
                    ),
                  ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NotificationIcon(type: notification.type),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: AppTypography.subheadline.copyWith(
                        fontWeight:
                            notification.isRead ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      notification.message,
                      style: AppTypography.footnote.copyWith(
                        color: AppColors.secondaryLabel(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      notification.timeAgo,
                      style: AppTypography.caption2.copyWith(
                        color: AppColors.tertiaryLabel(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (!notification.isRead)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationIcon extends StatelessWidget {
  final NotificationType? type;

  const _NotificationIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _getColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        _getIcon(),
        color: _getColor(),
        size: 20,
      ),
    );
  }

  IconData _getIcon() {
    switch (type) {
      case NotificationType.alert:
        return Icons.warning_amber;
      case NotificationType.reminder:
        return Icons.alarm;
      case NotificationType.info:
        return Icons.info_outline;
      case null:
        return Icons.notifications_outlined;
    }
  }

  Color _getColor() {
    switch (type) {
      case NotificationType.alert:
        return Colors.orange;
      case NotificationType.reminder:
        return Colors.blue;
      case NotificationType.info:
        return Colors.teal;
      case null:
        return Colors.grey;
    }
  }
}
