import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

void main() {
  group('WorkRequestStatus', () {
    test('fromString returns correct status for valid values', () {
      expect(WorkRequestStatus.fromString('DRAFT'), WorkRequestStatus.draft);
      expect(WorkRequestStatus.fromString('SUBMITTED'), WorkRequestStatus.submitted);
      expect(WorkRequestStatus.fromString('APPROVED'), WorkRequestStatus.approved);
      expect(WorkRequestStatus.fromString('REJECTED'), WorkRequestStatus.rejected);
      expect(WorkRequestStatus.fromString('ASSIGNED'), WorkRequestStatus.assigned);
      expect(WorkRequestStatus.fromString('IN_PROGRESS'), WorkRequestStatus.inProgress);
      expect(WorkRequestStatus.fromString('ON_HOLD'), WorkRequestStatus.onHold);
      expect(WorkRequestStatus.fromString('COMPLETED'), WorkRequestStatus.completed);
      expect(WorkRequestStatus.fromString('CANCELLED'), WorkRequestStatus.cancelled);
      expect(WorkRequestStatus.fromString('CLOSED'), WorkRequestStatus.closed);
    });

    test('fromString returns draft for invalid value', () {
      expect(WorkRequestStatus.fromString('INVALID'), WorkRequestStatus.draft);
      expect(WorkRequestStatus.fromString(null), WorkRequestStatus.draft);
    });

    test('isEditable returns correct value', () {
      expect(WorkRequestStatus.draft.isEditable, true);
      expect(WorkRequestStatus.submitted.isEditable, true);
      expect(WorkRequestStatus.rejected.isEditable, true);
      expect(WorkRequestStatus.approved.isEditable, false);
      expect(WorkRequestStatus.completed.isEditable, false);
    });

    test('isActionable returns correct value', () {
      expect(WorkRequestStatus.approved.isActionable, true);
      expect(WorkRequestStatus.assigned.isActionable, true);
      expect(WorkRequestStatus.inProgress.isActionable, true);
      expect(WorkRequestStatus.draft.isActionable, false);
      expect(WorkRequestStatus.completed.isActionable, false);
    });

    test('isFinished returns correct value', () {
      expect(WorkRequestStatus.completed.isFinished, true);
      expect(WorkRequestStatus.cancelled.isFinished, true);
      expect(WorkRequestStatus.closed.isFinished, true);
      expect(WorkRequestStatus.draft.isFinished, false);
      expect(WorkRequestStatus.inProgress.isFinished, false);
    });
  });

  group('WorkRequestType', () {
    test('fromString returns correct type', () {
      expect(WorkRequestType.fromString('BREAKDOWN'), WorkRequestType.breakdown);
      expect(WorkRequestType.fromString('MAINTENANCE'), WorkRequestType.maintenance);
      expect(WorkRequestType.fromString('SERVICE'), WorkRequestType.service);
      expect(WorkRequestType.fromString('INSPECTION'), WorkRequestType.inspection);
      expect(WorkRequestType.fromString('INSTALLATION'), WorkRequestType.installation);
      expect(WorkRequestType.fromString('MODIFICATION'), WorkRequestType.modification);
      expect(WorkRequestType.fromString('GENERAL'), WorkRequestType.general);
    });

    test('fromString returns general for invalid value', () {
      expect(WorkRequestType.fromString('INVALID'), WorkRequestType.general);
      expect(WorkRequestType.fromString(null), WorkRequestType.general);
    });

    test('value property returns correct string', () {
      expect(WorkRequestType.breakdown.value, 'BREAKDOWN');
      expect(WorkRequestType.maintenance.value, 'MAINTENANCE');
    });

    test('label property returns Turkish label', () {
      expect(WorkRequestType.breakdown.label, 'Arıza Bildirimi');
      expect(WorkRequestType.maintenance.label, 'Bakım Talebi');
    });
  });

  group('WorkRequestPriority', () {
    test('fromString returns correct priority', () {
      expect(WorkRequestPriority.fromString('LOW'), WorkRequestPriority.low);
      expect(WorkRequestPriority.fromString('NORMAL'), WorkRequestPriority.normal);
      expect(WorkRequestPriority.fromString('HIGH'), WorkRequestPriority.high);
      expect(WorkRequestPriority.fromString('URGENT'), WorkRequestPriority.urgent);
      expect(WorkRequestPriority.fromString('CRITICAL'), WorkRequestPriority.critical);
    });

    test('fromString returns normal for invalid value', () {
      expect(WorkRequestPriority.fromString('INVALID'), WorkRequestPriority.normal);
      expect(WorkRequestPriority.fromString(null), WorkRequestPriority.normal);
    });

    test('level property is correct', () {
      expect(WorkRequestPriority.low.level, 1);
      expect(WorkRequestPriority.normal.level, 2);
      expect(WorkRequestPriority.high.level, 3);
      expect(WorkRequestPriority.urgent.level, 4);
      expect(WorkRequestPriority.critical.level, 5);
    });

    test('isHigherThan comparison works', () {
      expect(WorkRequestPriority.high.isHigherThan(WorkRequestPriority.normal), true);
      expect(WorkRequestPriority.normal.isHigherThan(WorkRequestPriority.high), false);
      expect(WorkRequestPriority.critical.isHigherThan(WorkRequestPriority.low), true);
    });
  });

  group('WorkRequest', () {
    late WorkRequest request;
    late DateTime requestedAt;
    late DateTime expectedCompletionDate;

    setUp(() {
      requestedAt = DateTime(2025, 6, 10, 9, 0);
      expectedCompletionDate = DateTime(2025, 6, 15, 17, 0);

      request = WorkRequest(
        id: 'request-123',
        requestNumber: 'WR-2025-001',
        title: 'AC Unit Repair',
        description: 'Air conditioning unit not cooling properly',
        type: WorkRequestType.breakdown,
        status: WorkRequestStatus.submitted,
        priority: WorkRequestPriority.high,
        requestedById: 'user-123',
        requestedByName: 'John Doe',
        requestedAt: requestedAt,
        expectedCompletionDate: expectedCompletionDate,
        tenantId: 'tenant-123',
        siteId: 'site-456',
        siteName: 'Main Building',
        unitId: 'unit-789',
        unitName: 'Unit 101',
        estimatedDuration: 120,
        estimatedCost: 500.0,
        currency: 'TRY',
        tags: ['urgent', 'hvac'],
        createdAt: requestedAt,
      );
    });

    test('creates instance with required fields', () {
      expect(request.id, 'request-123');
      expect(request.requestNumber, 'WR-2025-001');
      expect(request.title, 'AC Unit Repair');
      expect(request.type, WorkRequestType.breakdown);
      expect(request.status, WorkRequestStatus.submitted);
      expect(request.priority, WorkRequestPriority.high);
      expect(request.tenantId, 'tenant-123');
    });

    test('isEditable returns correct value', () {
      expect(request.isEditable, true);

      final approvedRequest = request.copyWith(status: WorkRequestStatus.approved);
      expect(approvedRequest.isEditable, false);
    });

    test('isActionable returns correct value', () {
      expect(request.isActionable, false);

      final assignedRequest = request.copyWith(status: WorkRequestStatus.assigned);
      expect(assignedRequest.isActionable, true);
    });

    test('isFinished returns correct value', () {
      expect(request.isFinished, false);

      final completedRequest = request.copyWith(status: WorkRequestStatus.completed);
      expect(completedRequest.isFinished, true);
    });

    test('isAssigned returns correct value', () {
      expect(request.isAssigned, false);

      final assignedRequest = request.copyWith(assignedToId: 'user-456');
      expect(assignedRequest.isAssigned, true);
    });

    test('isOverdue returns correct value', () {
      // Not overdue when expected date is in future
      final futureRequest = request.copyWith(
        expectedCompletionDate: DateTime.now().add(const Duration(days: 7)),
      );
      expect(futureRequest.isOverdue, false);

      // Overdue when expected date is in past and not finished
      final overdueRequest = request.copyWith(
        expectedCompletionDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(overdueRequest.isOverdue, true);

      // Not overdue when finished (even if past due date)
      final finishedRequest = request.copyWith(
        status: WorkRequestStatus.completed,
        expectedCompletionDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(finishedRequest.isOverdue, false);
    });

    test('locationSummary returns correct string', () {
      expect(request.locationSummary, 'Main Building > Unit 101');

      final noLocationRequest = WorkRequest(
        id: 'request-456',
        title: 'No Location',
        requestedById: 'user-123',
        requestedAt: requestedAt,
        tenantId: 'tenant-123',
        createdAt: requestedAt,
      );
      expect(noLocationRequest.locationSummary, '-');
    });

    test('estimatedDurationFormatted returns correct string', () {
      expect(request.estimatedDurationFormatted, '2s 0dk');

      final shortRequest = request.copyWith(estimatedDuration: 45);
      expect(shortRequest.estimatedDurationFormatted, '45dk');

      final noDurationRequest = request.copyWith(estimatedDuration: null);
      expect(noDurationRequest.estimatedDurationFormatted, '-');
    });

    test('costSummary returns correct string', () {
      expect(request.costSummary, '~500.00 TRY');

      final actualCostRequest = request.copyWith(actualCost: 450.0);
      expect(actualCostRequest.costSummary, '450.00 TRY');

      final noCostRequest = WorkRequest(
        id: 'request-456',
        title: 'No Cost',
        requestedById: 'user-123',
        requestedAt: requestedAt,
        tenantId: 'tenant-123',
        createdAt: requestedAt,
      );
      expect(noCostRequest.costSummary, '-');
    });

    test('allowedTransitions returns correct list', () {
      // Draft can go to submitted or cancelled
      final draftRequest = request.copyWith(status: WorkRequestStatus.draft);
      expect(
        draftRequest.allowedTransitions,
        [WorkRequestStatus.submitted, WorkRequestStatus.cancelled],
      );

      // Submitted can go to approved, rejected, or cancelled
      expect(
        request.allowedTransitions,
        [
          WorkRequestStatus.approved,
          WorkRequestStatus.rejected,
          WorkRequestStatus.cancelled,
        ],
      );

      // Completed can only go to closed
      final completedRequest = request.copyWith(status: WorkRequestStatus.completed);
      expect(completedRequest.allowedTransitions, [WorkRequestStatus.closed]);

      // Closed has no transitions
      final closedRequest = request.copyWith(status: WorkRequestStatus.closed);
      expect(closedRequest.allowedTransitions, isEmpty);
    });

    test('canTransitionTo returns correct value', () {
      expect(request.canTransitionTo(WorkRequestStatus.approved), true);
      expect(request.canTransitionTo(WorkRequestStatus.rejected), true);
      expect(request.canTransitionTo(WorkRequestStatus.completed), false);
    });

    test('fromJson creates correct instance', () {
      final json = {
        'id': 'request-789',
        'request_number': 'WR-2025-002',
        'title': 'Elevator Maintenance',
        'description': 'Scheduled maintenance',
        'type': 'MAINTENANCE',
        'status': 'APPROVED',
        'priority': 'NORMAL',
        'requested_by_id': 'user-456',
        'requested_at': '2025-06-12T10:00:00.000Z',
        'tenant_id': 'tenant-789',
        'site_id': 'site-123',
        'site_name': 'Tower A',
        'estimated_duration': 180,
        'estimated_cost': 1500.0,
        'tags': ['elevator', 'preventive'],
        'created_at': '2025-06-12T10:00:00.000Z',
        'notes': [],
        'attachments': [],
        'metadata': {'floor': 5},
      };

      final parsed = WorkRequest.fromJson(json);

      expect(parsed.id, 'request-789');
      expect(parsed.requestNumber, 'WR-2025-002');
      expect(parsed.title, 'Elevator Maintenance');
      expect(parsed.type, WorkRequestType.maintenance);
      expect(parsed.status, WorkRequestStatus.approved);
      expect(parsed.priority, WorkRequestPriority.normal);
      expect(parsed.siteName, 'Tower A');
      expect(parsed.estimatedDuration, 180);
      expect(parsed.tags, ['elevator', 'preventive']);
      expect(parsed.metadata['floor'], 5);
    });

    test('toJson creates correct map', () {
      final json = request.toJson();

      expect(json['id'], 'request-123');
      expect(json['request_number'], 'WR-2025-001');
      expect(json['title'], 'AC Unit Repair');
      expect(json['type'], 'BREAKDOWN');
      expect(json['status'], 'SUBMITTED');
      expect(json['priority'], 'HIGH');
      expect(json['tenant_id'], 'tenant-123');
      expect(json['site_name'], 'Main Building');
      expect(json['estimated_cost'], 500.0);
      expect(json['tags'], ['urgent', 'hvac']);
    });

    test('copyWith creates new instance with updated fields', () {
      final updated = request.copyWith(
        title: 'Updated Title',
        status: WorkRequestStatus.approved,
        priority: WorkRequestPriority.critical,
      );

      expect(updated.title, 'Updated Title');
      expect(updated.status, WorkRequestStatus.approved);
      expect(updated.priority, WorkRequestPriority.critical);
      expect(updated.id, request.id); // Unchanged
      expect(updated.type, request.type); // Unchanged
    });

    test('equality is based on id', () {
      final sameId = WorkRequest(
        id: 'request-123',
        title: 'Different Title',
        requestedById: 'user-999',
        requestedAt: DateTime.now(),
        tenantId: 'tenant-999',
        createdAt: DateTime.now(),
      );

      expect(request == sameId, true);
      expect(request.hashCode, sameId.hashCode);
    });
  });

  group('WorkRequestAttachment', () {
    test('fileSizeFormatted returns correct string', () {
      expect(
        WorkRequestAttachment(
          id: '1',
          fileName: 'doc.pdf',
          fileUrl: 'url',
          fileSize: 500,
          uploadedAt: DateTime.now(),
        ).fileSizeFormatted,
        '500B',
      );

      expect(
        WorkRequestAttachment(
          id: '2',
          fileName: 'doc.pdf',
          fileUrl: 'url',
          fileSize: 2048,
          uploadedAt: DateTime.now(),
        ).fileSizeFormatted,
        '2.0KB',
      );

      expect(
        WorkRequestAttachment(
          id: '3',
          fileName: 'video.mp4',
          fileUrl: 'url',
          fileSize: 5242880,
          uploadedAt: DateTime.now(),
        ).fileSizeFormatted,
        '5.0MB',
      );
    });

    test('isImage returns correct value', () {
      final image = WorkRequestAttachment(
        id: '1',
        fileName: 'photo.jpg',
        fileUrl: 'url',
        mimeType: 'image/jpeg',
        uploadedAt: DateTime.now(),
      );
      expect(image.isImage, true);

      final pdf = WorkRequestAttachment(
        id: '2',
        fileName: 'doc.pdf',
        fileUrl: 'url',
        mimeType: 'application/pdf',
        uploadedAt: DateTime.now(),
      );
      expect(pdf.isImage, false);
    });

    test('fromJson and toJson work correctly', () {
      final json = {
        'id': 'attach-123',
        'file_name': 'report.pdf',
        'file_url': 'https://storage.example.com/report.pdf',
        'file_size': 102400,
        'mime_type': 'application/pdf',
        'description': 'Monthly report',
        'uploaded_by_id': 'user-123',
        'uploaded_at': '2025-06-10T10:00:00.000Z',
      };

      final attachment = WorkRequestAttachment.fromJson(json);
      expect(attachment.id, 'attach-123');
      expect(attachment.fileName, 'report.pdf');
      expect(attachment.fileSize, 102400);

      final output = attachment.toJson();
      expect(output['file_name'], 'report.pdf');
      expect(output['mime_type'], 'application/pdf');
    });
  });

  group('WorkRequestNote', () {
    test('fromJson and toJson work correctly', () {
      final json = {
        'id': 'note-123',
        'content': 'Work started on this request',
        'type': 'STATUS_CHANGE',
        'author_id': 'user-456',
        'author_name': 'Jane Smith',
        'created_at': '2025-06-11T14:30:00.000Z',
      };

      final note = WorkRequestNote.fromJson(json);
      expect(note.id, 'note-123');
      expect(note.content, 'Work started on this request');
      expect(note.type, WorkRequestNoteType.statusChange);
      expect(note.authorName, 'Jane Smith');

      final output = note.toJson();
      expect(output['content'], 'Work started on this request');
      expect(output['type'], 'STATUS_CHANGE');
    });
  });

  group('WorkRequestNoteType', () {
    test('fromString returns correct type', () {
      expect(WorkRequestNoteType.fromString('COMMENT'), WorkRequestNoteType.comment);
      expect(WorkRequestNoteType.fromString('SYSTEM'), WorkRequestNoteType.system);
      expect(WorkRequestNoteType.fromString('STATUS_CHANGE'), WorkRequestNoteType.statusChange);
      expect(WorkRequestNoteType.fromString('ASSIGNMENT'), WorkRequestNoteType.assignment);
      expect(WorkRequestNoteType.fromString('APPROVAL'), WorkRequestNoteType.approval);
      expect(WorkRequestNoteType.fromString('INVALID'), WorkRequestNoteType.comment);
    });
  });

  group('WorkRequestStats', () {
    test('fromJson creates correct instance', () {
      final json = {
        'total_count': 100,
        'pending_count': 20,
        'active_count': 30,
        'completed_count': 40,
        'overdue_count': 10,
      };

      final stats = WorkRequestStats.fromJson(json);

      expect(stats.totalCount, 100);
      expect(stats.pendingCount, 20);
      expect(stats.activeCount, 30);
      expect(stats.completedCount, 40);
      expect(stats.overdueCount, 10);
    });

    test('completionRate is calculated correctly', () {
      const stats = WorkRequestStats(
        totalCount: 100,
        completedCount: 75,
      );
      expect(stats.completionRate, 75.0);

      const emptyStats = WorkRequestStats(totalCount: 0);
      expect(emptyStats.completionRate, 0);
    });

    test('default values are zero', () {
      const stats = WorkRequestStats();
      expect(stats.totalCount, 0);
      expect(stats.pendingCount, 0);
      expect(stats.activeCount, 0);
      expect(stats.completedCount, 0);
    });
  });
}
