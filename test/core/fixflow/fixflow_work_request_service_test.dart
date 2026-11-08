import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../helpers/supabase_fakes.dart';
import 'fixflow_test_utils.dart';

void main() {
  late SupabaseHarness h;
  late FixflowWorkRequestService svc;

  setUp(() {
    h = SupabaseHarness();
    svc = FixflowWorkRequestService(
      supabase: h.client,
      session: FixflowSession.fixed(
          userId: 'u1', tenantId: 't1', organizationId: 'o1'),
    );
  });

  group('createWorkRequest', () {
    test('web insertItem kolonları; öncelik BÜYÜK harf; başlangıç durumu dışarıdan',
        () async {
      h.stubFrom('work_requests', result: {
        'id': 'w1',
        'code': 'WR-0012',
        'subject': 'Lamba değişimi',
        'status': 'draft',
        'priority': 'HIGH',
      });
      final wr = await svc.createWorkRequest(
        subject: '  Lamba değişimi ',
        description: 'Koridor',
        priorityCode: 'high',
        initialStatus: 'draft',
      );
      expect(wr.displayCode, 'WR-0012');
      final p = insertedPayload(h, 'work_requests');
      expect(p['subject'], 'Lamba değişimi');
      expect(p['description'], 'Koridor');
      expect(p['priority'], 'HIGH');
      expect(p['status'], 'draft');
      expect(p['tenant_id'], 't1');
      expect(p['organization_id'], 'o1');
      expect(p['created_by'], 'u1');
      expect(p['active'], true);
      expect(p['id'], isNotEmpty);
      // Eski mobil şemadaki olmayan kolonlar gönderilmez.
      for (final k in ['title', 'type', 'requested_by_id', 'requested_at']) {
        expect(p.containsKey(k), isFalse, reason: k);
      }
    });

    test('başlangıç durumu yoksa status kolonu gönderilmez; öncelik boş → null',
        () async {
      h.stubFrom('work_requests', result: {'id': 'w2', 'status': ''});
      await svc.createWorkRequest(subject: 'x', priorityCode: ' ');
      final p = insertedPayload(h, 'work_requests');
      expect(p.containsKey('status'), isFalse);
      expect(p['priority'], isNull);
    });

    test('boş konu → ArgumentError, ağ yok', () async {
      expect(() => svc.createWorkRequest(subject: '   '), throwsArgumentError);
      verifyNever(() => h.client.from('work_requests'));
    });
  });

  test('listWorkRequests: mineOnly → created_by; durum filtresi', () async {
    h.stubFrom('work_requests', result: [
      {'id': 'w1', 'subject': 'A', 'status': 'draft', 'staff_id': 's1'}
    ]);
    final l = await svc.listWorkRequests(
        mineOnly: true, statuses: ['draft', 'pending_approval']);
    expect(l.single.staffId, 's1');
    expect(hasEq(h, 'work_requests', 'created_by', 'u1'), isTrue);
    expect(hasEq(h, 'work_requests', 'tenant_id', 't1'), isTrue);
    expect(callsNamed(h, 'work_requests', 'inFilter').single, [
      'status',
      ['draft', 'pending_approval']
    ]);
  });

  test('listMaintenances: scheduled_date sıralı, eşleme', () async {
    h.stubFrom('maintenances', result: [
      {
        'id': 'm1',
        'code': 'MNT-1',
        'name': 'Aylık chiller bakımı',
        'status': 'scheduled',
        'maintenance_type': 'preventive',
        'scheduled_date': '2026-11-10T09:00:00Z',
        'estimated_duration_hours': 3,
      }
    ]);
    final l = await svc.listMaintenances(statuses: ['scheduled']);
    expect(l.single.maintenanceType, 'preventive');
    expect(l.single.estimatedDurationHours, 3);
    expect(callsNamed(h, 'maintenances', 'order').single.first,
        'scheduled_date');
    expect(hasEq(h, 'maintenances', 'status', 'scheduled'), isTrue);
  });

  test('eski WorkRequest.fromJson canlı satırı okuyabilir (subject/code/staff_id)',
      () {
    final wr = WorkRequest.fromJson({
      'id': 'w1',
      'code': 'WR-0001',
      'subject': 'Canlı satır',
      'status': 'in_progress',
      'priority': 'HIGH',
      'staff_id': 's1',
      'team_id': 'tm1',
      'tenant_id': 't1',
      'created_at': '2026-11-01T00:00:00Z',
    });
    expect(wr.title, 'Canlı satır');
    expect(wr.requestNumber, 'WR-0001');
    expect(wr.assignedToId, 's1');
    expect(wr.assignedTeamId, 'tm1');
    expect(wr.status, WorkRequestStatus.inProgress);
    expect(wr.priority, WorkRequestPriority.high);
  });
}
