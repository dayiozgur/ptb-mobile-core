import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../helpers/supabase_fakes.dart';

/// SprintService — sprint yaşam-döngüsü (web PtbSprintService mobil paritesi):
///   • listSprints    → sprints (RLS scope)
///   • startSprint    → sprints.state='active'
///   • completeSprint → state='closed' + biten-olmayan issue'ları backlog'a
/// Yazma hatası → WriteOutcome.failed / .denied (fırlatmaz). Tenant RLS'e bırakılır (explicit yok).
void main() {
  late SupabaseHarness h;
  late SprintService service;

  setUp(() {
    h = SupabaseHarness();
    service = SprintService(supabase: h.client);
  });

  group('listSprints', () {
    test('satırları Sprint listesine parse eder (state + projectId dahil)',
        () async {
      h.stubFrom('sprints', result: <Map<String, dynamic>>[
        {
          'id': 's1',
          'project_id': 'p1',
          'name': 'Sprint 1',
          'state': 'active',
          'entity_type': 'ppm_task'
        },
        {'id': 's2', 'project_id': 'p1', 'name': 'Sprint 2', 'state': 'future'},
        {'id': 's3', 'project_id': 'p1', 'name': 'Sprint 3', 'state': 'closed'},
      ]);

      final list = await service.listSprints('p1');

      expect(list.map((s) => s.id), ['s1', 's2', 's3']);
      expect(list[0].state, SprintState.active);
      expect(list[1].state, SprintState.future);
      expect(list[2].state, SprintState.closed);
      expect(list[0].entityType, 'ppm_task');
      expect(list[0].projectId, 'p1');
    });

    test('boş projectId → sorgu yok, boş liste', () async {
      expect(await service.listSprints('  '), isEmpty);
    });

    test('read error is rethrown (not "no sprints")', () async {
      h.stubFrom('sprints', error: Exception('db down'));
      expect(service.listSprints('p1'), throwsException);
    });
  });

  group('startSprint', () {
    test('geçerli → state=active update + true', () async {
      h.stubFrom('sprints', result: <Map<String, dynamic>>[
        {'id': 's1'}
      ]);

      final ok = await service.startSprint('  s1  ');

      expect(ok, WriteOutcome.ok);
      final upd = h.queryByTable['sprints']!.calls
          .firstWhere((i) => i.memberName == #update);
      expect((upd.positionalArguments.first as Map)['state'], 'active');
    });

    test('boş id → failed', () async {
      expect(await service.startSprint('  '), WriteOutcome.failed);
    });

    test('no row changed (RLS refused the update) → denied', () async {
      h.stubFrom('sprints', result: <Map<String, dynamic>>[]);
      expect(await service.startSprint('s1'), WriteOutcome.denied);
    });

    test('unique-violation/hata → failed (fırlatmaz)', () async {
      h.stubFrom('sprints', error: Exception('duplicate key value'));
      expect(await service.startSprint('s1'), WriteOutcome.failed);
    });
  });

  group('completeSprint', () {
    test('geçerli → state=closed + biten-olmayanı backlog (not-in final), true',
        () async {
      h.stubFrom('sprints', result: <Map<String, dynamic>>[
        {'id': 's1', 'entity_type': 'ppm_task'}
      ]);
      h.stubFrom('status_definitions', result: <Map<String, dynamic>>[
        {'code': 'done'},
        {'code': 'cancelled'}
      ]);
      h.stubFrom('form_submissions', result: <Map<String, dynamic>>[]);

      final ok = await service.completeSprint('s1');

      expect(ok, WriteOutcome.ok);
      // sprint 'closed' yazıldı
      final closed = h.queryByTable['sprints']!.calls
          .where((i) => i.memberName == #update)
          .any(
              (i) => (i.positionalArguments.first as Map)['state'] == 'closed');
      expect(closed, isTrue);
      // form_submissions: sprint_id null + not-in final filtresi
      final fs = h.queryByTable['form_submissions']!.calls;
      final fsUpd = fs.firstWhere((i) => i.memberName == #update);
      final payload = fsUpd.positionalArguments.first as Map;
      expect(payload.containsKey('sprint_id'), isTrue);
      expect(payload['sprint_id'], isNull);
      expect(fs.any((i) => i.memberName == #not), isTrue);
    });

    test('boş id → failed', () async {
      expect(await service.completeSprint(''), WriteOutcome.failed);
    });

    test('hata → failed (fırlatmaz)', () async {
      h.stubFrom('sprints', error: Exception('db down'));
      expect(await service.completeSprint('s1'), WriteOutcome.failed);
    });

    test('refused close (no row changed) → denied, issues untouched',
        () async {
      h.stubFrom('sprints', result: <Map<String, dynamic>>[]);
      h.stubFrom('form_submissions', result: <Map<String, dynamic>>[]);

      expect(await service.completeSprint('s1'), WriteOutcome.denied);
      expect(h.queryByTable['form_submissions'], isNull);
    });

    test('issue trigger refuses moving issues back (42501) → denied',
        () async {
      h.stubFrom('sprints', result: <Map<String, dynamic>>[
        {'id': 's1', 'entity_type': null}
      ]);
      h.stubFrom('form_submissions',
          error: const PostgrestException(
              message: 'ppm_permission_denied: backlog.rank', code: '42501'));

      expect(await service.completeSprint('s1'), WriteOutcome.denied);
    });
  });
}
