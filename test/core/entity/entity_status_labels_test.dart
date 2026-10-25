import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

void main() {
  group('EntityStatusLabels', () {
    final labels = EntityStatusLabels.fromDefinitions([
      {'code': 'needs_service', 'name': 'Needs Service', 'color': '#ef4444'},
      {'code': 'open', 'name': '', 'color': null},
      {'code': null, 'name': 'ignored'},
    ]);

    test('fromDefinitions: name, empty name → humanized code, null code skipped', () {
      expect(labels.keys, ['needs_service', 'open']);
      expect(labels['needs_service']!.name, 'Needs Service');
      expect(labels['open']!.name, 'Open');
    });

    test('nameOf never returns a raw snake_case code', () {
      expect(EntityStatusLabels.nameOf('needs_service', labels), 'Needs Service');
      expect(EntityStatusLabels.nameOf('in_progress', const {}), 'In progress');
      expect(EntityStatusLabels.nameOf(null, labels), '');
    });

    test('parseHex', () {
      expect(EntityStatusLabels.parseHex('#ef4444'), const Color(0xFFEF4444));
      expect(EntityStatusLabels.parseHex('80ef4444'), const Color(0x80EF4444));
      expect(EntityStatusLabels.parseHex('red'), isNull);
      expect(labels['needs_service']!.color, const Color(0xFFEF4444));
    });

    test('relabelRows replaces the status column only', () {
      final rows = [
        {'status': 'needs_service', 'n': 3},
        {'status': 7},
      ];
      final out = EntityStatusLabels.relabelRows(rows, labels);
      expect(out[0], {'status': 'Needs Service', 'n': 3});
      expect(identical(out[1], rows[1]), isTrue);
      expect(rows[0]['status'], 'needs_service'); // input untouched
    });
  });

  group('ReportQueryService.entityTypeOfDataSource', () {
    const cols = [
      {'code': 'status', 'role': 'dimension'},
      {'code': 'count', 'role': 'measure'},
    ];
    test('entity source with status column → entity type', () {
      expect(
          ReportQueryService.entityTypeOfDataSource([
            {'field': 'entity_type', 'operator': 'eq', 'value': 'ticket'}
          ], cols),
          'ticket');
    });
    test('param placeholder / missing status column / no filter → null', () {
      expect(
          ReportQueryService.entityTypeOfDataSource([
            {'field': 'entity_type', 'value': ':p_type'}
          ], cols),
          isNull);
      expect(
          ReportQueryService.entityTypeOfDataSource([
            {'field': 'entity_type', 'value': 'ticket'}
          ], [
            {'code': 'subject'}
          ]),
          isNull);
      expect(ReportQueryService.entityTypeOfDataSource(null, cols), isNull);
    });
  });
}
