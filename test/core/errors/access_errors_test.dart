import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  group('AccessErrors.isDenied', () {
    test('42501 (RLS write violation / revoked grant / RPC raise)', () {
      expect(
          AccessErrors.isDenied(const PostgrestException(
              message:
                  'new row violates row-level security policy for table "staff_documents"',
              code: '42501')),
          isTrue);
      expect(
          AccessErrors.isDenied(const PostgrestException(
              message: 'permission denied for table staffs', code: '42501')),
          isTrue);
    });

    test('permission wording without the code', () {
      expect(
          AccessErrors.isDenied(const PostgrestException(
              message: 'permission denied for column gross_salary')),
          isTrue);
    });

    test('Edge Function 403 / ERR_FORBIDDEN', () {
      expect(
          AccessErrors.isDenied(const FunctionException(
              status: 403, details: {'error': 'not permitted'})),
          isTrue);
      expect(
          AccessErrors.isDenied(const FunctionException(
              status: 400, details: {'code': 'ERR_FORBIDDEN'})),
          isTrue);
    });

    test('other failures are NOT "no access"', () {
      expect(
          AccessErrors.isDenied(const PostgrestException(
              message: 'canceling statement due to statement timeout',
              code: '57014')),
          isFalse);
      expect(
          AccessErrors.isDenied(const PostgrestException(
              message: 'JWT expired', code: 'PGRST301')),
          isFalse);
      expect(AccessErrors.isDenied(const FunctionException(status: 401)),
          isFalse);
      expect(AccessErrors.isDenied(const FunctionException(status: 500)),
          isFalse);
      expect(AccessErrors.isDenied(Exception('socket closed')), isFalse);
      expect(AccessErrors.isDenied(null), isFalse);
    });
  });

  group('views', () {
    setUp(() async {
      await sl.reset();
      registerFake<LocalizationService>(buildFakeLocalization(
        overrides: AppLocalizations.getTranslations(AppLocale.english),
        locale: AppLocale.english,
      ));
    });
    tearDown(() async => sl.reset());

    test('actionMessage: translated refusal, else the caller\'s fallback — '
        'never the raw exception', () {
      const denied = PostgrestException(
          message: 'new row violates row-level security policy', code: '42501');
      expect(AccessErrors.actionMessage(denied, fallback: 'Could not save'),
          'You do not have permission to perform this action');
      expect(
          AccessErrors.actionMessage(Exception('boom'),
              fallback: 'Could not save'),
          'Could not save');
    });

    testWidgets('AsyncView: a refused read is a calm "no access" state without '
        'retry', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AsyncView<List<int>>(
            load: () async => throw const PostgrestException(
                message: 'permission denied for table performance_reviews',
                code: '42501'),
            isEmpty: (d) => d.isEmpty,
            emptyTitle: 'Nothing here',
            builder: (_, d) => const Text('DATA'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(AppNoAccessView), findsOneWidget);
      expect(find.text('You have no access to this content'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Nothing here'), findsNothing,
          reason: 'a refusal is not the empty state');
    });

    testWidgets('AsyncView: a timeout is "could not load" with retry — not the '
        'empty state', (tester) async {
      var calls = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AsyncView<List<int>>(
            load: () async {
              calls++;
              if (calls == 1) {
                throw const PostgrestException(
                    message: 'statement timeout', code: '57014');
              }
              return <int>[];
            },
            isEmpty: (d) => d.isEmpty,
            emptyTitle: 'Nothing here',
            builder: (_, d) => const Text('DATA'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.byType(AppNoAccessView), findsNothing);
      expect(find.text('Nothing here'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing here'), findsOneWidget,
          reason: 'an RLS-filtered (empty) result is the normal empty state');
    });
  });
}
