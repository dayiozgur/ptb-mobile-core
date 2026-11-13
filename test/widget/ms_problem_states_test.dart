import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../helpers/supabase_fakes.dart';
import '../helpers/widget_test_helpers.dart';

class MockMicrosoftIntegrationService extends Mock
    implements MicrosoftIntegrationService {}

/// A failed Microsoft load is an honest, translated state — never an empty
/// list (mail inbox, OneDrive picker, Planner plan list).
void main() {
  late MockMicrosoftIntegrationService ms;

  const connected = IntegrationConnection(
    id: 'c1',
    provider: 'microsoft',
    status: 'connected',
    accountEmail: 'a@b.c',
    syncEnabled: true,
    scopes: ['Mail.Read'],
  );

  setUp(() async {
    await sl.reset();
    MicrosoftOAuthReturn.reset();
    ms = MockMicrosoftIntegrationService();
    registerFake<MicrosoftIntegrationService>(ms);
    registerFake<LocalizationService>(buildFakeLocalization(
      overrides: AppLocalizations.getTranslations(AppLocale.english),
      locale: AppLocale.english,
    ));
  });

  tearDown(() async {
    await sl.reset();
    MicrosoftOAuthReturn.reset();
  });

  Widget host(Widget child) => MaterialApp(home: child);

  void stubInbox(GraphResult result) {
    when(() => ms.graphCall('GET', '/me/mailFolders/inbox/messages',
        query: any(named: 'query'))).thenAnswer((_) async => result);
  }

  group('MsProblemView', () {
    testWidgets('throttled: retry is disabled until the countdown ends',
        (tester) async {
      var retried = 0;
      await tester.pumpWidget(host(Scaffold(
        body: MsProblemView(
          problem: const GraphProblem(
              kind: GraphProblemKind.throttled, status: 429, retryAfterSeconds: 3),
          onRetry: () => retried++,
        ),
      )));

      expect(find.text('Microsoft is temporarily limiting requests'),
          findsOneWidget);
      expect(find.text('Try again in 3 s'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ms-problem-retry')));
      expect(retried, 0, reason: 'disabled while Microsoft asks us to wait');

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Try again in 2 s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ms-problem-retry')));
      expect(retried, 1);
    });

    testWidgets('not connected → Connect; reauth / missing consent → Reconnect',
        (tester) async {
      var connects = 0;
      Future<void> pump(GraphProblemKind k) => tester.pumpWidget(host(Scaffold(
            body: MsProblemView(
              key: ValueKey(k),
              problem: GraphProblem(kind: k),
              onConnect: () => connects++,
              onRetry: () {},
            ),
          )));

      await pump(GraphProblemKind.notConnected);
      expect(find.text('No Microsoft 365 account connected'), findsOneWidget);
      expect(find.text('Connect with Microsoft'), findsOneWidget);
      expect(find.byKey(const ValueKey('ms-problem-retry')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('ms-problem-connect')));
      expect(connects, 1);

      await pump(GraphProblemKind.reauth);
      expect(find.text('Your Microsoft connection needs to be renewed'),
          findsOneWidget);
      expect(find.text('Reconnect'), findsOneWidget);

      await pump(GraphProblemKind.missingConsent);
      expect(
          find.text(
              'The Microsoft permission for this feature has not been granted'),
          findsOneWidget);
      expect(find.text('Reconnect'), findsOneWidget);
      expect(find.byKey(const ValueKey('ms-problem-hub')), findsOneWidget);
    });

    testWidgets('admin consent required: no reconnect loop, no retry',
        (tester) async {
      await tester.pumpWidget(host(Scaffold(
        body: MsProblemView(
          problem:
              const GraphProblem(kind: GraphProblemKind.adminConsentRequired),
          onRetry: () {},
        ),
      )));
      expect(find.text('Your Microsoft 365 administrator has to approve this'),
          findsOneWidget);
      expect(find.byKey(const ValueKey('ms-problem-connect')), findsNothing);
      expect(find.byKey(const ValueKey('ms-problem-retry')), findsNothing);
      expect(find.byKey(const ValueKey('ms-problem-hub')), findsOneWidget);
    });

    testWidgets('blocked: explanation only', (tester) async {
      await tester.pumpWidget(host(Scaffold(
        body: MsProblemView(
          problem: const GraphProblem(kind: GraphProblemKind.blocked),
          onRetry: () {},
        ),
      )));
      expect(find.text('This action is not available right now'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    test('toast text fills the web {{seconds}} placeholder', () {
      expect(
        msProblemToast(const GraphProblem(
            kind: GraphProblemKind.throttled, retryAfterSeconds: 42)),
        'Microsoft is temporarily limiting requests. Try again in 42 s.',
      );
    });
  });

  group('MsMailboxScreen', () {
    testWidgets('throttled inbox → throttled state, not "inbox is empty"',
        (tester) async {
      when(() => ms.lookupConnection())
          .thenAnswer((_) async => const ConnectionLookup(connection: connected));
      stubInbox(GraphResult.failure(const GraphProblem(
          kind: GraphProblemKind.throttled, status: 429, retryAfterSeconds: 5)));

      await tester.pumpWidget(host(const MsMailboxScreen()));
      await tester.pump();
      await tester.pump();

      expect(find.text('Microsoft is temporarily limiting requests'),
          findsOneWidget);
      expect(find.text('crm.mailbox.empty'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      // let the countdown timer finish so no timer is pending at teardown
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('missing Mail.Read consent → missing-consent state',
        (tester) async {
      when(() => ms.lookupConnection())
          .thenAnswer((_) async => const ConnectionLookup(connection: connected));
      stubInbox(GraphResult.failure(
          const GraphProblem(kind: GraphProblemKind.missingConsent, status: 403)));

      await tester.pumpWidget(host(const MsMailboxScreen()));
      await tester.pump();
      await tester.pump();

      expect(
          find.text(
              'The Microsoft permission for this feature has not been granted'),
          findsOneWidget);
      expect(find.text('Reconnect'), findsOneWidget);
    });

    testWidgets('no connection → not-connected state with Connect',
        (tester) async {
      when(() => ms.lookupConnection())
          .thenAnswer((_) async => const ConnectionLookup());

      await tester.pumpWidget(host(const MsMailboxScreen()));
      await tester.pump();
      await tester.pump();

      expect(find.text('No Microsoft 365 account connected'), findsOneWidget);
      expect(find.text('Connect with Microsoft'), findsOneWidget);
      verifyNever(() => ms.graphCall(any(), any(), query: any(named: 'query')));
    });

    testWidgets('connection could not be checked → unavailable, not "not connected"',
        (tester) async {
      when(() => ms.lookupConnection())
          .thenAnswer((_) async => const ConnectionLookup(failed: true));

      await tester.pumpWidget(host(const MsMailboxScreen()));
      await tester.pump();
      await tester.pump();

      expect(find.text('Microsoft 365 cannot be reached right now'),
          findsOneWidget);
      expect(find.text('No Microsoft 365 account connected'), findsNothing);
    });

    testWidgets('a genuinely empty inbox still says empty', (tester) async {
      when(() => ms.lookupConnection())
          .thenAnswer((_) async => const ConnectionLookup(connection: connected));
      stubInbox(const GraphResult(200, {'value': []}));

      await tester.pumpWidget(host(const MsMailboxScreen()));
      await tester.pump();
      await tester.pump();

      expect(find.text('crm.mailbox.empty'), findsOneWidget);
      expect(find.byType(MsProblemView), findsNothing);
    });
  });

  group('PlannerLinkService', () {
    late SupabaseHarness h;
    late PlannerLinkService planner;

    setUp(() {
      h = SupabaseHarness();
      planner = PlannerLinkService(supabase: h.client, ms: ms);
    });

    test('a failed plan list carries the problem (not "no plans")', () async {
      when(() => ms.graphCall('GET', '/me/planner/plans')).thenAnswer(
          (_) async => GraphResult.failure(const GraphProblem(
              kind: GraphProblemKind.missingConsent, status: 403)));
      final res = await planner.listPlans();
      expect(res.ok, isFalse);
      expect(res.plans, isEmpty);
      expect(res.problem!.kind, GraphProblemKind.missingConsent);
    });

    test('plans are listed; ids that are not Planner ids are dropped',
        () async {
      when(() => ms.graphCall('GET', '/me/planner/plans'))
          .thenAnswer((_) async => const GraphResult(200, {
                'value': [
                  {'id': 'xqQg5FS2LkCp935s-FIFm2QAFkHM', 'title': 'Roadmap'},
                  {'id': '../x', 'title': 'bad'},
                ]
              }));
      final res = await planner.listPlans();
      expect(res.ok, isTrue);
      expect(res.plans.map((p) => p.title), ['Roadmap']);
    });

    test('plan id format matches the server CHECK ^[A-Za-z0-9_-]{8,64}\$', () {
      expect(PlannerLinkService.isValidPlanId('xqQg5FS2LkCp935s-FIFm2QAFkHM'),
          isTrue);
      expect(PlannerLinkService.isValidPlanId('short'), isFalse);
      expect(PlannerLinkService.isValidPlanId('has/slash-in-it'), isFalse);
      expect(PlannerLinkService.isValidPlanId('has space in it'), isFalse);
      expect(PlannerLinkService.isValidPlanId('a' * 65), isFalse);
      expect(PlannerLinkService.isValidPlanId(null), isFalse);
    });

    test('link() never writes a plan id the server would refuse', () async {
      h.stubFrom('planner_plan_links', result: <String, dynamic>{});
      final link = await planner.link(
        projectEntityId: 'p1',
        plan: const PlannerPlan(id: '../../me/messages', title: 't'),
        bucketBy: 'status',
      );
      expect(link, isNull);
      verifyNever(() => h.client.from('planner_plan_links'));
    });

    test('sync that found no eligible connection is not reported as success',
        () async {
      h.stubFunction('ppm-planner-sync', data: {
        'mode': 'user',
        'synced': 0,
        'connections': [],
        'note': 'no connected Microsoft account with Tasks.ReadWrite',
      });
      final res = await planner.syncNow();
      expect(res!.noEligibleConnection, isTrue);
    });
  });
}
