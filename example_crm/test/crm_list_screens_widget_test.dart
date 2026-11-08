import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_crm/features/companies/crm_companies_screen.dart';
import 'package:protoolbag_crm/features/companies/crm_companies_service.dart';
import 'package:protoolbag_crm/features/leads/crm_leads_screen.dart';
import 'package:protoolbag_crm/features/pipeline/crm_pipeline_screen.dart';
import 'package:protoolbag_crm/features/pipeline/crm_stage_service.dart';
import 'package:protoolbag_crm/features/sequences/crm_sequences_screen.dart';
import 'package:protoolbag_crm/features/sequences/crm_sequences_service.dart';
import 'package:protoolbag_crm/features/shared/crm_records_service.dart';
import 'package:protoolbag_crm/features/web_leads/web_leads_screen.dart';
import 'package:protoolbag_crm/features/web_leads/web_leads_service.dart';

import 'helpers/fake_crm.dart';

Widget _app(Widget child) => MaterialApp(home: child);

/// Canlı DB biçiminde etiket tablosu (keywords: status.* tr-TR).
const _tr = {
  'status.lead': 'Aday',
  'status.qualified': 'Nitelikli',
  'status.proposal': 'Teklif',
  'status.won': 'Kazanıldı',
  'status.lost': 'Kaybedildi',
  'status.new': 'Yeni',
  'status.contacted': 'İletişime Geçildi',
  'status.converted': 'Dönüştürüldü',
};

String _t(String k) => _tr[k] ?? k;

