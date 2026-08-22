import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Form-motoru shape-drift regresyonları — web bazı select alanlarını farklı
/// şekillerde saklar; hard-cast'ler runtime crash veriyordu (deal + employee).
void main() {
  group('FormField.fromJson options shape-drift', () {
    test('options.items STRING dizisi → FieldOption(value=label) (crash yok)', () {
      final f = FormField.fromJson({
        'id': 'f1',
        'field_type': 'select',
        'code': 'department',
        'label': 'Departman',
        'options': {
          'type': 'static',
          'items': ['IT', 'Finans', 'Saha']
        },
      });
      expect(f.options.items.length, 3);
      expect(f.options.items.first.value, 'IT');
      expect(f.options.items.first.label, 'IT');
    });

    test('options HAM dizi (obje elemanlı) → static items', () {
      final f = FormField.fromJson({
        'id': 'f2',
        'field_type': 'select',
        'code': 'stage',
        'label': 'Aşama',
        'options': [
          {'value': 'won', 'label': 'Won'},
          {'value': 'lost', 'label': 'Lost'},
        ],
      });
      expect(f.options.items.length, 2);
      expect(f.options.items.first.value, 'won');
    });

    test('options.items obje dizisi → normal', () {
      final f = FormField.fromJson({
        'id': 'f3',
        'field_type': 'select',
        'code': 'x',
        'label': 'X',
        'options': {
          'items': [
            {'value': 'a', 'label': 'A'}
          ]
        },
      });
      expect(f.options.items.single.label, 'A');
    });

    test('validation_rules DİZİ → boş validation (crash yok)', () {
      final f = FormField.fromJson({
        'id': 'f4',
        'field_type': 'text',
        'code': 'y',
        'label': 'Y',
        'validation_rules': ['bad', 'shape'],
      });
      expect(f.validation, isNotNull);
    });

    test('options null → boş items', () {
      final f = FormField.fromJson({
        'id': 'f5',
        'field_type': 'text',
        'code': 'z',
        'label': 'Z',
      });
      expect(f.options.items, isEmpty);
    });
  });
}
