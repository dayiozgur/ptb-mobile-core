import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:protoolbag_pms/features/alarms/alarm_actions_helper.dart';

import 'helpers/pms_fakes.dart';

void main() {
  late MockAlarmService alarms;
  late int refreshes;

  final alarm = Alarm(
    id: 'a1',
    name: 'Kompresör yüksek basınç',
    code: 'HP1',
    priorityId: 'p-crit',
    startTime: DateTime.utc(2026, 1, 5, 9, 0),
  );

  setUp(() async {
    await sl.reset();
    AppClock.setZone('Europe/Istanbul');
    registerFake<LocalizationService>(fakeLocalization(const {
      'alarm.reset_action': 'Sıfırla',
      'alarm.acknowledge': 'Onayla',
      'common.cancel': 'Vazgeç',
      'common.confirm': 'Evet',
      'alarm.confirm_reset_message': 'Emin misiniz?',
      'alarm.reset_success': 'Alarm sıfırlandı',
      'alarm.ack_success': 'Alarm onaylandı',
      'alarm.action_failed': 'İşlem tamamlanamadı',
    }));
    alarms = MockAlarmService();
    when(() => alarms.resetAlarm(any())).thenAnswer((_) async => true);
    when(() => alarms.acknowledgeAlarm(any())).thenAnswer((_) async => true);
    registerFake<AlarmService>(alarms);
    refreshes = 0;
  });

  Future<void> openSheet(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAlarmActions(
              context,
              alarm: alarm,
              priority: PriorityCatalog(fixturePriorities()).resolve('p-crit'),
              onRefresh: () async => refreshes++,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('reset: onay diyaloğu — Vazgeç → RPC ÇAĞRILMAZ', (tester) async {
    await openSheet(tester);
    await tester.tap(find.text('Sıfırla'));
    // Buton aksiyon sürerken spinner gösterir (diyalog açıkken) → settle olmaz.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Emin misiniz?'), findsOneWidget);

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    verifyNever(() => alarms.resetAlarm(any()));
    expect(refreshes, 0);
  });

  testWidgets('reset: onaylanınca RPC + SnackBar + yenileme', (tester) async {
    await openSheet(tester);
    await tester.tap(find.text('Sıfırla'));
    // Buton aksiyon sürerken spinner gösterir (diyalog açıkken) → settle olmaz.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Evet'));
    await tester.pumpAndSettle();

    verify(() => alarms.resetAlarm('a1')).called(1);
    expect(find.text('Alarm sıfırlandı'), findsOneWidget);
    expect(refreshes, 1);
  });

  testWidgets('reset: sunucu reddi (false) → başarısız mesajı', (tester) async {
    when(() => alarms.resetAlarm(any())).thenAnswer((_) async => false);
    await openSheet(tester);
    await tester.tap(find.text('Sıfırla'));
    // Buton aksiyon sürerken spinner gösterir (diyalog açıkken) → settle olmaz.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Evet'));
    await tester.pumpAndSettle();
    expect(find.text('İşlem tamamlanamadı'), findsOneWidget);
  });

  testWidgets('acknowledge: yıkıcı değil → diyalog yok, doğrudan RPC', (tester) async {
    await openSheet(tester);
    await tester.tap(find.text('Onayla'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    verify(() => alarms.acknowledgeAlarm('a1')).called(1);
    expect(find.text('Alarm onaylandı'), findsOneWidget);
  });

  testWidgets('detay: öncelik etiketi + tenant saatli başlangıç', (tester) async {
    await openSheet(tester);
    // 09:00 UTC → 12:00 İstanbul
    expect(find.text('05.01.2026 12:00:00'), findsOneWidget);
    expect(find.text('Kritik'), findsOneWidget); // çevrilmemiş anahtar → satır adı
  });
}
