import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_pem/features/alarms/pem_alarms_service.dart';
import 'package:protoolbag_pem/features/dashboard/pem_dashboard_service.dart';
import 'package:protoolbag_pem/features/meters/pem_meters_service.dart';
import 'package:protoolbag_pem/features/shared/pem_analytics_service.dart';
import 'package:protoolbag_pem/features/shared/pem_models.dart';
import 'package:protoolbag_pem/features/sites/pem_sites_service.dart';

import 'helpers/fake_pem.dart';

/// Canlı `fn_energy_consumption_rollup` biçiminde satır (numeric → String).
Map<String, dynamic> rollupRow(String day, String utility, num kwh,
        {num cost = 0, num? peak}) =>
    {
      'bucket_start': '${day}T00:00:00+00:00',
      'utility_type': utility,
      'total_kwh': '$kwh',
      'total_cost': '$cost',
      'avg_peak_kw': peak?.toString(),
      'reading_count': 24,
    };

void main() {
  setUp(() => registerFakeLocalization());

  group('PemWindow', () {
    test('son 30 gün: bugün dahil, UTC gün sınırları', () {
      final w = PemWindow.lastDays(fixedNow(), 30);
      expect(w.fromIso, '2026-10-10T00:00:00.000Z');
      expect(w.toIso, '2026-11-08T23:59:59.999Z');
    });

    test('yıl başından', () {
      final w = PemWindow.yearToDate(fixedNow());
      expect(w.fromIso, '2026-01-01T00:00:00.000Z');
      expect(w.toIso, '2026-11-08T23:59:59.999Z');
    });
  });

  group('PemDashboardService', () {
    test('RPC parametreleri web ile aynı + KPI/pivot/utility', () async {
      final be = FakePemBackend(
        rollup: [
          rollupRow('2026-11-02', 'electricity', 100, cost: 10, peak: 12.5),
          rollupRow('2026-11-02', 'water', 20, cost: 2),
          rollupRow('2026-11-01', 'electricity', 80, cost: 8, peak: 20),
        ],
        dimension: {
          'site': [
            {'label': 'B Sahası', 'total_kwh': '40', 'total_cost': '4', 'pct': '20'},
            {'label': 'A Sahası', 'total_kwh': '160', 'total_cost': '16', 'pct': '80'},
          ],
        },
        alarmCount: 3,
        latest: '2026-11-05T11:00:00+00:00',
      );
      final svc = PemDashboardService(backend: be, clock: fixedNow);
      final d = await svc.load(PemPeriod.last30Days);

      final rpc = be.last('fn_energy_consumption_rollup')!;
      expect(rpc.params['p_bucket'], 'day');
      expect(rpc.params['p_organization_id'], 'org-1');
      expect(rpc.params['p_from'], '2026-10-10T00:00:00.000Z');
      expect(be.last('fn_pms_energy_by_dimension')!.params['p_dim'], 'site');
      expect(be.last('alarms.count')!.params,
          {'tenant_id': 'tenant-1', 'organization_id': 'org-1'});

      expect(d.kpis.totalKwh, 200);
      expect(d.kpis.totalCost, 20);
      expect(d.kpis.peakDemandKw, 20);
      expect(d.kpis.activeAlarms, 3);
      expect(d.series.map((p) => p.value).toList(), [80, 120]);
      expect(d.series.first.period, DateTime.utc(2026, 11, 1));
      expect(d.byUtility.first.label, 'electricity');
      expect(d.byUtility.first.pct, closeTo(90, 0.001));
      expect(d.topSites.first.label, 'A Sahası');
      expect(d.latestReadingAt, '2026-11-05T11:00:00+00:00');
      expect(d.isEmpty, isFalse);
    });

    test('YTD → aylık kova', () async {
      final be = FakePemBackend();
      await PemDashboardService(backend: be, clock: fixedNow)
          .load(PemPeriod.yearToDate);
      expect(be.last('fn_energy_consumption_rollup')!.params['p_bucket'],
          'month');
      expect(be.last('fn_energy_consumption_rollup')!.params['p_from'],
          '2026-01-01T00:00:00.000Z');
    });

    test('veri yok → boş; alarm/tazelik hatası 0/null’a düşer', () async {
      final be = FakePemBackend(errors: {
        'alarms.count': Exception('boom'),
        'energy_readings_rollup.latest': Exception('boom'),
      });
      final d = await PemDashboardService(backend: be, clock: fixedNow)
          .load(PemPeriod.last30Days);
      expect(d.isEmpty, isTrue);
      expect(d.kpis.activeAlarms, 0);
      expect(d.latestReadingAt, isNull);
    });

    test('trend hatası yukarı fırlatılır', () async {
      final be = FakePemBackend(
          errors: {'fn_energy_consumption_rollup': Exception('rls')});
      expect(
          PemDashboardService(backend: be, clock: fixedNow)
              .load(PemPeriod.last30Days),
          throwsA(isA<Exception>()));
    });
  });

  group('PemSitesService', () {
    final sites = [
      {'id': 's1', 'name': 'Ankara Depo', 'code': 'ANK', 'city': 'Ankara'},
      {'id': 's2', 'name': 'İzmir Mağaza', 'code': 'IZM', 'city': 'İzmir'},
    ];

    test('benchmark saha id ile birleşir (son 12 ay, hdd)', () async {
      final be = FakePemBackend(siteRows: sites, benchmark: [
        {
          'site_id': 's2',
          'site_code': 'IZM',
          'site_name': 'İzmir Mağaza',
          'consumption_kwh': '1234.5',
          'intensity_kwh_per_dd': '3.2',
          'rank': 1,
          'validity': 'weak',
        },
      ]);
      final list =
          await PemSitesService(backend: be, clock: fixedNow).listSites();
      expect(list.map((s) => s.id), ['s1', 's2']);
      expect(list[0].rank, isNull);
      expect(list[1].rank, 1);
      expect(list[1].consumptionKwh, 1234.5);
      expect(list[1].validity, 'weak');
      final b = be.last('fn_energy_site_benchmark')!;
      expect(b.params['p_driver'], 'hdd');
      expect(b.params['p_from'], '2025-11-09T00:00:00.000Z');
      expect(be.last('sites')!.params['tenant_id'], 'tenant-1');
    });

    test('benchmark hatası listeyi engellemez', () async {
      final be = FakePemBackend(
          siteRows: sites,
          errors: {'fn_energy_site_benchmark': Exception('x')});
      final list =
          await PemSitesService(backend: be, clock: fixedNow).listSites();
      expect(list.length, 2);
    });

    test('sites hatası yukarı fırlatılır', () {
      final be = FakePemBackend(errors: {'sites': Exception('x')});
      expect(PemSitesService(backend: be).listSites(), throwsException);
    });

    test('arama ad/kod/şehir', () {
      final all = [
        const PemSite(id: '1', name: 'Ankara Depo', code: 'ANK', city: 'Ankara'),
        const PemSite(id: '2', name: 'Mağaza', code: 'IZM', city: 'İzmir'),
      ];
      expect(PemSitesService.filter(all, 'izm').single.id, '2');
      expect(PemSitesService.filter(all, 'depo').single.id, '1');
      expect(PemSitesService.filter(all, '  ').length, 2);
    });

    test('günlük rollup gün başına toplanır', () {
      final days = PemSitesService.aggregateDaily([
        {
          'bucket_start': '2026-11-02T00:00:00+00:00',
          'consumption_kwh': '10',
          'cost': '1',
          'peak_demand_kw': '4'
        },
        {
          'bucket_start': '2026-11-02T00:00:00+00:00',
          'consumption_kwh': 5,
          'cost': null,
          'peak_demand_kw': '7'
        },
        {
          'bucket_start': '2026-11-01T00:00:00+00:00',
          'consumption_kwh': '3',
          'cost': '0.5',
          'peak_demand_kw': null
        },
      ]);
      expect(days.map((d) => d.day),
          [DateTime.utc(2026, 11, 1), DateTime.utc(2026, 11, 2)]);
      expect(days[1].kwh, 15);
      expect(days[1].cost, 1);
      expect(days[1].peakKw, 7);
      expect(days[0].peakKw, isNull);
    });

    test('saha detayı: sayaç/profil hatası boşa düşer, pencere 30/90 gün',
        () async {
      final be = FakePemBackend(daily: [
        {'bucket_start': '2026-11-03T00:00:00Z', 'consumption_kwh': 12},
      ], errors: {
        'energy_meters': Exception('x'),
        'fn_energy_load_profile': Exception('y'),
      });
      final d =
          await PemSitesService(backend: be, clock: fixedNow).siteDetail('s1');
      expect(d.totalKwh, 12);
      expect(d.meters, isEmpty);
      expect(d.loadProfile, isEmpty);
      final q = be.last('energy_readings_rollup.daily')!;
      expect(q.params['site_id'], 's1');
      expect(q.params['from'], '2026-10-10T00:00:00.000Z');
      expect(be.last('fn_energy_load_profile')!.params['p_from'],
          '2026-08-11T00:00:00.000Z');
    });
  });

  group('PemAlarmsService', () {
    test('öncelik eşlenir, etiket alarm.priority.<code>', () async {
      registerFakeLocalization({'alarm.priority.high': 'Yüksek'});
      final be = FakePemBackend(priorityRows: [
        {'id': 'p1', 'name': 'HIGH', 'code': 'high', 'color': '#dc3545', 'level': 2},
      ], alarmRows: [
        {
          'id': 'a1',
          'name': 'Tüketim aşımı',
          'code': 'ENERGY_CONSUMPTION_x',
          'status': 'active',
          'start_time': '2026-11-05T08:00:00+00:00',
          'priority_id': 'p1',
          'category': 1,
        },
        {'id': 'a2', 'code': 'ENERGY_ANOM_y', 'status': 'closed'},
      ]);
      final list = await PemAlarmsService(backend: be).list();
      expect(be.last('alarms')!.params, {'tenant_id': 'tenant-1', 'limit': 100});
      expect(list.first.priority!.label, 'Yüksek');
      expect(list.first.isOpen, isTrue);
      expect(list[1].title, 'ENERGY_ANOM_y');
      expect(list[1].isOpen, isFalse);
      expect(PemAlarmsService.apply(list, PemAlarmFilter.open).length, 1);
      expect(PemAlarmsService.apply(list, PemAlarmFilter.all).length, 2);
    });

    test('öncelik sözlüğü okunamazsa alarmlar yine gelir', () async {
      final be = FakePemBackend(
          alarmRows: [
            {'id': 'a1', 'code': 'ENERGY_X', 'status': 'active', 'priority_id': 'p1'}
          ],
          errors: {'priorities': Exception('x')});
      final list = await PemAlarmsService(backend: be).list();
      expect(list.single.priority, isNull);
    });

    test('durum etiketi status.<code>, yoksa okunur', () {
      registerFakeLocalization({'status.active': 'Aktif'});
      expect(const PemAlarm(id: '1', status: 'active').statusLabel, 'Aktif');
      expect(const PemAlarm(id: '1', status: 'acknowledged').statusLabel,
          'Acknowledged');
    });
  });

  group('PemAnalyticsService', () {
    test('anomali: web varsayılan pencereleri/sürücü/σ, KPI', () async {
      final be = FakePemBackend(anomalyRows: [
        {
          'period_day': '2026-11-01T00:00:00+00:00',
          'actual_kwh': '120',
          'predicted_kwh': '80',
          'deviation_pct': '50',
          'z_score': '3.1',
          'is_anomaly': true
        },
        {
          'period_day': '2026-11-02T00:00:00+00:00',
          'actual_kwh': '82',
          'predicted_kwh': '80',
          'deviation_pct': '-2.5',
          'z_score': '0.2',
          'is_anomaly': false
        },
      ]);
      final r = await PemAnalyticsService(backend: be, clock: fixedNow)
          .anomalies('s1');
      final c = be.last('fn_energy_consumption_anomalies')!;
      expect(c.params['p_site_id'], 's1');
      expect(c.params['p_driver'], 'peak_demand_kw');
      expect(c.params['p_sigma'], 2);
      expect(c.params['p_baseline_from'], '2026-07-11T00:00:00.000Z');
      expect(c.params['p_baseline_to'], '2026-10-09T23:59:59.000Z');
      expect(c.params['p_detect_from'], '2026-10-09T00:00:00.000Z');
      expect(c.params['p_detect_to'], '2026-11-08T23:59:59.000Z');
      expect(r.analysedDays, 2);
      expect(r.flaggedDays, 1);
      expect(r.maxAbsDeviationPct, 50);
      expect(r.days.first.day, DateTime.utc(2026, 11, 2)); // en yeni önce
    });

    test('yük profili: portföy (site null), dow sıralı', () async {
      final be = FakePemBackend(profile: [
        {'dow': 3, 'avg_consumption_kwh': '10', 'max_peak_demand_kw': '2', 'total_consumption_kwh': '30', 'day_count': 3},
        {'dow': 0, 'avg_consumption_kwh': '5', 'max_peak_demand_kw': '1', 'total_consumption_kwh': '15', 'day_count': 3},
      ]);
      final p = await PemAnalyticsService(backend: be, clock: fixedNow)
          .loadProfile(null);
      expect(be.last('fn_energy_load_profile')!.params['p_site_id'], isNull);
      expect(p.map((x) => x.dow), [0, 3]);
    });
  });

  group('PemMetersService', () {
    test('sahaya göre grupla, ana sayaç önce, saha adı sıralı', () async {
      final be = FakePemBackend(siteRows: [
        {'id': 's1', 'name': 'Zeytinburnu'},
        {'id': 's2', 'name': 'Ankara'},
      ], meterRows: [
        {'id': 'm1', 'site_id': 's1', 'utility_type': 'water', 'is_site_main': false},
        {'id': 'm2', 'site_id': 's1', 'utility_type': 'electricity', 'is_site_main': true, 'controller_id': 'c1'},
        {'id': 'm3', 'site_id': 's2', 'utility_type': 'electricity', 'source': 'manual'},
      ]);
      final g = await PemMetersService(backend: be).grouped();
      expect(g.map((x) => x.siteName), ['Ankara', 'Zeytinburnu']);
      expect(g[1].meters.first.id, 'm2');
      expect(g[1].meters.first.isTelemetry, isTrue);
      expect(g[0].meters.single.isTelemetry, isFalse);
    });
  });
}
