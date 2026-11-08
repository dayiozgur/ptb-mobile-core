import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

void main() {
  tearDown(() {
    InAppRoute.resetConfig();
    ScreenResolver.reset();
  });

  group('normalize', () {
    test('relative paths pass through, missing slash is added', () {
      expect(InAppRoute.normalize('/fixflow/tickets/1'), '/fixflow/tickets/1');
      expect(InAppRoute.normalize(' hr/leave/my-requests '),
          '/hr/leave/my-requests');
    });

    test('empty / null → null', () {
      expect(InAppRoute.normalize(null), isNull);
      expect(InAppRoute.normalize('   '), isNull);
    });

    test('absolute URL only for an owned host (path + query kept)', () {
      expect(InAppRoute.normalize('https://app.crm.protoolbag.com/crm/x?a=1'),
          isNull,
          reason: 'no host configured → reject absolute URLs');
      InAppRoute.configure(appHosts: {'App.CRM.protoolbag.com'});
      expect(InAppRoute.normalize('https://app.crm.protoolbag.com/crm/x?a=1'),
          '/crm/x?a=1');
      expect(InAppRoute.normalize('https://evil.example.com/crm/x'), isNull);
      expect(
          InAppRoute.normalize('https://evil.example.com/x',
              appHosts: const {'evil.example.com'}),
          '/x');
    });
  });

  group('fromPayload', () {
    test('action_url wins, then route / deep_link / screen', () {
      expect(
          InAppRoute.fromPayload(
              {'action_url': '/fixflow/tickets/1', 'route': '/notifications'}),
          '/fixflow/tickets/1');
      expect(InAppRoute.fromPayload({'route': '/notifications'}),
          '/notifications');
      expect(InAppRoute.fromPayload({'screen': 'settings'}), '/settings');
      expect(InAppRoute.fromPayload({'route': ' '}), isNull);
      expect(InAppRoute.fromPayload(null), isNull);
    });
  });

  test('isShellRoute uses the configured set and ignores the query', () {
    expect(InAppRoute.isShellRoute('/settings?tab=1'), isTrue);
    expect(InAppRoute.isShellRoute('/crm/deals'), isFalse);
    InAppRoute.configure(shellRoutes: {'/home'});
    expect(InAppRoute.isShellRoute('/home'), isTrue);
    expect(InAppRoute.isShellRoute('/settings'), isFalse);
  });

  group('open', () {
    testWidgets('non-shell path → pushes the resolved screen', (tester) async {
      ScreenResolver.addResolver((item) =>
          item.path == '/x/target' ? const Text('TARGET') : null);
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(navigatorKey: key, home: const Text('HOME')));

      expect(InAppRoute.open('/x/target', navigatorKey: key), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('TARGET'), findsOneWidget);
    });

    testWidgets('requireScreen skips paths with no mobile screen',
        (tester) async {
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(navigatorKey: key, home: const Text('HOME')));

      expect(
          InAppRoute.open('/nowhere', navigatorKey: key, requireScreen: true),
          isFalse);
      expect(InAppRoute.open('/nowhere', navigatorKey: key), isTrue,
          reason: 'without requireScreen it falls back to ComingSoon');
      expect(InAppRoute.open('/', navigatorKey: key), isFalse);
    });

    testWidgets('shell route → go_router', (tester) async {
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => const Text('ROOT')),
        GoRoute(path: '/settings', builder: (_, __) => const Text('SETTINGS')),
      ]);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      final ctx = tester.element(find.text('ROOT'));

      expect(InAppRoute.open('/settings', context: ctx), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('SETTINGS'), findsOneWidget);
    });
  });
}
