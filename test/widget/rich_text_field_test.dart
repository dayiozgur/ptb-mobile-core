import 'package:flutter/material.dart' hide FormField;
import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:protoolbag_core/src/presentation/dynamic_form/field_registry.dart';
import 'package:protoolbag_core/src/presentation/dynamic_form/field_render_context.dart';

/// `rich_text` alanı: markdown-toolbar'lı çok-satır editör. Değer daima String
/// olarak `onChanged` ile akar; toolbar seçime/satıra markdown işareti ekler.
void main() {
  FormField field() => const FormField(
        id: 'f1',
        formSectionId: 's1',
        code: 'notes',
        label: 'Notlar',
        fieldType: 'rich_text',
      );

  Future<List<dynamic>> pump(WidgetTester tester, {String initial = ''}) async {
    final emitted = <dynamic>[];
    final widget = resolveFieldWidget('rich_text');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => widget.build(
              context,
              FieldRenderContext(
                field: field(),
                value: initial,
                onChanged: emitted.add,
              ),
            ),
          ),
        ),
      ),
    );
    return emitted;
  }

  testWidgets('registry rich_text → RichTextFieldWidget (unsupported değil)',
      (tester) async {
    final w = resolveFieldWidget('rich_text');
    expect(w.runtimeType.toString(), 'RichTextFieldWidget');
  });

  testWidgets('yazınca String değer emit edilir', (tester) async {
    final emitted = await pump(tester);
    await tester.enterText(find.byType(TextField), 'merhaba');
    expect(emitted.last, 'merhaba');
    expect(emitted.last, isA<String>());
  });

  testWidgets('Kalın toolbar butonu markdown ** ekler', (tester) async {
    final emitted = await pump(tester);
    await tester.tap(find.byTooltip('Kalın'));
    await tester.pump();
    expect(emitted.isNotEmpty, isTrue);
    expect(emitted.last.toString(), contains('**'));
  });

  testWidgets('Madde toolbar butonu satır başına "- " ekler', (tester) async {
    final emitted = await pump(tester, initial: 'satir');
    await tester.tap(find.byTooltip('Madde'));
    await tester.pump();
    expect(emitted.last, startsWith('- '));
  });

  testWidgets('readonly (enabled:false) → toolbar gizli', (tester) async {
    final widget = resolveFieldWidget('rich_text');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => widget.build(
              context,
              FieldRenderContext(
                field: field(),
                value: 'x',
                onChanged: (_) {},
                enabled: false,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byTooltip('Kalın'), findsNothing);
  });
}
