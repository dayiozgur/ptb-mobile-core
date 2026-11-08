import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_pem/features/alarms/pem_alarms_screen.dart';
import 'package:protoolbag_pem/features/alarms/pem_alarms_service.dart';
import 'package:protoolbag_pem/features/anomalies/pem_anomalies_screen.dart';
import 'package:protoolbag_pem/features/dashboard/pem_dashboard_screen.dart';
import 'package:protoolbag_pem/features/dashboard/pem_dashboard_service.dart';
import 'package:protoolbag_pem/features/load_profile/pem_load_profile_screen.dart';
import 'package:protoolbag_pem/features/meters/pem_meters_screen.dart';
import 'package:protoolbag_pem/features/meters/pem_meters_service.dart';
import 'package:protoolbag_pem/features/shared/pem_analytics_service.dart';
import 'package:protoolbag_pem/features/shared/pem_models.dart';
import 'package:protoolbag_pem/features/sites/pem_site_detail_screen.dart';
import 'package:protoolbag_pem/features/sites/pem_sites_screen.dart';
import 'package:protoolbag_pem/features/sites/pem_sites_service.dart';

import 'helpers/fake_pem.dart';

Widget _app(Widget child) => MaterialApp(home: child);

/// Canlı DB biçiminde etiket alt kümesi (keywords tr-TR).
const _tr = {
  'energy.cockpit.kpi_total_kwh': 'Toplam Tüketim',
  'energy.cockpit.trend_title': 'Tüketim Eğilimi',
  'energy.cockpit.top_consumers_title': 'En Çok Tüketenler',
  'energy.freshness.waiting_title': 'Canlı bağlantı bekleniyor',
  'energy.utility.electricity': 'Elektrik',
  'energy.utility.water': 'Su',
  'energy.alarm.fired_empty': 'Tetiklenen enerji alarmı yok',
  'status.active': 'Aktif',
  'common.all': 'Tümü',
};

Map<String, dynamic> _rollup(String day, String u, num kwh) => {
      'bucket_start': '${day}T00:00:00+00:00',
      'utility_type': u,
      'total_kwh': '$kwh',
      'total_cost': '1',
      'avg_peak_kw': '5',
      'reading_count': 24,
    };

