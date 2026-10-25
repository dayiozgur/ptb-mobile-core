import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:protoolbag_pms/features/alarms/screens/active_alarms_screen.dart';

import 'helpers/pms_fakes.dart';

void main() {
  late MockAlarmService alarms;
  late MockPriorityService priorities;

  final fixture = <Alarm>[
    // Carel vendor satırı → platform "critical" olarak görünmeli.
    Alarm(
      id: 'a1',
      name: 'Kompresör yüksek basınç',
      code: 'HP1',
      priorityId: 'c-vh',
      startTime: DateTime.utc(2026, 1, 5, 9, 0),
    ),
    Alarm(
      id: 'a2',
      name: 'Kapı açık',
      code: 'DOOR',
      priorityId: 'p-high',
      startTime: DateTime.utc(2026, 1, 5, 10, 0),
    ),
  ];

  setUp(() async {
    await sl.reset();
    AppClock.setZone('Europe/Istanbul');
    registerFake<LocalizationService>(fakeLocalization(const {
      'alarm.priority.critical': 'Kritik',
      'alarm.priority.high': 'Yüksek',
    }));
    final tenant = MockTenantService();
    when(() => tenant.currentTenantId).thenReturn('t1');
    registerFake<TenantService>(tenant);
    final rt = MockRealtimeService();
    when(() => rt.subscribe<Map<String, dynamic>>(
          table: any(named: 'table'),
          fromJson: any(named: 'fromJson'),
          onChange: any(named: 'onChange'),
        )).thenThrow(StateError('no realtime in tests'));
    registerFake<RealtimeService>(rt);

    alarms = MockAlarmService();
    when(() => alarms.setTenant(any())).thenReturn(null);
    when(() => alarms.getActiveAlarms(includeVariable: true))
        .thenAnswer((_) async => fixture);
    registerFake<AlarmService>(alarms);

    priorities = MockPriorityService();
    when(() => priorities.getAll(forceRefresh: true))
        .thenAnswer((_) async => fixturePriorities());
    registerFake<PriorityService>(priorities);
  });

  testWidgets('aktif alarmlar: priorities tablosundan etiket + renk (vendor → platform)',
      (tester) async {
    await tester.pumpWidget(wrap(const ActiveAlarmsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Kompresör yüksek basınç'), findsOneWidget);
    expect(find.text('Kapı açık'), findsOneWidget);
    // Etiketler alarm.priority.<code> anahtarından (Carel "Very High" DEĞİL).
    expect(find.text('Kritik'), findsOneWidget);
    expect(find.text('Yüksek'), findsOneWidget);
    expect(find.text('Very High'), findsNothing);

    // Renk = priorities.color (platform satırının).
    final critLabel = tester.widget<Text>(find.text('Kritik'));
    expect(critLabel.style?.color, kCritical);
    final highLabel = tester.widget<Text>(find.text('Yüksek'));
    expect(highLabel.style?.color, kHigh);

    // En yeni başlangıç üstte (sıralama start_time desc).
    final yDoor = tester.getTopLeft(find.text('Kapı açık')).dy;
    final yHp = tester.getTopLeft(find.text('Kompresör yüksek basınç')).dy;
    expect(yDoor, lessThan(yHp));
  });

  testWidgets('arama: eşleşme yoksa boş-sonuç durumu', (tester) async {
    await tester.pumpWidget(wrap(const ActiveAlarmsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Kapı açık'), findsNothing);
    expect(find.text('alarm.no_search_match'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'door');
    await tester.pumpAndSettle();
    expect(find.text('Kapı açık'), findsOneWidget);
    expect(find.text('Kompresör yüksek basınç'), findsNothing);
  });

  testWidgets('yükleme hatası: hata görünümü + tekrar dene', (tester) async {
    when(() => alarms.getActiveAlarms(includeVariable: true))
        .thenThrow(Exception('network'));
    await tester.pumpWidget(wrap(const ActiveAlarmsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('alarm.load_error'), findsOneWidget);
    expect(find.text('Kapı açık'), findsNothing);
  });
}
