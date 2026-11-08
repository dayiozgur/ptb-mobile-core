import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// WP-A: platform-context `license` ayrıştırma + EntitlementService kararı/yenileme.
Map<String, dynamic> _ctx(Map<String, dynamic>? license) => {
      'platform': {'id': 'p1', 'code': 'PMS', 'name': 'PMS', 'isActive': true},
      'license': license,
      'features': <String, dynamic>{},
      'tenantId': 't1',
      'resolvedAt': '2026-11-08T10:00:00.000Z',
    };

Map<String, dynamic> _license({
  String? accessState,
  bool isActive = true,
  String status = 'active',
  String? graceUntil,
  String planCode = 'pms_professional',
}) =>
    {
      if (accessState != null) 'accessState': accessState,
      if (graceUntil != null) 'graceUntil': graceUntil,
      'isActive': isActive,
      'isTrial': false,
      'status': status,
      'subscribedAt': '2026-01-01T00:00:00Z',
      'trialStartsAt': null,
      'trialEndsAt': null,
      'expiresAt': '2026-10-31T00:00:00Z',
      'autoUpgrade': false,
      'customLimits': null,
      'lockedVersionId': null,
      'plan': {
        'plan_code': planCode,
        'plan_name': 'PMS Professional',
        'price_monthly': 99
      },
    };

