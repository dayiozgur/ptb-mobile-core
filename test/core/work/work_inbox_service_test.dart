import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../helpers/supabase_fakes.dart';

/// WorkInboxService — kaynağın RPC'sini çağırır + mapper ile eşler; hata/null →
/// boş liste (UI'a fırlatmaz). Ctor-inject (sl gerekmez).
void main() {
  late SupabaseHarness h;
  setUp(() => h = SupabaseHarness());

  WorkInboxSource src(String rpc, {Map<String, dynamic>? params}) =>
      WorkInboxSource(
        title: 'İşlerim',
        rpcName: rpc,
        params: params,
        mapper: (r) => WorkInboxItem(
          id: r['id']?.toString() ?? '',
          title: r['subject']?.toString() ?? '—',
          status: r['status']?.toString(),
        ),
      );

  test('RPC satırlarını mapper ile eşler', () async {
    h.stubRpc('fn_wi', result: [
      {'id': '1', 'subject': 'A', 'status': 'open'},
      {'id': '2', 'subject': 'B'},
    ]);
    final svc = WorkInboxService(supabase: h.client);
    final items = await svc.load(src('fn_wi', params: {'p': 1}));
    expect(items.length, 2);
    expect(items.first.id, '1');
    expect(items.first.title, 'A');
    expect(items.first.status, 'open');
    expect(items[1].title, 'B');
    expect(h.capturedRpcParams('fn_wi'), {'p': 1});
  });

  test('hata → boş liste (UI fırlatmaz)', () async {
    h.stubRpc('fn_err', error: Exception('x'));
    final svc = WorkInboxService(supabase: h.client);
    expect(await svc.load(src('fn_err')), isEmpty);
  });

  test('null sonuç → boş liste', () async {
    h.stubRpc('fn_null', result: null);
    final svc = WorkInboxService(supabase: h.client);
    expect(await svc.load(src('fn_null')), isEmpty);
  });
}
