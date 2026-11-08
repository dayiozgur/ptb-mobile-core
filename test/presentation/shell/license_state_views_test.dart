import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// WP-A: salt-okunur bandı + kilit ekranı (çeviri anahtarları, eylemler).
String _t(String key) => '[$key]';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets(
      'ReadOnlyLicenseBanner başlık/detay/bitiş tarihi ve fatura eylemi',
      (tester) async {
    var billing = 0;
    await tester.pumpWidget(_host(ReadOnlyLicenseBanner(
      translate: _t,
      graceUntilText: '20 Kas 2026',
      onBilling: () => billing++,
    )));

    expect(find.byKey(const Key('license-read-only-banner')), findsOneWidget);
    expect(find.text('[entitlement.read_only.title]'), findsOneWidget);
    expect(
        find.text(
            '[entitlement.read_only.detail] [entitlement.read_only.until] 20 Kas 2026'),
        findsOneWidget);
    await tester.tap(find.text('[entitlement.read_only.billing]'));
    expect(billing, 1);
  });

  testWidgets('ReadOnlyLicenseBanner tarih yoksa "until" göstermez',
      (tester) async {
    await tester.pumpWidget(_host(const ReadOnlyLicenseBanner(translate: _t)));
    expect(find.text('[entitlement.read_only.detail]'), findsOneWidget);
    expect(find.text('[entitlement.read_only.billing]'), findsNothing);
  });

  testWidgets('LicenseLockedView hesap / tekrar dene / çıkış eylemleri',
      (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(_host(LicenseLockedView(
      translate: _t,
      onBilling: () => taps.add('billing'),
      onRetry: () => taps.add('retry'),
      onSignOut: () => taps.add('signout'),
    )));

    expect(find.byKey(const Key('license-locked-view')), findsOneWidget);
    expect(find.text('[not_licensed.title]'), findsOneWidget);
    expect(find.text('[not_licensed.message]'), findsOneWidget);
    await tester.tap(find.text('[not_licensed.billing]'));
    await tester.tap(find.text('[not_licensed.retry]'));
    await tester.tap(find.text('[not_licensed.sign_out]'));
    expect(taps, ['billing', 'retry', 'signout']);
  });

  testWidgets('LicenseLockedView busy iken tekrar dene devre dışı',
      (tester) async {
    var retries = 0;
    await tester.pumpWidget(_host(LicenseLockedView(
      translate: _t,
      busy: true,
      onRetry: () => retries++,
    )));
    await tester.tap(find.text('[not_licensed.retry]'));
    expect(retries, 0);
  });
}
