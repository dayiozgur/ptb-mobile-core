import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class _MockStatus extends Mock implements FixflowStatusService {}

class _MockWr extends Mock implements FixflowWorkRequestService {}

void main() {
  late _MockStatus status;
  late _MockWr wr;

  final catalog = FixflowStatusCatalog(const [
    FixflowStatus(code: 'draft', name: 'Taslak', isInitial: true, sortOrder: 0),
    FixflowStatus(code: 'pending_approval', name: 'Gönderildi', sortOrder: 1),
    FixflowStatus(code: 'done', name: 'Tamamlandı', isFinal: true, sortOrder: 4),
  ]);

  setUp(() async {
    await sl.reset();
    status = _MockStatus();
    wr = _MockWr();
    FixflowServices.override(status: status, workRequests: wr);
    when(() => status.catalog(any())).thenAnswer((_) async => catalog);
  });

  tearDown(() async {
    FixflowServices.reset();
    await sl.reset();
  });

  testWidgets('liste: açık durumlar + durum adı', (tester) async {
    when(() => wr.listWorkRequests(
          mineOnly: any(named: 'mineOnly'),
          statuses: any(named: 'statuses'),
        )).thenAnswer((_) async => const [
          FixflowWorkRequest(
              id: 'w1', code: 'WR-1', subject: 'Lamba', status: 'pending_approval'),
        ]);
    await tester.pumpWidget(
        const MaterialApp(home: FixflowWorkRequestListScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Lamba'), findsOneWidget);
    expect(find.text('Gönderildi'), findsOneWidget);
    verify(() => wr.listWorkRequests(
          mineOnly: false,
          statuses: ['draft', 'pending_approval'],
        )).called(1);
  });

  testWidgets('oluştur: konu zorunlu; başlangıç durumu is_initial, öncelik kodu',
      (tester) async {
    when(() => wr.createWorkRequest(
          subject: any(named: 'subject'),
          description: any(named: 'description'),
          priorityCode: any(named: 'priorityCode'),
          initialStatus: any(named: 'initialStatus'),
        )).thenAnswer((_) async => const FixflowWorkRequest(
        id: 'w9', code: 'WR-9', subject: 'Su kaçağı', status: 'draft'));

    await tester.pumpWidget(const MaterialApp(
      home: FixflowWorkRequestCreateScreen(priorities: [
        Priority(id: 'p1', code: 'high', name: 'Yüksek', level: 2, explicitlyActive: true),
        Priority(id: 'p2', code: 'low', name: 'Düşük', level: 4, explicitlyActive: true),
        Priority(id: 'v1', code: 'carel_x', name: 'Vendor', vendor: 'carel', explicitlyActive: true),
      ]),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('fixflow_wr_save')));
    await tester.pumpAndSettle();
    expect(find.text('Subject is required.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('fixflow_wr_subject')), 'Su kaçağı');
    await tester.tap(find.byKey(const Key('fixflow_wr_priority')));
    await tester.pumpAndSettle();
    expect(find.text('Vendor'), findsNothing); // vendor satırı sunulmaz
    await tester.tap(find.text('Yüksek').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fixflow_wr_save')));
    await tester.pumpAndSettle();

    verify(() => wr.createWorkRequest(
          subject: 'Su kaçağı',
          description: '',
          priorityCode: 'high',
          initialStatus: 'draft',
        )).called(1);
  });
}
