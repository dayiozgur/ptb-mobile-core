import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_crm/features/companies/crm_companies_service.dart';
import 'package:protoolbag_crm/features/sequences/crm_sequences_service.dart';
import 'package:protoolbag_crm/features/shared/crm_record.dart';
import 'package:protoolbag_crm/features/web_leads/web_leads_service.dart';

import 'helpers/fake_crm.dart';

void main() {
  group('CrmCompaniesService', () {
    test('account360 → fn_crm_account_360(p_company_id) eşlemesi', () async {
      final be = FakeCrmBackend(rpcRowResults: {
        'fn_crm_account_360': [
          {
            'deal_id': 'd1',
            'subject': 'ERP',
            'status': 'proposal',
            'amount': '1000',
            'probability': 40
          },
          {'deal_id': null, 'subject': 'bozuk'},
        ],
      });
      final deals = await CrmCompaniesService(backend: be).account360('c1');
      expect(be.calls.single.name, 'fn_crm_account_360');
      expect(be.calls.single.params, {'p_company_id': 'c1'});
      expect(deals.single.amount, 1000);
      expect(deals.single.probability, 40);
    });

    test('contacts: hata → boş liste', () async {
      final be = FakeCrmBackend(error: Exception('x'));
      expect(await CrmCompaniesService(backend: be).contacts('c1'), isEmpty);
    });

    test('contacts: Contact modeline eşler', () async {
      final be = FakeCrmBackend(contacts: [
        {'id': 'p1', 'first_name': 'Ece', 'last_name': 'Demir'}
      ]);
      final list = await CrmCompaniesService(backend: be).contacts('c1');
      expect(list.single.displayName, 'Ece Demir');
      expect(be.calls.single.params, {'company_id': 'c1'});
    });

    test('AccountKpis: açık = final-olmayan, ağırlıklı, kazanılan', () {
      const deals = [
        AccountDeal(id: '1', status: 'proposal', amount: 1000, probability: 50),
        AccountDeal(id: '2', status: 'won', amount: 300),
        AccountDeal(id: '3', status: 'lost', amount: 999),
      ];
      final k = AccountKpis.of(deals, {'won', 'lost'});
      expect(k.openPipeline, 1000);
      expect(k.weighted, 500);
      expect(k.won, 300);
      expect(k.dealCount, 3);
    });

    test('filterCompanies: ad / şehir', () {
      const all = [
        CrmRecord(id: '1', subject: 'Acme', metadata: {'city': 'İzmir'}),
        CrmRecord(id: '2', subject: 'Beta', metadata: {'city': 'Ankara'}),
      ];
      expect(filterCompanies(all, 'izm').single.id, '1');
      expect(filterCompanies(all, '  ').length, 2);
    });
  });

  group('WebLeadsService', () {
    test('list → fn_crm_web_leads_list(p_status) + form_type eşlemesi',
        () async {
      final be = FakeCrmBackend(rpcRowResults: {
        'fn_crm_web_leads_list': [
          {
            'id': 'w1',
            'name': 'Ali',
            'status': 'new',
            'metadata': {'form_type': 'demo'},
            'created_at': '2026-11-01T10:00:00Z',
          },
          {'id': 'w2', 'name': '', 'email': 'x@y.com', 'metadata': {'form_type': 'weird'}},
        ],
      });
      final rows = await WebLeadsService(backend: be).list(WebLeadFilter.spam);
      expect(be.calls.single.params, {'p_status': 'spam'});
      expect(rows.first.formType, 'demo');
      expect(rows.last.formType, 'contact');
      expect(rows.last.displayName, 'x@y.com');
    });

    test('convert → fn_crm_convert_web_lead(p_id) yeni lead id döner',
        () async {
      final be =
          FakeCrmBackend(rpcResults: {'fn_crm_convert_web_lead': 'lead-9'});
      expect(await WebLeadsService(backend: be).convert('w1'), 'lead-9');
      expect(be.calls.single.name, 'fn_crm_convert_web_lead');
      expect(be.calls.single.params, {'p_id': 'w1'});
    });

    test('setStatus → fn_crm_web_lead_set_status(p_id, p_status)', () async {
      final be = FakeCrmBackend();
      await WebLeadsService(backend: be).setStatus('w1', 'spam');
      expect(be.calls.single.name, 'fn_crm_web_lead_set_status');
      expect(be.calls.single.params, {'p_id': 'w1', 'p_status': 'spam'});
    });

    test('isNotAuthorized', () {
      expect(
          WebLeadsService.isNotAuthorized(
              Exception('PostgrestException(message: not authorized)')),
          isTrue);
      expect(WebLeadsService.isNotAuthorized(Exception('timeout')), isFalse);
    });
  });

  group('CrmSequencesService', () {
    test('list: pasif diziler de gelir', () async {
      final be = FakeCrmBackend(rpcRowResults: {
        'fn_crm_sequences_list': [
          {'id': 's1', 'name': 'Onboarding', 'active': true, 'step_count': 3, 'active_enrollments': 2},
          {'id': 's2', 'name': 'Eski', 'active': false, 'step_count': 0},
        ],
      });
      final rows = await CrmSequencesService(backend: be).list();
      expect(rows.map((s) => s.id), ['s1', 's2']);
      expect(rows.last.active, isFalse);
      expect(rows.first.activeEnrollments, 2);
    });

    test('enrollments → fn_crm_sequence_enrollments(p_sequence_id, null)',
        () async {
      final be = FakeCrmBackend(rpcRowResults: {
        'fn_crm_sequence_enrollments': [
          {'id': 'e1', 'contact_name': 'Ece', 'status': 'active', 'current_step': 2},
        ],
      });
      final rows = await CrmSequencesService(backend: be).enrollments('s1');
      expect(be.calls.single.params,
          {'p_sequence_id': 's1', 'p_contact_id': null});
      expect(rows.single.currentStep, 2);
    });
  });
}
