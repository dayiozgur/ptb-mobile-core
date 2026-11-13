import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/widget_test_helpers.dart';

class MockWorkflowService extends Mock implements WorkflowService {}

/// The approvals inbox must never say "no approvals waiting for you" when it
/// could not load them (timeout / network / refused).
void main() {
  late MockWorkflowService workflow;

  setUp(() async {
    await sl.reset();
    workflow = MockWorkflowService();
    registerFake<WorkflowService>(workflow);
    registerFake<LocalizationService>(buildFakeLocalization(
      overrides: AppLocalizations.getTranslations(AppLocale.english),
      locale: AppLocale.english,
    ));
  });

  tearDown(() async => sl.reset());

  Widget host() => const MaterialApp(home: ApprovalsInboxScreen());

  testWidgets('timeout → "could not load" + retry, not the empty state',
      (tester) async {
    var calls = 0;
    when(() => workflow.pendingApprovalsOrThrow()).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        throw const PostgrestException(
            message: 'canceling statement due to statement timeout',
            code: '57014');
      }
      return const <WorkflowApproval>[];
    });

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Could not load approvals.'), findsOneWidget);
    expect(find.text('No approvals waiting for you.'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('No approvals waiting for you.'), findsOneWidget);
    expect(find.text('Could not load approvals.'), findsNothing);
  });

  testWidgets('refused (42501) → "no access", no retry', (tester) async {
    when(() => workflow.pendingApprovalsOrThrow()).thenThrow(
        const PostgrestException(message: 'permission denied', code: '42501'));

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.byType(AppNoAccessView), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(find.text('No approvals waiting for you.'), findsNothing);
  });

  testWidgets('a genuinely empty inbox says so (translated title)',
      (tester) async {
    when(() => workflow.pendingApprovalsOrThrow())
        .thenAnswer((_) async => const <WorkflowApproval>[]);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('My approvals'), findsOneWidget);
    expect(find.text('No approvals waiting for you.'), findsOneWidget);
  });

  testWidgets('a refused decision shows the translated reason, not the raw '
      'exception', (tester) async {
    when(() => workflow.pendingApprovalsOrThrow()).thenAnswer((_) async => [
          WorkflowApproval.fromJson(const {'id': 'a1', 'title': 'Leave for Ada'}),
        ]);
    when(() => workflow.decideApproval(
          approvalId: 'a1',
          approve: true,
          note: any(named: 'note'),
        )).thenThrow(const PostgrestException(
        message: 'new row violates row-level security policy for table "workflow_approvals"',
        code: '42501'));

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(find.text('You do not have permission to perform this action'),
        findsOneWidget);
    expect(find.textContaining('row-level security'), findsNothing);
    expect(find.text('Leave for Ada'), findsOneWidget);
  });
}
