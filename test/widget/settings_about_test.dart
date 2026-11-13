import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../helpers/widget_test_helpers.dart';

class MockThemeService extends Mock implements ThemeService {}

/// Settings → About: the privacy policy and the terms are reachable from
/// inside the app (both stores expect that), the version is not hardcoded and
/// the section titles are keywords.
void main() {
  late MockAuthService auth;
  late MockProfileService profiles;
  late MockFileStorageService files;
  late MockThemeService theme;

  setUp(() async {
    await sl.reset();
    InAppRoute.resetConfig();
    auth = MockAuthService();
    profiles = MockProfileService();
    files = MockFileStorageService();
    theme = MockThemeService();
    when(() => auth.isBiometricLoginEnabled()).thenAnswer((_) async => false);
    when(() => auth.isBiometricAvailable()).thenAnswer((_) async => false);
    when(() => auth.currentUser).thenReturn(null);
    when(() => profiles.getProfileBundle()).thenAnswer((_) async => null);
    when(() => files.getAvatarUrl(any())).thenAnswer((_) async => null);
    when(() => theme.themeMode).thenReturn(AppThemeMode.system);
    registerFake<AuthService>(auth);
    registerFake<ProfileService>(profiles);
    registerFake<FileStorageService>(files);
    registerFake<ThemeService>(theme);
    registerFake<LocalizationService>(buildFakeLocalization(
      overrides: AppLocalizations.getTranslations(AppLocale.english),
      locale: AppLocale.english,
    ));
  });

  tearDown(() async {
    await sl.reset();
    InAppRoute.resetConfig();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('legal links are listed when the app knows its web origin',
      (tester) async {
    InAppRoute.configure(webOrigin: 'https://app.crm.protoolbag.com');
    await pump(tester);

    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings.legal.privacy-policy')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('settings.legal.terms-of-service')),
        findsOneWidget);
  });

  testWidgets('no web origin → no dead links', (tester) async {
    await pump(tester);
    expect(find.text('Privacy Policy'), findsNothing);
    expect(find.text('Terms of Service'), findsNothing);
  });

  testWidgets('section titles are keywords; the version is not hardcoded',
      (tester) async {
    await pump(tester);
    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Change Password'), findsOneWidget);
    expect(find.text('Güvenlik'), findsNothing);
    expect(find.text('1.0.0 (Build 1)'), findsNothing);
  });
}
