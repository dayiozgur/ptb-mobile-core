import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/supabase_fakes.dart';

/// AggregateService — fn_*_rollup sarmalayıcı. TABLE→satır, json→ham, null→boş,
/// hata→rethrow. Kanonik SupabaseHarness ile (ağ yok).
void main() {
  late SupabaseHarness h;

  setUp(() {
    h = SupabaseHarness();
    if (sl.isRegistered<SupabaseClient>()) sl.unregister<SupabaseClient>();
    sl.registerSingleton<SupabaseClient>(h.client);
  });

  tearDown(() {
    if (sl.isRegistered<SupabaseClient>()) sl.unregister<SupabaseClient>();
  });

  group('AggregateService.rows', () {
    test('TABLE (List) → satır listesi', () async {
      h.stubRpc('fn_x', result: [
        {'a': 1},
        {'a': 2},
      ]);
      final rows = await AggregateService().rows('fn_x', params: {'p': 1});
      expect(rows.length, 2);
      expect(rows.first['a'], 1);
      expect(h.capturedRpcParams('fn_x'), {'p': 1});
    });

    test('json (Map) → tek satır', () async {
      h.stubRpc('fn_y', result: {'k': 'v'});
      final rows = await AggregateService().rows('fn_y');
      expect(rows.length, 1);
      expect(rows.first['k'], 'v');
    });

    test('null → boş liste', () async {
      h.stubRpc('fn_z', result: null);
      expect(await AggregateService().rows('fn_z'), isEmpty);
    });

    test('hata → rethrow', () async {
      h.stubRpc('fn_e', error: Exception('boom'));
      expect(
        () => AggregateService().rows('fn_e'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('AggregateService.json', () {
    test('ham json (Map) döner', () async {
      h.stubRpc('fn_j', result: {
        'kpis': {'x': 5}
      });
      final raw = await AggregateService().json('fn_j');
      expect((raw['kpis'] as Map)['x'], 5);
    });
  });
}
