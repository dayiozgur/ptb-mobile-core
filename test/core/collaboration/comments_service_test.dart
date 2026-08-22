import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../helpers/supabase_fakes.dart';

class MockTenantService extends Mock implements TenantService {}

void main() {
  late SupabaseHarness h;
  late MockTenantService tenant;
  late CommentsService service;

  setUp(() {
    h = SupabaseHarness();
    tenant = MockTenantService();
    when(() => tenant.currentTenantId).thenReturn('tenant-1');
    final sl = GetIt.instance;
    if (sl.isRegistered<TenantService>()) sl.unregister<TenantService>();
    sl.registerSingleton<TenantService>(tenant);
    service = CommentsService(supabase: h.client);
  });

  tearDown(() => GetIt.instance.reset());

  group('list', () {
    test('parses comments + resolves author names', () async {
      h.stubFrom('comments', result: <Map<String, dynamic>>[
        {
          'id': 'c1',
          'content': 'Merhaba',
          'created_by': 'u1',
          'created_at': '2026-08-22T10:00:00Z',
        },
      ]);
      h.stubFrom('profiles', result: <Map<String, dynamic>>[
        {
          'id': 'u1',
          'first_name': 'Ada',
          'last_name': 'Lovelace',
          'email': 'a@x.com',
        },
      ]);

      final list = await service.list('deal', 'd1');

      expect(list.length, 1);
      expect(list.first.content, 'Merhaba');
      expect(list.first.authorName, 'Ada Lovelace');
    });

    test('empty result → []', () async {
      h.stubFrom('comments', result: <Map<String, dynamic>>[]);
      final list = await service.list('deal', 'd1');
      expect(list, isEmpty);
    });

    test('error → [] (UI\'a fırlatmaz)', () async {
      h.stubFrom('comments', error: Exception('boom'));
      final list = await service.list('deal', 'd1');
      expect(list, isEmpty);
    });
  });

  group('add', () {
    test('inserts + returns comment (authorName=Siz)', () async {
      h.stubCurrentUser(id: 'u1');
      h.stubFrom('comments', result: <String, dynamic>{
        'id': 'c2',
        'content': 'Yeni yorum',
        'created_by': 'u1',
        'created_at': '2026-08-22T11:00:00Z',
      });

      final c = await service.add('deal', 'd1', 'Yeni yorum');

      expect(c, isNotNull);
      expect(c!.content, 'Yeni yorum');
      expect(c.authorName, 'Siz');
    });

    test('boş içerik → null (insert yok)', () async {
      final c = await service.add('deal', 'd1', '   ');
      expect(c, isNull);
    });
  });
}
