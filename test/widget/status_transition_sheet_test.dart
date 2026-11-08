import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Generic status-change flow used by EntityDetailScreen: only the allowed
/// transitions are listed; comment / confirmation are enforced.
void main() {
  setUp(() async => sl.reset());

  const transitions = [
    AllowedStatusTransition(id: '1', fromCode: 'new', toCode: 'contacted'),
    AllowedStatusTransition(
        id: '2', fromCode: 'new', toCode: 'disqualified', requiresComment: true),
    AllowedStatusTransition(
        id: '3', fromCode: 'new', toCode: 'on_hold', requiresConfirmation: true),
  ];

  Future<Future<StatusTransitionChoice?>> launch(WidgetTester tester) async {
    late Future<StatusTransitionChoice?> result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () {
              result = showStatusTransitionFlow(ctx,
                  transitions: transitions,
                  currentCode: 'new',
                  nameOf: (c) => 'N:$c');
            },
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('lists only the allowed targets; plain pick returns it',
      (tester) async {
    final result = await launch(tester);
    expect(find.text('N:contacted'), findsOneWidget);
    expect(find.text('N:disqualified'), findsOneWidget);
    expect(find.text('N:on_hold'), findsOneWidget);
    expect(find.text('N:converted'), findsNothing);

    await tester.tap(find.text('N:contacted'));
    await tester.pumpAndSettle();
    final choice = await result;
    expect(choice!.transition.toCode, 'contacted');
    expect(choice.comment, isNull);
  });

  testWidgets('requires_comment: empty comment cancels, text is returned',
      (tester) async {
    var result = await launch(tester);
    await tester.tap(find.text('N:disqualified'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('status-transition-comment')), findsOneWidget);
    await tester.tap(find.byKey(const Key('status-transition-confirm')));
    await tester.pumpAndSettle();
    expect(await result, isNull);

    result = await launch(tester);
    await tester.tap(find.text('N:disqualified'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('status-transition-comment')), '  spam  ');
    await tester.tap(find.byKey(const Key('status-transition-confirm')));
    await tester.pumpAndSettle();
    final choice = await result;
    expect(choice!.transition.toCode, 'disqualified');
    expect(choice.comment, 'spam');
  });

  testWidgets('requires_confirmation: confirm dialog gates the choice',
      (tester) async {
    final result = await launch(tester);
    await tester.tap(find.text('N:on_hold'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.byKey(const Key('status-transition-confirm')));
    await tester.pumpAndSettle();
    expect((await result)!.transition.toCode, 'on_hold');
  });

  testWidgets('EntityDetailExtensions.planTransition: default proceed, hook may cancel',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));
    const entity = GenericEntity(id: 'e1', entityType: 'wp_f_test');
    const t = AllowedStatusTransition(
        id: '1', fromCode: 'a', toCode: 'b', toRow: {'code': 'b', 'is_final': true});
    expect(await EntityDetailExtensions.planTransition(ctx, 'wp_f_other', entity, t),
        same(EntityTransitionPlan.proceed));

    final seen = <String>[];
    EntityDetailExtensions.registerTransitionHook('wp_f_test', (c, e, tr) async {
      seen.add('${e.id}:${tr.toCode}');
      return tr.toRow['is_final'] == true ? null : EntityTransitionPlan.proceed;
    });
    expect(await EntityDetailExtensions.planTransition(ctx, 'wp_f_test', entity, t),
        isNull);
    expect(seen, ['e1:b']);
  });
}
