import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../helpers/widget_test_helpers.dart';

/// Widget tests for [LoginScreen].
///
/// The screen pulls its collaborators from the service locator:
///   * `LocalizationService` — every visible string (`translate`) + locale flag
///   * `BrandingService`     — `current` logo/tagline/features (null → fallbacks)
///   * `PlatformContext`     — `activePlatformCode` shown as the big title
///   * `AuthService`         — biometric probes fired from `initState`
///
/// We register minimal fakes for all four (never a real Supabase client) and
/// assert the login form renders deterministically.
void main() {
  late MockAuthService auth;
  late MockBrandingService branding;
  late MockPlatformContext platform;

  setUp(() async {
    await sl.reset();

    auth = MockAuthService();
    branding = MockBrandingService();
    platform = MockPlatformContext();

    // initState → biometric probes. Keep them false so no biometric UI shows.
    when(() => auth.isBiometricAvailable()).thenAnswer((_) async => false);
    when(() => auth.isBiometricLoginEnabled()).thenAnswer((_) async => false);

    // No DB-driven branding → screen falls back to platform code + i18n strings.
    when(() => branding.current).thenReturn(null);

    when(() => platform.activePlatformCode).thenReturn('PHR');

    registerFake<AuthService>(auth);
    registerFake<BrandingService>(branding);
    registerFake<PlatformContext>(platform);
    registerFake<LocalizationService>(buildFakeLocalization());
  });

  tearDown(() async {
    await sl.reset();
  });

  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the brand logo image in the app bar', (tester) async {
    await pumpLogin(tester);

    // Branding has no http logoUrl → the screen renders the bundled asset logo
    // (an Image widget) in the title slot. Assert on the Image rather than the
    // icon fallback, which only appears if the asset decode errors.
    expect(find.byType(Image), findsWidgets);
  });

  testWidgets('renders email and password fields', (tester) async {
    await pumpLogin(tester);

    expect(find.byType(AppEmailField), findsOneWidget);
    expect(find.byType(AppPasswordField), findsOneWidget);
  });

  testWidgets("renders the 'Giriş Yap' login button", (tester) async {
    await pumpLogin(tester);

    expect(find.text('Giriş Yap'), findsOneWidget);
    expect(find.byType(AppButton), findsWidgets);
  });

  testWidgets('shows the active platform code as the title', (tester) async {
    await pumpLogin(tester);

    expect(find.text('PHR'), findsOneWidget);
  });

  testWidgets('renders the language flag action for the current locale',
      (tester) async {
    await pumpLogin(tester);

    // Locale is pinned to Turkish → the app-bar action shows the 🇹🇷 flag.
    expect(find.text(flagEmoji('TR')), findsOneWidget);
  });

  testWidgets('shows the request-access (waitlist) call to action',
      (tester) async {
    await pumpLogin(tester);

    expect(find.text('Erişim Talep Et'), findsOneWidget);
  });
}
