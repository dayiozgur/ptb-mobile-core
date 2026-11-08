import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../helpers/supabase_fakes.dart';

/// WP-D: mobil yasal onay kapısı (web consentActiveGuard + ConsentGateComponent).
// LocalizationService gibi: eksik anahtar → anahtarın kendisi.
String _t(String key) {
  if (key == 'consent.document.kvkk.title') return 'KVKK-tr';
  if (key.startsWith('consent.document.')) return key;
  return '[$key]';
}

const _kvkk = ConsentDoc(code: 'kvkk', title: 'KVKK stored', version: '2', url: '/legal/kvkk');
const _tos = ConsentDoc(code: 'tos', title: 'ToS stored', version: '1');
const _cerez =
    ConsentDoc(code: 'cerez', title: 'Çerez', version: '1', mandatory: false);

class _FakeConsent extends ConsentService {
  _FakeConsent() : super(supabase: MockSupabaseClient());

  List<ConsentDoc> missing = const [];
  List<ConsentDoc> all = const [_kvkk, _tos, _cerez];
  Object? checkError;
  Object? writeError;
  final recorded = <List<ConsentDecision>>[];
  String? recordedTenant;
  int checks = 0;

  @override
  Future<List<ConsentDoc>> getMissingMandatory(String userId) async {
    checks++;
    if (checkError != null) throw checkError!;
    return missing;
  }

  @override
  Future<List<ConsentDoc>> getAllActiveDocuments() async => all;

  @override
  Future<String?> getAppBaseUrl(String? platformId) async =>
      'https://app.pms.protoolbag.com';

  @override
  Future<void> recordConsents({
    required String userId,
    String? tenantId,
    required List<ConsentDecision> decisions,
    String? userAgent,
  }) async {
    if (writeError != null) throw writeError!;
    recordedTenant = tenantId;
    recorded.add(decisions);
  }
}

Widget _app(_FakeConsent svc,
        {String? uid = 'u1', Future<void> Function()? onSignOut}) =>
    MaterialApp(
      home: ConsentGate(
        service: svc,
        userId: () => uid,
        tenantId: () => 't1',
        platformId: () => 'p1',
        translate: _t,
        onSignOut: onSignOut,
        child: const Text('SHELL', textDirection: TextDirection.ltr),
      ),
    );

void main() {
  setUp(ConsentGate.resetSession);

  testWidgets('eksik onay yok → shell', (tester) async {
    final svc = _FakeConsent();
    await tester.pumpWidget(_app(svc));
    await tester.pumpAndSettle();
    expect(find.text('SHELL'), findsOneWidget);
    expect(find.byKey(const Key('consent-gate-view')), findsNothing);
  });

  testWidgets('kullanıcı yok → fail-open, sorgu yok', (tester) async {
    final svc = _FakeConsent()..missing = const [_kvkk];
    await tester.pumpWidget(_app(svc, uid: null));
    expect(find.text('SHELL'), findsOneWidget);
    expect(svc.checks, 0);
  });

  testWidgets('kontrol hatası → fail-open', (tester) async {
    final svc = _FakeConsent()..checkError = Exception('db');
    await tester.pumpWidget(_app(svc));
    await tester.pumpAndSettle();
    expect(find.text('SHELL'), findsOneWidget);
  });

  testWidgets(
      'eksik onay → ekran; zorunlular işaretlenmeden gönder kapalı; '
      'onay → platform_consents + shell', (tester) async {
    final svc = _FakeConsent()..missing = const [_kvkk];
    await tester.pumpWidget(_app(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('consent-gate-view')), findsOneWidget);
    expect(find.text('SHELL'), findsNothing);
    // Başlık: i18n anahtarı varsa çeviri, yoksa saklı başlık.
    expect(find.text('[consent.accept_prefix] KVKK-tr'), findsOneWidget);
    expect(find.text('[consent.accept_prefix] ToS stored'), findsOneWidget);
    expect(find.text('[consent.optional]'), findsOneWidget);
    // Göreli url → mutlak bağlantı ikonu; url'siz belgede yok.
    expect(find.byKey(const Key('consent-open-kvkk')), findsOneWidget);
    expect(find.byKey(const Key('consent-open-tos')), findsNothing);

    // Yalnız bir zorunlu → gönder hâlâ kapalı.
    await tester.tap(find.byKey(const Key('consent-doc-kvkk')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('consent-submit')));
    await tester.tap(find.byKey(const Key('consent-submit')));
    await tester.pump();
    expect(svc.recorded, isEmpty);

    await tester.ensureVisible(find.byKey(const Key('consent-doc-tos')));
    await tester.tap(find.byKey(const Key('consent-doc-tos')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('consent-submit')));
    await tester.tap(find.byKey(const Key('consent-submit')));
    await tester.pumpAndSettle();

    expect(svc.recorded, hasLength(1));
    expect(svc.recorded.single.map((d) => '${d.code}@${d.version}'),
        ['kvkk@2', 'tos@1']); // isteğe bağlı çerez işaretlenmedi → yazılmaz
    expect(svc.recordedTenant, 't1');
    expect(find.text('SHELL'), findsOneWidget);
  });

  testWidgets('tümünü kabul et → isteğe bağlı dahil hepsi yazılır', (tester) async {
    final svc = _FakeConsent()..missing = const [_tos];
    await tester.pumpWidget(_app(svc));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('consent-accept-all')));
    await tester.tap(find.byKey(const Key('consent-accept-all')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('consent-submit')));
    await tester.tap(find.byKey(const Key('consent-submit')));
    await tester.pumpAndSettle();
    expect(svc.recorded.single.map((d) => d.code), ['kvkk', 'tos', 'cerez']);
  });

  testWidgets('yazım hatası → save_error, ekran kalır', (tester) async {
    final svc = _FakeConsent()
      ..missing = const [_tos]
      ..writeError = Exception('rls');
    await tester.pumpWidget(_app(svc));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('consent-accept-all')));
    await tester.tap(find.byKey(const Key('consent-accept-all')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('consent-submit')));
    await tester.tap(find.byKey(const Key('consent-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('[consent.save_error]'), findsOneWidget);
    expect(find.byKey(const Key('consent-gate-view')), findsOneWidget);
    expect(find.text('SHELL'), findsNothing);
  });

  testWidgets('reddet → çıkış', (tester) async {
    var signedOut = 0;
    final svc = _FakeConsent()..missing = const [_kvkk];
    await tester.pumpWidget(_app(svc, onSignOut: () async => signedOut++));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('consent-reject')));
    await tester.tap(find.byKey(const Key('consent-reject')));
    await tester.pump();
    expect(signedOut, 1);
  });

  testWidgets('geçilen kullanıcı oturum içinde tekrar sorgulanmaz', (tester) async {
    final svc = _FakeConsent();
    await tester.pumpWidget(_app(svc));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(svc));
    expect(find.text('SHELL'), findsOneWidget);
    expect(svc.checks, 1);
  });
}
