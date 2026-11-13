import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../helpers/supabase_fakes.dart';

class _MockTenant extends Mock implements TenantService {}

/// List reads that used to swallow a failure into an empty list now rethrow;
/// the screens decide between retry and the calm no-access state.
void main() {
  late SupabaseHarness h;

  const refused =
      PostgrestException(message: 'permission denied', code: '42501');

  setUp(() {
    h = SupabaseHarness();
    final tenant = _MockTenant();
    when(() => tenant.currentTenantId).thenReturn('t1');
    final sl = GetIt.instance;
    if (sl.isRegistered<TenantService>()) sl.unregister<TenantService>();
    sl.registerSingleton<TenantService>(tenant);
  });

  tearDown(() => GetIt.instance.reset());

  Future<Object?> caught(Future<Object?> Function() f) async {
    try {
      await f();
    } catch (e) {
      return e;
    }
    return null;
  }

  test('AnnouncementService.list: refused read is rethrown as no access',
      () async {
    final svc = AnnouncementService(supabase: h.client);
    h.stubFrom('announcements', error: refused);
    expect(AccessErrors.isDenied(await caught(() => svc.list())), isTrue);

    h.stubFrom('announcements', result: <Map<String, dynamic>>[]);
    expect(await svc.list(), isEmpty);
  });

  test('EntityFileLinkService.list: failure is rethrown, empty stays empty',
      () async {
    final svc = EntityFileLinkService(supabase: h.client);
    h.stubFrom('entity_file_links', error: Exception('offline'));
    expect(await caught(() => svc.list('contact', 'c1')), isA<Exception>());

    h.stubFrom('entity_file_links', result: <Map<String, dynamic>>[]);
    expect(await svc.list('contact', 'c1'), isEmpty);
  });
}
