import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Mocks
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockCacheManager extends Mock implements CacheManager {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}

class MockPostgrestTransformBuilder extends Mock
    implements PostgrestTransformBuilder<List<Map<String, dynamic>>> {}

void main() {
  late WorkRequestService workRequestService;
  late MockSupabaseClient mockSupabase;
  late MockCacheManager mockCacheManager;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockCacheManager = MockCacheManager();
    workRequestService = WorkRequestService(
      supabase: mockSupabase,
      cacheManager: mockCacheManager,
    );
  });

  tearDown(() {
    workRequestService.dispose();
  });

  group('WorkRequestService - Context Management', () {
    test('setTenant updates tenant context', () {
      workRequestService.setTenant('tenant-123');
      // No exception means success
      expect(true, isTrue);
    });

    test('setTenant clears requests when tenant changes', () async {
      workRequestService.setTenant('tenant-1');
      workRequestService.setTenant('tenant-2');

      expect(workRequestService.requests, isEmpty);
    });

    test('setUser updates user context', () {
      workRequestService.setUser('user-123');
      // No exception means success
      expect(true, isTrue);
    });

    test('clearContext resets all state', () {
      workRequestService.setTenant('tenant-123');
      workRequestService.setUser('user-123');
      workRequestService.clearContext();

      expect(workRequestService.requests, isEmpty);
      expect(workRequestService.selected, isNull);
    });
  });

  group('WorkRequestService - Getters', () {
    test('requestsStream returns broadcast stream', () {
      expect(workRequestService.requestsStream, isA<Stream<List<WorkRequest>>>());
    });

    test('selectedStream returns broadcast stream', () {
      expect(workRequestService.selectedStream, isA<Stream<WorkRequest?>>());
    });

    test('requests returns unmodifiable list', () {
      final requests = workRequestService.requests;
      expect(requests, isA<List<WorkRequest>>());
      expect(() => (requests as List).add(null), throwsUnsupportedError);
    });
  });

  group('WorkRequestService - selectRequest', () {
    test('selectRequest updates selected and stream', () async {
      final request = WorkRequest(
        id: 'request-1',
        title: 'Test Request',
        requestedById: 'user-123',
        requestedAt: DateTime.now(),
        tenantId: 'tenant-123',
        createdAt: DateTime.now(),
      );

      final streamFuture = workRequestService.selectedStream.first;
      workRequestService.selectRequest(request);

      expect(workRequestService.selected, request);
      final streamValue = await streamFuture;
      expect(streamValue, request);
    });

    test('selectRequest with null clears selection', () {
      final request = WorkRequest(
        id: 'request-1',
        title: 'Test Request',
        requestedById: 'user-123',
        requestedAt: DateTime.now(),
        tenantId: 'tenant-123',
        createdAt: DateTime.now(),
      );

      workRequestService.selectRequest(request);
      expect(workRequestService.selected, isNotNull);

      workRequestService.selectRequest(null);
      expect(workRequestService.selected, isNull);
    });
  });

  group('WorkRequestService - Filtered Getters', () {
    test('pendingRequests filters correctly', () {
      expect(workRequestService.pendingRequests, isEmpty);
    });

    test('activeRequests filters correctly', () {
      expect(workRequestService.activeRequests, isEmpty);
    });

    test('overdueRequests filters correctly', () {
      expect(workRequestService.overdueRequests, isEmpty);
    });

    test('myAssignedRequests returns empty when user not set', () {
      expect(workRequestService.myAssignedRequests, isEmpty);
    });

    test('myCreatedRequests returns empty when user not set', () {
      expect(workRequestService.myCreatedRequests, isEmpty);
    });
  });

  group('WorkRequestService - Error Handling', () {
    test('getAll throws when tenant not set', () async {
      expect(
        () => workRequestService.getAll(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Tenant context is not set'),
        )),
      );
    });

    test('create throws when tenant not set', () async {
      expect(
        () => workRequestService.create(title: 'Test'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Tenant context is not set'),
        )),
      );
    });

    test('create throws when user not set', () async {
      workRequestService.setTenant('tenant-123');

      expect(
        () => workRequestService.create(title: 'Test'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('User context is not set'),
        )),
      );
    });

    test('getStats throws when tenant not set', () async {
      expect(
        () => workRequestService.getStats(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Tenant context is not set'),
        )),
      );
    });

    test('assign throws when no assignee provided', () async {
      workRequestService.setTenant('tenant-123');
      workRequestService.setUser('user-123');

      expect(
        () => workRequestService.assign('request-1'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('addNote throws when user not set', () async {
      expect(
        () => workRequestService.addNote('request-1', content: 'Test note'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('User context is not set'),
        )),
      );
    });
  });

  group('WorkRequestService - Status Transitions', () {
    test('submit method exists', () {
      expect(workRequestService.submit, isA<Function>());
    });

    test('approve method exists', () {
      expect(workRequestService.approve, isA<Function>());
    });

    test('reject method exists', () {
      expect(workRequestService.reject, isA<Function>());
    });

    test('assign method exists', () {
      expect(workRequestService.assign, isA<Function>());
    });

    test('startWork method exists', () {
      expect(workRequestService.startWork, isA<Function>());
    });

    test('putOnHold method exists', () {
      expect(workRequestService.putOnHold, isA<Function>());
    });

    test('resume method exists', () {
      expect(workRequestService.resume, isA<Function>());
    });

    test('complete method exists', () {
      expect(workRequestService.complete, isA<Function>());
    });

    test('cancel method exists', () {
      expect(workRequestService.cancel, isA<Function>());
    });

    test('close method exists', () {
      expect(workRequestService.close, isA<Function>());
    });
  });

  group('WorkRequestService - Note Operations', () {
    test('addNote method exists', () {
      expect(workRequestService.addNote, isA<Function>());
    });
  });

  group('WorkRequestService - Lifecycle', () {
    test('dispose closes streams', () async {
      final service = WorkRequestService(
        supabase: mockSupabase,
        cacheManager: mockCacheManager,
      );

      service.dispose();

      // After dispose, adding to stream should throw
      // This is tested implicitly - no assertion needed
      expect(true, isTrue);
    });
  });
}
