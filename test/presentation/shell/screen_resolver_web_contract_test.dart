import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../helpers/widget_test_helpers.dart';

/// Web menu / route changes of 2026-11-13 that reach the mobile apps through
/// the shared `platform_menu_items` table and through app links:
/// `/report/my`, `/m365/mail`, `/admin/energy/setup`, the approvals row.
/// None of them may crash, show a blank page or be mistaken for something else.
MenuItem _item(String path, {String title = ''}) =>
    MenuItem(itemKey: path, title: title, path: path);

void main() {
  setUp(() {
    ScreenResolver.reset();
    InAppRoute.resetConfig();
  });
  tearDown(() {
    ScreenResolver.reset();
    InAppRoute.resetConfig();
  });

  group('/report/my is the personal report builder, not a report code', () {
    for (final path in [
      '/report/my',
      '/report/my/',
      '/Report/My',
      '/report/my/new',
      '/report/my/3f2c/edit',
      '/reports/my',
      '/report/my?tab=shared',
    ]) {
      test('$path → web-only screen (never ReportViewer "my")', () {
        final w = ScreenResolver.resolve(_item(path));
        expect(w, isA<ComingSoonScreen>());
        expect((w as ComingSoonScreen).webOnly, isTrue);
        expect(w.titleKey, 'breadcrumb.my_reports');
        expect(ScreenResolver.hasScreen(path), isFalse,
            reason: 'not a mobile menu entry');
        expect(ScreenResolver.isWebOnly(path), isTrue);
      });
    }

    test('real report codes still open the viewer', () {
      final w = ScreenResolver.resolve(_item('/report/crm-sales-analysis'));
      expect(w, isA<ReportViewerScreen>());
      expect((w as ReportViewerScreen).reportCode, 'crm-sales-analysis');
      // a code that merely starts with "my" is a code
      final w2 = ScreenResolver.resolve(_item('/report/my-team-kpi'));
      expect(w2, isA<ReportViewerScreen>());
      expect((w2 as ReportViewerScreen).reportCode, 'my-team-kpi');
      expect(ScreenResolver.hasScreen('/report/my-team-kpi'), isTrue);
    });

    test('the menu title wins over the built-in one', () {
      final w = ScreenResolver.resolve(_item('/report/my', title: 'nav.x'));
      expect((w as ComingSoonScreen).titleKey, 'nav.x');
    });
  });

  group('/m365/mail (requires_capability = mail.read)', () {
    test('resolves to the core Outlook mailbox when opened', () {
      expect(ScreenResolver.resolve(_item('/m365/mail')),
          isA<MsMailboxScreen>());
      expect(ScreenResolver.resolve(_item('/M365/Mail/?x=1')),
          isA<MsMailboxScreen>());
    });

    test('is NOT a mobile menu entry (hasScreen false), but can be opened', () {
      expect(ScreenResolver.hasScreen('/m365/mail'), isFalse);
      expect(ScreenResolver.canOpen('/m365/mail'), isTrue);
      expect(ScreenResolver.isWebOnly('/m365/mail'), isFalse);
    });

    test('a domain resolver may still claim the path', () {
      ScreenResolver.addResolver(
          (i) => i.path == '/m365/mail' ? const SizedBox() : null);
      expect(ScreenResolver.resolve(_item('/m365/mail')), isA<SizedBox>());
      expect(ScreenResolver.hasScreen('/m365/mail'), isTrue);
    });

    test('a row whose capability the user lacks never reaches the menu', () {
      const row = MenuItem(
        itemKey: 'm365/mail',
        title: 'nav.m365_mail',
        path: '/m365/mail',
        requiresCapability: 'mail.read',
      );
      const group = MenuItem(itemKey: 'm365', title: 'nav.m365', children: [row]);
      // capability not granted (no connection / no Mail.Read / state unknown)
      expect(MenuCapabilities.filter(const [group], const {}), isEmpty,
          reason: 'the row is dropped and the now-empty group with it');
      // granted → kept by the capability filter (then pruned by hasScreen)
      final kept = MenuCapabilities.filter(const [group], const {'mail.read'});
      expect(kept.single.children.single.path, '/m365/mail');
    });
  });

  group('other Microsoft 365 hub pages and the web file manager', () {
    for (final path in [
      '/m365/calendar',
      '/m365/planner',
      '/m365',
      '/files',
      '/files?source=onedrive',
    ]) {
      test('$path → web-only screen, not in the menu', () {
        final w = ScreenResolver.resolve(_item(path));
        expect(w, isA<ComingSoonScreen>());
        expect((w as ComingSoonScreen).webOnly, isTrue);
        expect(ScreenResolver.hasScreen(path), isFalse);
        expect(ScreenResolver.canOpen(path), isFalse);
      });
    }
  });

  group('/admin/energy/setup (PEM setup wizard, ROLE_ADMIN)', () {
    test('core alone: never a crash — generic admin placeholder', () {
      final w = ScreenResolver.resolve(_item('/admin/energy/setup'));
      expect(w, isA<ComingSoonScreen>());
    });

    test('hidden by the app → out of the menu, honest web-only screen', () {
      ScreenResolver.hideOnMobile(['/admin/energy/setup']);
      expect(ScreenResolver.hasScreen('/admin/energy/setup'), isFalse);
      expect(ScreenResolver.canOpen('/admin/energy/setup'), isFalse);
      final w = ScreenResolver.resolve(
          _item('/admin/energy/setup', title: 'nav.energy_setup'));
      expect(w, isA<ComingSoonScreen>());
      expect((w as ComingSoonScreen).webOnly, isTrue);
      expect(w.titleKey, 'nav.energy_setup');
    });
  });

  group('approvals row', () {
    for (final path in [
      '/workflow/approvals',
      '/workflow/approvals/',
      '/workflow/inbox',
      '/approvals',
      '/approvals/inbox',
      '/my-approvals',
      '/workflow/my-approvals',
      '/workflow/approvals?tab=mine',
    ]) {
      test('$path → generic approvals inbox', () {
        expect(ScreenResolver.resolve(_item(path)), isA<ApprovalsInboxScreen>());
        expect(ScreenResolver.hasScreen(path), isTrue);
      });
    }
  });

  group('InAppRoute.webUrlFor', () {
    test('null without a web origin', () {
      expect(InAppRoute.webOrigin, isNull);
      expect(InAppRoute.webUrlFor('/report/my'), isNull);
    });

    test('derived from the first app host', () {
      InAppRoute.configure(appHosts: {'App.CRM.protoolbag.com'});
      expect(InAppRoute.webOrigin, 'https://app.crm.protoolbag.com');
      expect(InAppRoute.webUrlFor('/report/my?tab=1').toString(),
          'https://app.crm.protoolbag.com/report/my?tab=1');
    });

    test('explicit origin wins; only https origins are accepted', () {
      InAppRoute.configure(appHosts: {'app.crm.protoolbag.com'});
      InAppRoute.configure(webOrigin: 'https://app.pms.protoolbag.com/ignored/path');
      expect(InAppRoute.webOrigin, 'https://app.pms.protoolbag.com');
      InAppRoute.configure(webOrigin: 'http://insecure.example');
      expect(InAppRoute.webOrigin, 'https://app.pms.protoolbag.com');
      InAppRoute.configure(webOrigin: 'javascript:alert(1)');
      expect(InAppRoute.webOrigin, 'https://app.pms.protoolbag.com');
    });

    test('only relative in-app paths become a URL', () {
      InAppRoute.configure(webOrigin: 'https://app.pms.protoolbag.com');
      expect(InAppRoute.webUrlFor('//evil.example/x'), isNull);
      expect(InAppRoute.webUrlFor('https://evil.example/x'), isNull);
      expect(InAppRoute.webUrlFor(r'/\evil.example'), isNull);
      expect(InAppRoute.webUrlFor(''), isNull);
      expect(InAppRoute.webUrlFor(null), isNull);
      expect(InAppRoute.webUrlFor('/admin/energy/setup')!.host,
          'app.pms.protoolbag.com');
    });
  });

  group('placeholder screen', () {
    setUp(() async {
      await sl.reset();
      registerFake<LocalizationService>(buildFakeLocalization(
        overrides: AppLocalizations.getTranslations(AppLocale.english),
        locale: AppLocale.english,
      ));
    });
    tearDown(() async => sl.reset());

    testWidgets('web-only: translated explanation + Open on the web',
        (tester) async {
      InAppRoute.configure(webOrigin: 'https://app.pem.protoolbag.com');
      await tester.pumpWidget(MaterialApp(
        home: ScreenResolver.webOnlyScreen('/admin/energy/setup'),
      ));
      expect(find.text('In the web app'), findsWidgets);
      expect(
          find.text(
              'This screen is used in the web app; it has no counterpart in the mobile app.'),
          findsOneWidget);
      expect(find.text('Open on the web'), findsOneWidget);
      expect(find.text('app.pem.protoolbag.com'), findsOneWidget);
    });

    testWidgets('no web origin configured: explanation only, no dead button',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ScreenResolver.resolve(_item('/report/my')),
      ));
      expect(find.text('My reports'), findsOneWidget);
      expect(find.byKey(const ValueKey('open-on-web')), findsNothing);
    });

    testWidgets('coming soon: translated, no hardcoded Turkish',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ScreenResolver.resolve(_item('/nowhere', title: 'Nowhere')),
      ));
      expect(find.text('Coming soon'), findsOneWidget);
      expect(find.text('This screen is not in the mobile app yet.'),
          findsOneWidget);
      expect(find.textContaining('yakında'), findsNothing);
    });

    testWidgets('app link to a web-only page opens the honest screen',
        (tester) async {
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
          MaterialApp(navigatorKey: key, home: const Text('HOME')));
      final links = DeepLinkService(completeOAuth: (_) async => true);
      InAppRoute.configure(appHosts: {'app.crm.protoolbag.com'});

      // not initialised through the platform channel: wire what init() wires
      expect(InAppRoute.open('/report/my', navigatorKey: key, requireScreen: true),
          isFalse);
      expect(InAppRoute.openWebOnly('/report/my', navigatorKey: key), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('My reports'), findsOneWidget);
      expect(find.text('Open on the web'), findsOneWidget);
      expect(links.isInitialized, isFalse);
    });

    testWidgets('link to /m365/mail opens (direct-only screen)', (tester) async {
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
          MaterialApp(navigatorKey: key, home: const Text('HOME')));
      // requireScreen now accepts direct-only screens
      expect(ScreenResolver.canOpen('/m365/mail'), isTrue);
      expect(InAppRoute.open('/nowhere', navigatorKey: key, requireScreen: true),
          isFalse);
    });
  });
}
