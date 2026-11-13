import 'package:flutter/material.dart' hide FormField;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:protoolbag_core/src/presentation/dynamic_form/field_registry.dart';
import 'package:protoolbag_core/src/presentation/dynamic_form/field_render_context.dart';

import '../helpers/widget_test_helpers.dart';

class MockLookupService extends Mock implements LookupService {}

/// A `select` field whose options come from a table (`options.type: lookup`,
/// e.g. the service-request priority) loads them through
/// LookupService.selectOptions — before, the mobile select showed only static
/// items, so this list was always empty.
void main() {
  const options = FieldOptions(
    type: 'lookup',
    table: 'priorities',
    valueField: 'code',
    labelField: 'name',
    filters: {'vendor': null},
  );
  const field = FormField(
    id: 'f1',
    formSectionId: 's1',
    code: 'priority',
    label: 'Priority',
    fieldType: 'select',
    options: options,
  );

  late MockLookupService lookup;

  setUpAll(() => registerFallbackValue(const FieldOptions()));

  setUp(() {
    lookup = MockLookupService();
    registerFake<LookupService>(lookup);
    registerFake<LocalizationService>(buildFakeLocalization(overrides: {
      'field.options_load_failed': 'Options could not be loaded',
    }));
  });

  tearDown(() => sl.reset());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => resolveFieldWidget('select').build(
            context,
            FieldRenderContext(field: field, value: null, onChanged: (_) {}),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('loads table options with the field options (filters kept)',
      (tester) async {
    when(() => lookup.selectOptions(any(),
            dependsOnValues: any(named: 'dependsOnValues')))
        .thenAnswer((_) async => const [
              FieldOption(value: 'HIGH', label: 'High'),
              FieldOption(value: 'LOW', label: 'Low'),
            ]);

    await pump(tester);

    final captured = verify(() => lookup.selectOptions(captureAny(),
            dependsOnValues: any(named: 'dependsOnValues')))
        .captured;
    expect((captured.single as FieldOptions).filters, {'vendor': null});
    final dropdown = tester
        .widget<AppDropdown<dynamic>>(find.byType(AppDropdown<dynamic>));
    expect(dropdown.items.map((i) => i.value), ['HIGH', 'LOW']);
    expect(find.text('Options could not be loaded'), findsNothing);
  });

  testWidgets('a failed read says so and offers a retry', (tester) async {
    when(() => lookup.selectOptions(any(),
            dependsOnValues: any(named: 'dependsOnValues')))
        .thenThrow(Exception('db down'));

    await pump(tester);

    expect(find.text('Options could not be loaded'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });
}
