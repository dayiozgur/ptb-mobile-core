import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Reusable `mocktail` doubles + registration helpers for widget tests.
///
/// The shell screens obtain their collaborators through the `get_it` service
/// locator (`sl<T>()` and the convenience getters such as `authService`).
/// These fakes let a test register the *minimal* set of services a screen
/// touches during `build`/`initState`, so it can be pumped with no real
/// Supabase client, no network, and no timers.
///
/// Deterministic: every stub resolves synchronously (or via a caller-supplied
/// [Completer]); nothing here talks to a real backend.

class MockAuthService extends Mock implements AuthService {}

class MockNotificationService extends Mock implements NotificationService {}

class MockProfileService extends Mock implements ProfileService {}

class MockFileStorageService extends Mock implements FileStorageService {}

class MockLocalizationService extends Mock implements LocalizationService {}

class MockBrandingService extends Mock implements BrandingService {}

class MockPlatformContext extends Mock implements PlatformContext {}

/// A handful of Turkish literals the shell screens ask for by key. The screens
/// call `translate(key)` with no interpolation params, so a plain key→string
/// map is enough; unknown keys fall back to the raw key (never throws).
const Map<String, String> _kDefaultTranslations = {
  'auth.login': 'Giriş Yap',
  'auth.email': 'E-posta',
  'auth.password': 'Şifre',
  'auth.forgot_password': 'Şifremi Unuttum',
  'auth.login.subtitle': 'Sahadan yönetime tek uygulama',
  'auth.login.app_name': 'Protoolbag',
  'auth.login.email_placeholder': 'ornek@sirket.com',
  'auth.login.password_placeholder': '••••••••',
  'auth.request_access.no_account': 'Hesabınız yok mu?',
  'auth.request_access.cta': 'Erişim Talep Et',
};

/// Builds a fake [LocalizationService] whose `translate` returns a known
/// Turkish string for the keys in [_kDefaultTranslations] (merged with any
/// [overrides]) and echoes the key for anything else. `currentLocale` is
/// pinned to [locale] (default Turkish) so the flag/locale actions render.
MockLocalizationService buildFakeLocalization({
  Map<String, String>? overrides,
  AppLocale locale = AppLocale.turkish,
}) {
  final loc = MockLocalizationService();
  final table = <String, String>{..._kDefaultTranslations, ...?overrides};
  when(() => loc.translate(any())).thenAnswer((invocation) {
    final key = invocation.positionalArguments.first as String;
    return table[key] ?? key;
  });
  when(() => loc.currentLocale).thenReturn(locale);
  return loc;
}

/// Registers [instance] for type [T] in the locator, replacing any prior
/// registration (safe to call after `sl.reset()` or over an existing entry).
void registerFake<T extends Object>(T instance) {
  if (sl.isRegistered<T>()) {
    sl.unregister<T>();
  }
  sl.registerSingleton<T>(instance);
}
