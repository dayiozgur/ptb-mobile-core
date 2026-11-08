import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/supabase_fakes.dart';
import 'fixflow_test_utils.dart';

void main() {
  late SupabaseHarness h;
  late FixflowStatusService svc;

  const translations = {
    'status.open': 'Open (tr)',
    'status.assigned': 'Assigned (tr)',
  };

  setUp(() {
    h = SupabaseHarness();
    svc = FixflowStatusService(
      supabase: h.client,
      session: FixflowSession.fixed(
        userId: 'u1',
        tenantId: 't1',
        roles: {'technician'},
      ),
      translate: (k) => translations[k] ?? k,
    );
  });

  group('catalog', () {
    test('FixFlow platform filtresi + tenant override + i18n + sıralama',
        () async {
      h.stubFrom('status_definitions', result: [
        {
          'code': 'resolved',
          'name': 'Çözüldü',
          'color': '#22C55E',
          'is_final': true,
          'sort_order': 3,
          'is_system': false,
          'metadata': null,
        },
        {
          'code': 'open',
          'name': 'Açık',
          'color': '#3B82F6',
          'is_initial': true,
          'sort_order': 0,
          'is_system': true,
          'metadata': null,
        },
        {
          // Aynı code için tenant satırı sistemi yener.
          'code': 'open',
          'name': 'Açık-T',
          'color': '#000000',
          'is_initial': true,
          'sort_order': 0,
          'is_system': false,
          'metadata': {
            'i18n': {'name': 'status.open'}
          },
        },
        {
          'code': 'assigned',
          'name': 'Atandı',
          'sort_order': 1,
          'is_system': true,
          'metadata': null,
        },
      ]);

      final c = await svc.catalog('ticket');

      expect(c.statuses.map((s) => s.code), ['open', 'assigned', 'resolved']);
      expect(c.byCode('open')!.colorHex, '#000000'); // tenant satırı
      expect(c.nameOf('open'), 'Open (tr)'); // metadata.i18n.name
      expect(c.nameOf('assigned'), 'Assigned (tr)'); // is_system → status.<code>
      expect(c.nameOf('resolved'), 'Çözüldü'); // anahtar yok → DB adı
      expect(c.nameOf('needs_parts'), 'Needs parts'); // tanımsız → humanize
      expect(c.openCodes, ['open', 'assigned']);
      expect(c.finalCodes, ['resolved']);
      expect(c.initialCode, 'open');

      expect(hasEq(h, 'status_definitions', 'entity_type', 'ticket'), isTrue);
      final ors = callsNamed(h, 'status_definitions', 'or');
      expect(ors.single.first,
          contains('platform_id.eq.${FixflowConstants.platformId}'));
    });

    test('memoize: ikinci çağrı ağa gitmez; boş sonuç önbelleğe alınmaz',
        () async {
      h.stubFrom('status_definitions', result: [
        {'code': 'open', 'name': 'Açık', 'sort_order': 0, 'is_system': false},
      ]);
      await svc.catalog('ticket');
      final first = h.queryByTable['status_definitions'];
      await svc.catalog('ticket');
      expect(identical(first, h.queryByTable['status_definitions']), isTrue);

      h.stubFrom('status_definitions', result: <Map<String, dynamic>>[]);
      final empty = await svc.catalog('maintenance');
      expect(empty.statuses, isEmpty);
      final q1 = h.queryByTable['status_definitions'];
      await svc.catalog('maintenance');
      expect(identical(q1, h.queryByTable['status_definitions']), isFalse);
    });

    test('hata → boş katalog (fırlatmaz)', () async {
      h.stubFrom('status_definitions',
          error: const PostgrestException(message: 'boom'));
      final c = await svc.catalog('ticket');
      expect(c.statuses, isEmpty);
    });
  });

  group('availableTransitions', () {
    Map<String, dynamic> tr(String id, String from, String to,
            {List<String>? roles,
            bool comment = false,
            bool form = false,
            bool fin = false,
            int sort = 0}) =>
        {
          'id': id,
          'name': '$from->$to',
          'required_roles': roles,
          'requires_comment': comment,
          'requires_confirmation': false,
          'required_form_template_id': form ? 'f1' : null,
          'sort_order': sort,
          'from_status': {'code': from},
          'to_status': {
            'code': to,
            'name': to.toUpperCase(),
            'is_final': fin,
            'sort_order': sort,
            'is_system': false,
          },
        };

    test('from-kodu, rol, form ve hedef tekilleştirme filtreleri', () async {
      h.stubFrom('status_transitions', result: [
        tr('1', 'assigned', 'in_progress', roles: ['technician', 'admin']),
        tr('2', 'assigned', 'open', roles: ['dispatcher', 'admin'],
            comment: true),
        tr('3', 'assigned', 'in_progress'), // aynı hedef → elenir
        tr('4', 'assigned', 'on_hold', form: true), // form → elenir
        tr('5', 'assigned', 'cancelled', fin: true, comment: true),
        tr('6', 'open', 'assigned'), // başka from
      ]);

      final list = await svc.availableTransitions('ticket', 'assigned');

      expect(list.map((t) => t.toStatus.code), ['in_progress', 'cancelled']);
      expect(list.first.id, '1');
      expect(list.last.requiresComment, isTrue);
      expect(list.last.toStatus.isFinal, isTrue);
      expect(hasEq(h, 'status_transitions', 'entity_type', 'ticket'), isTrue);
    });

    test('ROLE_ADMIN kaba rolü normalize edilir', () async {
      final admin = FixflowStatusService(
        supabase: h.client,
        session: FixflowSession.fixed(roles: {normalizeFixflowRole('ROLE_ADMIN')}),
        translate: (k) => k,
      );
      h.stubFrom('status_transitions', result: [
        tr('2', 'assigned', 'open', roles: ['dispatcher', 'ADMIN']),
      ]);
      final list = await admin.availableTransitions('ticket', 'assigned');
      expect(list.single.toStatus.code, 'open');
    });

    test('hata → boş liste', () async {
      h.stubFrom('status_transitions',
          error: const PostgrestException(message: 'x'));
      expect(await svc.availableTransitions('ticket', 'open'), isEmpty);
    });
  });

  group('executeTransition (status-transition EF)', () {
    test('web ile aynı gövde; yorum kırpılır', () async {
      h.stubFunction('status-transition', data: {
        'success': true,
        'data': {'newStatus': 'in_progress'}
      });
      await svc.executeTransition(
        entityType: 'ticket',
        entityId: 'tk1',
        toStatus: 'in_progress',
        comment: '  başladım  ',
      );
      expect(h.capturedFunctionBody('status-transition'), {
        'entityType': 'ticket',
        'entityId': 'tk1',
        'toStatus': 'in_progress',
        'comment': 'başladım',
      });
    });

    test('boş yorum gönderilmez', () async {
      h.stubFunction('status-transition', data: {'success': true});
      await svc.executeTransition(
          entityType: 'ticket', entityId: 'tk1', toStatus: 'resolved',
          comment: '   ');
      expect(h.capturedFunctionBody('status-transition')!.containsKey('comment'),
          isFalse);
    });

    test('2xx-dışı yanıt → FixflowTransitionException(code)', () async {
      h.stubFunction('status-transition',
          error: const FunctionException(status: 400, details: {
            'error': {
              'code': 'ERR_COMMENT_REQUIRED',
              'message': 'This transition requires a comment'
            }
          }));
      await expectLater(
        svc.executeTransition(
            entityType: 'ticket', entityId: 'tk1', toStatus: 'open'),
        throwsA(isA<FixflowTransitionException>()
            .having((e) => e.commentRequired, 'commentRequired', isTrue)),
      );
    });

    test('success:false zarfı → hata', () async {
      h.stubFunction('status-transition', data: {
        'success': false,
        'error': {'code': 'ERR_FORBIDDEN', 'message': 'no'}
      });
      await expectLater(
        svc.executeTransition(
            entityType: 'ticket', entityId: 'tk1', toStatus: 'open'),
        throwsA(isA<FixflowTransitionException>()
            .having((e) => e.forbidden, 'forbidden', isTrue)),
      );
    });

    test('detaysız FunctionException → EDGE_FUNCTION_ERROR', () async {
      h.stubFunction('status-transition',
          error: const FunctionException(status: 500));
      await expectLater(
        svc.executeTransition(
            entityType: 'ticket', entityId: 'tk1', toStatus: 'open'),
        throwsA(isA<FixflowTransitionException>()
            .having((e) => e.code, 'code', 'EDGE_FUNCTION_ERROR')),
      );
    });
  });
}
