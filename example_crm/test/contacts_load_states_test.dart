import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:protoolbag_crm/features/contacts/contacts_list_screen.dart';
import 'package:protoolbag_crm/features/contacts/contacts_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'helpers/fake_crm.dart';

/// Contacts list: a failed load is never "no contacts found".
class _FakeContacts extends ContactsService {
  _FakeContacts(this.responses);
  final List<Object> responses; // List<Contact> or an error to throw
  int calls = 0;

  @override
  Future<List<Contact>> list({String? query, int limit = 100}) async {
    final r =
        responses[calls < responses.length ? calls : responses.length - 1];
    calls++;
    if (r is List<Contact>) return r;
    throw r;
  }
}

void main() {
  setUp(() => registerFakeLocalization(const {
        'common.retry': 'Retry',
        'crm.contact.not_found': 'No contacts found',
      }));

  Widget app(ContactsService svc) =>
      MaterialApp(home: ContactsListScreen(service: svc));

  testWidgets('timeout → could not load + retry, then empty state',
      (tester) async {
    final svc = _FakeContacts([
      const PostgrestException(message: 'timeout', code: '57014'),
      <Contact>[],
    ]);
    await tester.pumpWidget(app(svc));
    await tester.pumpAndSettle();

    expect(find.byType(AppLoadFailedView), findsOneWidget);
    expect(find.text('No contacts found'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No contacts found'), findsOneWidget);
  });

  testWidgets('refused (42501) → no access, no retry', (tester) async {
    final svc = _FakeContacts([
      const PostgrestException(message: 'permission denied', code: '42501'),
    ]);
    await tester.pumpWidget(app(svc));
    await tester.pumpAndSettle();

    expect(find.byType(AppNoAccessView), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(find.text('No contacts found'), findsNothing);
  });

  testWidgets('RLS-filtered empty result stays the normal empty state',
      (tester) async {
    await tester.pumpWidget(app(_FakeContacts([<Contact>[]])));
    await tester.pumpAndSettle();
    expect(find.text('No contacts found'), findsOneWidget);
    expect(find.byType(AppLoadFailedView), findsNothing);
  });
}
