import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../helpers/supabase_fakes.dart';
import '../helpers/widget_test_helpers.dart';

/// Widget tests for [NotificationsScreen] — the read screen's loading and
/// empty states.
///
/// `initState` resolves the current profile id from `authService.currentUser`,
/// subscribes to `notificationService.notificationsStream`, starts realtime
/// listening, then loads via `getNotifications(...)`. We fake all of that:
///   * a signed-in user (so `profileService` is never touched),
///   * an empty notifications stream,
///   * `getNotifications` driven by a [Completer] so the pending future can be
///     observed as the spinner, then completed to reveal the empty state.
void main() {
  late MockAuthService auth;
  late MockNotificationService notifications;
  late MockUser user;

  setUp(() async {
    await sl.reset();

    auth = MockAuthService();
    notifications = MockNotificationService();
    user = MockUser();

    when(() => user.id).thenReturn('user-1');
    when(() => auth.currentUser).thenReturn(user);

    // Live stream + realtime start/stop are stubbed to no-ops.
    when(() => notifications.notificationsStream)
        .thenAnswer((_) => const Stream<List<AppNotification>>.empty());
    when(() => notifications.startListening(any())).thenAnswer((_) async {});
    when(() => notifications.stopListening()).thenAnswer((_) async {});

    registerFake<AuthService>(auth);
    registerFake<NotificationService>(notifications);
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('shows a spinner while notifications are loading',
      (tester) async {
    final completer = Completer<List<AppNotification>>();
    when(() => notifications.getNotifications('user-1',
        forceRefresh: any(named: 'forceRefresh'))).thenAnswer(
      (_) => completer.future,
    );

    await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
    await tester.pump(); // run initState micro-tasks; future still pending

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Bildirim yok'), findsNothing);

    // Let the future resolve so no timers/futures dangle past the test.
    completer.complete(const <AppNotification>[]);
    await tester.pumpAndSettle();
  });

  testWidgets('renders the empty state when there are no notifications',
      (tester) async {
    when(() => notifications.getNotifications('user-1',
            forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => const <AppNotification>[]);

    await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(AppEmptyState), findsOneWidget);
    expect(find.text('Bildirim yok'), findsOneWidget);
    expect(find.text('Henüz bildiriminiz bulunmuyor.'), findsOneWidget);
  });

  testWidgets('renders a notification tile when the service returns data',
      (tester) async {
    when(() => notifications.getNotifications('user-1',
        forceRefresh: any(named: 'forceRefresh'))).thenAnswer(
      (_) async => [
        AppNotification(
          id: 'n-1',
          title: 'Yeni iş emri',
          description: 'Size bir iş emri atandı',
          type: NotificationType.info,
          isRead: false,
          dateTime: DateTime(2026, 8, 21, 9),
        ),
      ],
    );

    await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Bildirim yok'), findsNothing);
    expect(find.text('Yeni iş emri'), findsOneWidget);
    // Unread present → the "mark all read" app-bar action shows.
    expect(find.byIcon(Icons.done_all), findsOneWidget);
  });
}
