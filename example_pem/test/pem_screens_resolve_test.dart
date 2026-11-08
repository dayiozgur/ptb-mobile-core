import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:protoolbag_pem/config/pem_screens.dart';
import 'package:protoolbag_pem/features/alarms/pem_alarms_screen.dart';
import 'package:protoolbag_pem/features/anomalies/pem_anomalies_screen.dart';
import 'package:protoolbag_pem/features/dashboard/pem_dashboard_screen.dart';
import 'package:protoolbag_pem/features/load_profile/pem_load_profile_screen.dart';
import 'package:protoolbag_pem/features/meters/pem_meters_screen.dart';
import 'package:protoolbag_pem/features/sites/pem_sites_screen.dart';

import 'helpers/fake_pem.dart';

/// Canlı PEM DB-menü yolları (platform_menu_items, PEM platformu) → mobil
/// ekran. Web'e özgü yollar bu çözümleyicide null ve kayıtla mobilde gizlenir.
void main() {
  setUp(() => registerFakeLocalization());

  MenuItem item(String path) => MenuItem(itemKey: '', title: '', path: path);

  test('PEM menü yolları ekrana çözülür', () {
    expect(pemResolve(item('/admin/energy/dashboard')),
        isA<PemDashboardScreen>());
    expect(pemResolve(item('/admin/energy/cockpit')),
        isA<PemDashboardScreen>());
    expect(pemResolve(item('/admin/energy/benchmarking')),
        isA<PemSitesScreen>());
    expect(pemResolve(item('/admin/energy/consumption')),
        isA<PemSitesScreen>());
    expect(pemResolve(item('/admin/energy/alarms')), isA<PemAlarmsScreen>());
    expect(pemResolve(item('/admin/energy/anomalies')),
        isA<PemAnomaliesScreen>());
    expect(pemResolve(item('/admin/energy/load-profile')),
        isA<PemLoadProfileScreen>());
    expect(pemResolve(item('/admin/energy/meters')), isA<PemMetersScreen>());
  });

  test('raporlar → çekirdek ReportViewerScreen (pem-energy-overview)', () {
    final w = pemResolve(item('/admin/energy/reports'));
    expect(w, isA<ReportViewerScreen>());
    expect((w as ReportViewerScreen).reportCode, 'pem-energy-overview');
  });

  test('yol normalizasyonu (büyük harf / query / sondaki slash)', () {
    expect(pemResolve(item('/Admin/Energy/Alarms/')), isA<PemAlarmsScreen>());
    expect(pemResolve(item('/admin/energy/dashboard?from=push')),
        isA<PemDashboardScreen>());
    expect(pemResolve(item('/admin/energy')), isA<PemDashboardScreen>());
  });

  test('web-özel yollar ve yabancı yollar çözümsüz', () {
    for (final p in kPemWebOnlyPaths) {
      expect(pemResolve(item(p)), isNull, reason: p);
    }
    expect(pemResolve(item('/crm/contacts')), isNull);
    expect(pemResolve(item('')), isNull);
    expect(pemResolve(const MenuItem(itemKey: 'g', title: 'g')), isNull);
  });

  test('kayıt sonrası çekirdek ScreenResolver PEM ekranını döndürür', () {
    ScreenResolver.reset();
    registerPemScreens();
    expect(ScreenResolver.hasScreen('/admin/energy/alarms'), isTrue);
    expect(ScreenResolver.resolve(item('/admin/energy/meters')),
        isA<PemMetersScreen>());
    // Web'e özgü yollar mobil menüde GİZLİ (çekirdek /admin yedeğine düşmez).
    for (final p in kPemWebOnlyPaths) {
      expect(ScreenResolver.isHiddenOnMobile(p), isTrue, reason: p);
      expect(ScreenResolver.hasScreen(p), isFalse, reason: p);
    }
    // Eşlenmemiş diğer /admin yolları yine nötr yedeğe düşer.
    expect(ScreenResolver.hasScreen('/admin/users'), isTrue);
  });
}
