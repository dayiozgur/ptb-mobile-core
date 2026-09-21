import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../helpers/supabase_fakes.dart';

/// SprintService — sprint yaşam-döngüsü (web PtbSprintService mobil paritesi):
///   • listSprints    → sprints (RLS scope)
///   • startSprint    → sprints.state='active'
///   • completeSprint → state='closed' + biten-olmayan issue'ları backlog'a
/// Yazma hatası → false (fırlatmaz). Tenant RLS'e bırakılır (explicit yok).
void main() {
  late SupabaseHarness h;
  late SprintService service;

  setUp(() {
    h = SupabaseHarness();
    service = SprintService(supabase: h.client);
  });

  group('listSprints', () {
    test('satırları Sprint listesine parse eder (state + projectId dahil)', () async {
      h.stubFrom('sprints', result: <Map<String, dynamic>>[
        {'id': 's1', 'project_id': 'p1', 'name': 'Sprint 1', 'state': 'active', 'entity_type': 'ppm_task'},
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

    test('hata → boş liste (fırlatmaz)', () async {
      h.stubFrom('sprints', error: Exception('db down'));
      expect(await service.listSprints('p1'), isEmpty);
    });
  });

  group('startSprint', () {
    test('geçerli → state=active update + true', () async {
      h.stubFrom('sprints', result: <Map<String, dynamic>>[{'id': 's1'}]);

      final ok = await service.startSprint('  s1  ');

      expect(ok, isTrue);
      final upd = h.queryByTable['sprints']!.calls
          .firstWhere((i) => i.memberName == #update);
      expect((upd.positionalArguments.first as Map)['state'], 'active');
    });

    test('boş id → false', () async {
      expect(await service.startSprint('  '), isFalse);
    });

    test('etkilenen satır yok → false', () async {
      h.stubFrom('sprints', result: <Map<String, dynamic>>[]);
      expect(await service.startSprint('s1'), isFalse);
    });

    test('unique-violation/hata → false (fırlatmaz)', () async {
      h.stubFrom('sprints', error: Exception('duplicate key value'));
      expect(await service.startSprint('s1'), isFalse);
    });
  });

  group('completeSprint', () {
    test('geçerli → state=closed + biten-olmayanı backlog (not-in final), true',
        () async {
      h.stubFrom('sprints', result: <String, dynamic>{'entity_type': 'ppm_task'});
      h.stubFrom('status_definitions',
          result: <Map<String, dynamic>>[{'code': 'done'}, {'code': 'cancelled'}]);
      h.stubFrom('form_submissions', result: <Map<String, dynamic>>[]);

      final ok = await service.completeSprint('s1');

      expect(ok, isTrue);
      // sprint 'closed' yazıldı
      final closed = h.queryByTable['sprints']!.calls
          .where((i) => i.memberName == #update)
          .any((i) => (i.positionalArguments.first as Map)['state'] == 'closed');
      expect(closed, isTrue);
      // form_submissions: sprint_id null + not-in final filtresi
      final fs = h.queryByTable['form_submissions']!.calls;
      final fsUpd = fs.firstWhere((i) => i.memberName == #update);
      final payload = fsUpd.positionalArguments.first as Map;
      expect(payload.containsKey('sprint_id'), isTrue);
      expect(payload['sprint_id'], isNull);
      expect(fs.any((i) => i.memberName == #not), isTrue);
    });

    test('boş id → false', () async {
      expect(await service.completeSprint(''), isFalse);
    });

    test('hata → false (fırlatmaz)', () async {
      h.stubFrom('sprints', error: Exception('db down'));
      expect(await service.completeSprint('s1'), isFalse);
    });
  });
}
