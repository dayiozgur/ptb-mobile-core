import 'package:flutter/material.dart';

import '../../core/menu/menu_item.dart';
import '../shell/screen_resolver.dart';
import '../shell/workflow/approvals_inbox_screen.dart';
import 'fixflow_dashboard_screen.dart';
import 'fixflow_maintenance_list_screen.dart';
import 'fixflow_ticket_detail_screen.dart';
import 'fixflow_ticket_list_screen.dart';
import 'fixflow_work_request_screens.dart';

/// FixFlow domain ekran çözümleyicisi — `platform_menu_items`
/// (menu_source='db', FIXFLOW platformu) yollarını mobil ekranlara bağlar.
///
/// YALNIZ tam eşleşmeler: `/fixflow/entities/<tip>` gibi yollar çekirdek
/// entity-engine'de kalır; tanınmayan alt yollar (`/fixflow/reports`,
/// `/fixflow/service-customers` …) null döner → menüde budanır.
Widget? fixflowResolve(MenuItem item) {
  final path = item.path;
  if (path == null || path.isEmpty) return null;
  final p = path.split('?').first.toLowerCase().replaceAll(RegExp(r'/+$'), '');

  switch (p) {
    case '/fixflow':
    case '/fixflow/dashboard':
      return const FixflowDashboardScreen();
    case '/fixflow/tickets':
    case '/fixflow/my-tickets':
      return const FixflowTicketListScreen();
    case '/fixflow/work-requests':
      return const FixflowWorkRequestListScreen();
    case '/fixflow/work-requests/new':
      return const FixflowWorkRequestCreateScreen();
    case '/fixflow/maintenance':
      return const FixflowMaintenanceListScreen();
    case '/fixflow/sla':
      return const FixflowTicketListScreen(slaMode: true);
    case '/fixflow/approvals':
      // Alias → mevcut jenerik workflow onay gelen-kutusu.
      return const ApprovalsInboxScreen();
  }

  // Bildirim deep-link'i: /fixflow/tickets/<id|code> (EF action_url).
  const prefix = '/fixflow/tickets/';
  if (p.startsWith(prefix)) {
    final rest = path.split('?').first.substring(prefix.length);
    final id = rest.split('/').firstWhere((s) => s.isNotEmpty, orElse: () => '');
    if (id.isNotEmpty && id.toLowerCase() != 'new') {
      return FixflowTicketDetailScreen(ticketId: id);
    }
  }
  return null;
}

bool _registered = false;

/// FixFlow ekranlarını çekirdek [ScreenResolver]'a kaydet (bir kez, idempotent).
/// İlk shell render'ından ÖNCE `main()` içinde çağrılmalı. Yollar
/// `/fixflow/*` önekli olduğundan diğer domain resolver'larla çakışmaz.
void registerFixflowScreens() {
  if (_registered) return;
  ScreenResolver.addResolver(fixflowResolve);
  _registered = true;
}
