import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// The provider callback returns to `<scheme>://oauth-callback` with either
/// `oauth_complete=<nonce>` (finish the link) or an enumerated result
/// (`oauth_error` / `admin_consent`). See `supabase/functions/oauth-callback`.
void main() {
  setUp(MicrosoftOAuthReturn.reset);
  tearDown(MicrosoftOAuthReturn.reset);

  DeepLinkService service({Future<bool> Function(String)? complete}) =>
      DeepLinkService(completeOAuth: complete ?? (_) async => true);

  for (final entry in {
    'oauth_error=declined': OAuthReturnNotice.declined,
    'oauth_error=admin_consent_required':
        OAuthReturnNotice.adminConsentRequired,
    'oauth_error=failed': OAuthReturnNotice.failed,
    'admin_consent=granted': OAuthReturnNotice.consentGranted,
    'admin_consent=declined': OAuthReturnNotice.consentDeclined,
  }.entries) {
    test('ptbcrm://oauth-callback?${entry.key} → ${entry.value.code}', () {
      final s = service();
      // No init() (no platform channel in unit tests): feed the link directly.
      s.handleUriForTest(Uri.parse('ptbcrm://oauth-callback?${entry.key}'));
      expect(MicrosoftOAuthReturn.notice.value, entry.value);
      expect(MicrosoftOAuthReturn.completions.value, 0,
          reason: 'nothing to complete without oauth_complete');
    });
  }

  test('unknown result values are ignored', () {
    service().handleUriForTest(
        Uri.parse('ptbcrm://oauth-callback?oauth_error=something_new&x=1'));
    expect(MicrosoftOAuthReturn.notice.value, isNull);
  });

  test('oauth_complete → completes the link and bumps completions', () async {
    String? seen;
    final s = service(complete: (c) async {
      seen = c;
      return true;
    });
    s.handleUriForTest(
        Uri.parse('ptbcrm://oauth-callback?oauth_complete=NONCE123'));
    await Future<void>.delayed(Duration.zero);
    expect(seen, 'NONCE123');
    expect(MicrosoftOAuthReturn.completions.value, 1);
    expect(MicrosoftOAuthReturn.notice.value, isNull);
  });

  test('a refused completion surfaces as "failed"', () async {
    final s = service(complete: (_) async => false);
    s.handleUriForTest(
        Uri.parse('ptbcrm://oauth-callback?oauth_complete=NONCE123'));
    await Future<void>.delayed(Duration.zero);
    expect(MicrosoftOAuthReturn.completions.value, 1);
    expect(MicrosoftOAuthReturn.notice.value, OAuthReturnNotice.failed);
  });

  test('a throwing completion never escapes and surfaces as "failed"',
      () async {
    final s = service(complete: (_) async => throw StateError('boom'));
    s.handleUriForTest(
        Uri.parse('ptbcrm://oauth-callback?oauth_complete=NONCE123'));
    await Future<void>.delayed(Duration.zero);
    expect(MicrosoftOAuthReturn.notice.value, OAuthReturnNotice.failed);
  });

  test('a non-OAuth custom-scheme link reports nothing', () {
    service().handleUriForTest(Uri.parse('ptbcrm://something-else?oauth_error=declined'));
    expect(MicrosoftOAuthReturn.notice.value, isNull);
  });
}
