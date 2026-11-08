import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../helpers/supabase_fakes.dart';

class _MockTenantService extends Mock implements TenantService {}

/// Cache that never hits and swallows writes (generic `set<T>` is awkward to
/// stub with mocktail).
class _NoCache extends Fake implements CacheManager {
  @override
  Future<T?> get<T>(String key) async => null;

  @override
  Future<void> set<T>(String key, T value,
      {Duration ttl = const Duration(hours: 1)}) async {}

  @override
  Future<void> delete(String key) async {}
}

/// TenantScope read-through for services that used to keep their own
/// `_currentTenantId`: with no explicit `setTenant` they read the active
/// [TenantService] tenant; an explicit `setTenant` still wins; clearing the
/// context falls back to the active tenant; with neither, the original
/// "Tenant context is not set" guard is unchanged.
void main() {
  late SupabaseHarness h;
  late _MockTenantService tenants;
  late _NoCache cache;
  String? active;

  setUp(() {
    h = SupabaseHarness();
    tenants = _MockTenantService();
    cache = _NoCache();
    active = 't-active';
    when(() => tenants.currentTenantId).thenAnswer((_) => active);
    final sl = GetIt.instance;
    if (sl.isRegistered<TenantService>()) sl.unregister<TenantService>();
    sl.registerSingleton<TenantService>(tenants);
    for (final t in [
      'todo_items',
      'teams',
      'controllers',
      'organizations',
      'sites',
      'providers',
      'staffs',
      'variables',
    ]) {
      h.stubFrom(t, result: <Map<String, dynamic>>[]);
    }
  });

  tearDown(() => GetIt.instance.reset());

  String chain(String table) => h.queryByTable[table]!.calls
      .map((i) => '${i.memberName}${i.positionalArguments}')
      .join(' ');

  /// Shared contract for a tenant-filtered read.
  void contract({
    required String name,
    required String table,
    required Object Function() build,
    required Future<void> Function(Object s) read,
    required void Function(Object s, String id) setTenant,
    required void Function(Object s) clear,
  }) {
    group(name, () {
      test('no setTenant → reads the active TenantService tenant', () async {
        final s = build();
        await read(s);
        expect(chain(table), contains('t-active'));
      });

      test('explicit setTenant wins over the active tenant', () async {
        final s = build();
        setTenant(s, 't-explicit');
        await read(s);
        expect(chain(table), contains('t-explicit'));
        expect(chain(table), isNot(contains('t-active')));
      });

      test('clearing the context falls back to the active tenant', () async {
        final s = build();
        setTenant(s, 't-explicit');
        clear(s);
        await read(s);
        expect(chain(table), contains('t-active'));
      });

      test('no explicit and no active tenant → same guard as before', () async {
        active = null;
        final s = build();
        await expectLater(read(s), throwsA(isA<Exception>()));
      });
    });
  }

  contract(
    name: 'TodoService',
    table: 'todo_items',
    build: () => TodoService(supabase: h.client, cacheManager: cache),
    read: (s) => (s as TodoService).getTodos(forceRefresh: true),
    setTenant: (s, id) => (s as TodoService).setTenant(id),
    clear: (s) => (s as TodoService).clearContext(),
  );

  contract(
    name: 'TeamService',
    table: 'teams',
    build: () => TeamService(supabase: h.client, cacheManager: cache),
    read: (s) => (s as TeamService).getTeams(forceRefresh: true),
    setTenant: (s, id) => (s as TeamService).setTenant(id),
    clear: (s) => (s as TeamService).clearContext(),
  );

  contract(
    name: 'ControllerService',
    table: 'controllers',
    build: () => ControllerService(supabase: h.client, cacheManager: cache),
    read: (s) => (s as ControllerService).getAll(forceRefresh: true),
    setTenant: (s, id) => (s as ControllerService).setTenant(id),
    clear: (s) => (s as ControllerService).clearTenant(),
  );

  contract(
    name: 'DataProviderService',
    table: 'providers',
    build: () => DataProviderService(supabase: h.client, cacheManager: cache),
    read: (s) => (s as DataProviderService).getAll(forceRefresh: true),
    setTenant: (s, id) => (s as DataProviderService).setTenant(id),
    clear: (s) => (s as DataProviderService).clearTenant(),
  );

  contract(
    name: 'StaffService',
    table: 'staffs',
    build: () => StaffService(supabase: h.client, cacheManager: cache),
    read: (s) => (s as StaffService).getStaffs(forceRefresh: true),
    setTenant: (s, id) => (s as StaffService).setTenant(id),
    clear: (s) => (s as StaffService).clearContext(),
  );

  // VariableService: the `variables` table has no tenant_id, so its queries
  // never used the tenant. Only the tracked tenant source is unified.
  group('VariableService', () {
    test('tenant id reads through to the active tenant', () {
      final s = VariableService(supabase: h.client, cacheManager: cache);
      expect(s.currentTenantId, 't-active');
      s.setTenant('t-explicit');
      expect(s.currentTenantId, 't-explicit');
      s.clearTenant();
      expect(s.currentTenantId, 't-active');
    });

    test('queries stay tenant-agnostic', () async {
      final s = VariableService(supabase: h.client, cacheManager: cache);
      await s.getAll(forceRefresh: true);
      expect(chain('variables'), isNot(contains('tenant')));
    });
  });
}
