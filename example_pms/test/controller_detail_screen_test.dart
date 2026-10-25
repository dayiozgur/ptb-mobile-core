import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:protoolbag_pms/features/controllers/screens/controller_detail_screen.dart';

import 'helpers/pms_fakes.dart';

void main() {
  late MockControllerService controllers;
  late MockVariableService variables;
  late MockAlarmService alarms;
  late MockIoTLogService logs;

  final controller = Controller(
    id: 'c1',
    name: 'Soğuk Oda PLC',
    tenantId: 't1',
    code: 'PLC-01',
    ipAddress: '10.0.0.5',
    status: ControllerStatus.online,
    deviceModelId: 'dm1',
    // 07:15 UTC → 10:15 İstanbul
    lastDataAt: DateTime.utc(2026, 1, 5, 7, 15),
    createdAt: DateTime.utc(2025, 1, 1),
  );

  setUp(() async {
    await sl.reset();
    AppClock.setZone('Europe/Istanbul');
    registerFake<LocalizationService>(fakeLocalization(const {
      'alarm.priority.critical': 'Kritik',
    }));
    final tenant = MockTenantService();
    when(() => tenant.currentTenantId).thenReturn('t1');
    registerFake<TenantService>(tenant);

    controllers = MockControllerService();
    when(() => controllers.setTenant(any())).thenReturn(null);
    when(() => controllers.getById('c1')).thenAnswer((_) async => controller);
    registerFake<ControllerService>(controllers);

    variables = MockVariableService();
    when(() => variables.setTenant(any())).thenReturn(null);
    when(() => variables.getByDeviceModel('dm1')).thenAnswer((_) async => [
          const Variable(id: 'v1', name: 'Oda Sıcaklığı', value: '-18.5'),
        ]);
    registerFake<VariableService>(variables);

    alarms = MockAlarmService();
    when(() => alarms.setTenant(any())).thenReturn(null);
    when(() => alarms.getActiveAlarms(controllerId: 'c1', includeVariable: true))
        .thenAnswer((_) async => [
              Alarm(
                id: 'a1',
                name: 'Yüksek sıcaklık',
                controllerId: 'c1',
                priorityId: 'c-vh',
                startTime: DateTime.utc(2026, 1, 5, 6, 0),
              ),
            ]);
    registerFake<AlarmService>(alarms);

    final priorities = MockPriorityService();
    when(() => priorities.getAll()).thenAnswer((_) async => fixturePriorities());
    registerFake<PriorityService>(priorities);

    logs = MockIoTLogService();
    when(() => logs.setTenant(any())).thenReturn(null);
    when(() => logs.getLogs(
          controllerId: 'c1',
          limit: 20,
          forceRefresh: true,
          includeVariable: true,
        )).thenAnswer((_) async => []);
    registerFake<IoTLogService>(logs);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(wrap(const ControllerDetailScreen(controllerId: 'c1')));
    await tester.pumpAndSettle();
  }

  testWidgets('bilgi + device-model değişkenleri + tenant saati', (tester) async {
    await pump(tester);
    expect(find.text('PLC-01'), findsOneWidget);
    expect(find.text('10.0.0.5'), findsOneWidget);
    expect(find.text('05.01.2026 10:15'), findsOneWidget);
    expect(find.text('Oda Sıcaklığı'), findsOneWidget);
    // Tüm değişkenler DEĞİL, controller modelinin seti istenir.
    verify(() => variables.getByDeviceModel('dm1')).called(1);
    verifyNever(() => variables.getAll(
        deviceModelId: any(named: 'deviceModelId'),
        forceRefresh: any(named: 'forceRefresh')));
  });

  testWidgets('aktif alarm: sunucu filtresi + öncelik etiketi/rengi', (tester) async {
    await pump(tester);
    expect(find.text('Yüksek sıcaklık'), findsOneWidget);
    final meta = find.textContaining('Kritik');
    expect(meta, findsOneWidget);
    expect(tester.widget<Text>(meta).style?.color, kCritical);
    verify(() => alarms.getActiveAlarms(controllerId: 'c1', includeVariable: true))
        .called(1);
  });

  testWidgets('alarm yükleme hatası "alarm yok" olarak GÖSTERİLMEZ', (tester) async {
    when(() => alarms.getActiveAlarms(controllerId: 'c1', includeVariable: true))
        .thenThrow(Exception('rls'));
    await pump(tester);
    expect(find.text('alarm.load_error'), findsOneWidget);
    expect(find.text('alarm.none_active_inline'), findsNothing);
  });

  testWidgets('controller bulunamadı → not-found görünümü', (tester) async {
    when(() => controllers.getById('c1')).thenAnswer((_) async => null);
    await pump(tester);
    expect(find.text('controller.not_found_message'), findsOneWidget);
  });
}
