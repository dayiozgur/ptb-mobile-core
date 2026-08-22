import 'package:flutter/material.dart' hide FormField;
import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:protoolbag_core/src/presentation/dynamic_form/field_registry.dart';
import 'package:protoolbag_core/src/presentation/dynamic_form/field_render_context.dart';

/// `barcode` / `qr_scanner` alanları: kamerayla on-device okuma + manuel-giriş
/// fallback. Kamera test ortamında yok; burada registry eşlemesi, manuel-giriş
/// String emit'i ve "Tara" butonunun varlığı doğrulanır.
void main() {
  FormField field(String type) => FormField(
        id: 'f1',
        formSectionId: 's1',
        code: 'code',
        label: 'Kod',
        fieldType: type,
      );

  Future<List<dynamic>> pump(WidgetTester tester, String type) async {
    final emitted = <dynamic>[];
    final widget = resolveFieldWidget(type);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => widget.build(
              context,
              FieldRenderContext(
                field: field(type),
                value: '',
                onChanged: emitted.add,
              ),
            ),
          ),
        ),
      ),
    );
    return emitted;
  }

  testWidgets('registry barcode → BarcodeFieldWidget', (tester) async {
    expect(resolveFieldWidget('barcode').runtimeType.toString(),
        'BarcodeFieldWidget');
  });

  testWidgets('registry qr_scanner → QrScannerFieldWidget', (tester) async {
    expect(resolveFieldWidget('qr_scanner').runtimeType.toString(),
        'QrScannerFieldWidget');
  });

  testWidgets('barcode: manuel giriş String emit eder + Tara butonu var',
      (tester) async {
    final emitted = await pump(tester, 'barcode');
    expect(find.text('Tara'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '8690000000001');
    expect(emitted.last, '8690000000001');
    expect(emitted.last, isA<String>());
  });

  testWidgets('qr_scanner: manuel giriş String emit eder', (tester) async {
    final emitted = await pump(tester, 'qr_scanner');
    await tester.enterText(find.byType(TextField), 'ETTN:123');
    expect(emitted.last, 'ETTN:123');
  });
}
