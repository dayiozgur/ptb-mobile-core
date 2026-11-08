import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:protoolbag_fixflow/config/fixflow_app_screens.dart';

/// Canlı FIXFLOW DB-menü yolları (`platform_menu_items`, menu_source='db',
/// active=true; 2026-11-08 SELECT) → mobil ekran. `registerFixflowAppScreens()`
/// main()'de ilk shell render'ından ÖNCE çağrılır; burada aynı kayıt yapılır ve
/// shell'in budama kuralı ([ScreenResolver.hasScreen]) doğrulanır.
void main() {
  MenuItem item(String path) => MenuItem(itemKey: '', title: '', path: path);

  setUpAll(registerFixflowAppScreens);

  test('platform kimliği FIXFLOW', () {
    expect(kFixflowPlatformId, 'b1f1f10f-0000-4000-8000-000000000001');
    expect(kFixflowPlatformCode, 'FIXFLOW');
    expect(kFixflowAppLinkHost, 'app.fixflow.protoolbag.com');
  });

  test('çekirdek FixFlow menü yolları ekrana çözülür (menüde görünür)', () {
    expect(ScreenResolver.resolve(item('/fixflow')),
        isA<FixflowDashboardScreen>());
    expect(ScreenResolver.resolve(item('/fixflow/tickets')),
        isA<FixflowTicketListScreen>());
    expect(ScreenResolver.resolve(item('/fixflow/work-requests')),
        isA<FixflowWorkRequestListScreen>());
    expect(ScreenResolver.resolve(item('/fixflow/maintenance')),
        isA<FixflowMaintenanceListScreen>());
    expect(ScreenResolver.resolve(item('/fixflow/approvals')),
        isA<ApprovalsInboxScreen>());

    final sla = ScreenResolver.resolve(item('/fixflow/sla'));
    expect(sla, isA<FixflowTicketListScreen>());
    expect((sla as FixflowTicketListScreen).slaMode, isTrue);

    for (final p in const [
      '/fixflow',
      '/fixflow/tickets',
      '/fixflow/work-requests',
      '/fixflow/maintenance',
      '/fixflow/sla',
      '/fixflow/approvals',
    ]) {
      expect(ScreenResolver.hasScreen(p), isTrue, reason: p);
    }
  });

  test('bildirim deep-link: /fixflow/tickets/<id> → iş emri detayı', () {
    const id = '7d3c1b52-2f4e-4c55-9a51-0d6c9a1f2e10';
    final w = ScreenResolver.resolve(item('/fixflow/tickets/$id'));
    expect(w, isA<FixflowTicketDetailScreen>());
    expect((w as FixflowTicketDetailScreen).ticketId, id);

    // query / sondaki "/" toleransı
    final q = ScreenResolver.resolve(item('/fixflow/tickets/$id/?tab=photos'));
    expect((q as FixflowTicketDetailScreen).ticketId, id);

    // "new" detay değildir
    expect(ScreenResolver.hasScreen('/fixflow/tickets/new'), isFalse);
  });

  test('kayıt idempotent', () {
    registerFixflowAppScreens();
    registerFixflowAppScreens();
    expect(ScreenResolver.resolve(item('/fixflow/tickets')),
        isA<FixflowTicketListScreen>());
  });

  test('mobil karşılığı olmayan canlı menü yolları budanır (bilinen boşluk)',
      () {
    // Bu yollar canlı FIXFLOW menüsünde aktif ama mobilde ekranı yok →
    // drawer'da gizli. ("/my-space" shell'de ayrı sekme olarak zaten var.)
    const hidden = [
      '/my-space',
      '/globalmap',
      '/files',
      '/files?source=onedrive',
      '/status',
      '/fixflow/service-network',
      '/fixflow/service-customers',
      '/fixflow/reports',
      '/mail-system',
      '/mail-system/dashboard',
      '/management',
      '/management/tenant',
      '/system/logs',
      '/system/bug-reports',
    ];
    for (final p in hidden) {
      expect(ScreenResolver.hasScreen(p), isFalse, reason: p);
    }
  });
}
