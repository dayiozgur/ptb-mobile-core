import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../helpers/supabase_fakes.dart';

class MockOfflineSyncService extends Mock implements OfflineSyncService {}

class MockConnectivityService extends Mock implements ConnectivityService {}

/// CrmActionsService — CRM aksiyon-çubuğu write-pariteleri:
///   • logActivity   → `fn_crm_log_activity`
///   • logNextStep   → `fn_crm_log_next_step`
///   • completeActivity → `fn_crm_complete_activity`
/// Ctor-inject (sl gerekmez). Hata / geçersiz giriş → `false` (UI'a fırlatmaz).
/// RPC imzaları web CRM'den (my-work.component.ts / crm-activity-timeline)
/// ve mobil crm_entity_actions.dart'tan birebir doğrulandı.
void main() {
  late SupabaseHarness h;
  late CrmActionsService service;

  setUp(() {
    h = SupabaseHarness();
    service = CrmActionsService(supabase: h.client);
  });

  tearDown(() => GetIt.instance.reset());

  group('logActivity', () {
    test('tam payload → doğru params ile RPC + true', () async {
      h.stubRpc('fn_crm_log_activity', result: null);

      final ok = await service.logActivity(
        subject: '  Tanıtım görüşmesi  ',
        activityType: 'meeting',
        notes: '  ilk temas  ',
        outcome: '  olumlu  ',
        relatedDealId: 'd1',
        relatedDealName: '  Acme lisans  ',
        relatedContactId: 'c1',
        relatedContactName: '  Ali Veli  ',
      );

      expect(ok, isTrue);
      expect(h.capturedRpcParams('fn_crm_log_activity'), {
        'p_subject': 'Tanıtım görüşmesi', // trim
        'p_activity_type': 'meeting',
        'p_notes': 'ilk temas', // trim
        'p_outcome': 'olumlu', // trim
        'p_related_contact_id': 'c1',
        'p_related_contact_name': 'Ali Veli', // trim
        'p_related_deal_id': 'd1',
        'p_related_deal_name': 'Acme lisans', // trim
      });
    });

    test('opsiyoneller yok/boş → payload\'da yer almaz', () async {
      h.stubRpc('fn_crm_log_activity', result: null);

      final ok = await service.logActivity(
        subject: 'Not',
        relatedDealId: 'd9',
        notes: '   ', // boş → atlanır
        outcome: '', // boş → atlanır
      );

      expect(ok, isTrue);
      final p = h.capturedRpcParams('fn_crm_log_activity')!;
      expect(p['p_subject'], 'Not');
      expect(p['p_activity_type'], 'note'); // varsayılan tip
      expect(p['p_related_deal_id'], 'd9');
      expect(p.containsKey('p_notes'), isFalse);
      expect(p.containsKey('p_outcome'), isFalse);
      expect(p.containsKey('p_related_contact_id'), isFalse);
      expect(p.containsKey('p_related_contact_name'), isFalse);
      expect(p.containsKey('p_related_deal_name'), isFalse);
    });

    test('boş konu → RPC çağrılmaz, false', () async {
      h.stubRpc('fn_crm_log_activity', result: null);
      expect(await service.logActivity(subject: '   '), isFalse);
      expect(await service.logActivity(subject: ''), isFalse);
    });

    test('RPC hatası → false (fırlatmaz)', () async {
      h.stubRpc('fn_crm_log_activity', error: Exception('boom'));
      expect(await service.logActivity(subject: 'x'), isFalse);
    });
  });

  group('logNextStep', () {
    test('geçerli → p_deal_id + p_next_date (YYYY-MM-DD) + true', () async {
      h.stubRpc('fn_crm_log_next_step', result: null);

      final ok = await service.logNextStep(
        dealId: 'd1',
        dueDate: DateTime(2026, 9, 3, 14, 30), // saat kısmı düşer
      );

      expect(ok, isTrue);
      expect(h.capturedRpcParams('fn_crm_log_next_step'), {
        'p_deal_id': 'd1',
        'p_next_date': '2026-09-03', // yalnız tarih
      });
    });

    test('tek haneli ay/gün sıfır-dolgulu', () async {
      h.stubRpc('fn_crm_log_next_step', result: null);
      await service.logNextStep(dealId: 'd2', dueDate: DateTime(2026, 1, 5));
      expect(h.capturedRpcParams('fn_crm_log_next_step')!['p_next_date'],
          '2026-01-05');
    });

    test('boş dealId → RPC çağrılmaz, false', () async {
      h.stubRpc('fn_crm_log_next_step', result: null);
      expect(
        await service.logNextStep(dealId: '  ', dueDate: DateTime(2026, 9, 3)),
        isFalse,
      );
    });

    test('RPC hatası → false (fırlatmaz)', () async {
      h.stubRpc('fn_crm_log_next_step', error: Exception('boom'));
      expect(
        await service.logNextStep(dealId: 'd1', dueDate: DateTime(2026, 9, 3)),
        isFalse,
      );
    });
  });

  group('completeActivity', () {
    test('geçerli → p_activity_id + true', () async {
      h.stubRpc('fn_crm_complete_activity', result: null);

      final ok = await service.completeActivity(activityId: 'a1');

      expect(ok, isTrue);
      expect(h.capturedRpcParams('fn_crm_complete_activity'), {
        'p_activity_id': 'a1',
      });
    });

    test('boş activityId → RPC çağrılmaz, false', () async {
      h.stubRpc('fn_crm_complete_activity', result: null);
      expect(await service.completeActivity(activityId: '  '), isFalse);
    });

    test('RPC hatası → false (fırlatmaz)', () async {
      h.stubRpc('fn_crm_complete_activity', error: Exception('boom'));
      expect(await service.completeActivity(activityId: 'a1'), isFalse);
    });
  });

  group('offline kuyruk', () {
    late MockOfflineSyncService sync;
    late MockConnectivityService conn;

    void registerOffline({required bool offline}) {
      sync = MockOfflineSyncService();
      conn = MockConnectivityService();
      when(() => sync.isInitialized).thenReturn(true);
      when(() => conn.isOffline).thenReturn(offline);
      when(() => sync.enqueueRpc(
            function: any(named: 'function'),
            params: any(named: 'params'),
            entityId: any(named: 'entityId'),
            idempotencyKey: any(named: 'idempotencyKey'),
          )).thenAnswer((inv) async => PendingOperation.rpc(
            id: 'op-1',
            function: inv.namedArguments[#function] as String,
            params: const {},
            createdAt: DateTime(2026),
          ));
      final sl = GetIt.instance;
      sl.registerSingleton<OfflineSyncService>(sync);
      sl.registerSingleton<ConnectivityService>(conn);
    }

    test('OFFLINE logActivity → enqueueRpc(fn_crm_log_activity), ağa gitmez, true',
        () async {
      registerOffline(offline: true);
      // RPC ağ yolu STUB'LANMADI → çağrılırsa test patlar (kuyruk yolu kanıtı).

      final ok = await service.logActivity(subject: 'Görüşme', relatedDealId: 'd1');

      expect(ok, isTrue);
      final c = verify(() => sync.enqueueRpc(
            function: captureAny(named: 'function'),
            params: captureAny(named: 'params'),
            entityId: captureAny(named: 'entityId'),
            idempotencyKey: any(named: 'idempotencyKey'),
          )).captured;
      expect(c[0], 'fn_crm_log_activity');
      expect((c[1] as Map)['p_subject'], 'Görüşme');
      expect(c[2], 'd1'); // entityId = deal
    });

    test('OFFLINE logNextStep → enqueueRpc(fn_crm_log_next_step) + true', () async {
      registerOffline(offline: true);
      final ok =
          await service.logNextStep(dealId: 'd2', dueDate: DateTime(2026, 9, 3));
      expect(ok, isTrue);
      final c = verify(() => sync.enqueueRpc(
            function: captureAny(named: 'function'),
            params: captureAny(named: 'params'),
            entityId: any(named: 'entityId'),
            idempotencyKey: any(named: 'idempotencyKey'),
          )).captured;
      expect(c[0], 'fn_crm_log_next_step');
      expect((c[1] as Map)['p_next_date'], '2026-09-03');
    });

    test('OFFLINE completeActivity → enqueueRpc(fn_crm_complete_activity) + true',
        () async {
      registerOffline(offline: true);
      final ok = await service.completeActivity(activityId: 'a1');
      expect(ok, isTrue);
      verify(() => sync.enqueueRpc(
            function: 'fn_crm_complete_activity',
            params: any(named: 'params'),
            entityId: 'a1',
            idempotencyKey: any(named: 'idempotencyKey'),
          )).called(1);
    });

    test('ONLINE (kayıtlı ama isOffline=false) → ağ yolu, kuyruk yok', () async {
      registerOffline(offline: false);
      h.stubRpc('fn_crm_log_activity', result: null);

      final ok = await service.logActivity(subject: 'x', relatedDealId: 'd1');

      expect(ok, isTrue);
      expect(h.capturedRpcParams('fn_crm_log_activity')!['p_subject'], 'x');
      verifyNever(() => sync.enqueueRpc(
            function: any(named: 'function'),
            params: any(named: 'params'),
            entityId: any(named: 'entityId'),
            idempotencyKey: any(named: 'idempotencyKey'),
          ));
    });
  });
}
