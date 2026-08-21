import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../helpers/supabase_fakes.dart';

class MockCacheManager extends Mock implements CacheManager {}

void main() {
  late SupabaseHarness h;
  late SearchService service;

  setUp(() {
    h = SupabaseHarness();
    service = SearchService(supabase: h.client, cacheManager: MockCacheManager());
  });

  group('globalSearch (fn_universal_search rpc)', () {
    test('happy path: maps rows to GlobalSearchHit + sends params', () async {
      h.stubRpc('fn_universal_search', result: <dynamic>[
        {
          'source': 'work_request',
          'id': 'wr-1',
          'entity_type': 'work_request',
          'code': 'WR-001',
          'title': 'Broken pump',
          'subtitle': 'Site A',
        },
      ]);

      final hits = await service.globalSearch('pump', limit: 5);

      expect(hits.length, 1);
      expect(hits.first.id, 'wr-1');
      expect(hits.first.title, 'Broken pump');
      expect(hits.first.source, 'work_request');

      final params = h.capturedRpcParams('fn_universal_search')!;
      expect(params['p_query'], 'pump');
      expect(params['p_limit'], 5);
      expect(params['p_sources'], isNull);
    });

    test('trims the query and forwards sources', () async {
      h.stubRpc('fn_universal_search', result: <dynamic>[]);

      await service.globalSearch('  boiler  ', sources: ['sites', 'units']);

      final params = h.capturedRpcParams('fn_universal_search')!;
      expect(params['p_query'], 'boiler');
      expect(params['p_sources'], ['sites', 'units']);
    });

    test('short query (< 2 chars) short-circuits without an rpc call', () async {
      final hits = await service.globalSearch('a');
      expect(hits, isEmpty);
      verifyNever(() => h.client.rpc<dynamic>(any(), params: any(named: 'params')));
    });

    test('non-list response yields empty list', () async {
      h.stubRpc('fn_universal_search', result: {'not': 'a list'});
      expect(await service.globalSearch('pump'), isEmpty);
    });

    test('error is swallowed → empty list', () async {
      h.stubRpc('fn_universal_search', error: Exception('rpc down'));
      expect(await service.globalSearch('pump'), isEmpty);
    });

    test('title falls back to code when title is blank', () async {
      h.stubRpc('fn_universal_search', result: <dynamic>[
        {'source': 's', 'id': 'x', 'code': 'CODE-9', 'title': '  '},
      ]);

      final hits = await service.globalSearch('anything');
      expect(hits.single.title, 'CODE-9');
    });
  });
}
