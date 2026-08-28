import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../helpers/widget_test_helpers.dart';

/// Widget tests for [WorkInboxScreen] — generic "Bana atanan iş" ekranı
/// (CRM `fn_crm_my_work` / PPM `fn_ppm_my_work` aynı ekranla render eder).
///
/// [WorkInboxService] `sl<WorkInboxService>()` ile çözülür → mocktail double.
/// `RealtimeRefresher.start` `sl<RealtimeService>()`'i try/catch içinde
/// çağırdığından (register yok → GetIt throw → sessizce yutulur) realtime'ı
/// ayrıca stub'lamaya gerek yok.
class MockWorkInboxService extends Mock implements WorkInboxService {}

void main() {
  late MockWorkInboxService svc;

  final source = WorkInboxSource(
    title: 'Bana Atanan',
    rpcName: 'fn_crm_my_work',
    mapper: (m) => WorkInboxItem(id: m['id'] as String? ?? '', title: ''),
  );

  String? pushedPath;

  setUp(() async {
    await sl.reset();
    svc = MockWorkInboxService();
    registerFake<WorkInboxService>(svc);
    pushedPath = null;
  });

  tearDown(() async {
    await sl.reset();
  });

  Widget host() {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => WorkInboxScreen(source: source)),
      GoRoute(
        path: '/entities/:type/:id',
        builder: (ctx, st) {
          pushedPath = st.uri.toString();
          return const Scaffold(body: Text('DETAY'));
        },
      ),
    ]);
    return MaterialApp.router(routerConfig: router);
  }

  testWidgets('yüklenirken spinner gösterir', (tester) async {
    final completer = Completer<List<WorkInboxItem>>();
    when(() => svc.load(source)).thenAnswer((_) => completer.future);

    await tester.pumpWidget(host());
    await tester.pump(); // initState

    expect(find.byType(AppLoadingIndicator), findsOneWidget);

    completer.complete(const <WorkInboxItem>[]);
    await tester.pumpAndSettle();
  });

  testWidgets('atanmış iş yoksa boş-durum', (tester) async {
    when(() => svc.load(source))
        .thenAnswer((_) async => const <WorkInboxItem>[]);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Atanmış iş yok'), findsOneWidget);
  });

  testWidgets('öğeleri gruplara (GECİKMİŞ/BUGÜN) ayırıp başlık+alt-başlık+rozet '
      'ile listeler', (tester) async {
    when(() => svc.load(source)).thenAnswer((_) async => const [
          WorkInboxItem(
            id: '1',
            title: 'Gecikmiş görev',
            subtitle: 'Acme A.Ş.',
            group: 'overdue',
            status: 'open',
            trailing: '₺5.000',
            entityType: 'deal',
          ),
          WorkInboxItem(
            id: '2',
            title: 'Bugünkü görev',
            group: 'today',
            entityType: 'activity',
          ),
        ]);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // Grup başlıkları (bucket → TR etiket).
    expect(find.text('GECİKMİŞ'), findsOneWidget);
    expect(find.text('BUGÜN'), findsOneWidget);
    // Öğe içerikleri.
    expect(find.text('Gecikmiş görev'), findsOneWidget);
    expect(find.text('Bugünkü görev'), findsOneWidget);
    expect(find.text('Acme A.Ş.'), findsOneWidget);
    expect(find.text('₺5.000'), findsOneWidget);
    expect(find.text('open'), findsOneWidget); // durum rozeti
  });

  testWidgets('öğeye dokununca /entities/<type>/<id> detayına gider',
      (tester) async {
    when(() => svc.load(source)).thenAnswer((_) async => const [
          WorkInboxItem(
            id: '42',
            title: 'Gecikmiş görev',
            group: 'overdue',
            entityType: 'deal',
          ),
        ]);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gecikmiş görev'));
    await tester.pumpAndSettle();

    expect(pushedPath, '/entities/deal/42');
    expect(find.text('DETAY'), findsOneWidget);
  });

  testWidgets('entityType boş → navigasyon yok (çökmeye karşı)',
      (tester) async {
    when(() => svc.load(source)).thenAnswer((_) async => const [
          WorkInboxItem(id: '7', title: 'Tipsiz öğe', group: 'today'),
        ]);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tipsiz öğe'));
    await tester.pumpAndSettle();

    expect(pushedPath, isNull);
    expect(find.text('Tipsiz öğe'), findsOneWidget); // hâlâ inbox'ta
  });
}
