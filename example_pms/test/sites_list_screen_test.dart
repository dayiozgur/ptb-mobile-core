import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:protoolbag_pms/features/site/screens/sites_list_screen.dart';

import 'helpers/pms_fakes.dart';

void main() {
  late MockSiteService sites;
  late MockOrganizationService org;
  late MockAlarmService alarms;

  final fixture = [
    Site(
        id: 's1',
        name: 'Kadıköy Mağaza',
        organizationId: 'o1',
        markerId: '',
        code: 'KDK',
        address: 'Bahariye Cd.'),
    Site(
        id: 's2',
        name: 'Ankara Depo',
        organizationId: 'o1',
        markerId: '',
        code: 'ANK'),
  ];

  setUp(() async {
    await sl.reset();
    registerFake<LocalizationService>(fakeLocalization());
    org = MockOrganizationService();
    when(() => org.currentOrganizationId).thenReturn('o1');
    registerFake<OrganizationService>(org);
    sites = MockSiteService();
    when(() => sites.getSites('o1')).thenAnswer((_) async => fixture);
    registerFake<SiteService>(sites);
    alarms = MockAlarmService();
    when(() => alarms.getActiveAlarmCountsBySite())
        .thenAnswer((_) async => {'s1': 3, 'other-org-site': 9});
    registerFake<AlarmService>(alarms);
  });

  testWidgets('liste + site başı alarm rozeti', (tester) async {
    await tester.pumpWidget(wrap(const SitesListScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Kadıköy Mağaza'), findsOneWidget);
    expect(find.text('Ankara Depo'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // yalnız s1 rozeti
    expect(find.text('9'), findsNothing); // listede olmayan site sayılmaz
  });

  testWidgets('aktif alarm sayısı alınamazsa liste rozetsiz gösterilir',
      (tester) async {
    when(() => alarms.getActiveAlarmCountsBySite()).thenThrow(Exception('rls'));
    await tester.pumpWidget(wrap(const SitesListScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Kadıköy Mağaza'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber), findsNothing);
  });

  testWidgets('arama: kod ile eşleşir; eşleşme yoksa boş-sonuç',
      (tester) async {
    await tester.pumpWidget(wrap(const SitesListScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ank');
    await tester.pumpAndSettle();
    expect(find.text('Ankara Depo'), findsOneWidget);
    expect(find.text('Kadıköy Mağaza'), findsNothing);

    await tester.enterText(find.byType(TextField), 'bahariye');
    await tester.pumpAndSettle();
    expect(find.text('Kadıköy Mağaza'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'yok-boyle-site');
    await tester.pumpAndSettle();
    expect(find.text('common.no_results'), findsOneWidget);
  });

  testWidgets('organizasyonda site yok → boş durum (aşağı çekilebilir)',
      (tester) async {
    when(() => sites.getSites('o1')).thenAnswer((_) async => []);
    await tester.pumpWidget(wrap(const SitesListScreen()));
    await tester.pumpAndSettle();
    expect(find.text('site.not_found_title'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  testWidgets('yükleme hatası → hata + tekrar dene yeniden yükler',
      (tester) async {
    var calls = 0;
    when(() => sites.getSites('o1')).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('offline');
      return fixture;
    });
    await tester.pumpWidget(wrap(const SitesListScreen()));
    await tester.pumpAndSettle();
    expect(find.text('site.load_failed'), findsOneWidget);

    await tester.tap(find.text('common.retry'));
    await tester.pumpAndSettle();
    expect(find.text('Kadıköy Mağaza'), findsOneWidget);
  });
}
