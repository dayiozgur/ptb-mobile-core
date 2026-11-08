import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_crm/features/deals/crm_deal_reason.dart';
import 'package:protoolbag_crm/features/leads/crm_leads_screen.dart';
import 'package:protoolbag_crm/features/leads/lead_convert_screen.dart';
import 'package:protoolbag_crm/features/leads/lead_convert_service.dart';
import 'package:protoolbag_crm/features/pipeline/crm_stage_service.dart';
import 'package:protoolbag_crm/features/shared/crm_records_service.dart';
import 'package:protoolbag_crm/features/shared/crm_stage_change.dart';

import 'helpers/fake_crm.dart';
import 'helpers/fake_lead_convert.dart';

const _tr = {
  'status.new': 'Yeni',
  'status.qualified': 'Nitelikli',
  'status.converted': 'Dönüştürüldü',
  'status.disqualified': 'Elendi',
  'status.lead': 'Aday',
  'status.proposal': 'Teklif',
  'status.won': 'Kazanıldı',
  'status.lost': 'Kaybedildi',
  'crm.deal_workspace.reason.won.budget': 'Bütçe',
};

String _t(String k) => _tr[k] ?? k;

CrmStageService _stages() => CrmStageService(
      backend: FakeCrmBackend(statusDefs: {
        'lead': [
          statusRow('new', sort: 10),
          statusRow('qualified', sort: 30),
          statusRow('converted', sort: 40, isFinal: true),
          statusRow('disqualified', sort: 50, isFinal: true),
        ],
        'deal': [
          statusRow('lead', sort: 10),
          statusRow('proposal', sort: 30),
          statusRow('won', sort: 40, isFinal: true),
        ],
      }),
      translate: _t,
    );

