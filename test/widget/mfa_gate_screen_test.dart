import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../core/auth/mfa_gate_test.dart' show FakeMfaBackend, req;
import '../helpers/widget_test_helpers.dart';

/// The administrator's "requirement unavailable" state: retry or sign out,
/// never a way into the app.
void main() {
  final gate = MfaGate.instance;
  late MfaGateBackend original;

  setUp(() async {
    await sl.reset();
    original = gate.backend;
    registerFake<LocalizationService>(buildFakeLocalization(
      overrides: AppLocalizations.getTranslations(AppLocale.english),
      locale: AppLocale.english,
    ));
  });

  tearDown(() async {
    gate.backend = original;
    gate.clear();
    await sl.reset();
  });

  Widget host() => MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/mfa-gate',
          routes: [
            GoRoute(
                path: '/mfa-gate', builder: (_, __) => const MfaGateScreen()),
            GoRoute(
                path: '/main',
                builder: (_, __) => const Scaffold(body: Text('MAIN'))),
          ],
        ),
      );

  testWidgets('unavailable → message, retry and sign-out; no way in',
      (tester) async {
    final backend = FakeMfaBackend(requirementError: Exception('offline'));
    gate.backend = backend;
    await gate.evaluate(role: CoarseRoles.admin);
    expect(gate.state, MfaStepUp.unavailable);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mfa-gate-unavailable')), findsOneWidget);
    expect(find.textContaining('could not be read right now'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('MAIN'), findsNothing);

    // Still failing → stays on the retry state.
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mfa-gate-unavailable')), findsOneWidget);
    expect(backend.requirementCalls, 2);

    // Recovers and the requirement is "not required" → into the app.
    backend
      ..requirementError = null
      ..requirement = req();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('MAIN'), findsOneWidget);
  });
}
