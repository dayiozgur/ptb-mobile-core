import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:protoolbag_fixflow/config/fixflow_app_screens.dart';
import 'package:protoolbag_fixflow/config/push_routing.dart';

/// Push tap → uygulama-içi yol. FixFlow EF'leri `notifications.action_url`
/// olarak `/fixflow/tickets/<id>` yazar; tap bunu iş emri detayına açmalı.
void main() {
  const id = '7d3c1b52-2f4e-4c55-9a51-0d6c9a1f2e10';

  setUpAll(registerFixflowAppScreens);

  group('fixflowNotificationRoute', () {
    test('action_url önceliklidir', () {
      expect(
        fixflowNotificationRoute(
            {'action_url': '/fixflow/tickets/$id', 'route': '/notifications'}),
        '/fixflow/tickets/$id',
      );
    });

    test('route / deep_link / screen yedekleri', () {
      expect(fixflowNotificationRoute({'route': '/notifications'}),
          '/notifications');
      expect(fixflowNotificationRoute({'deep_link': 'fixflow/sla'}),
          '/fixflow/sla');
      expect(fixflowNotificationRoute({'screen': '/settings'}), '/settings');
    });

    test('entityType=ticket + entityId → ticket detayı', () {
      expect(
        fixflowNotificationRoute({'entityType': 'ticket', 'entityId': id}),
        '/fixflow/tickets/$id',
      );
      expect(
        fixflowNotificationRoute({'entity_type': 'tickets', 'entity_id': id}),
        '/fixflow/tickets/$id',
      );
      expect(
        fixflowNotificationRoute({'entityType': 'alarm', 'entityId': id}),
        isNull,
      );
    });

    test('veri yok → null', () {
      expect(fixflowNotificationRoute(null), isNull);
      expect(fixflowNotificationRoute({}), isNull);
      expect(fixflowNotificationRoute({'route': '  '}), isNull);
    });
  });

  group('normalizeFixflowRoute', () {
    test('kendi universal-link host → yol+query', () {
      expect(
        normalizeFixflowRoute(
            'https://app.fixflow.protoolbag.com/fixflow/tickets/$id?x=1'),
        '/fixflow/tickets/$id?x=1',
      );
    });

    test('yabancı host reddedilir', () {
      expect(normalizeFixflowRoute('https://evil.example.com/fixflow/tickets'),
          isNull);
    });
  });

  test('shell rotaları go_router, diğerleri ScreenResolver', () {
    expect(isFixflowShellRoute('/main'), isTrue);
    expect(isFixflowShellRoute('/settings?tab=1'), isTrue);
    expect(isFixflowShellRoute('/fixflow/tickets/$id'), isFalse);
  });

  test('ticket deep-link ekranı = FixflowTicketDetailScreen', () {
    final route =
        fixflowNotificationRoute({'action_url': '/fixflow/tickets/$id'})!;
    final w = fixflowScreenForRoute(route);
    expect(w, isA<FixflowTicketDetailScreen>());
    expect((w as FixflowTicketDetailScreen).ticketId, id);
  });

  test('mevcut DB tetikleyici route=/notifications → bildirim listesi', () {
    expect(fixflowScreenForRoute('/notifications'), isA<NotificationsScreen>());
  });
}
