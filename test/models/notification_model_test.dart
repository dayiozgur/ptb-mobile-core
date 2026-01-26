import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

void main() {
  group('NotificationType', () {
    test('fromString returns correct type', () {
      expect(NotificationType.fromString('ALERT'), NotificationType.alert);
      expect(NotificationType.fromString('REMINDER'), NotificationType.reminder);
      expect(NotificationType.fromString('INFO'), NotificationType.info);
    });

    test('fromString returns null for invalid value', () {
      expect(NotificationType.fromString('INVALID'), isNull);
      expect(NotificationType.fromString(null), isNull);
      expect(NotificationType.fromString(''), isNull);
    });

    test('value returns correct string', () {
      expect(NotificationType.alert.value, 'ALERT');
      expect(NotificationType.reminder.value, 'REMINDER');
      expect(NotificationType.info.value, 'INFO');
    });

    test('label returns correct label', () {
      expect(NotificationType.alert.label, 'Uyarı');
      expect(NotificationType.reminder.label, 'Hatırlatma');
      expect(NotificationType.info.label, 'Bilgi');
    });
  });

  group('NotificationEntityType', () {
    test('fromString returns correct type', () {
      expect(NotificationEntityType.fromString('INVOICE'), NotificationEntityType.invoice);
      expect(NotificationEntityType.fromString('PRODUCTION'), NotificationEntityType.production);
      expect(NotificationEntityType.fromString('UNIT'), NotificationEntityType.unit);
    });

    test('fromString returns null for invalid value', () {
      expect(NotificationEntityType.fromString('INVALID'), isNull);
      expect(NotificationEntityType.fromString(null), isNull);
    });

    test('all entity types have correct values', () {
      expect(NotificationEntityType.invoice.value, 'INVOICE');
      expect(NotificationEntityType.production.value, 'PRODUCTION');
      expect(NotificationEntityType.product.value, 'PRODUCT');
      expect(NotificationEntityType.blueprint.value, 'BLUEPRINT');
      expect(NotificationEntityType.productionOrder.value, 'PRODUCTION_ORDER');
      expect(NotificationEntityType.controller.value, 'CONTROLLER');
      expect(NotificationEntityType.provider.value, 'PROVIDER');
      expect(NotificationEntityType.item.value, 'ITEM');
      expect(NotificationEntityType.unit.value, 'UNIT');
    });
  });

  group('NotificationPriority', () {
    test('predefined priorities have correct values', () {
      expect(NotificationPriority.low.value, 0);
      expect(NotificationPriority.normal.value, 5);
      expect(NotificationPriority.high.value, 8);
      expect(NotificationPriority.urgent.value, 11);
    });

    test('label returns correct string', () {
      expect(NotificationPriority.low.label, 'Düşük');
      expect(NotificationPriority.normal.label, 'Normal');
      expect(NotificationPriority.high.label, 'Yüksek');
      expect(NotificationPriority.urgent.label, 'Acil');
    });

    test('priority level checks work correctly', () {
      expect(NotificationPriority.low.isLow, true);
      expect(NotificationPriority.low.isNormal, false);

      expect(NotificationPriority.normal.isNormal, true);
      expect(NotificationPriority.normal.isLow, false);

      expect(NotificationPriority.high.isHigh, true);
      expect(NotificationPriority.high.isNormal, false);

      expect(NotificationPriority.urgent.isUrgent, true);
      expect(NotificationPriority.urgent.isHigh, false);
    });

    test('custom priority works', () {
      const customPriority = NotificationPriority(3);
      expect(customPriority.value, 3);
      expect(customPriority.isNormal, true);
      expect(customPriority.label, 'Normal');
    });
  });

  group('AppNotification', () {
    final testNotification = AppNotification(
      id: 'notif-123',
      rowId: 1,
      active: true,
      title: 'Test Notification',
      description: 'This is a test notification',
      type: NotificationType.alert,
      priority: NotificationPriority.high,
      entityType: NotificationEntityType.unit,
      entityId: 'unit-123',
      dateTime: DateTime(2024, 1, 15, 10, 30),
      isRead: false,
      sent: true,
      acknowledged: false,
      platformId: 'platform-123',
      profileId: 'profile-123',
      createdAt: DateTime(2024, 1, 15, 10, 0),
    );

    test('fromJson parses correctly', () {
      final json = {
        'id': 'notif-123',
        'row_id': 1,
        'active': true,
        'title': 'Test Notification',
        'description': 'This is a test notification',
        'notification_type': 'ALERT',
        'priority': 8,
        'entity_type': 'UNIT',
        'entity_id': 'unit-123',
        'date_time': '2024-01-15T10:30:00',
        'read': false,
        'sent': true,
        'acknowledged': false,
        'platform_id': 'platform-123',
        'profile_id': 'profile-123',
        'created_at': '2024-01-15T10:00:00',
      };

      final notification = AppNotification.fromJson(json);

      expect(notification.id, 'notif-123');
      expect(notification.rowId, 1);
      expect(notification.active, true);
      expect(notification.title, 'Test Notification');
      expect(notification.description, 'This is a test notification');
      expect(notification.type, NotificationType.alert);
      expect(notification.priority.value, 8);
      expect(notification.entityType, NotificationEntityType.unit);
      expect(notification.entityId, 'unit-123');
      expect(notification.isRead, false);
      expect(notification.sent, true);
      expect(notification.acknowledged, false);
    });

    test('toJson serializes correctly', () {
      final json = testNotification.toJson();

      expect(json['id'], 'notif-123');
      expect(json['row_id'], 1);
      expect(json['active'], true);
      expect(json['title'], 'Test Notification');
      expect(json['notification_type'], 'ALERT');
      expect(json['priority'], 8);
      expect(json['entity_type'], 'UNIT');
      expect(json['entity_id'], 'unit-123');
      expect(json['read'], false);
      expect(json['sent'], true);
    });

    test('copyWith creates correct copy', () {
      final copy = testNotification.copyWith(
        title: 'Updated Title',
        isRead: true,
      );

      expect(copy.id, testNotification.id);
      expect(copy.title, 'Updated Title');
      expect(copy.isRead, true);
      expect(copy.description, testNotification.description);
      expect(copy.type, testNotification.type);
    });

    test('message returns description or title', () {
      expect(testNotification.message, 'This is a test notification');

      final notifWithoutDescription = AppNotification(
        id: 'notif-2',
        title: 'Only Title',
      );
      expect(notifWithoutDescription.message, 'Only Title');

      final notifWithoutBoth = AppNotification(id: 'notif-3');
      expect(notifWithoutBoth.message, '');
    });

    test('timeAgo returns correct relative time', () {
      // Create notification with recent time
      final recentNotification = AppNotification(
        id: 'recent',
        dateTime: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      expect(recentNotification.timeAgo.contains('dakika'), true);

      final hourAgoNotification = AppNotification(
        id: 'hour-ago',
        dateTime: DateTime.now().subtract(const Duration(hours: 2)),
      );
      expect(hourAgoNotification.timeAgo.contains('saat'), true);

      final dayAgoNotification = AppNotification(
        id: 'day-ago',
        dateTime: DateTime.now().subtract(const Duration(days: 3)),
      );
      expect(dayAgoNotification.timeAgo.contains('gün'), true);
    });

    test('equality works correctly', () {
      final notif1 = AppNotification(id: 'notif-1', title: 'Test');
      final notif2 = AppNotification(id: 'notif-1', title: 'Different');
      final notif3 = AppNotification(id: 'notif-2', title: 'Test');

      expect(notif1, equals(notif2));
      expect(notif1, isNot(equals(notif3)));
    });

    test('hashCode is based on id', () {
      final notif1 = AppNotification(id: 'notif-1', title: 'Test');
      final notif2 = AppNotification(id: 'notif-1', title: 'Different');

      expect(notif1.hashCode, equals(notif2.hashCode));
    });

    test('toString returns correct format', () {
      final string = testNotification.toString();

      expect(string.contains('notif-123'), true);
      expect(string.contains('Test Notification'), true);
    });
  });

  group('NotificationProfile', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'profile-123',
        'full_name': 'John Doe',
        'avatar_url': 'https://example.com/avatar.png',
      };

      final profile = NotificationProfile.fromJson(json);

      expect(profile.id, 'profile-123');
      expect(profile.fullName, 'John Doe');
      expect(profile.avatarUrl, 'https://example.com/avatar.png');
    });

    test('toJson serializes correctly', () {
      final profile = NotificationProfile(
        id: 'profile-123',
        fullName: 'John Doe',
        avatarUrl: 'https://example.com/avatar.png',
      );

      final json = profile.toJson();

      expect(json['id'], 'profile-123');
      expect(json['full_name'], 'John Doe');
      expect(json['avatar_url'], 'https://example.com/avatar.png');
    });
  });

  group('NotificationSummary', () {
    test('creates correctly', () {
      final summary = NotificationSummary(
        total: 10,
        unread: 3,
        unacknowledged: 2,
        byType: {
          NotificationType.alert: 5,
          NotificationType.info: 5,
        },
      );

      expect(summary.total, 10);
      expect(summary.unread, 3);
      expect(summary.unacknowledged, 2);
      expect(summary.byType.length, 2);
    });

    test('hasUnread returns correct value', () {
      final summaryWithUnread = NotificationSummary(total: 10, unread: 3);
      expect(summaryWithUnread.hasUnread, true);

      final summaryWithoutUnread = NotificationSummary(total: 10, unread: 0);
      expect(summaryWithoutUnread.hasUnread, false);
    });

    test('hasUnacknowledged returns correct value', () {
      final summaryWithUnack = NotificationSummary(
        total: 10,
        unread: 0,
        unacknowledged: 2,
      );
      expect(summaryWithUnack.hasUnacknowledged, true);

      final summaryWithoutUnack = NotificationSummary(
        total: 10,
        unread: 0,
        unacknowledged: 0,
      );
      expect(summaryWithoutUnack.hasUnacknowledged, false);
    });

    test('empty factory creates empty summary', () {
      final empty = NotificationSummary.empty();

      expect(empty.total, 0);
      expect(empty.unread, 0);
      expect(empty.unacknowledged, 0);
      expect(empty.hasUnread, false);
    });
  });
}
