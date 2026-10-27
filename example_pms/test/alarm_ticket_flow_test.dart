import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:protoolbag_pms/features/alarms/alarm_actions_helper.dart';

import 'helpers/pms_fakes.dart';

/// Alarm detay → "FixFlow iş emri oluştur" → form → fn_pms_alarm_create_ticket.
void main() {
  late MockAlarmService alarms;

  final alarm = Alarm(
    id: 'a1',
    name: 'Kompresör yüksek basınç',
    code: 'HP1',
    priorityId: 'p-crit',
    variableName: 'Komp-1',
    startTime: DateTime.utc(2026, 1, 5, 9, 0),
  );

  setUp(() async {
    await sl.reset();
    AppClock.setZone('Europe/Istanbul');
    registerFake<LocalizationService>(fakeLocalization(const {
      'pms.alarm.fixflow.create': 'FixFlow iş emri oluştur',
      'pms.alarm.fixflow.ticket_created': 'FixFlow iş emri oluşturuldu',
      'pms.alarm.fixflow.already_linked':
          'Bu alarm için açık bir iş emri zaten var: {{code}}',
      'pms.alarm.fixflow.not_entitled_title': 'FixFlow üyeliği gerekli',
      'pms.alarm.fixflow.create_error': 'FixFlow iş emri oluşturulamadı',
      'pms.alarm_ticket.route.internal':
          '{{target}} FixFlow\'unda {{team}} ekibine atanacak',
      'common.create': 'Oluştur',
      'common.cancel': 'Vazgeç',
      'common.priority': 'Öncelik',
    }));
    alarms = MockAlarmService();
    when(() => alarms.getLinkedTickets(any())).thenAnswer((_) async => []);
    when(() => alarms.getTicketRoutePreview(any()))
        .thenAnswer((_) async => const AlarmTicketRoutePreview(
              mode: AlarmTicketRouteMode.internal,
              contractorName: 'ATALIAN',
              priorityCode: 'critical',
              targetName: 'Müşteri A',
              teamName: 'Soğutma',
            ));
    when(() => alarms.createFixflowTicket(any(),
            subject: any(named: 'subject'),
            description: any(named: 'description'),
            priorityId: any(named: 'priorityId')))
        .thenAnswer(
            (_) async => const AlarmCreatedTicket(id: 't1', code: 'TCK-0042'));
    registerFake<AlarmService>(alarms);
    final priorities = MockPriorityService();
    when(() => priorities.getAll(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => fixturePriorities());
    when(() => priorities.getAll())
        .thenAnswer((_) async => fixturePriorities());
    registerFake<PriorityService>(priorities);
  });

  Future<void> openTicketForm(WidgetTester tester) async {
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
              onRefresh: () async {},
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('alarm-action-create-ticket')));
    await tester.pumpAndSettle();
  }

  testWidgets('form: konu/açıklama/öncelik/yönlendirme önceden dolu',
      (tester) async {
    await openTicketForm(tester);

    final subject = tester.widget<TextFormField>(
        find.byKey(const ValueKey('alarm-ticket-subject')));
    expect(subject.controller!.text, 'Kompresör yüksek basınç');
    final desc = tester.widget<TextFormField>(
        find.byKey(const ValueKey('alarm-ticket-description')));
    expect(desc.controller!.text, contains('common.code: HP1'));
    expect(desc.controller!.text, contains('pms.alarm.fixflow.device: Komp-1'));
    expect(desc.controller!.text, contains('05.01.2026 12:00:00'));
    expect(desc.controller!.text, contains('Öncelik: Kritik'));
    // Öncelik seçici: varsayılan = alarmın (yönlendirmenin) önceliği.
    final picker = tester.widget<DropdownButton<String>>(
        find.byKey(const ValueKey('alarm-ticket-priority-picker')));
    expect(picker.value, 'p-crit');
    // Yalnız platform öncelikleri (carel vendor satırı yok).
    expect(picker.items!.map((i) => i.value), ['p-crit', 'p-high']);
    expect(
        find.text('ATALIAN — Müşteri A FixFlow\'unda Soğutma ekibine atanacak'),
        findsOneWidget);
  });

  testWidgets('oluştur: RPC + sheet\'ler kapanır + iş emri no SnackBar',
      (tester) async {
    await openTicketForm(tester);
    await tester.enterText(
        find.byKey(const ValueKey('alarm-ticket-subject')), 'HP alarmı');
    await tester.tap(find.byKey(const ValueKey('alarm-ticket-submit')));
    await tester.pumpAndSettle();

    final captured = verify(() => alarms.createFixflowTicket(captureAny(),
        subject: captureAny(named: 'subject'),
        description: any(named: 'description'),
        priorityId: captureAny(named: 'priorityId'))).captured;
    // Öncelik değişmedi → p_priority_id gönderilmez (null).
    expect(captured, ['a1', 'HP alarmı', null]);
    expect(find.text('FixFlow iş emri oluşturuldu: TCK-0042'), findsOneWidget);
    expect(find.byType(AlarmTicketSheet), findsNothing);
    expect(find.byType(ActiveAlarmDetailSheet), findsNothing);
  });

  testWidgets('açık bağlı iş emri varsa yeni iş emri açılmaz', (tester) async {
    when(() => alarms.getLinkedTickets(any())).thenAnswer((_) async => const [
          AlarmLinkedTicket(ticketId: 't9', code: 'TCK-0009', subject: 'HP'),
        ]);
    await openTicketForm(tester);

    expect(find.text('Bu alarm için açık bir iş emri zaten var: TCK-0009'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('alarm-ticket-subject')), findsNothing);
    final btn = tester.widget<ButtonStyleButton>(
        find.byKey(const ValueKey('alarm-ticket-submit')));
    expect(btn.onPressed, isNull);
  });

  testWidgets('kapanmış bağlı iş emri yenisini engellemez', (tester) async {
    when(() => alarms.getLinkedTickets(any())).thenAnswer((_) async => const [
          AlarmLinkedTicket(
              ticketId: 't8', code: 'TCK-0008', statusFinal: true),
        ]);
    await openTicketForm(tester);
    expect(find.byKey(const ValueKey('alarm-ticket-already-linked')),
        findsNothing);
    await tester.tap(find.byKey(const ValueKey('alarm-ticket-submit')));
    await tester.pumpAndSettle();
    verify(() => alarms.createFixflowTicket('a1',
        subject: any(named: 'subject'),
        description: any(named: 'description'),
        priorityId: any(named: 'priorityId'))).called(1);
  });

  testWidgets('FixFlow üyeliği yok → bilgilendirme, sheet açık kalır',
      (tester) async {
    when(() => alarms.createFixflowTicket(any(),
            subject: any(named: 'subject'),
            description: any(named: 'description'),
            priorityId: any(named: 'priorityId')))
        .thenThrow(Exception('fixflow_not_entitled'));
    await openTicketForm(tester);
    await tester.tap(find.byKey(const ValueKey('alarm-ticket-submit')));
    await tester.pumpAndSettle();

    expect(find.text('FixFlow üyeliği gerekli'), findsOneWidget);
    expect(find.byType(AlarmTicketSheet), findsOneWidget);
  });

  testWidgets('sunucu hatası → hata metni, tekrar denenebilir', (tester) async {
    when(() => alarms.createFixflowTicket(any(),
        subject: any(named: 'subject'),
        description: any(named: 'description'),
        priorityId: any(named: 'priorityId'))).thenThrow(Exception('boom'));
    await openTicketForm(tester);
    await tester.tap(find.byKey(const ValueKey('alarm-ticket-submit')));
    await tester.pumpAndSettle();
    expect(find.text('FixFlow iş emri oluşturulamadı'), findsOneWidget);
    expect(find.byKey(const ValueKey('alarm-ticket-subject')), findsOneWidget);
  });

  testWidgets('öncelik değişince priorityId gönderilir + açıklama güncellenir',
      (tester) async {
    await openTicketForm(tester);
    await tester
        .tap(find.byKey(const ValueKey('alarm-ticket-priority-picker')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('alarm-ticket-priority-p-high')).last);
    await tester.pumpAndSettle();

    final desc = tester.widget<TextFormField>(
        find.byKey(const ValueKey('alarm-ticket-description')));
    expect(desc.controller!.text, contains('Öncelik: Yüksek'));

    await tester.tap(find.byKey(const ValueKey('alarm-ticket-submit')));
    await tester.pumpAndSettle();
    final captured = verify(() => alarms.createFixflowTicket('a1',
        subject: any(named: 'subject'),
        description: any(named: 'description'),
        priorityId: captureAny(named: 'priorityId'))).captured;
    expect(captured, ['p-high']);
  });

  testWidgets('invalid priority → dostça uyarı, sheet açık kalır',
      (tester) async {
    when(() => alarms.createFixflowTicket(any(),
            subject: any(named: 'subject'),
            description: any(named: 'description'),
            priorityId: any(named: 'priorityId')))
        .thenThrow(Exception('invalid priority'));
    await openTicketForm(tester);
    await tester.tap(find.byKey(const ValueKey('alarm-ticket-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('alarm-ticket-invalid-priority')),
        findsOneWidget);
    expect(find.text('FixFlow iş emri oluşturulamadı'), findsNothing);
    expect(find.byType(AlarmTicketSheet), findsOneWidget);
  });
}