void main() {
  group('PlatformLicense / EntitlementSnapshot parsing', () {
    test('tam lisans alanları ayrıştırılır', () {
      final snap = EntitlementSnapshot.fromContext(
        'PMS',
        _ctx(_license(
            accessState: 'read_only',
            isActive: false,
            status: 'expired',
            graceUntil: '2026-11-20T00:00:00Z')),
      );
      final lic = snap.license!;
      expect(snap.loaded, isTrue);
      expect(lic.accessStateRaw, 'read_only');
      expect(lic.serverAccessState, LicenseAccessState.readOnly);
      expect(lic.graceUntil, DateTime.utc(2026, 11, 20));
      expect(lic.status, 'expired');
      expect(lic.isActive, isFalse);
      expect(lic.planCode, 'pms_professional');
      expect(lic.planName, 'PMS Professional');
      expect(lic.priceMonthly, 99);
      expect(lic.plan, SubscriptionPlan.professional);
      expect(lic.expiresAt, DateTime.utc(2026, 10, 31));
    });

    test('yüklenmemiş bağlam → full (fail-open)', () {
      expect(EntitlementSnapshot.unknown.accessState, LicenseAccessState.full);
    });

    test('yüklendi ama license null → locked (platform satın alınmamış)', () {
      expect(EntitlementSnapshot.fromContext('PMS', _ctx(null)).accessState,
          LicenseAccessState.locked);
    });

    test('aktif + active/trial → full (accessState yok olsa da)', () {
      expect(
          EntitlementSnapshot.fromContext('PMS', _ctx(_license())).accessState,
          LicenseAccessState.full);
      expect(
          EntitlementSnapshot.fromContext(
                  'PMS', _ctx(_license(status: 'trial')))
              .accessState,
          LicenseAccessState.full);
    });

    test('bitmiş + read_only → readOnly; bitmiş + locked/yok → locked', () {
      expect(
          EntitlementSnapshot.fromContext(
                  'PMS',
                  _ctx(_license(
                      isActive: false,
                      status: 'expired',
                      accessState: 'read_only')))
              .accessState,
          LicenseAccessState.readOnly);
      expect(
          EntitlementSnapshot.fromContext(
                  'PMS',
                  _ctx(_license(
                      isActive: false,
                      status: 'expired',
                      accessState: 'locked')))
              .accessState,
          LicenseAccessState.locked);
      expect(
          EntitlementSnapshot.fromContext(
                  'PMS', _ctx(_license(isActive: false, status: 'suspended')))
              .accessState,
          LicenseAccessState.locked);
    });

    test('SubscriptionPlan.fromPlanCode platform ön ekini atar', () {
      expect(SubscriptionPlan.fromPlanCode('pms_free'), SubscriptionPlan.free);
      expect(
          SubscriptionPlan.fromPlanCode('crm_starter'), SubscriptionPlan.basic);
      expect(SubscriptionPlan.fromPlanCode('fixflow_enterprise'),
          SubscriptionPlan.enterprise);
      expect(SubscriptionPlan.fromPlanCode('professional'),
          SubscriptionPlan.professional);
      expect(SubscriptionPlan.fromPlanCode('weird'), isNull);
      expect(SubscriptionPlan.fromPlanCode(null), isNull);
    });
  });

  group('EntitlementService', () {
    late PlatformContext platform;
    late List<String> calls;
    late FutureOr<Map<String, dynamic>?> Function(String code) respond;
    late EntitlementService service;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      platform = PlatformContext(initialPlatformCode: 'PMS');
      calls = [];
      respond = (_) => _ctx(_license());
      service = EntitlementService(
        platformContext: platform,
        fetcher: (code) async {
          calls.add(code);
          return respond(code);
        },
        errorRefreshInterval: Duration.zero,
      );
    });

    tearDown(() => service.dispose());

    test('start → platform-context aktif platform koduyla çağrılır', () async {
      final state = await service.start();
      expect(calls, ['PMS']);
      expect(state, LicenseAccessState.full);
      expect(service.license?.planCode, 'pms_professional');
    });

    test('read_only durum yayınlanır', () async {
      respond = (_) => _ctx(_license(
          isActive: false, status: 'expired', accessState: 'read_only'));
      final seen = <LicenseAccessState>[];
      service.accessStateListenable
          .addListener(() => seen.add(service.accessState));
      await service.start();
      expect(service.accessState, LicenseAccessState.readOnly);
      expect(service.canWrite, isFalse);
      expect(seen, [LicenseAccessState.readOnly]);
    });

    test('önbellek: zorlamasız refresh TTL içinde ağa gitmez', () async {
      await service.start();
      await service.refresh();
      expect(calls.length, 1);
      await service.refresh(force: true);
      expect(calls.length, 2);
    });

    test('ağ hatası önceki durumu korur', () async {
      respond = (_) => _ctx(_license(
          isActive: false, status: 'expired', accessState: 'read_only'));
      await service.start();
      respond = (_) => throw Exception('offline');
      await service.refresh(force: true);
      expect(service.accessState, LicenseAccessState.readOnly);
    });

    test('EF 404 (bilinmeyen platform) → fail-open full', () async {
      respond = (_) => throw const FunctionException(status: 404);
      await service.start();
      expect(service.accessState, LicenseAccessState.full);
      expect(service.snapshot.loaded, isFalse);
    });

    test('platform değişimi yeni kodla yeniler', () async {
      await service.start();
      platform.setActivePlatform('crm-id', code: 'CRM');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(calls, ['PMS', 'CRM']);
    });

    test(
        'yazma reddi (25006) görülünce bant hemen çıkar ve yenileme tetiklenir; '
        'sunucu full dese de gözlenen red korunur', () async {
      await service.start();
      expect(service.accessState, LicenseAccessState.full);

      final reported = service.reportError(const PostgrestException(
          message: 'cannot execute UPDATE in a read-only transaction',
          code: '25006'));
      expect(reported, isTrue);
      expect(service.accessState, LicenseAccessState.readOnly);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(calls.length, 2, reason: 'hata kaynaklı yenileme');
      expect(service.accessState, LicenseAccessState.readOnly);

      // Sıradan (resume/manuel) yenileme gözlenen reddi düşürür.
      await service.refresh(force: true);
      expect(service.accessState, LicenseAccessState.full);
    });

    test('Logger.error ile loglanan PTB402 da yakalanır', () async {
      await service.start();
      Logger.error(
          'write failed',
          const PostgrestException(
              message: 'entitlement_locked', code: 'PTB402'));
      expect(service.accessState, LicenseAccessState.locked);
    });

    test('lisans ilgisiz hata durumu değiştirmez', () async {
      await service.start();
      expect(service.reportError(Exception('boom')), isFalse);
      expect(service.accessState, LicenseAccessState.full);
    });
  });
}
