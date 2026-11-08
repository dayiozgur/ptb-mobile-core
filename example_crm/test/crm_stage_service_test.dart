import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_crm/features/pipeline/crm_stage_service.dart';

import 'helpers/fake_crm.dart';

/// CRM aşama mantığı — web PtbStatusService paritesi (etiket anahtarı,
/// kiracı-dedup, geçiş süzgeci, sihirbaz-yalnız hedef, EF yolu).
void main() {
  String tr(String k) => const {
        'status.qualified': 'Nitelikli',
        'status.won': 'Kazanıldı',
      }[k] ??
      k;

  group('CrmStageLogic.labelOf', () {
    test('metadata.i18n.name anahtarı çevrilir', () {
      expect(CrmStageLogic.labelOf(statusRow('qualified'), tr), 'Nitelikli');
    });

    test('çeviri yoksa DB adı', () {
      expect(CrmStageLogic.labelOf(statusRow('proposal', name: 'Proposal'), tr),
          'Proposal');
    });

    test('metadata yok + sistem satırı → status.<code>', () {
      final row = {'code': 'won', 'name': 'Won', 'is_system': true};
      expect(CrmStageLogic.labelOf(row, tr), 'Kazanıldı');
    });

    test('metadata yok + kiracı satırı → DB adı (anahtar uydurulmaz)', () {
      final row = {'code': 'won', 'name': 'Won', 'is_system': false};
      expect(CrmStageLogic.labelOf(row, tr), 'Won');
    });
  });

  group('CrmStageLogic.stagesFromRows', () {
    test('aynı kodda kiracı satırı sistemi yener + sort_order sıralı', () {
      final rows = [
        statusRow('won', sort: 40, isFinal: true),
        {...statusRow('lead', sort: 10, isSystem: true), 'color': '#000000'},
        statusRow('lead', sort: 10, color: '#6B7280'),
        statusRow('lead', sort: 10, color: '#6B7280'), // canlıdaki kopya satır
      ];
      final stages = CrmStageLogic.stagesFromRows(rows, tr);
      expect(stages.map((s) => s.code), ['lead', 'won']);
      expect(stages.first.colorHex, '#6B7280');
      expect(stages.last.isFinal, isTrue);
      expect(stages.last.name, 'Kazanıldı');
    });
  });

  group('CrmStageLogic.transitionsFrom', () {
    final rows = [
      txRow('qualified', 'converted'),
      txRow('qualified', 'disqualified'),
      txRow('qualified', 'disqualified'), // dedup
      txRow('new', 'contacted'),
      txRow('qualified', 'archived', roles: ['admin']),
      txRow('qualified', 'escalated', comment: true),
    ];

    test('from süzgeci + hedef dedup + lead→converted (sihirbaz) hariç', () {
      final t = CrmStageLogic.transitionsFrom(rows,
          entityType: 'lead', fromCode: 'qualified', role: 'ROLE_USER');
      expect(t.map((x) => x.toCode), ['disqualified', 'escalated']);
      expect(t.last.requiresComment, isTrue);
    });

    test('rol normalize: ROLE_ADMIN ↔ admin', () {
      final t = CrmStageLogic.transitionsFrom(rows,
          entityType: 'lead', fromCode: 'qualified', role: 'ROLE_ADMIN');
      expect(t.map((x) => x.toCode), contains('archived'));
    });

    test('rol bilinmiyorsa rol-kısıtlı geçiş gizlenir', () {
      final t = CrmStageLogic.transitionsFrom(rows,
          entityType: 'lead', fromCode: 'qualified');
      expect(t.map((x) => x.toCode), isNot(contains('archived')));
    });

    test('deal için converted sihirbaz-yalnız DEĞİL', () {
      final t = CrmStageLogic.transitionsFrom([txRow('proposal', 'converted')],
          entityType: 'deal', fromCode: 'proposal');
      expect(t.single.toCode, 'converted');
    });
  });

  group('CrmStageService', () {
    test('loadStages: backend hatası → boş liste', () async {
      final svc = CrmStageService(
          backend: FakeCrmBackend(error: Exception('boom')), translate: tr);
      expect(await svc.loadStages('deal'), isEmpty);
    });

    test('availableTransitions: satırlar tip başına bir kez çekilir', () async {
      final be = FakeCrmBackend(transitions: {
        'deal': [txRow('lead', 'qualified'), txRow('qualified', 'proposal')],
      });
      final svc = CrmStageService(backend: be, translate: tr);
      expect((await svc.availableTransitions('deal', 'lead')).single.toCode,
          'qualified');
      expect((await svc.availableTransitions('deal', 'qualified')).single.toCode,
          'proposal');
      expect(be.transitionRowFetches, 1);
    });

    test('move → status-transition EF (yorum iletilir)', () async {
      final be = FakeCrmBackend();
      final svc = CrmStageService(backend: be, translate: tr);
      await svc.move(
          entityType: 'deal', entityId: 'd1', toStatus: 'won', comment: 'ok');
      final call = be.calls.single;
      expect(call.name, 'status-transition');
      expect(call.params, {
        'entityType': 'deal',
        'entityId': 'd1',
        'toStatus': 'won',
        'comment': 'ok',
      });
    });

    test('move lead→converted reddedilir (EF çağrılmaz)', () async {
      final be = FakeCrmBackend();
      final svc = CrmStageService(backend: be, translate: tr);
      await expectLater(
          svc.move(entityType: 'lead', entityId: 'l1', toStatus: 'converted'),
          throwsStateError);
      expect(be.calls, isEmpty);
    });

    test('isInvalidTransitionError', () {
      expect(
          CrmStageLogic.isInvalidTransitionError(
              Exception('status-transition failed: ERR_INVALID_TRANSITION')),
          isTrue);
      expect(CrmStageLogic.isInvalidTransitionError(Exception('timeout')),
          isFalse);
    });
  });
}
