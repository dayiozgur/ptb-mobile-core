import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../helpers/supabase_fakes.dart';

/// `options.filters` with a null value must mean IS NULL (web form engine
/// rule, 2026-11-13): the service-request priority select will be pinned to
/// `{"vendor": null}` so vendor (e.g. Carel) priorities stay out of the list.
void main() {
  late SupabaseHarness h;
  late LookupService service;

  setUp(() {
    h = SupabaseHarness();
    service = LookupService(supabase: h.client);
  });

  const priorityOptions = FieldOptions(
    type: 'lookup',
    table: 'priorities',
    valueField: 'code',
    labelField: 'name',
    orderBy: 'level',
    filters: {'vendor': null},
  );

  group('selectOptions (select field backed by a table)', () {
    test('null filter → IS NULL (not eq.null); active, orderBy, value/label',
        () async {
      h.stubFrom('priorities', result: <Map<String, dynamic>>[
        {'code': 'HIGH', 'name': 'Yüksek', 'level': 1},
        {'code': 'LOW', 'name': 'Düşük', 'level': 3},
      ]);

      final opts = await service.selectOptions(priorityOptions);

      expect(opts.map((o) => o.value), ['HIGH', 'LOW']);
      expect(opts.map((o) => o.label), ['Yüksek', 'Düşük']);
      final calls = h.queryByTable['priorities']!.calls;
      final isNull = calls.where((i) => i.memberName == #isFilter).toList();
      expect(isNull, hasLength(1));
      expect(isNull.single.positionalArguments, ['vendor', null]);
      final eqs = calls.where((i) => i.memberName == #eq).toList();
      expect(eqs.map((i) => i.positionalArguments), [
        ['active', true]
      ]);
      final order = calls.firstWhere((i) => i.memberName == #order);
      expect(order.positionalArguments.first, 'level');
    });

    test('non-null filter stays an equality', () async {
      h.stubFrom('priorities', result: <Map<String, dynamic>>[]);
      await service.selectOptions(const FieldOptions(
          type: 'lookup', table: 'priorities', filters: {'vendor': 'carel'}));
      final eqs = h.queryByTable['priorities']!.calls
          .where((i) => i.memberName == #eq)
          .map((i) => i.positionalArguments)
          .toList();
      expect(eqs, anyElement(equals(['vendor', 'carel'])));
      expect(
          h.queryByTable['priorities']!.calls
              .any((i) => i.memberName == #isFilter),
          isFalse);
    });

    test('a failed read is rethrown (not "no options")', () async {
      h.stubFrom('priorities', error: Exception('db down'));
      await expectLater(
          service.selectOptions(priorityOptions), throwsException);
    });

    test('no table → empty, no query', () async {
      expect(await service.selectOptions(const FieldOptions(type: 'lookup')),
          isEmpty);
    });
  });

  group('search (lookup field)', () {
    test('null filter no longer throws; becomes IS NULL', () async {
      h.stubFrom('priorities', result: <Map<String, dynamic>>[
        {'code': 'HIGH', 'name': 'Yüksek'},
      ]);

      final rows = await service.search(priorityOptions);

      expect(rows.single['entityId'], 'HIGH');
      expect(
          h.queryByTable['priorities']!.calls
              .where((i) => i.memberName == #isFilter)
              .single
              .positionalArguments,
          ['vendor', null]);
    });
  });
}
