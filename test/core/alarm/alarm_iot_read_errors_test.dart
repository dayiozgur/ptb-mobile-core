import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../helpers/supabase_fakes.dart';

/// Empty cache: every read misses, writes are dropped.
class _NoCache extends Fake implements CacheManager {
  @override
  Future<T?> get<T>(String key) async => null;

  @override
  Future<void> set<T>(String key, T value, {Duration? ttl}) async {}
}

/// PMS reads that used to turn a failure into an empty list ("no alarm
/// history", "no logs") now rethrow; the screens decide between retry and the
/// no-access state. An RLS-filtered empty result is still an empty list.
void main() {
  late SupabaseHarness h;
  late _NoCache cache;
  late AlarmService alarms;
  late IoTLogService logs;

  const timeout = PostgrestException(
      message: 'canceling statement due to statement timeout', code: '57014');
  const refused =
      PostgrestException(message: 'permission denied', code: '42501');

  setUp(() {
    h = SupabaseHarness();
    cache = _NoCache();
    alarms = AlarmService(supabase: h.client, cacheManager: cache)
      ..setTenant('t1');
    logs = IoTLogService(supabase: h.client, cacheManager: cache)
      ..setTenant('t1');
  });

  group('AlarmService', () {
    test('getHistory: failure is rethrown, empty stays empty', () async {
      h.stubFrom('alarm_histories', error: timeout);
      await expectLater(alarms.getHistory(siteId: 's1', forceRefresh: true),
          throwsA(isA<PostgrestException>()));

      h.stubFrom('alarm_histories', result: <Map<String, dynamic>>[]);
      expect(
          await alarms.getHistory(siteId: 's1', forceRefresh: true), isEmpty);
    });

    test('getResetAlarms: refused read is rethrown and reads as no access',
        () async {
      h.stubFrom('alarm_histories', error: refused);
      Object? caught;
      try {
        await alarms.getResetAlarms(forceRefresh: true);
      } catch (e) {
        caught = e;
      }
      expect(AccessErrors.isDenied(caught), isTrue);
    });

    test('getTopAlarms: failure is rethrown', () async {
      h.stubFrom('alarm_histories', error: timeout);
      await expectLater(alarms.getTopAlarms(forceRefresh: true),
          throwsA(isA<PostgrestException>()));
    });
  });

  group('IoTLogService', () {
    test('getLogs: failure is rethrown, empty stays empty', () async {
      h.stubFrom('logs', error: timeout);
      await expectLater(logs.getLogs(providerId: 'p1', forceRefresh: true),
          throwsA(isA<PostgrestException>()));

      h.stubFrom('logs', result: <Map<String, dynamic>>[]);
      expect(await logs.getLogs(providerId: 'p1', forceRefresh: true), isEmpty);
    });
  });
}
