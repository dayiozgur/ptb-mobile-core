import 'package:flutter/material.dart' hide FormField;
import 'package:protoolbag_core/protoolbag_core.dart';

import '../features/calendar/crm_agenda_screen.dart';
import '../features/contacts/contacts_list_screen.dart';
import '../features/dashboard/crm_dashboard_screen.dart';
import '../features/deals/crm_entity_actions.dart';
import '../features/forecast/crm_forecast_screen.dart';
import '../features/companies/crm_companies_screen.dart';
import '../features/companies/crm_company_detail_screen.dart';
import '../features/leads/crm_leads_screen.dart';
import '../features/pipeline/crm_pipeline_screen.dart';
import '../features/sequences/crm_sequences_screen.dart';
import '../features/web_leads/web_leads_screen.dart';
import '../features/duplicates/crm_duplicates_screen.dart';
import '../crm_common.dart';

/// CRM "Günlük İşlerim" kaynağı — `fn_crm_my_work` satırlarını generic
/// [WorkInboxItem]'a eşler (bucket: overdue/today/stale gruplaması).
final WorkInboxSource crmMyWorkSource = WorkInboxSource(
  title: crmT('crm.work.my_work', 'Günlük İşlerim'),
  rpcName: 'fn_crm_my_work',
  mapper: (r) => WorkInboxItem(
    id: r['entity_id']?.toString() ?? '',
    title: r['subject']?.toString() ?? '—',
    subtitle: [r['deal_name'], r['contact_name'], r['company_name']]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(' · '),
    group: r['bucket']?.toString(),
    status: r['status']?.toString(),
    entityType: r['item_kind']?.toString(), // 'activity' | 'deal'
    dueDate: r['due_date'] != null
        ? DateTime.tryParse(r['due_date'].toString())
        : null,
  ),
);

/// CRM domain ekran çözümleyicisi.
///
/// CRM'in çoğu tipi (deal/lead/activity/proposal/product) çekirdek entity-engine
/// ile otomatik gelir; nötr yollar (settings/report/page) çekirdek
/// [ScreenResolver]'da çözülür. Burada YALNIZ CRM-özel domain yolları:
/// Kişiler (`contacts` gerçek tablosu), Günlük İşlerim (`fn_crm_my_work`),
/// Satış Hattı / Potansiyeller / Firmalar / Web Potansiyelleri / Diziler.
Widget? crmResolve(MenuItem item) {
  final path = item.path;
  if (path == null || path.isEmpty) return null;
  final p = path.toLowerCase();

  if (p == '/crm/contacts' || p == '/contacts') {
    return const ContactsListScreen();
  }
  if (p == '/crm/my-work' || p == '/my-work' || p == '/crm/tasks') {
    return WorkInboxScreen(source: crmMyWorkSource);
  }
  if (p == '/crm/dashboard' || p == '/dashboard' || p == '/crm/reports') {
    return const CrmDashboardScreen();
  }
  if (p == '/crm/calendar' || p == '/crm/agenda') {
    return const CrmAgendaScreen();
  }
  // CRM-07 forecast: web menü-item'ı `/crm/forecast` ZATEN var (nav.crm_forecast);
  // burada yalnız mobil ekranı bu mevcut yola bağlarız (menü paylaşımlı — web kırılmaz).
  if (p == '/crm/forecast') {
    return const CrmForecastScreen();
  }
  // Yinelenen kayıtlar: web menü-item'ı `/crm/duplicates` ZATEN var (nav.crm_duplicates).
  if (p == '/crm/duplicates') {
    return const CrmDuplicatesScreen();
  }
  // WP-C: web DB-menü yolları (canlı platform_menu_items, CRM platformu) —
  // önceden çözümsüzdü → mobilde gizleniyordu.
  if (p == '/crm/pipeline') return const CrmPipelineScreen();
  if (p == '/crm/leads') return const CrmLeadsScreen();
  if (p == '/crm/companies') return const CrmCompaniesScreen();
  // Firma 360 deep-link (web `/crm/companies/:id`).
  final company = RegExp(r'^/crm/companies/([0-9a-f-]{36})$').firstMatch(p);
  if (company != null) {
    return CrmCompanyDetailScreen(companyId: company.group(1)!);
  }
  // Web `/crm/web-leads/:id` drawer'ı mobilde ayrı detay yok → kuyruğa düşer.
  if (p == '/crm/web-leads' || p.startsWith('/crm/web-leads/')) {
    return const WebLeadsScreen();
  }
  if (p == '/crm/sequences') return const CrmSequencesScreen();
  // `/crm/mailbox` BİLİNÇLİ olarak çözümsüz (menüde gizli): web posta kutusu
  // Microsoft Graph entegrasyonu + `mail.read` yeteneği ister; mobilde yok.
  return null;
}

bool _done = false;

/// CRM domain ekranlarını çekirdek [ScreenResolver]'a kaydet (bir kez).
/// İlk shell render'ından ÖNCE `main()` içinde çağrılmalı.
void registerCrmScreens() {
  if (_done) return;
  ScreenResolver.addResolver(crmResolve);
  registerCrmEntityActions(); // entity_detail'e CRM aksiyon-çubuğu + feed
  registerMicrosoftFilesSection(); // OneDrive/SharePoint dosya kartı (tüm tipler)
  _done = true;
}
