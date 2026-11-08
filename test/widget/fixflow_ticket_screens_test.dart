import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class _MockStatus extends Mock implements FixflowStatusService {}

class _MockTickets extends Mock implements FixflowTicketService {}

/// Widget tests for the FixFlow technician ticket list + detail screens.
/// Services are swapped through [FixflowServices.override]; the locator is
/// empty so `ffT` falls back to the English literals.
void main() {
  late _MockStatus status;
  late _MockTickets tickets;

  final catalog = FixflowStatusCatalog(const [
    FixflowStatus(code: 'open', name: 'Açık', colorHex: '#3B82F6', isInitial: true, sortOrder: 0),
    FixflowStatus(code: 'assigned', name: 'Atandı', colorHex: '#8B5CF6', sortOrder: 1),
    FixflowStatus(code: 'in_progress', name: 'Devam Ediyor', sortOrder: 2),
    FixflowStatus(code: 'resolved', name: 'Çözüldü', isFinal: true, sortOrder: 3),
    FixflowStatus(code: 'cancelled', name: 'İptal Edildi', isFinal: true, sortOrder: 6),
  ]);

  FixflowTicket ticket({String status = 'assigned', DateTime? due}) =>
      FixflowTicket(
        id: 'tk1',
        code: 'TKT-0007',
        subject: 'Chiller arızası',
        description: 'Basınç yüksek',
        status: status,
        priorityCode: 'high',
        priorityName: 'Yüksek',
        priorityColor: '#FD7E14',
        locationName: 'Kazan dairesi',
        assignedToName: 'Teknisyen Bir',
        dueDate: due,
      );

  setUpAll(() {
    registerFallbackValue(FixflowTicketScope.mine);
    registerFallbackValue(Uint8List(0));
  });

  setUp(() async {
    await sl.reset();
    status = _MockStatus();
    tickets = _MockTickets();
    FixflowServices.override(status: status, tickets: tickets);
    when(() => status.catalog(any())).thenAnswer((_) async => catalog);
  });

  tearDown(() async {
    FixflowServices.reset();
    await sl.reset();
  });

  group('FixflowTicketListScreen', () {
    testWidgets('varsayılan: bana atanan + açık durumlar; ad/renk katalogdan',
        (tester) async {
      when(() => tickets.listTickets(
            scope: any(named: 'scope'),
            statuses: any(named: 'statuses'),
            orderByDue: any(named: 'orderByDue'),
          )).thenAnswer((_) async => [
            ticket(due: DateTime.utc(2026, 11, 1)),
          ]);

      await tester.pumpWidget(MaterialApp(
        home: FixflowTicketListScreen(clock: () => DateTime.utc(2026, 11, 8)),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Chiller arızası'), findsOneWidget);
      expect(find.text('TKT-0007'), findsOneWidget);
      // Durum ADI (ham kod değil) — chip satırında da "Atandı" filtresi var.
      expect(find.text('Atandı'), findsWidgets);
      expect(find.text('assigned'), findsNothing);
      expect(find.text('Overdue · 01.11.2026'), findsOneWidget);

      verify(() => tickets.listTickets(
            scope: FixflowTicketScope.mine,
            statuses: ['open', 'assigned', 'in_progress'],
            orderByDue: false,
          )).called(1);
    });

    testWidgets('kapsam "My team" ve durum çipi yeniden yükler', (tester) async {
      when(() => tickets.listTickets(
            scope: any(named: 'scope'),
            statuses: any(named: 'statuses'),
            orderByDue: any(named: 'orderByDue'),
          )).thenAnswer((_) async => <FixflowTicket>[]);

      await tester.pumpWidget(const MaterialApp(home: FixflowTicketListScreen()));
      await tester.pumpAndSettle();
      expect(find.text('No tickets'), findsOneWidget);

      await tester.tap(find.text('My team'));
      await tester.pumpAndSettle();
      verify(() => tickets.listTickets(
            scope: FixflowTicketScope.team,
            statuses: ['open', 'assigned', 'in_progress'],
            orderByDue: false,
          )).called(1);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Çözüldü'));
      await tester.pumpAndSettle();
      verify(() => tickets.listTickets(
            scope: FixflowTicketScope.team,
            statuses: ['resolved'],
            orderByDue: false,
          )).called(1);
    });

    testWidgets('hata → yeniden dene', (tester) async {
      when(() => tickets.listTickets(
            scope: any(named: 'scope'),
            statuses: any(named: 'statuses'),
            orderByDue: any(named: 'orderByDue'),
          )).thenThrow(Exception('offline'));
      await tester.pumpWidget(const MaterialApp(home: FixflowTicketListScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Could not load'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('SLA modu: tüm açık biletler due_date sıralı', (tester) async {
      when(() => tickets.listTickets(
            scope: any(named: 'scope'),
            statuses: any(named: 'statuses'),
            orderByDue: any(named: 'orderByDue'),
          )).thenAnswer((_) async => <FixflowTicket>[]);
      await tester.pumpWidget(
          const MaterialApp(home: FixflowTicketListScreen(slaMode: true)));
      await tester.pumpAndSettle();
      expect(find.text('SLA tracking'), findsOneWidget);
      verify(() => tickets.listTickets(
            scope: FixflowTicketScope.all,
            statuses: ['open', 'assigned', 'in_progress'],
            orderByDue: true,
          )).called(1);
    });
  });

  group('FixflowTicketDetailScreen', () {
    void stubDetail({
      required FixflowTicket t,
      List<FixflowTransition> transitions = const [],
    }) {
      when(() => tickets.getTicket('tk1')).thenAnswer((_) async => t);
      when(() => status.availableTransitions('ticket', t.status))
          .thenAnswer((_) async => transitions);
      when(() => tickets.listWorklogs('tk1')).thenAnswer((_) async => const [
            FixflowWorklog(id: 'w1', minutes: 90, description: 'Kontrol'),
          ]);
      when(() => tickets.listAttachments('tk1'))
          .thenAnswer((_) async => const <FixflowAttachment>[]);
    }

    const toInProgress = FixflowTransition(
      id: 'tr1',
      toStatus: FixflowStatus(code: 'in_progress', name: 'Devam Ediyor', sortOrder: 2),
    );
    const toResolved = FixflowTransition(
      id: 'tr2',
      toStatus: FixflowStatus(code: 'resolved', name: 'Çözüldü', isFinal: true, sortOrder: 3),
      requiresComment: true,
    );

    testWidgets('detay alanları, efor toplamı ve aksiyonlar', (tester) async {
      stubDetail(t: ticket(), transitions: const [toInProgress, toResolved]);
      await tester.pumpWidget(const MaterialApp(
          home: FixflowTicketDetailScreen(ticketId: 'tk1')));
      await tester.pumpAndSettle();

      expect(find.text('TKT-0007'), findsOneWidget);
      expect(find.text('Chiller arızası'), findsOneWidget);
      expect(find.text('Atandı'), findsOneWidget);
      expect(find.text('Teknisyen Bir'), findsOneWidget);
      expect(find.text('Kazan dairesi'), findsOneWidget);
      expect(find.text('Total: 1 h 30 min'), findsOneWidget);
      expect(find.byKey(const Key('fixflow_change_status')), findsOneWidget);
      expect(find.byKey(const Key('fixflow_close_ticket')), findsOneWidget);
    });

    testWidgets('durum değiştir → yalnız status-transition EF üzerinden',
        (tester) async {
      stubDetail(t: ticket(), transitions: const [toInProgress, toResolved]);
      when(() => status.executeTransition(
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
            toStatus: any(named: 'toStatus'),
            comment: any(named: 'comment'),
          )).thenAnswer((_) async {});

      await tester.pumpWidget(const MaterialApp(
          home: FixflowTicketDetailScreen(ticketId: 'tk1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('fixflow_change_status')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Devam Ediyor'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('fixflow_transition_comment')), 'Başladım');
      await tester.tap(find.byKey(const Key('fixflow_transition_confirm')));
      await tester.pumpAndSettle();

      verify(() => status.executeTransition(
            entityType: 'ticket',
            entityId: 'tk1',
            toStatus: 'in_progress',
            comment: 'Başladım',
          )).called(1);
      verify(() => tickets.getTicket('tk1')).called(2); // yeniden yüklendi
    });

    testWidgets('kapat: yorum zorunlu geçişte boş yorum engellenir',
        (tester) async {
      stubDetail(t: ticket(status: 'in_progress'), transitions: const [toResolved]);
      when(() => status.executeTransition(
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
            toStatus: any(named: 'toStatus'),
            comment: any(named: 'comment'),
          )).thenAnswer((_) async {});

      await tester.pumpWidget(const MaterialApp(
          home: FixflowTicketDetailScreen(ticketId: 'tk1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('fixflow_close_ticket')));
      await tester.pumpAndSettle();
      expect(find.text('Change status to "Çözüldü"?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('fixflow_transition_confirm')));
      await tester.pumpAndSettle();
      expect(find.text('This change requires a comment.'), findsOneWidget);
      verifyNever(() => status.executeTransition(
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
            toStatus: any(named: 'toStatus'),
            comment: any(named: 'comment'),
          ));

      await tester.enterText(
          find.byKey(const Key('fixflow_transition_comment')), 'Valf değişti');
      await tester.tap(find.byKey(const Key('fixflow_transition_confirm')));
      await tester.pumpAndSettle();
      verify(() => status.executeTransition(
            entityType: 'ticket',
            entityId: 'tk1',
            toStatus: 'resolved',
            comment: 'Valf değişti',
          )).called(1);
    });

    testWidgets('EF reddi kullanıcıya gösterilir', (tester) async {
      stubDetail(t: ticket(), transitions: const [toInProgress]);
      when(() => status.executeTransition(
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
            toStatus: any(named: 'toStatus'),
            comment: any(named: 'comment'),
          )).thenThrow(const FixflowTransitionException('ERR_FORBIDDEN', 'no'));

      await tester.pumpWidget(const MaterialApp(
          home: FixflowTicketDetailScreen(ticketId: 'tk1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fixflow_change_status')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Devam Ediyor'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fixflow_transition_confirm')));
      await tester.pumpAndSettle();
      expect(find.text('You are not allowed to make this change.'),
          findsOneWidget);
    });

    testWidgets('final durumda aksiyon yok', (tester) async {
      stubDetail(t: ticket(status: 'resolved'));
      await tester.pumpWidget(const MaterialApp(
          home: FixflowTicketDetailScreen(ticketId: 'tk1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fixflow_change_status')), findsNothing);
      expect(find.byKey(const Key('fixflow_close_ticket')), findsNothing);
      expect(find.text('No status change is available to you.'), findsNothing);
    });

    testWidgets('efor kaydı ekle', (tester) async {
      stubDetail(t: ticket());
      when(() => tickets.addWorklog(
            entityId: any(named: 'entityId'),
            minutes: any(named: 'minutes'),
            description: any(named: 'description'),
          )).thenAnswer((_) async =>
          const FixflowWorklog(id: 'w2', minutes: 30));

      await tester.pumpWidget(const MaterialApp(
          home: FixflowTicketDetailScreen(ticketId: 'tk1')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('fixflow_log_work')));
      await tester.tap(find.byKey(const Key('fixflow_log_work')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('fixflow_worklog_minutes')), '30');
      await tester.enterText(
          find.byKey(const Key('fixflow_worklog_desc')), 'Filtre temizliği');
      await tester.tap(find.byKey(const Key('fixflow_worklog_save')));
      await tester.pumpAndSettle();

      verify(() => tickets.addWorklog(
            entityId: 'tk1',
            minutes: 30,
            description: 'Filtre temizliği',
          )).called(1);
    });

    testWidgets('fotoğraf ekle (enjekte seçici) → uploadAttachment',
        (tester) async {
      stubDetail(t: ticket());
      when(() => tickets.uploadAttachment(
            entityId: any(named: 'entityId'),
            bytes: any(named: 'bytes'),
            fileName: any(named: 'fileName'),
            mimeType: any(named: 'mimeType'),
          )).thenAnswer((_) async => const FixflowAttachment(
          id: 'a1', fileName: 'p.jpg', filePath: 'x', mimeType: 'image/jpeg'));

      await tester.pumpWidget(MaterialApp(
        home: FixflowTicketDetailScreen(
          ticketId: 'tk1',
          photoPicker: (source) async {
            expect(source, ImageSource.camera);
            return (
              bytes: Uint8List.fromList([1, 2]),
              name: 'p.jpg',
              mimeType: 'image/jpeg',
            );
          },
        ),
      ));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('fixflow_add_photo')));
      await tester.tap(find.byKey(const Key('fixflow_add_photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take photo'));
      await tester.pumpAndSettle();

      verify(() => tickets.uploadAttachment(
            entityId: 'tk1',
            bytes: any(named: 'bytes'),
            fileName: 'p.jpg',
            mimeType: 'image/jpeg',
          )).called(1);
      verify(() => tickets.listAttachments('tk1')).called(2);
    });

    testWidgets('bilet yok → bulunamadı', (tester) async {
      when(() => tickets.getTicket('tk1')).thenAnswer((_) async => null);
      await tester.pumpWidget(const MaterialApp(
          home: FixflowTicketDetailScreen(ticketId: 'tk1')));
      await tester.pumpAndSettle();
      expect(find.text('Ticket not found'), findsOneWidget);
    });
  });

  group('fixflowResolve', () {
    MenuItem item(String path) => MenuItem(itemKey: path, title: '', path: path);

    test('FixFlow menü yolları ekrana çözülür; entity yolları çekirdeğe kalır',
        () {
      expect(fixflowResolve(item('/fixflow')), isA<FixflowDashboardScreen>());
      expect(fixflowResolve(item('/fixflow/tickets')),
          isA<FixflowTicketListScreen>());
      expect(fixflowResolve(item('/fixflow/work-requests')),
          isA<FixflowWorkRequestListScreen>());
      expect(fixflowResolve(item('/fixflow/maintenance')),
          isA<FixflowMaintenanceListScreen>());
      expect(fixflowResolve(item('/fixflow/approvals')),
          isA<ApprovalsInboxScreen>());
      final sla = fixflowResolve(item('/fixflow/sla'));
      expect(sla, isA<FixflowTicketListScreen>());
      expect((sla! as FixflowTicketListScreen).slaMode, isTrue);
      final detail = fixflowResolve(item('/fixflow/tickets/TKT-0007'));
      expect((detail! as FixflowTicketDetailScreen).ticketId, 'TKT-0007');

      expect(fixflowResolve(item('/fixflow/entities/patent')), isNull);
      expect(fixflowResolve(item('/fixflow/reports')), isNull);
      expect(fixflowResolve(item('/crm/contacts')), isNull);
    });

    test('registerFixflowScreens → ScreenResolver.hasScreen', () {
      ScreenResolver.reset();
      registerFixflowScreens();
      expect(ScreenResolver.hasScreen('/fixflow/tickets'), isTrue);
      expect(ScreenResolver.hasScreen('/fixflow/approvals'), isTrue);
    });
  });
}
