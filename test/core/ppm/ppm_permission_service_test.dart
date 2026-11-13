import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../helpers/supabase_fakes.dart';

void main() {
  group('PpmPermissions', () {
    test('not enforced → every action allowed', () {
      final p = PpmPermissions.fromJson({'enforced': false, 'actions': []});
      expect(p.allows(PpmAction.sprintManage), isTrue);
      expect(p.canRank, isTrue);
    });

    test('enforced → only granted actions', () {
      final p = PpmPermissions.fromJson({
        'enforced': true,
        'actions': ['issue.edit', 'backlog.rank'],
      });
      expect(p.allows(PpmAction.issueEdit), isTrue);
      expect(p.allows(PpmAction.issueTransition), isFalse);
      expect(p.allows(PpmAction.sprintManage), isFalse);
      expect(p.canRank, isTrue);
    });

    test('rank is allowed by sprint.manage alone (server rule)', () {
      final p = PpmPermissions.fromJson({
        'enforced': true,
        'actions': ['sprint.manage'],
      });
      expect(p.canRank, isTrue);
    });

    test('malformed payload → open (nothing hidden)', () {
      expect(PpmPermissions.fromJson(null).enforced, isFalse);
      expect(PpmPermissions.fromJson('x').allows(PpmAction.issueDelete), isTrue);
    });
  });

  group('PpmPermissionService.load', () {
    late SupabaseHarness h;
    late PpmPermissionService svc;

    setUp(() {
      h = SupabaseHarness();
      svc = PpmPermissionService(supabase: h.client);
    });

    test('calls fn_ppm_my_effective_permissions with the project and caches',
        () async {
      h.stubRpc('fn_ppm_my_effective_permissions', result: {
        'enforced': true,
        'actions': ['issue.transition'],
      });

      final p = await svc.load(' p1 ');
      await svc.load('p1');

      expect(p.allows(PpmAction.issueTransition), isTrue);
      expect(p.allows(PpmAction.sprintManage), isFalse);
      final captured = verify(() => h.client.rpc<dynamic>(
              'fn_ppm_my_effective_permissions',
              params: captureAny(named: 'params')))
          .captured;
      expect(captured, [
        {'p_project_id': 'p1'}
      ]); // one round-trip: the second load is served from the cache
    });

    test('RPC error → open (the server stays the protection)', () async {
      h.stubRpc('fn_ppm_my_effective_permissions',
          error: const PostgrestException(message: 'boom', code: '500'));
      final p = await svc.load('p1');
      expect(p.enforced, isFalse);
    });

    test('empty project id → open, no call', () async {
      expect((await svc.load('  ')).enforced, isFalse);
      verifyNever(() => h.client.rpc<dynamic>(any(),
          params: any(named: 'params')));
    });
  });

  group('WriteOutcome.fromError', () {
    test('42501 → denied, other → failed', () {
      expect(
          WriteOutcome.fromError(
              const PostgrestException(message: 'x', code: '42501')),
          WriteOutcome.denied);
      expect(WriteOutcome.fromError(Exception('db down')), WriteOutcome.failed);
    });
  });
}
