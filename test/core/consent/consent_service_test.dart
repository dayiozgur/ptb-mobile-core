import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../helpers/supabase_fakes.dart';

/// WP-D: mobil ConsentService — web `consent.service.ts` ile aynı sorgu/kural.
Map<String, dynamic> _doc(String code,
        {String version = '1',
        bool mandatory = true,
        String? scope = 'platform',
        int sort = 0}) =>
    {
      'code': code,
      'title': 'T-$code',
      'version': version,
      'url': '/legal/$code',
      'mandatory': mandatory,
      'active': true,
      'sort_order': sort,
      if (scope != null) 'scope': scope,
    };

List<List<Object?>> _args(FakeQueryBuilder qb, Symbol name) => qb.calls
    .where((c) => c.memberName == name)
    .map((c) => c.positionalArguments)
    .toList();

void main() {
  late SupabaseHarness h;
  late ConsentService svc;

  setUp(() {
    h = SupabaseHarness();
    svc = ConsentService(supabase: h.client);
  });

  test('zorunlu belgeler: active+mandatory filtre, yalnız platform kapsamı', () async {
    h.stubFrom('consent_documents', result: [
      _doc('kvkk_aydinlatma', sort: 1),
      _doc('legacy', scope: null, sort: 2), // scope kolonu yok → platform
      _doc('team_chat', scope: 'team_chat', mandatory: false, sort: 20),
    ]);
    final docs = await svc.getMandatoryDocuments();
    expect(docs.map((d) => d.code), ['kvkk_aydinlatma', 'legacy']);
    final qb = h.queryByTable['consent_documents']!;
    expect(_args(qb, #select).first, ['*']);
    expect(_args(qb, #eq), [
      ['active', true],
      ['mandatory', true]
    ]);
  });

  test('kullanıcı onayları: accepted=true + revoked_at IS NULL', () async {
    h.stubFrom('platform_consents', result: [
      {'document_code': 'tos', 'version': '2', 'accepted': true, 'revoked_at': null}
    ]);
    final m = await svc.getUserConsents('u1');
    expect(m, {'tos': '2'});
    final qb = h.queryByTable['platform_consents']!;
    expect(_args(qb, #eq), [
      ['user_id', 'u1'],
      ['accepted', true]
    ]);
    expect(_args(qb, #isFilter), [
      ['revoked_at', null]
    ]);
  });

  test('missingFrom: sürüm farkı = eksik (sürüm artışı yeniden onay ister)', () {
    const docs = [
      ConsentDoc(code: 'kvkk', title: 'K', version: '2'),
      ConsentDoc(code: 'tos', title: 'T', version: '1'),
      ConsentDoc(code: 'privacy', title: 'P', version: '1'),
    ];
    final missing =
        ConsentService.missingFrom(docs, {'kvkk': '1', 'tos': '1'});
    expect(missing.map((d) => d.code), ['kvkk', 'privacy']);
    expect(ConsentService.missingFrom(docs, {'kvkk': '2', 'tos': '1', 'privacy': '1'}),
        isEmpty);
  });

  test('getMissingMandatory iki tabloyu birleştirir', () async {
    h.stubFrom('consent_documents',
        result: [_doc('kvkk'), _doc('tos', version: '3')]);
    h.stubFrom('platform_consents', result: [
      {'document_code': 'kvkk', 'version': '1'},
      {'document_code': 'tos', 'version': '2'},
    ]);
    final missing = await svc.getMissingMandatory('u1');
    expect(missing.map((d) => d.code), ['tos']);
  });

  test('recordConsents: web ile aynı satır şekli, source=mobile', () async {
    h.stubFrom('platform_consents', result: null);
    await svc.recordConsents(
      userId: 'u1',
      tenantId: 't1',
      decisions: const [
        ConsentDecision(code: 'kvkk', version: '1'),
        ConsentDecision(code: 'cerez', version: '1'),
      ],
      userAgent: 'ua',
    );
    final rows = _args(h.queryByTable['platform_consents']!, #insert).single.single
        as List<Map<String, dynamic>>;
    expect(rows, hasLength(2));
    expect(rows.first, containsPair('user_id', 'u1'));
    expect(rows.first, containsPair('tenant_id', 't1'));
    expect(rows.first, containsPair('document_code', 'kvkk'));
    expect(rows.first, containsPair('version', '1'));
    expect(rows.first, containsPair('accepted', true));
    expect(rows.first, containsPair('revoked_at', null));
    expect(rows.first, containsPair('source', 'mobile'));
    expect(rows.first, containsPair('user_agent', 'ua'));
    expect(DateTime.tryParse(rows.first['accepted_at'] as String), isNotNull);
  });

  test('recordConsents: boş karar → yazım yok', () async {
    await svc.recordConsents(userId: 'u1', decisions: const []);
    expect(h.queryByTable, isEmpty);
  });

  test('resolveDocumentUrl: göreli → app_base_url ile mutlak', () {
    expect(
        ConsentService.resolveDocumentUrl(
            '/legal/kvkk', 'https://app.crm.protoolbag.com/'),
        'https://app.crm.protoolbag.com/legal/kvkk');
    expect(ConsentService.resolveDocumentUrl('https://x.y/z', null),
        'https://x.y/z');
    expect(ConsentService.resolveDocumentUrl('/legal/kvkk', null), isNull);
    expect(ConsentService.resolveDocumentUrl(null, 'https://a'), isNull);
  });

  test('getAppBaseUrl: platforms.app_base_url; hata → null', () async {
    h.stubFrom('platforms',
        result: {'app_base_url': 'https://app.pms.protoolbag.com'});
    expect(await svc.getAppBaseUrl('p1'), 'https://app.pms.protoolbag.com');
    h.stubFrom('platforms', error: Exception('x'));
    expect(await svc.getAppBaseUrl('p1'), isNull);
    expect(await svc.getAppBaseUrl(null), isNull);
  });
}
