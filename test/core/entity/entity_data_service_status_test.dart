import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/supabase_fakes.dart';
import '../fixflow/fixflow_test_utils.dart';

class _MockCacheManager extends Mock implements CacheManager {}

void main() {
  late SupabaseHarness h;
  late EntityDataService service;
  Set<String> roles = const {};

  const translations = {
    'crm.status.won': 'Kazanıldı',
    'status.lead': 'Aday',
  };

  setUp(() {
    h = SupabaseHarness();
    roles = const {};
    service = EntityDataService(
      supabase: h.client,
      cacheManager: _MockCacheManager(),
      translate: (k) => translations[k] ?? k,
      rolesResolver: () async => roles,
    );
  });

  group('loadStatusDefinitions (metadata i18n)', () {
    test('reads metadata and translates metadata.i18n.name, then status.<code>',
        () async {
      h.stubFrom('status_definitions', result: [
        {
          'code': 'won',
          'name': 'Won',
          'sort_order': 40,
          'is_system': false,
          'metadata': {
            'i18n': {'name': 'crm.status.won'}
          },
        },
        {'code': 'lead', 'name': 'Lead', 'sort_order': 10, 'is_system': true},
        {
          'code': 'proposal',
          'name': 'Proposal',
          'sort_order': 30,
          'is_system': false,
          'metadata': null,
        },
      ]);

      final rows = await service.loadStatusDefinitions('deal');

      expect(rows.map((r) => r['code']), ['lead', 'proposal', 'won']);
      expect(rows.map((r) => r['name']), ['Aday', 'Proposal', 'Kazanıldı']);
      final select = callsNamed(h, 'status_definitions', 'select').single.first
          as String;
      expect(select, contains('metadata'));
    });

    test('statusLabels shows the translated names (no raw English)', () async {
      h.stubFrom('status_definitions', result: [
        {
          'code': 'won',
          'name': 'Won',
          'is_system': false,
          'metadata': {
            'i18n': {'name': 'crm.status.won'}
          },
        },
      ]);
      final labels = await service.statusLabels('deal');
      expect(EntityStatusLabels.nameOf('won', labels), 'Kazanıldı');
    });
  });

  group('availableTransitions', () {
    Map<String, dynamic> tx(String id, String from, String to,
            {List<String>? req, bool comment = false, bool form = false}) =>
        {
          'id': id,
          'required_roles': req,
          'requires_comment': comment,
          'requires_confirmation': false,
          'required_form_template_id': form ? 'f' : null,
          'sort_order': 0,
          'from_status': {'code': from},
          'to_status': {'code': to, 'name': to},
        };

    test('only allowed targets from the current status, role filtered', () async {
      h.stubFrom('status_transitions', result: [
        tx('1', 'new', 'contacted'),
        tx('2', 'new', 'disqualified', req: ['manager'], comment: true),
        tx('3', 'new', 'archived', form: true),
        tx('4', 'contacted', 'qualified'),
      ]);
      final user = await service.availableTransitions('lead', 'new');
      expect(user.map((t) => t.toCode), ['contacted']);

      roles = {'manager'};
      final mgr = await service.availableTransitions('lead', 'new');
      expect(mgr.map((t) => t.toCode), ['contacted', 'disqualified']);
      expect(mgr.last.requiresComment, isTrue);
      expect(hasEq(h, 'status_transitions', 'entity_type', 'lead'), isTrue);
      expect(hasEq(h, 'status_transitions', 'active', true), isTrue);
    });

    test('lead→converted is not offered (convert wizard only)', () async {
      h.stubFrom('status_transitions', result: [
        tx('1', 'qualified', 'converted'),
        tx('2', 'qualified', 'disqualified'),
      ]);
      final out = await service.availableTransitions('lead', 'qualified');
      expect(out.map((t) => t.toCode), ['disqualified']);
    });

    test('error → empty list', () async {
      h.stubFrom('status_transitions',
          error: const PostgrestException(message: 'boom'));
      expect(await service.availableTransitions('lead', 'new'), isEmpty);
    });
  });
}
