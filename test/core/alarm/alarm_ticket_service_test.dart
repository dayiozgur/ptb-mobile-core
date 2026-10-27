import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/supabase_fakes.dart';

class _MockCache extends Mock implements CacheManager {}

/// AlarmService — alarm → FixFlow iş emri RPC sarmalayıcıları (web ile aynı
/// fn_pms_alarm_create_ticket / _linked_ticket / _ticket_route_preview).
void main() {
  late SupabaseHarness h;
  late AlarmService svc;

  setUp(() {
    h = SupabaseHarness();
    svc = AlarmService(supabase: h.client, cacheManager: _MockCache());
  });

  group('createFixflowTicket', () {
    test('parametreler kırpılır, boş açıklama → null; TABLE satırı döner',
        () async {
      h.stubRpc('fn_pms_alarm_create_ticket', result: [
        {'id': 't1', 'code': 'TCK-0042'},
      ]);
      final t = await svc.createFixflowTicket('a1',
          subject: '  Yüksek basınç  ', description: '   ');
      expect(t.id, 't1');
      expect(t.displayCode, 'TCK-0042');
      expect(h.capturedRpcParams('fn_pms_alarm_create_ticket'), {
        'p_alarm_uid': 'a1',
        'p_subject': 'Yüksek basınç',
        'p_description': null,
      });
    });

    test('kod yoksa displayCode = id', () async {
      h.stubRpc('fn_pms_alarm_create_ticket', result: {'id': 't2'});
      final t = await svc.createFixflowTicket('a1', subject: 'x');
      expect(t.displayCode, 't2');
    });

    test('boş konu → RPC çağrılmaz', () async {
      h.stubRpc('fn_pms_alarm_create_ticket', result: const []);
      expect(() => svc.createFixflowTicket('a1', subject: '  '),
          throwsArgumentError);
      verifyNever(
          () => h.client.rpc<dynamic>(any(), params: any(named: 'params')));
    });

    test('boş sonuç → StateError', () async {
      h.stubRpc('fn_pms_alarm_create_ticket', result: const []);
      expect(
          () => svc.createFixflowTicket('a1', subject: 'x'), throwsStateError);
    });

    test('fixflow_not_entitled hatası tanınır', () async {
      const err =
          PostgrestException(message: 'fixflow_not_entitled', code: '42501');
      h.stubRpc('fn_pms_alarm_create_ticket', error: err);
      Object? caught;
      try {
        await svc.createFixflowTicket('a1', subject: 'x');
      } catch (e) {
        caught = e;
      }
      expect(isFixflowNotEntitled(caught), isTrue);
      expect(isFixflowNotEntitled(Exception('other')), isFalse);
      expect(isFixflowNotEntitled(null), isFalse);
    });
  });

  test('getLinkedTickets: satırlar eşlenir, ticket_id\'siz atlanır', () async {
    h.stubRpc('fn_pms_alarm_linked_ticket', result: [
      {
        'ticket_id': 't1',
        'code': 'TCK-1',
        'subject': 'HP',
        'status': 'open',
        'status_final': false,
        'routing': 'external',
        'created_at': '2026-01-05T09:00:00Z',
      },
      {'ticket_id': 't0', 'code': 'TCK-0', 'status_final': true},
      {'code': 'orphan'},
    ]);
    final list = await svc.getLinkedTickets('a1');
    expect(list.map((t) => t.ticketId), ['t1', 't0']);
    expect(list.first.isOpen, isTrue);
    expect(list.first.createdAt, DateTime.utc(2026, 1, 5, 9));
    expect(list.last.isOpen, isFalse);
    expect(h.capturedRpcParams('fn_pms_alarm_linked_ticket'),
        {'p_alarm_uid': 'a1'});
  });

  test('getTicketRoutePreview: mod eşlemesi; boş → null', () async {
    h.stubRpc('fn_pms_alarm_ticket_route_preview', result: [
      {
        'mode': 'internal',
        'contractor_name': 'ATALIAN',
        'priority_code': 'critical',
        'target_name': 'Müşteri A',
        'team_name': 'Soğutma',
        'ambiguous': true,
      },
    ]);
    final p = await svc.getTicketRoutePreview('a1');
    expect(p!.mode, AlarmTicketRouteMode.internal);
    expect(p.priorityCode, 'critical');
    expect(p.ambiguous, isTrue);

    h.stubRpc('fn_pms_alarm_ticket_route_preview', result: const []);
    expect(await svc.getTicketRoutePreview('a1'), isNull);
  });

  group('açıklama + yer tutucu', () {
    test('fillTicketPlaceholders: {{k}} ve {k}', () {
      expect(
          fillTicketPlaceholders(
              '{{target}} / {team}', {'target': 'A', 'team': 'B'}),
          'A / B');
    });

    test('buildAlarmTicketDescription: boş satırlar atlanır', () {
      AppClock.setZone('Europe/Istanbul');
      final text = buildAlarmTicketDescription(
        Alarm(
          id: 'a1',
          name: 'HP',
          code: 'HP1',
          variableName: 'Komp-1',
          startTime: DateTime.utc(2026, 1, 5, 9, 0),
        ),
        siteName: 'Depo 3',
        translate: (k) => k,
      );
      expect(text.split('\n'), [
        'common.code: HP1',
        'pms.alarm.col.location: Depo 3',
        'pms.alarm.fixflow.device: Komp-1',
        'pms.alarm.col.start: 05.01.2026 12:00:00',
      ]);
    });
  });
}