Future<void> _tapKey(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => registerFakeLocalization(_tr));

  group('LeadConvertScreen', () {
    FakeLeadConvertBackend backend({String status = 'qualified'}) =>
        FakeLeadConvertBackend(
          entities: {
            'L1': ConvertEntity(
              id: 'L1',
              status: status,
              code: 'LEAD-1',
              formTemplateId: 'tpl-lead',
              values: const {
                'contact_name': 'Ada Lovelace',
                'contact_email': 'ada@acme.io',
                'company': {
                  'entityType': 'crm_companies',
                  'entityId': 'co1',
                  'displayValue': 'Acme'
                },
                'est_value': 1200,
              },
            ),
            'D1': const ConvertEntity(id: 'D1', status: 'lead'),
          },
          companies: const [CompanyMatch(id: 'co1', name: 'Acme', code: 'CMP-1')],
          contacts: const [
            ContactMatch(id: 'ct1', name: 'Ada Lovelace', email: 'ada@acme.io')
          ],
          memberList: const [MemberOption('p1', 'Özgür')],
          leadTransitions: leadLadderRows(),
          executionRows: [createdDealExecution('D1')],
        );

    testWidgets('prefilled wizard converts and opens the new deal', (tester) async {
      final be = backend();
      String? opened;
      await tester.pumpWidget(MaterialApp(
        home: LeadConvertScreen(
          leadId: 'L1',
          service: LeadConvertService(backend: be, sleep: (_) async {}),
          stageService: _stages(),
          onOpenDeal: (_, id) => opened = id,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('LEAD-1'), findsOneWidget);
      await _tapKey(tester, const Key('lead-convert-next')); // review → parties
      // Linked company + e-mail-matched contact are preselected.
      // Linked company pinned on top (one entry, search dup dropped).
      expect(find.byKey(const ValueKey('lead-convert-company-co1')), findsOneWidget);
      expect(find.text('Ada Lovelace <ada@acme.io>'), findsOneWidget);
      await _tapKey(tester, const Key('lead-convert-next')); // parties → deal
      expect(find.widgetWithText(TextField, '1200'), findsOneWidget);
      await _tapKey(tester, const Key('lead-convert-next')); // deal → confirm
      expect(find.textContaining('Acme'), findsWidgets);
      await _tapKey(tester, const Key('lead-convert-submit'));

      expect(opened, 'D1');
      expect(be.transitions.where((t) => t.type == 'lead').map((t) => t.to),
          ['converted']);
      final patch = be.patched['L1']!;
      expect((patch['company'] as Map)['entityId'], 'co1');
      expect((patch['contact'] as Map)['entityId'], 'ct1');
      expect(patch['est_value'], 1200);
    });

    testWidgets('a lead in a final status cannot be converted', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: LeadConvertScreen(
          leadId: 'L1',
          service: LeadConvertService(
              backend: backend(status: 'disqualified'), sleep: (_) async {}),
          stageService: _stages(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lead-convert-terminal')), findsOneWidget);
      await _tapKey(tester, const Key('lead-convert-next'));
      // Still on step 1 (company search not shown).
      expect(find.byKey(const Key('lead-convert-company-search')), findsNothing);
    });

    testWidgets('deal amount is required before confirming', (tester) async {
      final be = backend();
      await tester.pumpWidget(MaterialApp(
        home: LeadConvertScreen(
          leadId: 'L1',
          service: LeadConvertService(backend: be, sleep: (_) async {}),
          stageService: _stages(),
        ),
      ));
      await tester.pumpAndSettle();
      await _tapKey(tester, const Key('lead-convert-next'));
      await _tapKey(tester, const Key('lead-convert-next'));
      await tester.enterText(find.byKey(const Key('lead-convert-amount')), '');
      await _tapKey(tester, const Key('lead-convert-next'));
      expect(find.byKey(const Key('lead-convert-submit')), findsNothing);
      expect(find.text('Required'), findsNothing); // fallback text shown instead
      expect(find.text('Zorunlu'), findsOneWidget);
    });
  });

  testWidgets('CrmLeadsScreen card offers the convert action', (tester) async {
    String? converted;
    await tester.pumpWidget(MaterialApp(
      home: CrmLeadsScreen(
        records: CrmRecordsService(
            backend: FakeCrmBackend(submissions: {
          'lead': [
            {'id': 'L1', 'subject': 'Acme lead', 'status': 'qualified', 'metadata': {}}
          ]
        })),
        stageService: _stages(),
        onConvertLead: (_, l) => converted = l.id,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('crm-lead-convert-L1')));
    expect(converted, 'L1');
  });

  group('Deal won/lost reason', () {
    test('options: DB items, translated when a key exists; defaults otherwise', () {
      final rows = [
        {
          'code': 'won_reason',
          'options': {
            'items': [
              {'label': 'Budget', 'value': 'budget'},
              {'label': 'Speed', 'value': 'speed'},
            ]
          },
        },
      ];
      final won = CrmDealReason.optionsFrom(rows, 'won_reason', _t);
      expect(won.map((o) => o.label), ['Bütçe', 'Speed']);
      final lost = CrmDealReason.optionsFrom(rows, 'lost_reason', _t);
      expect(lost.map((o) => o.value), CrmDealReason.defaults['lost_reason']);
      expect(lost.first.label, 'Price');
      expect(CrmDealReason.fieldFor('won'), 'won_reason');
      expect(CrmDealReason.fieldFor('lost'), 'lost_reason');
    });

    testWidgets('collect: reason required, saved only via the returned callback',
        (tester) async {
      final saved = <String>[];
      Future<void> Function(BuildContext)? save;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                save = await CrmDealReason.collect(ctx,
                    dealId: 'D1',
                    finalStatus: 'won',
                    loadRows: () async => const [],
                    saver: (f, r) async => saved.add('$f=$r'));
              },
              child: const Text('close'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('close'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('deal-reason-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Lütfen bir neden seçin.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('deal-reason-budget')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('deal-reason-confirm')));
      await tester.pumpAndSettle();
      expect(save, isNotNull);
      expect(saved, isEmpty); // nothing written before the transition
      await save!(tester.element(find.text('close')));
      expect(saved, ['won_reason=budget']);
    });

    testWidgets('stage change to a final deal status asks first, saves after move',
        (tester) async {
      final be = FakeCrmBackend(transitions: {
        'deal': [txRow('proposal', 'won'), txRow('proposal', 'lead')],
      });
      final stageSvc = CrmStageService(backend: be, translate: _t);
      final stages = await stageSvc.loadStages('deal');
      final events = <String>[];
      bool? ok;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                ok = await showCrmStageChange(ctx,
                    stageService: stageSvc,
                    entityType: 'deal',
                    entityId: 'D1',
                    currentStatus: 'proposal',
                    stages: [
                      ...stages,
                      const CrmStage(code: 'won', name: 'Kazanıldı', isFinal: true),
                      const CrmStage(code: 'lead', name: 'Aday'),
                    ],
                    collectDealReason: (c, {required dealId, required finalStatus}) async {
                      events.add('ask:$finalStatus');
                      return (_) async => events.add('save');
                    });
              },
              child: const Text('move'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('move'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kazanıldı'));
      await tester.pumpAndSettle();
      expect(ok, isTrue);
      expect(events, ['ask:won', 'save']);
      expect(be.calls.where((c) => c.name == 'status-transition').single.params!['toStatus'],
          'won');
    });

    testWidgets('cancelling the reason prompt cancels the move', (tester) async {
      final be = FakeCrmBackend(transitions: {
        'deal': [txRow('proposal', 'won')],
      });
      final stageSvc = CrmStageService(backend: be, translate: _t);
      bool? ok;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                ok = await showCrmStageChange(ctx,
                    stageService: stageSvc,
                    entityType: 'deal',
                    entityId: 'D1',
                    currentStatus: 'proposal',
                    stages: const [
                      CrmStage(code: 'won', name: 'Kazanıldı', isFinal: true)
                    ],
                    collectDealReason: (c, {required dealId, required finalStatus}) async =>
                        null);
              },
              child: const Text('move'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('move'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kazanıldı'));
      await tester.pumpAndSettle();
      expect(ok, isFalse);
      expect(be.calls.where((c) => c.name == 'status-transition'), isEmpty);
    });
  });
}
