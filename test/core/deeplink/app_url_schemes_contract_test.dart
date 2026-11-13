import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Every app that sets `CoreConfig.appUrlScheme` must register that scheme on
/// both platforms, and the scheme must be one the server returns to
/// (`MOBILE_SCHEMES` in the web repo's `supabase/functions/_shared/oauth-flow.ts`;
/// `ptbfixflow:` was added there on 2026-11-13 — deployed separately).
void main() {
  // Snapshot of the server allow-list (web repo). Update both together.
  const serverSchemes = {
    'ptbcrm',
    'ptbphr',
    'ptbpms',
    'ptbppm',
    'ptbfixflow',
    'ptbmobile',
  };
  const apps = [
    'example_crm',
    'example_fixflow',
    'example_phr',
    'example_pms',
    'example_ppm',
    'example_pem',
  ];
  final schemeRe = RegExp(r"appUrlScheme:\s*'([a-z0-9]+)'");

  for (final app in apps) {
    final main = File('$app/lib/main.dart');
    if (!main.existsSync()) continue;
    final scheme = schemeRe.firstMatch(main.readAsStringSync())?.group(1);
    // No scheme → no in-app connect flow ("connect on the web").
    if (scheme == null) continue;

    test(
        '$app: $scheme is registered on Android and iOS and allowed by the server',
        () {
      expect(serverSchemes, contains(scheme));
      final manifest = File('$app/android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(manifest, contains('android:scheme="$scheme"'));
      final plist = File('$app/ios/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('<key>CFBundleURLSchemes</key>'));
      expect(plist, contains('<string>$scheme</string>'));
      expect(
          CoreConfig(
                  supabaseUrl: 'x',
                  supabaseAnonKey: 'y',
                  apiBaseUrl: 'z',
                  appUrlScheme: scheme)
              .oauthRedirectUri,
          '$scheme://oauth-callback');
    });
  }

  group('FixFlow return once the server accepts ptbfixflow:', () {
    setUp(MicrosoftOAuthReturn.reset);
    tearDown(MicrosoftOAuthReturn.reset);

    test('oauth_complete finishes the link', () async {
      String? seen;
      DeepLinkService(completeOAuth: (c) async {
        seen = c;
        return true;
      }).handleUriForTest(
          Uri.parse('ptbfixflow://oauth-callback?oauth_complete=N1'));
      await Future<void>.delayed(Duration.zero);
      expect(seen, 'N1');
      expect(MicrosoftOAuthReturn.completions.value, 1);
    });

    test('administrator approval required is reported', () {
      DeepLinkService(
          completeOAuth: (_) async =>
              true).handleUriForTest(Uri.parse(
          'ptbfixflow://oauth-callback?oauth_error=admin_consent_required'));
      expect(MicrosoftOAuthReturn.notice.value,
          OAuthReturnNotice.adminConsentRequired);
    });
  });
}
