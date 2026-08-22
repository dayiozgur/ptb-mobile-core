import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../helpers/supabase_fakes.dart';

void main() {
  late SupabaseHarness h;
  late WorkInboxService service;

  WorkInboxSource crmLikeSource() => WorkInboxSource(
        title: 'İşlerim',
        rpcName: 'fn_crm_my_work',
        mapper: (r) => WorkInboxItem(
          id: r['entity_id']?.toString() ?? '',
          title: r['subject']?.toString() ?? '—',
          group: r['bucket']?.toString(),
          status: r['status']?.toString(),
          entityType: r['item_kind']?.toString(),
        ),
      );

  setUp(() {
    h = SupabaseHarness();
    service = WorkInboxService(supabase: h.client);
  });

  tearDown(() => GetIt.instance.reset());

  test('load: RPC satırlarını mapper ile WorkInboxItem\'a çevirir', () async {
    h.stubRpc('fn_crm_my_work', result: <Map<String, dynamic>>[
      {
        'entity_id': 'e1',
        'subject': 'Ada\'yı ara',
        'bucket': 'today',
        'status': 'open',
        'item_kind': 'activity',
      },
      {
        'entity_id': 'e2',
        'subject': 'Teklif gönder',
        'bucket': 'overdue',
        'status': 'qualified',
        'item_kind': 'deal',
      },
    ]);

    final items = await service.load(crmLikeSource());

    expect(items.length, 2);
    expect(items.first.title, 'Ada\'yı ara');
    expect(items.first.group, 'today');
    expect(items.first.entityType, 'activity');
    expect(items[1].entityType, 'deal');
  });

  test('load: RPC hatası → [] (UI\'a fırlatmaz)', () async {
    h.stubRpc('fn_crm_my_work', error: Exception('boom'));
    final items = await service.load(crmLikeSource());
    expect(items, isEmpty);
  });

  test('load: boş sonuç → []', () async {
    h.stubRpc('fn_crm_my_work', result: <Map<String, dynamic>>[]);
    final items = await service.load(crmLikeSource());
    expect(items, isEmpty);
  });
}
