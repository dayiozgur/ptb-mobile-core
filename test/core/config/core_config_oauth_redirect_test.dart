import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

void main() {
  CoreConfig cfg({String? scheme}) => CoreConfig(
        supabaseUrl: 'https://x.supabase.co',
        supabaseAnonKey: 'k',
        apiBaseUrl: 'https://api',
        appUrlScheme: scheme,
      );

  test('OAuth redirect comes from the app URL scheme', () {
    expect(cfg(scheme: 'ptbcrm').oauthRedirectUri, 'ptbcrm://oauth-callback');
    expect(cfg(scheme: 'ptbfixflow').oauthRedirectUri,
        'ptbfixflow://oauth-callback');
  });

  test('no scheme → no redirect (app cannot return from the browser)', () {
    expect(cfg().oauthRedirectUri, isNull);
    expect(cfg(scheme: '  ').oauthRedirectUri, isNull);
  });
}