void main() {
  setUp(() => registerFakeLocalization(_tr));

  group('PemDashboardScreen', () {
    testWidgets('KPI + trend + tesisat + en çok tüketenler', (tester) async {
      final be = FakePemBackend(
        rollup: [
          _rollup('2026-11-01', 'electricity', 100),
          _rollup('2026-11-02', 'water', 50),
        ],
        dimension: {
          'site': [
            {'label': 'Ankara Depo', 'total_kwh': '150', 'total_cost': '2', 'pct': '100'},
          ],
        },
        alarmCount: 2,
        latest: '2026-11-02T00:00:00Z',
      );
      await tester.pumpWidget(_app(PemDashboardScreen(
          service: PemDashboardService(backend: be, clock: fixedNow))));
      await tester.pumpAndSettle();

      expect(find.text('Toplam Tüketim'), findsOneWidget);
      expect(find.text('150 kWh'), findsWidgets);
      expect(find.text('Tüketim Eğilimi'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Ankara Depo'), 200);
      expect(find.text('Elektrik'), findsOneWidget);
      expect(find.text('Ankara Depo'), findsOneWidget);
    });

    testWidgets('hiç veri yok → canlı bağlantı bekleniyor', (tester) async {
      final be = FakePemBackend();
      await tester.pumpWidget(_app(PemDashboardScreen(
          service: PemDashboardService(backend: be, clock: fixedNow))));
      await tester.pumpAndSettle();
      expect(find.text('Canlı bağlantı bekleniyor'), findsOneWidget);
      expect(find.text('Tüketim Eğilimi'), findsNothing);
    });

    testWidgets('dönem değişimi aylık kova ile yeniden yükler', (tester) async {
      final be = FakePemBackend();
      await tester.pumpWidget(_app(PemDashboardScreen(
          service: PemDashboardService(backend: be, clock: fixedNow))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yıl başından'));
      await tester.pumpAndSettle();
      expect(be.last('fn_energy_consumption_rollup')!.params['p_bucket'],
          'month');
    });

    testWidgets('hata → yeniden dene', (tester) async {
      final be = FakePemBackend(
          errors: {'fn_energy_consumption_rollup': Exception('x')});
      await tester.pumpWidget(_app(PemDashboardScreen(
          service: PemDashboardService(backend: be, clock: fixedNow))));
      await tester.pumpAndSettle();
      expect(find.text('Yeniden dene'), findsOneWidget);
      final before = be.calls.length;
      await tester.tap(find.text('Yeniden dene'));
      await tester.pumpAndSettle();
      expect(be.calls.length, greaterThan(before));
    });
  });

  group('PemSitesScreen', () {
    final sites = [
      {'id': 's1', 'name': 'Ankara Depo', 'code': 'ANK', 'city': 'Ankara'},
      {'id': 's2', 'name': 'İzmir Mağaza', 'code': 'IZM', 'city': 'İzmir'},
    ];

    testWidgets('liste + arama + dokun → detay kancası', (tester) async {
      final be = FakePemBackend(siteRows: sites, benchmark: [
        {'site_id': 's1', 'consumption_kwh': '1000', 'rank': 1, 'validity': 'weak'},
      ]);
      PemSite? opened;
      await tester.pumpWidget(_app(PemSitesScreen(
        service: PemSitesService(backend: be, clock: fixedNow),
        onOpenSite: (_, s) => opened = s,
      )));
      await tester.pumpAndSettle();
      expect(find.text('Ankara Depo'), findsOneWidget);
      expect(find.text('#1'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'izm');
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Ankara Depo'), findsNothing);
      await tester.tap(find.text('İzmir Mağaza'));
      expect(opened?.id, 's2');
    });

    testWidgets('saha yok → boş durum', (tester) async {
      await tester.pumpWidget(_app(PemSitesScreen(
          service: PemSitesService(backend: FakePemBackend()))));
      await tester.pumpAndSettle();
      expect(find.text('Henüz tesis yok'), findsOneWidget);
    });
  });

  group('PemSiteDetailScreen', () {
    testWidgets('günlük grafik + profil + sayaçlar', (tester) async {
      final be = FakePemBackend(daily: [
        {'bucket_start': '2026-11-01T00:00:00Z', 'consumption_kwh': '40', 'cost': '4', 'peak_demand_kw': '9'},
        {'bucket_start': '2026-11-02T00:00:00Z', 'consumption_kwh': '60', 'cost': '6', 'peak_demand_kw': '11'},
      ], meterRows: [
        {'id': 'm1', 'site_id': 's1', 'utility_type': 'electricity', 'meter_role': 'main', 'unit': 'kWh', 'controller_id': 'c1'},
      ], profile: [
        {'dow': 1, 'avg_consumption_kwh': '50', 'max_peak_demand_kw': '11', 'total_consumption_kwh': '100', 'day_count': 2},
      ]);
      await tester.pumpWidget(_app(PemSiteDetailScreen(
        site: const PemSite(id: 's1', name: 'Ankara Depo', rank: 2),
        service: PemSitesService(backend: be, clock: fixedNow),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Ankara Depo'), findsOneWidget);
      expect(find.text('100 kWh'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Elektrik'), 200);
      expect(find.text('Pazartesi'), findsOneWidget);
      expect(find.text('Telemetri'), findsOneWidget);
    });

    testWidgets('veri yok → satır içi boş durumlar', (tester) async {
      await tester.pumpWidget(_app(PemSiteDetailScreen(
        site: const PemSite(id: 's1', name: 'Boş Saha'),
        service: PemSitesService(backend: FakePemBackend(), clock: fixedNow),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Bu dönem için tüketim verisi yok.'), findsWidgets);
    });
  });

  group('PemAlarmsScreen', () {
    testWidgets('aktif süzgeç varsayılan; Tümü kapalıları da gösterir',
        (tester) async {
      final be = FakePemBackend(alarmRows: [
        {'id': 'a1', 'name': 'Tüketim aşımı', 'code': 'ENERGY_CONSUMPTION_1', 'status': 'active', 'start_time': '2026-11-05T08:00:00Z'},
        {'id': 'a2', 'name': 'Eski anomali', 'code': 'ENERGY_ANOM_1', 'status': 'closed'},
      ]);
      await tester.pumpWidget(
          _app(PemAlarmsScreen(service: PemAlarmsService(backend: be))));
      await tester.pumpAndSettle();
      expect(find.text('Tüketim aşımı'), findsOneWidget);
      expect(find.text('Eski anomali'), findsNothing);
      await tester.tap(find.text('Tümü (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Eski anomali'), findsOneWidget);
    });

    testWidgets('alarm yok → boş durum', (tester) async {
      await tester.pumpWidget(_app(
          PemAlarmsScreen(service: PemAlarmsService(backend: FakePemBackend()))));
      await tester.pumpAndSettle();
      expect(find.text('Tetiklenen enerji alarmı yok'), findsOneWidget);
    });
  });

  group('PemAnomaliesScreen', () {
    testWidgets('tek saha otomatik seçilir, KPI + günler', (tester) async {
      final be = FakePemBackend(siteRows: [
        {'id': 's1', 'name': 'Ankara Depo'},
      ], anomalyRows: [
        {'period_day': '2026-11-01T00:00:00Z', 'actual_kwh': '120', 'predicted_kwh': '80', 'deviation_pct': '50', 'is_anomaly': true},
        {'period_day': '2026-11-02T00:00:00Z', 'actual_kwh': '81', 'predicted_kwh': '80', 'deviation_pct': '1.25', 'is_anomaly': false},
      ]);
      await tester.pumpWidget(_app(PemAnomaliesScreen(
          service: PemAnalyticsService(backend: be, clock: fixedNow))));
      await tester.pumpAndSettle();
      expect(be.last('fn_energy_consumption_anomalies')!.params['p_site_id'],
          's1');
      expect(find.text('İşaretli günler'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('01.11.2026'), 200);
      expect(find.text('Anomali'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('02.11.2026'), findsNothing);
    });

    testWidgets('veri yok → açıklayıcı boş durum', (tester) async {
      final be = FakePemBackend(siteRows: [
        {'id': 's1', 'name': 'Ankara Depo'},
      ]);
      await tester.pumpWidget(_app(PemAnomaliesScreen(
          service: PemAnalyticsService(backend: be, clock: fixedNow))));
      await tester.pumpAndSettle();
      expect(find.text('Bu pencere için incelenecek günlük veri yok.'),
          findsOneWidget);
    });
  });

  group('PemMetersScreen + PemLoadProfileScreen', () {
    testWidgets('sayaçlar saha başlığı altında', (tester) async {
      final be = FakePemBackend(siteRows: [
        {'id': 's1', 'name': 'Ankara Depo'},
      ], meterRows: [
        {'id': 'm1', 'site_id': 's1', 'utility_type': 'water', 'source': 'manual'},
      ]);
      await tester.pumpWidget(
          _app(PemMetersScreen(service: PemMetersService(backend: be))));
      await tester.pumpAndSettle();
      expect(find.text('Ankara Depo (1)'), findsOneWidget);
      expect(find.text('Su'), findsOneWidget);
      expect(find.text('Manuel'), findsOneWidget);
    });

    testWidgets('yük profili portföy varsayılan, veri yok → boş', (tester) async {
      final be = FakePemBackend();
      await tester.pumpWidget(_app(PemLoadProfileScreen(
          service: PemAnalyticsService(backend: be, clock: fixedNow))));
      await tester.pumpAndSettle();
      expect(be.last('fn_energy_load_profile')!.params['p_site_id'], isNull);
      expect(find.text('Bu dönem için tüketim verisi yok.'), findsOneWidget);
    });
  });
}
