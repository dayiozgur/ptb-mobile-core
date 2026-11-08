import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:protoolbag_crm/config/crm_screens.dart';
import 'package:protoolbag_crm/features/companies/crm_companies_screen.dart';
import 'package:protoolbag_crm/features/companies/crm_company_detail_screen.dart';
import 'package:protoolbag_crm/features/leads/crm_leads_screen.dart';
import 'package:protoolbag_crm/features/pipeline/crm_pipeline_screen.dart';
import 'package:protoolbag_crm/features/sequences/crm_sequences_screen.dart';
import 'package:protoolbag_crm/features/web_leads/web_leads_screen.dart';

/// WP-C: canlı CRM DB-menü yolları (platform_menu_items) artık bir ekrana
/// çözülür → mobil menüde budanmaz. `/crm/mailbox` bilinçli olarak çözümsüz.
void main() {
  MenuItem item(String path) => MenuItem(itemKey: '', title: '', path: path);

  test('yeni CRM yolları ekrana çözülür', () {
    expect(crmResolve(item('/crm/pipeline')), isA<CrmPipelineScreen>());
    expect(crmResolve(item('/crm/leads')), isA<CrmLeadsScreen>());
    expect(crmResolve(item('/crm/companies')), isA<CrmCompaniesScreen>());
    expect(crmResolve(item('/crm/web-leads')), isA<WebLeadsScreen>());
    expect(crmResolve(item('/crm/sequences')), isA<CrmSequencesScreen>());
  });

  test('firma 360 deep-link', () {
    final w = crmResolve(
        item('/crm/companies/d411e37d-d24e-44a1-a417-8251bb2d8b36'));
    expect(w, isA<CrmCompanyDetailScreen>());
    expect((w as CrmCompanyDetailScreen).companyId,
        'd411e37d-d24e-44a1-a417-8251bb2d8b36');
  });

  test('/crm/mailbox çözümsüz (gizli kalır)', () {
    expect(crmResolve(item('/crm/mailbox')), isNull);
  });
}
