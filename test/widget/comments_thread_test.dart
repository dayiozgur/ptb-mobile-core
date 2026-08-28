import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../helpers/widget_test_helpers.dart';

/// Widget tests for [CommentsThread] — the shared entity-yorum primitifi
/// (CRM aktivite / PPM issue / tüm entity-engine tipleri ortak).
///
/// [CommentsService] `sl<CommentsService>()` ile çözülür; mocktail double'ı
/// register ederek gerçek Supabase/ağ olmadan pump ederiz. `initState` →
/// `list(entityType, entityId)` yükler; `_send` → `add(...)` çağırır.
class MockCommentsService extends Mock implements CommentsService {}

void main() {
  late MockCommentsService svc;

  setUp(() async {
    await sl.reset();
    svc = MockCommentsService();
    registerFake<CommentsService>(svc);
  });

  tearDown(() async {
    await sl.reset();
  });

  Widget host() => const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CommentsThread(entityType: 'deal', entityId: 'e1'),
          ),
        ),
      );

  testWidgets('yüklenirken spinner gösterir (liste future beklerken)',
      (tester) async {
    final completer = Completer<List<EntityComment>>();
    when(() => svc.list('deal', 'e1')).thenAnswer((_) => completer.future);

    await tester.pumpWidget(host());
    await tester.pump(); // initState mikro-görevleri; future hâlâ bekliyor

    expect(find.byType(AppLoadingIndicator), findsOneWidget);
    expect(find.text('Henüz yorum yok.'), findsNothing);

    completer.complete(const <EntityComment>[]);
    await tester.pumpAndSettle();
  });

  testWidgets('yorum yoksa boş-durum metni', (tester) async {
    when(() => svc.list('deal', 'e1'))
        .thenAnswer((_) async => const <EntityComment>[]);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Henüz yorum yok.'), findsOneWidget);
  });

  testWidgets('yorumları yazar + içerik + saat + sayı-rozeti ile listeler',
      (tester) async {
    when(() => svc.list('deal', 'e1')).thenAnswer((_) async => [
          EntityComment(
              id: '1',
              content: 'İlk yorum',
              authorName: 'Ayşe',
              createdAt: DateTime(2026, 8, 28, 14, 29)),
          EntityComment(
              id: '2',
              content: 'İkinci yorum',
              authorName: 'Mehmet',
              createdAt: DateTime(2026, 8, 28, 9, 5)),
        ]);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Ayşe'), findsOneWidget);
    expect(find.text('İlk yorum'), findsOneWidget);
    expect(find.text('Mehmet'), findsOneWidget);
    expect(find.text('İkinci yorum'), findsOneWidget);
    // _loc null → toTenant dt'yi aynen döndürür → yerel saat biçimi.
    expect(find.text('28.08 14:29'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // başlık sayı-rozeti
  });

  testWidgets('gönder → servise ekler ve yeni yorum listeye yansır',
      (tester) async {
    when(() => svc.list('deal', 'e1'))
        .thenAnswer((_) async => const <EntityComment>[]);
    when(() => svc.add('deal', 'e1', 'Yeni yorum')).thenAnswer((_) async =>
        EntityComment(
            id: '9',
            content: 'Yeni yorum',
            authorName: 'Siz',
            createdAt: DateTime(2026, 8, 28, 10, 0)));

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Yeni yorum');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    verify(() => svc.add('deal', 'e1', 'Yeni yorum')).called(1);
    expect(find.text('Yeni yorum'), findsOneWidget); // input temizlendi, kalan = yorum
    expect(find.text('Henüz yorum yok.'), findsNothing);
  });

  testWidgets('boş metin gönderilmez (servise add çağrısı yok)',
      (tester) async {
    when(() => svc.list('deal', 'e1'))
        .thenAnswer((_) async => const <EntityComment>[]);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    verifyNever(() => svc.add(any(), any(), any()));
  });
}
