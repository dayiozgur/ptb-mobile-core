import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../helpers/supabase_fakes.dart';
import 'fixflow_test_utils.dart';

class _MockFiles extends Mock implements FileStorageService {}

void main() {
  late SupabaseHarness h;
  late _MockFiles files;
  late FixflowTicketService svc;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(StorageCategory.document);
    registerFallbackValue(StorageAccessLevel.private);
  });

  setUp(() {
    h = SupabaseHarness();
    files = _MockFiles();
    svc = FixflowTicketService(
      supabase: h.client,
      session: FixflowSession.fixed(
          userId: 'u1', tenantId: 't1', organizationId: 'o1'),
      storage: files,
    );
  });

  final ticketRow = {
    'id': '11111111-1111-4111-8111-111111111111',
    'code': 'TKT-0007',
    'subject': 'Chiller arızası',
    'description': 'Basınç yüksek',
    'status': 'assigned',
    'priority_id': 'p1',
    'assigned_to': 'u1',
    'due_date': '2026-11-01T10:00:00Z',
    'created_at': '2026-10-30T08:00:00Z',
    'priorities': {'code': 'high', 'name': 'Yüksek', 'color': '#FD7E14'},
    'locations': {'name': 'Kazan dairesi'},
    'categories': {'name': 'HVAC'},
    'assignedTo': {'id': 'u1', 'full_name': ' ', 'username': 'tech1'},
  };

  group('listTickets', () {
    test('mine: active + tenant + assigned_to + çoklu durum, join eşlenir',
        () async {
      h.stubFrom('tickets', result: [ticketRow]);
      final list = await svc.listTickets(
        scope: FixflowTicketScope.mine,
        statuses: ['open', 'assigned'],
        search: 'chil%ler',
      );
      final t = list.single;
      expect(t.displayCode, 'TKT-0007');
      expect(t.priorityCode, 'high');
      expect(t.priorityColor, '#FD7E14');
      expect(t.locationName, 'Kazan dairesi');
      expect(t.categoryName, 'HVAC');
      expect(t.assignedToName, 'tech1'); // boş full_name → username
      expect(t.dueDate, DateTime.utc(2026, 11, 1, 10));
      expect(t.isOverdueAt(DateTime.utc(2026, 11, 8)), isTrue);

      expect(hasEq(h, 'tickets', 'active', true), isTrue);
      expect(hasEq(h, 'tickets', 'tenant_id', 't1'), isTrue);
      expect(hasEq(h, 'tickets', 'assigned_to', 'u1'), isTrue);
      expect(callsNamed(h, 'tickets', 'inFilter').single,
          ['status', ['open', 'assigned']]);
      expect(callsNamed(h, 'tickets', 'or').single.first,
          'subject.ilike.%chil ler%,description.ilike.%chil ler%');
      expect(callsNamed(h, 'tickets', 'select').single.first,
          contains('priorities!priority_id(code, name, color)'));
    });

    test('tek durum → eq(status)', () async {
      h.stubFrom('tickets', result: <Map<String, dynamic>>[]);
      await svc.listTickets(statuses: ['open']);
      expect(hasEq(h, 'tickets', 'status', 'open'), isTrue);
      expect(callsNamed(h, 'tickets', 'inFilter'), isEmpty);
    });

    test('team: staffs → team_staffs → assigned_team_id IN', () async {
      h.stubFrom('staffs', result: [
        {'id': 's1'}
      ]);
      h.stubFrom('team_staffs', result: [
        {'team_id': 'tm1'},
        {'team_id': 'tm1'},
        {'team_id': 'tm2'},
      ]);
      h.stubFrom('tickets', result: <Map<String, dynamic>>[]);
      await svc.listTickets(scope: FixflowTicketScope.team);
      expect(hasEq(h, 'staffs', 'profile_id', 'u1'), isTrue);
      expect(callsNamed(h, 'team_staffs', 'inFilter').single, [
        'staff_id',
        ['s1']
      ]);
      expect(callsNamed(h, 'tickets', 'inFilter').single, [
        'assigned_team_id',
        ['tm1', 'tm2']
      ]);
    });

    test('team: ekip yoksa bilet sorgusu yapılmaz', () async {
      h.stubFrom('staffs', result: <Map<String, dynamic>>[]);
      h.stubFrom('tickets', result: <Map<String, dynamic>>[]);
      final list = await svc.listTickets(scope: FixflowTicketScope.team);
      expect(list, isEmpty);
      verifyNever(() => h.client.from('tickets'));
    });

    test('all: assigned_to filtresi yok; SLA → due_date sıralı', () async {
      h.stubFrom('tickets', result: <Map<String, dynamic>>[]);
      await svc.listTickets(scope: FixflowTicketScope.all, orderByDue: true);
      expect(callsNamed(h, 'tickets', 'eq').any((a) => a[0] == 'assigned_to'),
          isFalse);
      expect(callsNamed(h, 'tickets', 'order').single.first, 'due_date');
    });

    test('oturum yoksa (mine) boş', () async {
      final anon = FixflowTicketService(
          supabase: h.client, session: FixflowSession.fixed(), storage: files);
      h.stubFrom('tickets', result: [ticketRow]);
      expect(await anon.listTickets(), isEmpty);
    });
  });

  group('getTicket', () {
    test('uuid → eq(id); kod → eq(code); yok → null', () async {
      h.stubFrom('tickets', result: ticketRow);
      final t = await svc.getTicket('11111111-1111-4111-8111-111111111111');
      expect(t!.subject, 'Chiller arızası');
      expect(hasEq(h, 'tickets', 'id', '11111111-1111-4111-8111-111111111111'),
          isTrue);

      h.stubFrom('tickets', result: ticketRow);
      await svc.getTicket('TKT-0007');
      expect(hasEq(h, 'tickets', 'code', 'TKT-0007'), isTrue);

      h.stubFrom('tickets', result: null);
      expect(await svc.getTicket('TKT-404'), isNull);
    });
  });

  group('worklogs', () {
    test('addWorklog: web kolonları (dakika, work_date, entity, tenant)',
        () async {
      h.stubFrom('worklogs', result: {
        'id': 'w1',
        'time_spent': 45,
        'description': 'Kompresör kontrol',
        'work_date': '2026-11-08',
      });
      final w = await svc.addWorklog(
        entityId: 'tk1',
        minutes: 45,
        description: ' Kompresör kontrol ',
        workDate: DateTime(2026, 11, 8),
      );
      expect(w.minutes, 45);
      final p = insertedPayload(h, 'worklogs');
      expect(p['time_spent'], 45);
      expect(p['work_date'], '2026-11-08');
      expect(p['description'], 'Kompresör kontrol');
      expect(p['entity_type'], 'ticket');
      expect(p['entity_id'], 'tk1');
      expect(p['tenant_id'], 't1');
      expect(p['created_by'], 'u1');
      expect(p['id'], isNotEmpty);
    });

    test('dakika <= 0 → ArgumentError, ağ yok', () async {
      expect(() => svc.addWorklog(entityId: 'tk1', minutes: 0),
          throwsArgumentError);
      verifyNever(() => h.client.from('worklogs'));
    });

    test('listWorklogs: entity filtresi; hata → []', () async {
      h.stubFrom('worklogs', result: [
        {'id': 'w1', 'time_spent': 30, 'work_date': '2026-11-07'}
      ]);
      final l = await svc.listWorklogs('tk1');
      expect(l.single.minutes, 30);
      expect(hasEq(h, 'worklogs', 'entity_type', 'ticket'), isTrue);
      expect(hasEq(h, 'worklogs', 'entity_id', 'tk1'), isTrue);
    });
  });

  group('attachments', () {
    test('uploadAttachment: private/document + entity, ardından attachments satırı',
        () async {
      const path =
          'FIXFLOW/t1/o1/document/abc-photo.jpg';
      when(() => files.uploadBytes(
            bytes: any(named: 'bytes'),
            fileName: any(named: 'fileName'),
            category: any(named: 'category'),
            access: any(named: 'access'),
            contentType: any(named: 'contentType'),
            tenantId: any(named: 'tenantId'),
            organizationId: any(named: 'organizationId'),
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
          )).thenAnswer((_) async => UploadResult.success(path: path));
      h.stubFrom('attachments', result: {
        'id': 'a1',
        'filename': 'abc-photo.jpg',
        'original_filename': 'photo.jpg',
        'file_path': path,
        'mime_type': 'image/jpeg',
      });

      final a = await svc.uploadAttachment(
        entityId: 'tk1',
        bytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
      );

      expect(a.isImage, isTrue);
      expect(a.fileName, 'photo.jpg');
      verify(() => files.uploadBytes(
            bytes: any(named: 'bytes'),
            fileName: 'photo.jpg',
            category: StorageCategory.document,
            access: StorageAccessLevel.private,
            contentType: 'image/jpeg',
            tenantId: 't1',
            organizationId: 'o1',
            entityType: 'ticket',
            entityId: 'tk1',
          )).called(1);
      final p = insertedPayload(h, 'attachments');
      expect(p['file_path'], path);
      expect(p['filename'], 'abc-photo.jpg');
      expect(p['original_filename'], 'photo.jpg');
      expect(p['file_size'], 3);
      expect(p['entity_type'], 'ticket');
      expect(p['entity_id'], 'tk1');
      expect(p['work_request_id'], 'tk1'); // web AttachmentService ile birebir
      expect(p['tenant_id'], 't1');
      expect(p['active'], true);
    });

    test('yükleme başarısız → StateError, satır yazılmaz', () async {
      when(() => files.uploadBytes(
            bytes: any(named: 'bytes'),
            fileName: any(named: 'fileName'),
            category: any(named: 'category'),
            access: any(named: 'access'),
            contentType: any(named: 'contentType'),
            tenantId: any(named: 'tenantId'),
            organizationId: any(named: 'organizationId'),
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
          )).thenAnswer((_) async => UploadResult.failure('quota'));
      await expectLater(
        svc.uploadAttachment(
            entityId: 'tk1', bytes: Uint8List(1), fileName: 'x.jpg'),
        throwsStateError,
      );
      verifyNever(() => h.client.from('attachments'));
    });

    test('attachmentUrl: platform-private imzalı URL', () async {
      when(() => files.getSignedUrl(
          bucket: any(named: 'bucket'),
          path: any(named: 'path'))).thenAnswer((_) async => 'https://signed');
      final url = await svc.attachmentUrl(const FixflowAttachment(
          id: 'a1', fileName: 'p.jpg', filePath: 'FIXFLOW/t1/o1/document/p.jpg'));
      expect(url, 'https://signed');
      verify(() => files.getSignedUrl(
          bucket: 'platform-private',
          path: 'FIXFLOW/t1/o1/document/p.jpg')).called(1);
    });
  });
}
