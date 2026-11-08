import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_crm/features/leads/lead_convert_service.dart';

import 'helpers/fake_lead_convert.dart';

/// Lead → deal conversion — web `LeadConvertService` parity.
void main() {
  group('LeadConvertLogic', () {
    test('dealIdFromNodeResults / dealErrorFromNodeResults', () {
      expect(
          LeadConvertLogic.dealIdFromNodeResults(
              createdDealExecution('d9')['node_results']),
          'd9');
      expect(
          LeadConvertLogic.dealIdFromNodeResults({
            'n': {
              'output': {'entityType': 'deal', 'entityId': 'x', 'created': false}
            }
          }),
          isNull);
      expect(
          LeadConvertLogic.dealErrorFromNodeResults({
            'n': {
              'nodeType': 'action_create_entity',
              'status': 'failed',
              'error': 'amount required'
            }
          }),
          'amount required');
      expect(LeadConvertLogic.dealErrorFromNodeResults(null), isNull);
    });

    test('splitName / readLookup', () {
      final s = LeadConvertLogic.splitName('  Ada  Lovelace King ');
      expect(s.first, 'Ada');
      expect(s.last, 'Lovelace King');
      expect(LeadConvertLogic.splitName('').first, isNull);
      final l = LeadConvertLogic.readLookup(
          {'entityType': 'crm_companies', 'entityId': 'c1', 'displayValue': 'Acme'});
      expect(l.id, 'c1');
      expect(l.name, 'Acme');
      expect(LeadConvertLogic.readLookup('c2').id, 'c2');
    });

    test('fieldValueRows: template fields only, typed column, empties skipped', () {
      final rows = LeadConvertLogic.fieldValueRows(
        submissionId: 's1',
        userId: 'u1',
        fields: {
          'est_value': (id: 'f1', fieldType: 'currency'),
          'company': (id: 'f2', fieldType: 'lookup'),
          'notes': (id: 'f3', fieldType: 'textarea'),
          'h': (id: 'f4', fieldType: 'heading'),
        },
        values: {
          'est_value': '1500',
          'company': {'entityId': 'c1'},
          'notes': '   ',
          'h': 'x',
          'not_a_field': 'y',
        },
      );
      expect(rows.length, 2);
      final byField = {for (final r in rows) r['form_field_id']: r};
      expect(byField['f1']!['value_number'], 1500);
      expect(byField['f2']!['value_json'], {'entityId': 'c1'});
      expect(byField['f1']!['active'], isTrue);
      expect(byField['f1']!['created_by'], 'u1');
    });
  });

  group('LeadConvertService.convert', () {
    ConvertEntity lead({String status = 'new'}) => ConvertEntity(
          id: 'L1',
          status: status,
          formTemplateId: 'tpl-lead',
          values: const {'contact_name': 'Ada Lovelace', 'est_value': 100},
        );

    FakeLeadConvertBackend backend({List<Map<String, dynamic>>? executions}) =>
        FakeLeadConvertBackend(
          entities: {
            'D1': const ConvertEntity(
                id: 'D1',
                status: 'lead',
                formTemplateId: 'tpl-deal',
                values: {'subject': 'Acme deal', 'amount': 100}),
          },
          leadTransitions: leadLadderRows(),
          fields: {
            'tpl-lead': {
              'est_value': (id: 'fl1', fieldType: 'currency'),
              'company': (id: 'fl2', fieldType: 'lookup'),
              'contact': (id: 'fl3', fieldType: 'lookup'),
              'contact_name': (id: 'fl4', fieldType: 'text'),
            },
            'tpl-deal': {
              'amount': (id: 'fd1', fieldType: 'currency'),
              'owner': (id: 'fd2', fieldType: 'lookup'),
              'expected_close': (id: 'fd3', fieldType: 'date'),
              'subject': (id: 'fd4', fieldType: 'text'),
            },
          },
          executionRows: executions ?? [createdDealExecution('D1')],
        );

    LeadConvertService svc(FakeLeadConvertBackend be) =>
        LeadConvertService(backend: be, sleep: (_) async {});

    test('creates company, patches lead, walks the workflow, applies deal details',
        () async {
      final be = backend();
      final result = await svc(be).convert(
        lead: lead(),
        company: const NewCompany('Acme'),
        contact: const ExistingContact('ct1', 'Ada Lovelace'),
        deal: const DealDetails(
            amount: 2500,
            stage: 'qualified',
            ownerId: 'p1',
            ownerName: 'Özgür',
            expectedClose: '2026-12-31'),
        finalLeadCodes: const {'converted', 'disqualified'},
        comment: 'Converted to deal',
      );

      expect(result.dealId, 'D1');
      expect(result.detailsApplied, isTrue);

      // Order: company → lead patch + field values → walk → deal patch → stage.
      expect(be.log, [
        'createCompany:tpl-company:Acme',
        'patch:L1',
        'ffv:L1',
        'tx:lead:contacted',
        'tx:lead:qualified',
        'tx:lead:converted',
        'patch:D1',
        'ffv:D1',
        'tx:deal:qualified',
      ]);
      final leadPatch = be.patched['L1']!;
      expect(leadPatch['est_value'], 2500);
      expect((leadPatch['company'] as Map)['entityId'], 'co-new');
      expect((leadPatch['contact'] as Map)['entityId'], 'ct1');
      expect(leadPatch['contact_name'], 'Ada Lovelace'); // full snapshot kept
      // est_value reaches form_field_values (the EF/automation read it there).
      expect(
          be.replacedRows['L1']!
              .firstWhere((r) => r['form_field_id'] == 'fl1')['value_number'],
          2500);
      expect(be.transitions.where((t) => t.type == 'lead').map((t) => t.comment),
          everyElement('Converted to deal'));

      final dealPatch = be.patched['D1']!;
      expect((dealPatch['owner'] as Map)['entityId'], 'p1');
      expect((dealPatch['owner'] as Map)['entityType'], 'profiles');
      expect(dealPatch['expected_close'], '2026-12-31');
      expect(dealPatch['amount'], 2500);
      expect(dealPatch['subject'], 'Acme deal');
    });

    test('qualified lead: single converted step; no deal reported → dealId null',
        () async {
      final be = backend(executions: const []);
      final s = svc(be)..pollDelays = const [Duration.zero, Duration.zero];
      final result = await s.convert(
        lead: lead(status: 'qualified'),
        company: const NoCompany(),
        contact: const NoContact(),
        deal: const DealDetails(amount: 10, stage: 'lead'),
      );
      expect(result.dealId, isNull);
      expect(be.transitions.map((t) => t.to), ['converted']);
      expect(be.executionPolls, 2);
    });

    test('automation failure surfaces as an error', () async {
      final be = backend(executions: [
        {
          'node_results': {
            'n': {
              'nodeType': 'action_create_entity',
              'status': 'failed',
              'error': 'amount required'
            }
          }
        }
      ]);
      await expectLater(
        svc(be).convert(
          lead: lead(status: 'qualified'),
          company: const NoCompany(),
          contact: const NoContact(),
          deal: const DealDetails(amount: 10),
        ),
        throwsA(isA<LeadConvertException>()
            .having((e) => e.detail, 'detail', 'amount required')),
      );
    });

    test('new company without a company template → keyed error, nothing written',
        () async {
      final be = FakeLeadConvertBackend(companyTemplate: null);
      await expectLater(
        svc(be).convert(
          lead: lead(),
          company: const NewCompany('Acme'),
          contact: const NoContact(),
          deal: const DealDetails(amount: 1),
        ),
        throwsA(isA<LeadConvertException>().having(
            (e) => e.key, 'key', 'crm.lead_convert.error_company_template')),
      );
      expect(be.log, isEmpty);
    });

    test('new contact is linked to the chosen company', () async {
      final be = backend();
      await svc(be).convert(
        lead: lead(status: 'qualified'),
        company: const ExistingCompany('co1', 'Acme'),
        contact: const NewContact(firstName: 'Ada', lastName: 'Lovelace'),
        deal: const DealDetails(amount: 5),
      );
      expect(be.log.first, 'createContact:Ada Lovelace:co1');
    });

    test('findCompanies needs 2+ chars; findContacts splits the name', () async {
      final be = FakeLeadConvertBackend(
          contacts: const [
            ContactMatch(id: 'c1', name: 'Ada'),
            ContactMatch(id: 'c1', name: 'Ada'),
          ]);
      final s = svc(be);
      expect(await s.findCompanies('a'), isEmpty);
      expect(be.log, isEmpty);
      final found = await s.findContacts('ada@x.io', 'Ada Lovelace');
      expect(found.length, 1);
      expect(be.log.single, 'searchContacts:ada@x.io|Ada|Lovelace');
    });
  });
}
