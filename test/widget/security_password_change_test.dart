import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../helpers/widget_test_helpers.dart';

/// Widget tests for the Security screen password sheet (CRA F-108): the
/// current password is required and server outcomes land on the right field
/// with the right message (rate limit is never shown as "wrong password").
void main() {
  late MockAuthService auth;

  setUp(() async {
    await sl.reset();
    auth = MockAuthService();
    when(() => auth.listMfaFactors()).thenAnswer((_) async => []);
    when(() => auth.emailFactorEnabled()).thenAnswer((_) async => false);
    registerFake<AuthService>(auth);
    // translate() echoes the key → the screen shows its Turkish fallbacks.
    registerFake<LocalizationService>(buildFakeLocalization());
  });

  tearDown(() async {
    await sl.reset();
  });

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SecurityScreen()));
    await tester.pumpAndSettle();
    final tile = find.text('Şifre Değiştir').first;
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }

  Future<void> fillAndSubmit(
    WidgetTester tester, {
    required String current,
    String newPw = 'NewPassw0rd!',
  }) async {
    Finder field(String key) => find.descendant(
        of: find.byKey(Key(key)), matching: find.byType(TextFormField));
    await tester.enterText(field('security.password.current'), current);
    await tester.enterText(field('security.password.new'), newPw);
    await tester.enterText(field('security.password.confirm'), newPw);
    final submit = find.text('Şifreyi Güncelle');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
  }

  void stubOutcome(PasswordChangeOutcome outcome) {
    when(() => auth.changePasswordVerified(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        )).thenAnswer((_) async => PasswordChangeResult(outcome));
  }

  testWidgets('empty current password blocks submit (no service call)',
      (tester) async {
    stubOutcome(PasswordChangeOutcome.success);
    await openSheet(tester);

    await fillAndSubmit(tester, current: '');

    expect(find.text('Mevcut şifrenizi girin.'), findsOneWidget);
    verifyNever(() => auth.changePasswordVerified(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        ));
  });

  testWidgets('wrong current password is shown on the field; sheet stays',
      (tester) async {
    stubOutcome(PasswordChangeOutcome.wrongCurrentPassword);
    await openSheet(tester);

    await fillAndSubmit(tester, current: 'OldPassw0rd!');

    verify(() => auth.changePasswordVerified(
          currentPassword: 'OldPassw0rd!',
          newPassword: 'NewPassw0rd!',
        )).called(1);
    expect(find.text('Mevcut şifre hatalı.'), findsOneWidget);
    expect(find.text('Şifreyi Güncelle'), findsOneWidget);
  });

  testWidgets('rate limit shows its own message, not wrong password',
      (tester) async {
    stubOutcome(PasswordChangeOutcome.rateLimited);
    await openSheet(tester);

    await fillAndSubmit(tester, current: 'OldPassw0rd!');

    expect(
        find.text(
            'Çok fazla deneme yapıldı. Lütfen biraz bekleyip tekrar deneyin.'),
        findsOneWidget);
    expect(find.text('Mevcut şifre hatalı.'), findsNothing);
  });

  testWidgets('network error shows the generic error', (tester) async {
    stubOutcome(PasswordChangeOutcome.networkError);
    await openSheet(tester);

    await fillAndSubmit(tester, current: 'OldPassw0rd!');

    expect(find.text('Şifre güncellenemedi.'), findsOneWidget);
    expect(find.text('Mevcut şifre hatalı.'), findsNothing);
  });

  /// First attempt (no code) → the server asks for the second factor; the
  /// attempt that carries a code gets [withCode].
  void stubMfaFlow({required PasswordChangeOutcome withCode}) {
    when(() => auth.changePasswordVerified(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
          mfaCode: any(named: 'mfaCode'),
        )).thenAnswer((inv) async {
      final code = inv.namedArguments[#mfaCode] as String?;
      return PasswordChangeResult(
          code == null ? PasswordChangeOutcome.mfaRequired : withCode);
    });
  }

  testWidgets('MFA account: the sheet asks for the authenticator code and '
      'resubmits with it (nothing is lost, no generic error)', (tester) async {
    stubMfaFlow(withCode: PasswordChangeOutcome.success);
    await openSheet(tester);

    expect(find.byKey(const Key('security.password.mfa_code')), findsNothing);
    await fillAndSubmit(tester, current: 'OldPassw0rd!');

    // the reason + the code field appear; the generic error does not
    expect(find.byKey(const Key('security.password.mfa_code')), findsOneWidget);
    expect(find.textContaining('6 haneli kodu girin'), findsOneWidget);
    expect(find.text('Şifre güncellenemedi.'), findsNothing);

    await tester.enterText(
        find.descendant(
            of: find.byKey(const Key('security.password.mfa_code')),
            matching: find.byType(TextFormField)),
        '123456');
    final submit = find.text('Şifreyi Güncelle');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    verify(() => auth.changePasswordVerified(
          currentPassword: 'OldPassw0rd!',
          newPassword: 'NewPassw0rd!',
          mfaCode: '123456',
        )).called(1);
    expect(find.text('Şifreniz güncellendi.'), findsOneWidget);
  });

  testWidgets('a wrong authenticator code is shown on the code field',
      (tester) async {
    stubMfaFlow(withCode: PasswordChangeOutcome.mfaCodeInvalid);
    await openSheet(tester);
    await fillAndSubmit(tester, current: 'OldPassw0rd!');

    await tester.enterText(
        find.descendant(
            of: find.byKey(const Key('security.password.mfa_code')),
            matching: find.byType(TextFormField)),
        '000000');
    final submit = find.text('Şifreyi Güncelle');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Girdiğiniz kod hatalı.'), findsOneWidget);
    expect(find.text('Mevcut şifre hatalı.'), findsNothing);
    expect(find.text('Şifreyi Güncelle'), findsOneWidget);
  });

  testWidgets('secure password change: asks to sign in again (web wording)',
      (tester) async {
    stubOutcome(PasswordChangeOutcome.reauthenticationNeeded);
    await openSheet(tester);

    await fillAndSubmit(tester, current: 'OldPassw0rd!');

    expect(find.textContaining('çıkış yapıp yeniden giriş yapın'),
        findsOneWidget);
    expect(find.text('Mevcut şifre hatalı.'), findsNothing);
  });
}