void main() {
  setUp(() => registerFakeLocalization(_tr));

  group('CrmPipelineScreen', () {
    FakeCrmBackend backend() => FakeCrmBackend(
          statusDefs: {
            'deal': [
              statusRow('lead', sort: 10),
              statusRow('qualified', sort: 20),
              statusRow('proposal', sort: 30),
              statusRow('won', sort: 40, isFinal: true),
              statusRow('lost', sort: 50, isFinal: true),
            ],
          },
          transitions: {
            'deal': [
              txRow('lead', 'qualified'),
              txRow('lead', 'lost'),
              txRow('qualified', 'proposal'),
            ],
          },
          submissions: {
            'deal': [
              {
                'id': 'd1',
                'code': 'DEAL-0001',
                'subject': 'ERP Projesi',
                'status': 'lead',
                'metadata': {'amount': 1000, 'probability': 50, 'currency': 'TRY'},
              },
              {
                'id': 'd2',
                'code': 'DEAL-0002',
                'subject': 'Analitik Modülü',
                'status': 'qualified',
                'metadata': {'amount': 500, 'probability': 20, 'currency': 'TRY'},
              },
              {
                'id': 'd3',
                'code': 'DEAL-0003',
                'subject': 'Kazanılan İş',
                'status': 'won',
                'metadata': {'amount': 9999, 'currency': 'TRY'},
              },
            ],
          },
        );

    Widget screen(FakeCrmBackend be) => _app(CrmPipelineScreen(
          records: CrmRecordsService(backend: be),
          stageService: CrmStageService(backend: be, translate: _t),
          onOpenDeal: (_, __) {},
        ));

    testWidgets('DB etiketli aşama şeridi + adetler + ilk dolu aşama',
        (tester) async {
      await tester.pumpWidget(screen(backend()));
      await tester.pumpAndSettle();

      expect(find.text('Aday (1)'), findsOneWidget);
      expect(find.text('Nitelikli (1)'), findsOneWidget);
      expect(find.text('Kazanıldı (1)'), findsOneWidget);
      expect(find.text('ERP Projesi'), findsOneWidget);
      expect(find.text('Analitik Modülü'), findsNothing);

      await tester.tap(find.text('Nitelikli (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Analitik Modülü'), findsOneWidget);
      expect(find.text('ERP Projesi'), findsNothing);
    });

    testWidgets('aşama değiştir: yalnız izinli hedefler, EF ile yürütülür',
        (tester) async {
      final be = backend();
      await tester.pumpWidget(screen(be));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.swap_horiz).first);
      await tester.pumpAndSettle();
      // lead → qualified / lost izinli; proposal/won sunulmaz.
      expect(find.widgetWithText(ListTile, 'Nitelikli'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Kaybedildi'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Teklif'), findsNothing);

      await tester.tap(find.widgetWithText(ListTile, 'Nitelikli'));
      await tester.pumpAndSettle();

      final call = be.calls.firstWhere((c) => c.name == 'status-transition');
      expect(call.params!['entityType'], 'deal');
      expect(call.params!['entityId'], 'd1');
      expect(call.params!['toStatus'], 'qualified');
    });

    testWidgets('yükleme hatası → hata durumu', (tester) async {
      final be = FakeCrmBackend(error: Exception('rls'));
      await tester.pumpWidget(screen(be));
      await tester.pumpAndSettle();
      expect(find.text('Satış hattı yüklenemedi'), findsOneWidget);
    });
  });

  group('CrmLeadsScreen', () {
    testWidgets('terminal potansiyeller gizli, durum rozeti DB etiketiyle',
        (tester) async {
      final be = FakeCrmBackend(
        statusDefs: {
          'lead': [
            statusRow('new', sort: 10),
            statusRow('contacted', sort: 20),
            statusRow('converted', sort: 40, isFinal: true),
          ],
        },
        submissions: {
          'lead': [
            {
              'id': 'l1',
              'status': 'new',
              'metadata': {'contact_name': 'Ali Veli', 'company_text': 'Acme'},
            },
            {
              'id': 'l2',
              'status': 'converted',
              'metadata': {'contact_name': 'Dönmüş Kişi'},
            },
          ],
        },
      );
      await tester.pumpWidget(_app(CrmLeadsScreen(
        records: CrmRecordsService(backend: be),
        stageService: CrmStageService(backend: be, translate: _t),
        onOpenLead: (_, __) {},
      )));
      await tester.pumpAndSettle();

      expect(find.text('Ali Veli'), findsOneWidget);
      expect(find.text('Dönmüş Kişi'), findsNothing);
      // 'Yeni' hem filtre çipinde hem rozette.
      expect(find.text('Yeni'), findsNWidgets(2));
      expect(find.text('Acme'), findsOneWidget);
    });
  });

  group('CrmCompaniesScreen', () {
    testWidgets('liste + arama süzgeci', (tester) async {
      final be = FakeCrmBackend(submissions: {
        'company': [
          {
            'id': 'c1',
            'subject': 'Aksoy Teknoloji A.Ş.',
            'status': 'active',
            'metadata': {'city': 'İstanbul', 'sector': 'technology'},
          },
          {
            'id': 'c2',
            'subject': 'Demir Çelik Sanayi Ltd.',
            'status': 'active',
            'metadata': {'city': 'İzmir', 'sector': 'manufacturing'},
          },
        ],
      });
      String? opened;
      await tester.pumpWidget(_app(CrmCompaniesScreen(
        records: CrmRecordsService(backend: be),
        companies: CrmCompaniesService(backend: be),
        onOpenCompany: (_, c) => opened = c.id,
      )));
      await tester.pumpAndSettle();

      expect(find.text('Aksoy Teknoloji A.Ş.'), findsOneWidget);
      expect(find.text('Demir Çelik Sanayi Ltd.'), findsOneWidget);
      // Sektör anahtarı yoksa okunur koda düşer.
      expect(find.text('İstanbul · Technology'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'izmir');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Aksoy Teknoloji A.Ş.'), findsNothing);

      await tester.tap(find.text('Demir Çelik Sanayi Ltd.'));
      expect(opened, 'c2');
    });
  });

  group('WebLeadsScreen', () {
    testWidgets('yeni başvuru → Dönüştür RPC + yeni potansiyele gider',
        (tester) async {
      final be = FakeCrmBackend(
        rpcRowResults: {
          'fn_crm_web_leads_list': [
            {
              'id': 'w1',
              'name': 'Zeynep',
              'email': 'z@acme.com',
              'company': 'Acme',
              'status': 'new',
              'metadata': {'form_type': 'demo'},
            },
          ],
        },
        rpcResults: {'fn_crm_convert_web_lead': 'lead-77'},
      );
      String? openedLead;
      await tester.pumpWidget(_app(WebLeadsScreen(
        service: WebLeadsService(backend: be),
        onOpenLead: (_, id) => openedLead = id,
      )));
      await tester.pumpAndSettle();

      expect(find.text('Zeynep'), findsOneWidget);
      expect(be.calls.first.params, {'p_status': 'new'});

      await tester.tap(find.byKey(const ValueKey('wl-convert-w1')));
      await tester.pumpAndSettle();

      final convert =
          be.calls.firstWhere((c) => c.name == 'fn_crm_convert_web_lead');
      expect(convert.params, {'p_id': 'w1'});
      expect(openedLead, 'lead-77');
    });

    testWidgets('yetkisiz → yalnız-yönetici mesajı, yeniden-dene yok',
        (tester) async {
      final be = FakeCrmBackend(error: Exception('not authorized'));
      await tester.pumpWidget(
          _app(WebLeadsScreen(service: WebLeadsService(backend: be))));
      await tester.pumpAndSettle();
      expect(find.text('Bu liste yalnız yöneticilere açıktır.'), findsOneWidget);
    });
  });

  group('CrmSequencesScreen', () {
    testWidgets('salt-okunur liste: ad, adım, aktif/pasif', (tester) async {
      final be = FakeCrmBackend(rpcRowResults: {
        'fn_crm_sequences_list': [
          {'id': 's1', 'name': 'Onboarding', 'active': true, 'step_count': 3, 'active_enrollments': 2},
          {'id': 's2', 'name': 'Eski Dizi', 'active': false, 'step_count': 1, 'active_enrollments': 0},
        ],
      });
      await tester.pumpWidget(
          _app(CrmSequencesScreen(service: CrmSequencesService(backend: be))));
      await tester.pumpAndSettle();

      expect(find.text('Onboarding'), findsOneWidget);
      expect(find.text('Eski Dizi'), findsOneWidget);
      expect(find.text('Aktif'), findsOneWidget);
      expect(find.text('Pasif'), findsOneWidget);
      expect(find.text('Adım: 3 · Kayıtlı: 2'), findsOneWidget);
    });
  });
}
