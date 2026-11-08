import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_crm/features/leads/crm_leads_screen.dart';
import 'package:protoolbag_crm/features/pipeline/crm_pipeline_screen.dart';
import 'package:protoolbag_crm/features/pipeline/crm_stage_service.dart';
import 'package:protoolbag_crm/features/shared/crm_record.dart';
import 'package:protoolbag_crm/features/shared/crm_records_service.dart';

import 'helpers/fake_crm.dart';

CrmRecord rec(String id,
        {String? subject, String? status, Map<String, dynamic>? meta}) =>
    CrmRecord(id: id, subject: subject, status: status, metadata: meta ?? {});

void main() {
  group('CrmRecord.leadTitle (web leadDisplayTitle paritesi)', () {
    test('gerçek subject kazanır', () {
      expect(rec('1', subject: 'Demo talebi', meta: {'name': 'Ali'}).leadTitle,
          'Demo talebi');
    });

    test('subject = metadata.name kopyası → "Ad · Firma"', () {
      expect(
          rec('1', subject: 'Ali', meta: {'name': 'Ali', 'company': 'Acme'})
              .leadTitle,
          'Ali · Acme');
    });

    test('lead formu: contact_name + company lookup objesi', () {
      expect(
          rec('1', meta: {
            'contact_name': 'Ece',
            'company': {'id': 'c', 'name': 'Marmara'}
          }).leadTitle,
          'Ece · Marmara');
    });

    test('yalnız e-posta', () {
      expect(rec('1', meta: {'contact_email': 'x@y.com'}).leadTitle, 'x@y.com');
    });

    test('hiçbir şey yok → null', () {
      expect(rec('1').leadTitle, isNull);
    });
  });

  group('CrmRecord deal alanları', () {
    final d = CrmRecord.fromRow({
      'id': 'd1',
      'code': 'DEAL-0003',
      'subject': null,
      'status': 'lead',
      'metadata': {
        'amount': 450000,
        'probability': '30',
        'currency': 'TRY',
        'company': {'entityId': 'c1', 'displayValue': 'Yildiz Lojistik A.S.'},
        'expected_close': '2026-09-30',
      },
    });

    test('lookup displayValue + sayısal string', () {
      expect(d.amount, 450000);
      expect(d.probability, 30);
      expect(d.companyName, 'Yildiz Lojistik A.S.');
      expect(d.metaRefId('company'), 'c1');
      expect(d.expectedClose, DateTime(2026, 9, 30));
    });

    test('subject yoksa başlık "Firma · Kod"', () {
      expect(d.dealTitle, 'Yildiz Lojistik A.S. · DEAL-0003');
    });

    test('para birimi başına toplam + ağırlıklı', () {
      final deals = [
        d,
        rec('d2', meta: {'amount': 100, 'probability': 50, 'currency': 'USD'}),
        rec('d3', meta: {'currency': 'USD'}), // tutarsız → sayılmaz
      ];
      expect(crmSumByCurrency(deals), {'TRY': 450000, 'USD': 100});
      expect(crmSumByCurrency(deals, weighted: true),
          {'TRY': 135000, 'USD': 50});
      expect(crmMoneyTotals(const {}), '—');
    });
  });

  group('CrmRecordsService', () {
    test('entity tipine göre listeler, id\'siz satırı atar', () async {
      final be = FakeCrmBackend(submissions: {
        'company': [
          {'id': 'c1', 'subject': 'Acme', 'status': 'active'},
          {'id': null, 'subject': 'bozuk'},
        ],
      });
      final list = await CrmRecordsService(backend: be).list('company');
      expect(list.map((r) => r.id), ['c1']);
      expect(be.calls.single.name, 'list:company');
      expect(be.calls.single.params, {'limit': 200});
    });

    test('hata fırlatılır (ekran hata durumu gösterir)', () async {
      final be = FakeCrmBackend(error: Exception('rls'));
      expect(() => CrmRecordsService(backend: be).list('lead'), throwsException);
    });

    test('isTruncated', () {
      expect(CrmRecordsService.isTruncated(200), isTrue);
      expect(CrmRecordsService.isTruncated(199), isFalse);
    });
  });

  group('filterLeads', () {
    const stages = [
      CrmStage(code: 'new', name: 'Yeni'),
      CrmStage(code: 'qualified', name: 'Nitelikli'),
      CrmStage(code: 'converted', name: 'Dönüştürüldü', isFinal: true),
      CrmStage(code: 'disqualified', name: 'Elendi', isFinal: true),
    ];
    final leads = [
      rec('1', status: 'new', meta: {'contact_name': 'Ali', 'contact_email': 'ali@a.com'}),
      rec('2', status: 'qualified', meta: {'contact_name': 'Ece'}),
      rec('3', status: 'converted', meta: {'contact_name': 'Can'}),
      rec('4', status: 'disqualified'),
    ];

    test('final (DB is_final) potansiyeller gizlenir', () {
      expect(filterLeads(leads, stages).map((l) => l.id), ['1', '2']);
    });

    test('aşama + arama süzgeci', () {
      expect(filterLeads(leads, stages, stageCode: 'qualified').single.id, '2');
      expect(filterLeads(leads, stages, query: 'ALI@').single.id, '1');
    });
  });

  group('PipelineGroups', () {
    test('tanımsız durumdaki fırsat kaybolmaz; açık = final-olmayan', () {
      const stages = [
        CrmStage(code: 'lead', name: 'Aday', sortOrder: 10),
        CrmStage(code: 'won', name: 'Kazanıldı', sortOrder: 40, isFinal: true),
      ];
      final g = PipelineGroups.build(stages, [
        rec('a', status: 'lead'),
        rec('b', status: 'won'),
        rec('c', status: 'on_hold'),
      ]);
      expect(g.stages.map((s) => s.code), ['lead', 'won', 'on_hold']);
      expect(g.stages.last.name, 'On hold');
      expect(g.byStage['on_hold']!.single.id, 'c');
      expect(g.openDeals.map((d) => d.id), ['a', 'c']);
    });
  });
}
