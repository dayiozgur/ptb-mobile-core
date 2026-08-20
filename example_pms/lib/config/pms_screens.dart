import 'package:flutter/material.dart' hide FormField;
import 'package:protoolbag_core/protoolbag_core.dart';

import '../features/dashboard/screens/monitoring_dashboard_screen.dart';
import '../features/alarms/screens/global_alarms_screen.dart';
import '../features/alarms/screens/alarm_dashboard_screen.dart';
import '../features/site/screens/sites_list_screen.dart';
import '../features/map/screens/site_map_screen.dart';
import '../features/providers/screens/providers_screen.dart';
import '../features/controllers/screens/controllers_screen.dart';
import '../features/variables/screens/variables_screen.dart';
import '../features/logs/screens/log_viewer_screen.dart';
import '../features/kpi/screens/kpi_screen.dart';

/// PMS domain ekran çözümleyicisi — menü yolunu PMS ekranına çevirir.
///
/// Nötr yollar (settings/organization/entity) çekirdek [ScreenResolver]'da
/// çözülür; burada YALNIZ PMS/IoT-özel yollar. Yolu bilmiyorsa null → çekirdek
/// nötr/ComingSoon'a düşürür. Semantik eski monolitik resolver ile birebir.
Widget? pmsResolve(MenuItem item) {
  final path = item.path;
  if (path == null || path.isEmpty) return null;
  final p = path.toLowerCase();

  // Dashboard
  if (p == '/dashboard' || p == '/main' || p == '/monitoring') {
    return const MonitoringDashboardScreen();
  }
  // Global map / map
  if (p.startsWith('/globalmap') || p.startsWith('/map')) {
    return const SiteMapScreen();
  }
  // Sites
  if (p.startsWith('/sites') || p == '/site') {
    return const SitesListScreen();
  }
  // Supervisor → providers
  if (p.startsWith('/supervisor') || p.startsWith('/providers')) {
    return const ProvidersScreen();
  }
  // Alarm ML (alarm'dan ÖNCE — placeholder istiyoruz)
  if (p.startsWith('/alarm-ml')) {
    return null; // ComingSoon
  }
  // Alarms
  if (p.startsWith('/alarm')) {
    return p.startsWith('/alarms')
        ? const AlarmDashboardScreen()
        : const GlobalAlarmsScreen();
  }
  // Logs
  if (p.startsWith('/system/logs') || p.startsWith('/logs')) {
    return const LogViewerScreen();
  }
  // KPI
  if (p.startsWith('/kpi')) return const KpiScreen();
  // Controllers / variables
  if (p.startsWith('/controllers')) return const ControllersScreen();
  if (p.startsWith('/variables')) return const VariablesScreen();

  return null; // PMS-dışı yol → çekirdek çözer
}

bool _registered = false;

/// PMS domain ekranlarını çekirdek [ScreenResolver]'a kaydet (bir kez).
/// İlk shell render'ından ÖNCE `main()` içinde çağrılmalı.
void registerPmsScreens() {
  if (_registered) return;
  ScreenResolver.addResolver(pmsResolve);
  _registered = true;
}
