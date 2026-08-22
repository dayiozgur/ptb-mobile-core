import 'package:flutter/material.dart' hide FormField;
import 'package:protoolbag_core/protoolbag_core.dart';

import '../features/contacts/contacts_list_screen.dart';

/// CRM "Günlük İşlerim" kaynağı — `fn_crm_my_work` satırlarını generic
/// [WorkInboxItem]'a eşler (bucket: overdue/today/stale gruplaması).
final WorkInboxSource crmMyWorkSource = WorkInboxSource(
  title: 'Günlük İşlerim',
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
/// Kişiler (`contacts` gerçek tablosu) + Günlük İşlerim (`fn_crm_my_work`).
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
  return null;
}

bool _done = false;

/// CRM domain ekranlarını çekirdek [ScreenResolver]'a kaydet (bir kez).
/// İlk shell render'ından ÖNCE `main()` içinde çağrılmalı.
void registerCrmScreens() {
  if (_done) return;
  ScreenResolver.addResolver(crmResolve);
  _done = true;
}
