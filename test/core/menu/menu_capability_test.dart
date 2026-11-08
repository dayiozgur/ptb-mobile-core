import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../helpers/supabase_fakes.dart';

/// WP-D: `platform_menu_items.requires_capability` filtresi — web
/// `IntegrationCapabilityService` + `filterByCapabilitiesRecursive` paritesi.
class _MockCache extends Fake implements CacheManager {
  @override
  Future<T?> get<T>(String key) async => null;

  @override
  Future<void> set<T>(String key, T value,
      {Duration ttl = const Duration(hours: 1)}) async {}

  @override
  Future<void> delete(String key) async {}
}

Map<String, dynamic> _row(String key,
        {String? parent, String? path, String? cap, int sort = 0}) =>
    {
      'item_key': key,
      'parent_item_key': parent,
      'title': key,
      'path': path,
      'requires_capability': cap,
      'sort_order': sort,
      'active': true,
    };

Map<String, dynamic> _conn(
        {String provider = 'microsoft',
        String status = 'connected',
        List<String>? scopes}) =>
    {'id': 'c1', 'provider': provider, 'status': status, 'scopes': scopes};

void main() {
  group('MenuItem.fromJson', () {
    test('requires_capability okunur; boş/null → null', () {
      expect(MenuItem.fromJson(_row('a', cap: 'files')).requiresCapability,
          'files');
      expect(MenuItem.fromJson(_row('a', cap: '  ')).requiresCapability, isNull);
      expect(MenuItem.fromJson(_row('a')).requiresCapability, isNull);
      expect(
          MenuItem.fromJson(_row('a', cap: 'files'))
              .copyWith(children: const [])
              .requiresCapability,
          'files');
    });
  });

  group('MenuCapabilities.granted (web connectionHasCapability/state)', () {
    test('bağlantı yok → verilmez', () {
      expect(MenuCapabilities.granted({'files'}, const []), isEmpty);
    });

    test('connected + kapsam (graph prefix, harf duyarsız) → verilir', () {
      final g = MenuCapabilities.granted({'files', 'mail.read'}, [
        _conn(scopes: ['https://graph.microsoft.com/files.read', 'offline_access'])
      ]);
      expect(g, {'files'});
    });

    test('geniş kapsam dar yeteneği karşılar (Mail.ReadWrite → mail.read)', () {
      expect(
          MenuCapabilities.granted(
              {'mail.read'}, [_conn(scopes: ['Mail.ReadWrite'])]),
          {'mail.read'});
    });

    test('boş scopes = eski satır → izinli', () {
      expect(MenuCapabilities.granted({'calendar'}, [_conn(scopes: [])]),
          {'calendar'});
      expect(MenuCapabilities.granted({'calendar'}, [_conn()]), {'calendar'});
    });

    test('expired / bilinmeyen sağlayıcı / bilinmeyen yetenek → verilmez', () {
      expect(
          MenuCapabilities.granted({'files'}, [_conn(status: 'expired')]),
          isEmpty);
      expect(
          MenuCapabilities.granted({'files'}, [_conn(provider: 'google')]),
          isEmpty);
      expect(MenuCapabilities.granted({'nope'}, [_conn()]), isEmpty);
    });
  });

  group('MenuCapabilities.filter (web filterByCapabilitiesRecursive)', () {
    const group = MenuItem(
      itemKey: 'm365',
      title: 'm365',
      children: [
        MenuItem(itemKey: 'm365/files', title: 'f', path: '/files', requiresCapability: 'files'),
        MenuItem(itemKey: 'm365/mail', title: 'm', path: '/mail', requiresCapability: 'mail.read'),
      ],
    );
    const plain = MenuItem(itemKey: 'dash', title: 'd', path: '/dashboard');

    test('verilmeyen öğe düşer; yolsuz grup tüm çocukları düşünce düşer', () {
      final out = MenuCapabilities.filter([group, plain], const {});
      expect(out.map((e) => e.itemKey), ['dash']);
    });

    test('kısmi izin → grup kalır, yalnız verilen çocuk', () {
      final out = MenuCapabilities.filter([group, plain], {'files'});
      expect(out.map((e) => e.itemKey), ['m365', 'dash']);
      expect(out.first.children.map((e) => e.itemKey), ['m365/files']);
    });

    test('yolu olan ebeveyn çocukları düşse de kalır', () {
      const withPath = MenuItem(
        itemKey: 'p',
        title: 'p',
        path: '/p',
        children: [
          MenuItem(itemKey: 'p/x', title: 'x', path: '/x', requiresCapability: 'files')
        ],
      );
      final out = MenuCapabilities.filter([withPath], const {});
      expect(out.single.itemKey, 'p');
      expect(out.single.children, isEmpty);
    });

    test('collect ağaçtaki tüm kodları toplar', () {
      expect(MenuCapabilities.collect([group, plain]), {'files', 'mail.read'});
    });
  });

  group('MobileMenuService.loadMenu', () {
    late SupabaseHarness h;
    late _MockCache cache;

    setUp(() {
      h = SupabaseHarness();
      cache = _MockCache();
      h.stubFrom('entity_type_configs', result: <Map<String, dynamic>>[]);
      h.stubFrom('platform_menu_items', result: [
        _row('dash', path: '/dashboard', sort: 1),
        _row('m365', sort: 2),
        _row('m365/files', parent: 'm365', path: '/files?source=onedrive', cap: 'files', sort: 1),
      ]);
    });

    test('bağlantı yok → yetenekli öğe + boş grup gizli', () async {
      h.stubFrom('integration_connections', result: <Map<String, dynamic>>[]);
      final svc = MobileMenuService(supabase: h.client, cacheManager: cache);
      final tree = await svc.loadMenu(platformId: 'plat-x', coarseRole: 'ROLE_USER');
      expect(tree.map((e) => e.itemKey), ['dash']);
      // platform_id aktif platformdan gelir (sabit PMS varsayılanı yok).
      final eqCalls = h.queryByTable['platform_menu_items']!.calls
          .where((c) => c.memberName == #eq)
          .map((c) => c.positionalArguments)
          .toList();
      expect(eqCalls, anyElement(equals(['platform_id', 'plat-x'])));
    });

    test('Files kapsamlı bağlantı → öğe görünür', () async {
      h.stubFrom('integration_connections', result: [
        _conn(scopes: ['Files.ReadWrite.All'])
      ]);
      final svc = MobileMenuService(supabase: h.client, cacheManager: cache);
      final tree = await svc.loadMenu(platformId: 'p', coarseRole: 'ROLE_USER');
      expect(tree.map((e) => e.itemKey), ['dash', 'm365']);
      expect(tree[1].children.single.itemKey, 'm365/files');
    });

    test('bağlantı sorgusu hata → öğe gizli, menü düşmez', () async {
      h.stubFrom('integration_connections', error: Exception('boom'));
      final svc = MobileMenuService(supabase: h.client, cacheManager: cache);
      final tree = await svc.loadMenu(platformId: 'p', coarseRole: 'ROLE_USER');
      expect(tree.map((e) => e.itemKey), ['dash']);
    });

    test('yetenekli öğe yoksa bağlantı sorgusu YAPILMAZ', () async {
      h.stubFrom('platform_menu_items', result: [_row('dash', path: '/d')]);
      var asked = 0;
      final svc = MobileMenuService(
        supabase: h.client,
        cacheManager: cache,
        capabilityResolver: (_) async {
          asked++;
          return const {};
        },
      );
      await svc.loadMenu(platformId: 'p', coarseRole: null);
      expect(asked, 0);
      verifyNever(() => h.client.from('integration_connections'));
    });
  });
}
