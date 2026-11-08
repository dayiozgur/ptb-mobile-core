import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../features/alarms/pem_alarms_screen.dart';
import '../features/anomalies/pem_anomalies_screen.dart';
import '../features/dashboard/pem_dashboard_screen.dart';
import '../features/load_profile/pem_load_profile_screen.dart';
import '../features/meters/pem_meters_screen.dart';
import '../features/sites/pem_sites_screen.dart';
import '../pem_common.dart';

/// Web Enerji Raporları sayfasının genel rapor motorundaki sistem şablonu
/// (`dr_report_templates.code`, is_system, PEM platformu) — web
/// `PEM_ENERGY_REPORT_CODE` ile aynı.
const String kPemEnergyReportCode = 'pem-energy-overview';

/// Menü yolunu normalize et: küçük harf, query'siz, sondaki `/` yok.
String _norm(String path) {
  var p = path.split('?').first.trim().toLowerCase();
  while (p.length > 1 && p.endsWith('/')) {
    p = p.substring(0, p.length - 1);
  }
  return p;
}

/// PEM domain ekran çözümleyicisi.
///
/// Canlı PEM DB-menüsünün (`platform_menu_items`, platform
/// `a7704e2f-a330-4bbc-bdda-96a8a4f31d8c`) telefonda anlamlı yollarını mobil
/// ekranlara bağlar. Nötr yollar (settings/admin/report/page/notifications…)
/// çekirdek [ScreenResolver]'da çözülür.
///
/// NOT: çekirdeğin `/admin*` nötr yedeği eşlenmemiş `/admin/...` yollarını
/// ComingSoon'a çözer; web'e özgü [kPemWebOnlyPaths] ise
/// [ScreenResolver.hideOnMobile] ile gizlenir (menüde görünmez). Buradaki
/// eşlemeler ÖNCE çalışır.
Widget? pemResolve(MenuItem item) {
  final raw = item.path;
  if (raw == null || raw.isEmpty) return null;
  final p = _norm(raw);

  switch (p) {
    case '/admin/energy':
    case '/admin/energy/dashboard':
      return PemDashboardScreen(
          title: pemT('energy.dashboard.title', 'Enerji Panosu'));
    case '/admin/energy/cockpit':
      return PemDashboardScreen(
          title: pemT('energy.cockpit.title', 'Enerji Kokpiti'));
    case '/admin/energy/benchmarking':
      return PemSitesScreen(
          title: pemT('energy.benchmark.title', 'Saha Kıyaslama'));
    case '/admin/energy/consumption':
      return PemSitesScreen(
          title: pemT('nav.energy_consumption', 'Tüketim'));
    case '/admin/energy/alarms':
      return const PemAlarmsScreen();
    case '/admin/energy/anomalies':
      return const PemAnomaliesScreen();
    case '/admin/energy/load-profile':
      return const PemLoadProfileScreen();
    case '/admin/energy/meters':
      return const PemMetersScreen();
    case '/admin/energy/reports':
      // Web "rapor motorunda aç" ile aynı sistem şablonu; çekirdek rapor
      // görüntüleyici (dr_report_templates + report-query EF) — salt-okunur.
      return const ReportViewerScreen(reportCode: kPemEnergyReportCode);
  }
  return null;
}

/// Mobilde bilinçli olarak ekranı OLMAYAN PEM yolları (web'e özgü yapılandırma
/// / veri girişi / büyük tablo ekranları). [registerPemScreens] bunları
/// [ScreenResolver.hideOnMobile] ile gizler → menüde "yakında" olarak
/// görünmezler.
const List<String> kPemWebOnlyPaths = [
  '/admin/energy/enpis',
  '/admin/energy/baselines',
  '/admin/energy/review',
  '/admin/energy/data-quality',
  '/admin/energy/seu',
  '/admin/energy/tariffs',
  '/admin/energy/bills',
  '/admin/energy/meter-tree',
  '/admin/energy/single-line',
  '/admin/energy/carbon',
  '/admin/energy/emission-factors',
  '/admin/energy/objectives',
  '/admin/energy/emission-targets',
  '/admin/energy/action-plans',
  '/admin/energy/mv',
  '/admin/energy/data-import',
  '/admin/energy/sustainability-export',
  '/admin/energy/mv-savings',
];

bool _done = false;

/// PEM domain ekranlarını çekirdek [ScreenResolver]'a kaydet (bir kez).
/// İlk shell render'ından ÖNCE `main()` içinde çağrılmalı.
void registerPemScreens() {
  if (_done) return;
  ScreenResolver.addResolver(pemResolve);
  ScreenResolver.hideOnMobile(kPemWebOnlyPaths);
  _done = true;
}
