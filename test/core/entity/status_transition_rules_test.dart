import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

Map<String, dynamic> _tx(
  String id,
  String from,
  String to, {
  List<String>? roles,
  bool comment = false,
  bool confirm = false,
  bool form = false,
  int sort = 0,
  String? tenant,
}) =>
    {
      'id': id,
      'name': '$from->$to',
      'tenant_id': tenant,
      'required_roles': roles,
      'requires_comment': comment,
      'requires_confirmation': confirm,
      'required_form_template_id': form ? 'form-1' : null,
      'sort_order': sort,
      'from_status': {'code': from},
      'to_status': {'code': to, 'name': to.toUpperCase(), 'color': '#112233'},
    };

void main() {
  group('StatusTransitionRules.allowed', () {
    test('only transitions from the current status, ordered by sort_order', () {
      final rows = [
        _tx('1', 'open', 'done', sort: 20),
        _tx('2', 'open', 'in_progress', sort: 10),
        _tx('3', 'in_progress', 'done', sort: 5),
      ];
      final out = StatusTransitionRules.allowed(rows,
          entityType: 'task', fromCode: 'open', roles: const {});
      expect(out.map((t) => t.toCode), ['in_progress', 'done']);
      expect(out.first.toRow['name'], 'IN_PROGRESS');
    });

    test('role filter: required_roles normalized (ROLE_ADMIN ≙ admin)', () {
      final rows = [
        _tx('1', 'open', 'closed', roles: ['ROLE_ADMIN']),
        _tx('2', 'open', 'assigned', roles: ['dispatcher']),
        _tx('3', 'open', 'in_progress'),
      ];
      final user = StatusTransitionRules.allowed(rows,
          entityType: 'ticket', fromCode: 'open', roles: {'ROLE_USER'});
      expect(user.map((t) => t.toCode), ['in_progress']);
      final admin = StatusTransitionRules.allowed(rows,
          entityType: 'ticket', fromCode: 'open', roles: {'admin'});
      expect(admin.map((t) => t.toCode), ['closed', 'in_progress']);
    });

    test('EF row choice: own tenant first, then lowest sort_order; role on winner', () {
      // System row is permissive, tenant row is restricted → EF picks the
      // tenant row and would reject a non-manager, so it is NOT offered.
      final rows = [
        _tx('a', 'open', 'closed', tenant: StatusTransitionRules.systemTenantId),
        _tx('b', 'open', 'closed', tenant: 't1', roles: ['manager'], sort: 50),
      ];
      final out = StatusTransitionRules.allowed(rows,
          entityType: 'ticket', fromCode: 'open', roles: {'user'}, tenantId: 't1');
      expect(out, isEmpty);

      // Same tenant: the lower sort_order wins (restricted row at 0).
      final rows2 = [
        _tx('x', 'open', 'closed', tenant: 't1', sort: 10),
        _tx('y', 'open', 'closed', tenant: 't1', roles: ['manager'], sort: 0),
      ];
      expect(
          StatusTransitionRules.allowed(rows2,
              entityType: 'ticket', fromCode: 'open', roles: {'user'}, tenantId: 't1'),
          isEmpty);
      final mgr = StatusTransitionRules.allowed(rows2,
          entityType: 'ticket', fromCode: 'open', roles: {'manager'}, tenantId: 't1');
      expect(mgr.single.id, 'y');
    });

    test('comment / confirmation flags carried; form-required hidden by default', () {
      final rows = [
        _tx('1', 'open', 'on_hold', comment: true),
        _tx('2', 'open', 'cancelled', confirm: true),
        _tx('3', 'open', 'inspected', form: true),
      ];
      final out = StatusTransitionRules.allowed(rows,
          entityType: 'ticket', fromCode: 'open', roles: const {});
      expect(out.map((t) => t.toCode), ['on_hold', 'cancelled']);
      expect(out[0].requiresComment, isTrue);
      expect(out[1].requiresConfirmation, isTrue);
      final withForm = StatusTransitionRules.allowed(rows,
          entityType: 'ticket',
          fromCode: 'open',
          roles: const {},
          includeFormRequired: true);
      expect(withForm.last.requiresForm, isTrue);
    });

    test('lead→converted is never offered (wizard-only); deal→converted is', () {
      final rows = [
        _tx('1', 'qualified', 'converted'),
        _tx('2', 'qualified', 'disqualified'),
      ];
      expect(
          StatusTransitionRules.allowed(rows,
                  entityType: 'lead', fromCode: 'qualified', roles: const {})
              .map((t) => t.toCode),
          ['disqualified']);
      expect(
          StatusTransitionRules.allowed(rows,
                  entityType: 'deal', fromCode: 'qualified', roles: const {})
              .map((t) => t.toCode),
          ['converted', 'disqualified']);
    });
  });

  group('StatusTransitionRules.pathTo', () {
    final ladder = [
      _tx('1', 'new', 'contacted', sort: 10),
      _tx('2', 'contacted', 'qualified', sort: 20),
      _tx('3', 'qualified', 'converted', sort: 30),
      _tx('4', 'new', 'disqualified', sort: 60),
      _tx('5', 'disqualified', 'converted', sort: 70), // through a final → ignored
    ];

    test('walks the workflow without skips', () {
      expect(
          StatusTransitionRules.pathTo(ladder,
              entityType: 'lead',
              fromCode: 'new',
              toCode: 'converted',
              roles: const {},
              finalCodes: {'disqualified', 'converted'}),
          ['contacted', 'qualified', 'converted']);
      expect(
          StatusTransitionRules.pathTo(ladder,
              entityType: 'lead',
              fromCode: 'qualified',
              toCode: 'converted',
              roles: const {}),
          ['converted']);
    });

    test('unreachable → null', () {
      expect(
          StatusTransitionRules.pathTo(ladder,
              entityType: 'lead',
              fromCode: 'converted',
              toCode: 'new',
              roles: const {}),
          isNull);
    });
  });

  group('labels + roles', () {
    String tr(String k) =>
        const {'crm.status.won': 'Kazanıldı', 'status.lead': 'Aday'}[k] ?? k;

    test('metadata.i18n.name → status.<code> (system) → name', () {
      expect(
          StatusTransitionRules.localizedName({
            'code': 'won',
            'name': 'Won',
            'metadata': {
              'i18n': {'name': 'crm.status.won'}
            },
          }, tr),
          'Kazanıldı');
      expect(
          StatusTransitionRules.localizedName(
              {'code': 'lead', 'name': 'Lead', 'is_system': true}, tr),
          'Aday');
      expect(
          StatusTransitionRules.localizedName(
              {'code': 'lead', 'name': 'Lead', 'is_system': false}, tr),
          'Lead');
      expect(StatusTransitionRules.localizedName({'code': 'needs_parts'}, tr),
          'Needs parts');
    });

    test('effectiveRoles: JWT roles win, coarse role only as fallback', () {
      expect(
          StatusTransitionRules.effectiveRoles(
              jwtRoles: ['ROLE_TECHNICIAN'], coarseRole: 'ROLE_ADMIN'),
          {'technician'});
      expect(
          StatusTransitionRules.effectiveRoles(
              jwtRoles: const [], coarseRole: 'ROLE_ADMIN'),
          {'admin'});
      expect(StatusTransitionRules.effectiveRoles(), isEmpty);
    });
  });
}
