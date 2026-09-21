import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../helpers/supabase_fakes.dart';

/// CrmDuplicateService — web DuplicatesComponent mobil paritesi:
///   • findContactDuplicates → `fn_crm_find_duplicate_contacts`
///   • findCompanyDuplicates → `fn_crm_find_duplicate_companies`
///   • merge                 → `fn_crm_merge_{contacts,companies}` (survivor+duplicate)
/// Hata / geçersiz → [] / false (UI'a fırlatmaz). RPC imzaları canlı-DB'den.
void main() {
  late SupabaseHarness h;
  late CrmDuplicateService service;

  setUp(() {
    h = SupabaseHarness();
    service = CrmDuplicateService(supabase: h.client);
  });

  group('findContactDuplicates', () {
    test('kişi çiftlerini parse eder (isim + email·telefon + neden + güven)', () async {
      h.stubRpc('fn_crm_find_duplicate_contacts', result: <Map<String, dynamic>>[
        {
          'contact_a_id': 'a1', 'a_name': 'Ada Lovelace', 'a_email': 'ada@x.com', 'a_phone': '555',
          'contact_b_id': 'b1', 'b_name': 'Ada L.', 'b_email': 'ada@x.com', 'b_phone': null,
          'match_reason': 'same email', 'confidence': 92,
        },
      ]);

      final pairs = await service.findContactDuplicates();

      expect(pairs, hasLength(1));
      expect(pairs[0].kind, DupKind.contact);
      expect(pairs[0].aTitle, 'Ada Lovelace');
      expect(pairs[0].aSubtitle, 'ada@x.com · 555');
      expect(pairs[0].bSubtitle, 'ada@x.com'); // null telefon atlanır
      expect(pairs[0].reason, 'same email');
      expect(pairs[0].confidence, 92);
    });

    test('hata → boş liste (fırlatmaz)', () async {
      h.stubRpc('fn_crm_find_duplicate_contacts', error: Exception('db'));
      expect(await service.findContactDuplicates(), isEmpty);
    });
  });

  group('findCompanyDuplicates', () {
    test('firma çiftlerini parse eder (isim + domain)', () async {
      h.stubRpc('fn_crm_find_duplicate_companies', result: <Map<String, dynamic>>[
        {'company_a_id': 'c1', 'a_name': 'Acme', 'a_domain': 'acme.com',
         'company_b_id': 'c2', 'b_name': 'ACME Inc', 'b_domain': 'acme.com', 'match_reason': 'domain', 'confidence': 88},
      ]);
      final pairs = await service.findCompanyDuplicates();
      expect(pairs.single.kind, DupKind.company);
      expect(pairs.single.aSubtitle, 'acme.com');
    });
  });

  group('merge', () {
    test('contact → fn_crm_merge_contacts survivor+duplicate, true', () async {
      h.stubRpc('fn_crm_merge_contacts', result: <String, dynamic>{'ok': true});
      final ok = await service.merge(DupKind.contact, 'surv', 'dup');
      expect(ok, isTrue);
      final p = h.capturedRpcParams('fn_crm_merge_contacts');
      expect(p?['p_survivor'], 'surv');
      expect(p?['p_duplicate'], 'dup');
    });

    test('company → fn_crm_merge_companies', () async {
      h.stubRpc('fn_crm_merge_companies', result: <String, dynamic>{'ok': true});
      expect(await service.merge(DupKind.company, 's', 'd'), isTrue);
      expect(h.capturedRpcParams('fn_crm_merge_companies')?['p_survivor'], 's');
    });

    test('survivor==duplicate veya boş → false (RPC yok)', () async {
      expect(await service.merge(DupKind.contact, 'x', 'x'), isFalse);
      expect(await service.merge(DupKind.contact, '', 'd'), isFalse);
    });

    test('hata → false (fırlatmaz)', () async {
      h.stubRpc('fn_crm_merge_contacts', error: Exception('rls'));
      expect(await service.merge(DupKind.contact, 's', 'd'), isFalse);
    });
  });
}
