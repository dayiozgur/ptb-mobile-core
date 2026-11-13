import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../helpers/widget_test_helpers.dart';

class MockSearchService extends Mock implements SearchService {}

/// A failed search is not "no results".
void main() {
  late MockSearchService search;

  setUp(() async {
    await sl.reset();
    search = MockSearchService();
    registerFake<SearchService>(search);
    registerFake<LocalizationService>(buildFakeLocalization(
      overrides: AppLocalizations.getTranslations(AppLocale.english),
      locale: AppLocale.english,
    ));
  });

  tearDown(() async => sl.reset());

  Future<void> type(WidgetTester tester, String text) async {
    await tester.pumpWidget(const MaterialApp(home: GlobalSearchScreen()));
    await tester.enterText(find.byType(TextField), text);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  testWidgets('failure → "search failed" + retry, then results state',
      (tester) async {
    var calls = 0;
    when(() => search.globalSearch('pump')).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('offline');
      return const <GlobalSearchHit>[];
    });

    await type(tester, 'pump');
    expect(find.byType(AppLoadFailedView), findsOneWidget);
    expect(find.text('No results found'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(AppLoadFailedView), findsNothing);
    expect(find.text('No results found'), findsOneWidget);
  });

  testWidgets('refused (42501) → no access', (tester) async {
    when(() => search.globalSearch('pump')).thenThrow(
        const PostgrestException(message: 'permission denied', code: '42501'));
    await type(tester, 'pump');
    expect(find.byType(AppNoAccessView), findsOneWidget);
  });
}
