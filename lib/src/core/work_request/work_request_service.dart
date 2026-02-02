import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../utils/logger.dart';
import 'work_request_model.dart';

/// Work Request Service
///
/// İş taleplerini yönetir. CRUD operasyonları, durum geçişleri,
/// atama ve onay işlemleri sağlar.
class WorkRequestService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  /// Work request listesi stream
  final _requestsController = StreamController<List<WorkRequest>>.broadcast();

  /// Seçili work request stream
  final _selectedController = StreamController<WorkRequest?>.broadcast();

  /// Mevcut tenant ID
  String? _currentTenantId;

  /// Mevcut kullanıcı ID
  String? _currentUserId;

  /// Mevcut request listesi
  List<WorkRequest> _requests = [];

  /// Seçili request
  WorkRequest? _selected;

  WorkRequestService({
    required SupabaseClient supabase,
    required CacheManager cacheManager,
  })  : _supabase = supabase,
        _cacheManager = cacheManager;

  // ============================================
  // GETTERS
  // ============================================

  /// Work request listesi stream
  Stream<List<WorkRequest>> get requestsStream => _requestsController.stream;

  /// Seçili work request stream
  Stream<WorkRequest?> get selectedStream => _selectedController.stream;

  /// Mevcut request listesi
  List<WorkRequest> get requests => List.unmodifiable(_requests);

  /// Seçili request
  WorkRequest? get selected => _selected;

  /// Bekleyen talepler
  List<WorkRequest> get pendingRequests =>
      _requests.where((r) => r.status == WorkRequestStatus.submitted).toList();

  /// Devam eden talepler
  List<WorkRequest> get activeRequests =>
      _requests.where((r) => r.status.isActionable).toList();

  /// Geciken talepler
  List<WorkRequest> get overdueRequests =>
      _requests.where((r) => r.isOverdue).toList();

  /// Bana atanan talepler
  List<WorkRequest> get myAssignedRequests {
    if (_currentUserId == null) return [];
    return _requests.where((r) => r.assignedToId == _currentUserId).toList();
  }

  /// Benim oluşturduğum talepler
  List<WorkRequest> get myCreatedRequests {
    if (_currentUserId == null) return [];
    return _requests.where((r) => r.requestedById == _currentUserId).toList();
  }

  // ============================================
  // CONTEXT
  // ============================================

  /// Tenant context'ini ayarla
  void setTenant(String tenantId) {
    if (_currentTenantId != tenantId) {
      _currentTenantId = tenantId;
      _requests = [];
      _selected = null;
      _requestsController.add(_requests);
      _selectedController.add(_selected);
    }
  }

  /// Kullanıcı context'ini ayarla
  void setUser(String userId) {
    _currentUserId = userId;
  }

  /// Context'i temizle
  void clearContext() {
    _currentTenantId = null;
    _currentUserId = null;
    _requests = [];
    _selected = null;
    _requestsController.add(_requests);
    _selectedController.add(_selected);
  }

  // ============================================
  // CRUD OPERATIONS
  // ============================================

  /// Tüm work request'leri getir
  Future<List<WorkRequest>> getAll({
    String? siteId,
    String? unitId,
    WorkRequestStatus? status,
    WorkRequestType? type,
    WorkRequestPriority? priority,
    String? assignedToId,
    DateTime? fromDate,
    DateTime? toDate,
    bool forceRefresh = false,
  }) async {
    if (_currentTenantId == null) {
      throw Exception('Tenant context is not set');
    }

    final cacheKey = 'work_requests_${_currentTenantId}_${siteId ?? 'all'}';

    // Cache kontrolü
    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        try {
          _requests = cached
              .map((e) => WorkRequest.fromJson(e as Map<String, dynamic>))
              .toList();
          _requestsController.add(_requests);
          return _applyFilters(status: status, type: type, priority: priority, assignedToId: assignedToId);
        } catch (cacheError) {
          Logger.warning('Failed to parse work requests from cache: $cacheError');
          await _cacheManager.delete(cacheKey);
        }
      }
    }

    try {
      var query = _supabase
          .from('work_requests')
          .select()
          .eq('tenant_id', _currentTenantId!);

      if (siteId != null) {
        query = query.eq('site_id', siteId);
      }

      if (unitId != null) {
        query = query.eq('unit_id', unitId);
      }

      if (status != null) {
        query = query.eq('status', status.value);
      }

      if (type != null) {
        query = query.eq('type', type.value);
      }

      if (priority != null) {
        query = query.eq('priority', priority.value);
      }

      if (assignedToId != null) {
        query = query.eq('assigned_to_id', assignedToId);
      }

      if (fromDate != null) {
        query = query.gte('created_at', fromDate.toIso8601String());
      }

      if (toDate != null) {
        query = query.lte('created_at', toDate.toIso8601String());
      }

      final response = await query.order('created_at', ascending: false);
      final responseList = response as List;

      Logger.debug('Work requests query returned ${responseList.length} records');

      _requests = responseList
          .map((e) => WorkRequest.fromJson(e as Map<String, dynamic>))
          .toList();

      // Cache'e kaydet
      await _cacheManager.set(
        cacheKey,
        responseList,
        ttl: const Duration(minutes: 5),
      );

      _requestsController.add(_requests);
      return _requests;
    } catch (e) {
      Logger.error('Error fetching work requests: $e');
      rethrow;
    }
  }

  /// ID ile work request getir
  Future<WorkRequest?> getById(String id) async {
    try {
      final response = await _supabase
          .from('work_requests')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      final request = WorkRequest.fromJson(response);
      _selected = request;
      _selectedController.add(_selected);
      return request;
    } catch (e) {
      Logger.error('Error fetching work request by id: $e');
      rethrow;
    }
  }

  /// Yeni work request oluştur
  Future<WorkRequest> create({
    required String title,
    String? description,
    WorkRequestType type = WorkRequestType.general,
    WorkRequestPriority priority = WorkRequestPriority.normal,
    String? siteId,
    String? unitId,
    String? controllerId,
    DateTime? expectedCompletionDate,
    int? estimatedDuration,
    double? estimatedCost,
    String? categoryId,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) async {
    if (_currentTenantId == null) {
      throw Exception('Tenant context is not set');
    }

    if (_currentUserId == null) {
      throw Exception('User context is not set');
    }

    try {
      final now = DateTime.now();
      final data = {
        'title': title,
        'description': description,
        'type': type.value,
        'status': WorkRequestStatus.draft.value,
        'priority': priority.value,
        'tenant_id': _currentTenantId,
        'requested_by_id': _currentUserId,
        'requested_at': now.toIso8601String(),
        'site_id': siteId,
        'unit_id': unitId,
        'controller_id': controllerId,
        'expected_completion_date': expectedCompletionDate?.toIso8601String(),
        'estimated_duration': estimatedDuration,
        'estimated_cost': estimatedCost,
        'category_id': categoryId,
        'tags': tags ?? [],
        'metadata': metadata ?? {},
        'created_by': _currentUserId,
        'created_at': now.toIso8601String(),
      };

      final response = await _supabase
          .from('work_requests')
          .insert(data)
          .select()
          .single();

      final request = WorkRequest.fromJson(response);

      // Listeye ekle ve stream'i güncelle
      _requests.insert(0, request);
      _requestsController.add(_requests);

      // Cache'i temizle
      await _invalidateCache();

      Logger.info('Created work request: ${request.id}');
      return request;
    } catch (e) {
      Logger.error('Error creating work request: $e');
      rethrow;
    }
  }

  /// Work request güncelle
  Future<WorkRequest> update(
    String id, {
    String? title,
    String? description,
    WorkRequestType? type,
    WorkRequestPriority? priority,
    String? siteId,
    String? unitId,
    String? controllerId,
    DateTime? expectedCompletionDate,
    int? estimatedDuration,
    double? estimatedCost,
    String? categoryId,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': _currentUserId,
      };

      if (title != null) data['title'] = title;
      if (description != null) data['description'] = description;
      if (type != null) data['type'] = type.value;
      if (priority != null) data['priority'] = priority.value;
      if (siteId != null) data['site_id'] = siteId;
      if (unitId != null) data['unit_id'] = unitId;
      if (controllerId != null) data['controller_id'] = controllerId;
      if (expectedCompletionDate != null) {
        data['expected_completion_date'] = expectedCompletionDate.toIso8601String();
      }
      if (estimatedDuration != null) data['estimated_duration'] = estimatedDuration;
      if (estimatedCost != null) data['estimated_cost'] = estimatedCost;
      if (categoryId != null) data['category_id'] = categoryId;
      if (tags != null) data['tags'] = tags;
      if (metadata != null) data['metadata'] = metadata;

      final response = await _supabase
          .from('work_requests')
          .update(data)
          .eq('id', id)
          .select()
          .single();

      final request = WorkRequest.fromJson(response);

      // Listeyi güncelle
      final index = _requests.indexWhere((r) => r.id == id);
      if (index >= 0) {
        _requests[index] = request;
        _requestsController.add(_requests);
      }

      if (_selected?.id == id) {
        _selected = request;
        _selectedController.add(_selected);
      }

      await _invalidateCache();

      Logger.info('Updated work request: $id');
      return request;
    } catch (e) {
      Logger.error('Error updating work request: $e');
      rethrow;
    }
  }

  /// Work request sil
  Future<void> delete(String id) async {
    try {
      await _supabase.from('work_requests').delete().eq('id', id);

      // Listeden kaldır
      _requests.removeWhere((r) => r.id == id);
      _requestsController.add(_requests);

      if (_selected?.id == id) {
        _selected = null;
        _selectedController.add(_selected);
      }

      await _invalidateCache();

      Logger.info('Deleted work request: $id');
    } catch (e) {
      Logger.error('Error deleting work request: $e');
      rethrow;
    }
  }

  // ============================================
  // STATUS TRANSITIONS
  // ============================================

  /// Talebi gönder (draft → submitted)
  Future<WorkRequest> submit(String id) async {
    return _updateStatus(id, WorkRequestStatus.submitted);
  }

  /// Talebi onayla
  Future<WorkRequest> approve(String id, {String? note}) async {
    final data = <String, dynamic>{
      'status': WorkRequestStatus.approved.value,
      'approved_by_id': _currentUserId,
      'approved_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'updated_by': _currentUserId,
    };

    if (note != null) {
      data['approval_note'] = note;
    }

    return _updateWithData(id, data);
  }

  /// Talebi reddet
  Future<WorkRequest> reject(String id, {required String reason}) async {
    final data = <String, dynamic>{
      'status': WorkRequestStatus.rejected.value,
      'rejection_reason': reason,
      'updated_at': DateTime.now().toIso8601String(),
      'updated_by': _currentUserId,
    };

    return _updateWithData(id, data);
  }

  /// Talep ata
  Future<WorkRequest> assign(String id, {
    String? assignedToId,
    String? assignedTeamId,
  }) async {
    if (assignedToId == null && assignedTeamId == null) {
      throw ArgumentError('assignedToId or assignedTeamId must be provided');
    }

    final data = <String, dynamic>{
      'status': WorkRequestStatus.assigned.value,
      'assigned_to_id': assignedToId,
      'assigned_team_id': assignedTeamId,
      'assigned_by_id': _currentUserId,
      'assigned_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'updated_by': _currentUserId,
    };

    return _updateWithData(id, data);
  }

  /// İşleme başla (assigned → in_progress)
  Future<WorkRequest> startWork(String id) async {
    return _updateStatus(id, WorkRequestStatus.inProgress);
  }

  /// Beklet (in_progress → on_hold)
  Future<WorkRequest> putOnHold(String id) async {
    return _updateStatus(id, WorkRequestStatus.onHold);
  }

  /// Devam et (on_hold → in_progress)
  Future<WorkRequest> resume(String id) async {
    return _updateStatus(id, WorkRequestStatus.inProgress);
  }

  /// Tamamla
  Future<WorkRequest> complete(String id, {
    int? actualDuration,
    double? actualCost,
  }) async {
    final data = <String, dynamic>{
      'status': WorkRequestStatus.completed.value,
      'actual_completion_date': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'updated_by': _currentUserId,
    };

    if (actualDuration != null) {
      data['actual_duration'] = actualDuration;
    }

    if (actualCost != null) {
      data['actual_cost'] = actualCost;
    }

    return _updateWithData(id, data);
  }

  /// İptal et
  Future<WorkRequest> cancel(String id, {String? reason}) async {
    final data = <String, dynamic>{
      'status': WorkRequestStatus.cancelled.value,
      'updated_at': DateTime.now().toIso8601String(),
      'updated_by': _currentUserId,
    };

    if (reason != null) {
      data['rejection_reason'] = reason;
    }

    return _updateWithData(id, data);
  }

  /// Kapat (completed → closed)
  Future<WorkRequest> close(String id) async {
    return _updateStatus(id, WorkRequestStatus.closed);
  }

  // ============================================
  // NOTES
  // ============================================

  /// Not ekle
  Future<WorkRequest> addNote(String requestId, {
    required String content,
    WorkRequestNoteType type = WorkRequestNoteType.comment,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User context is not set');
    }

    try {
      // Mevcut request'i al
      final request = await getById(requestId);
      if (request == null) {
        throw Exception('Work request not found');
      }

      final note = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'content': content,
        'type': type.value,
        'author_id': _currentUserId,
        'created_at': DateTime.now().toIso8601String(),
      };

      final notes = [...request.notes.map((n) => n.toJson()), note];

      final response = await _supabase
          .from('work_requests')
          .update({
            'notes': notes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId)
          .select()
          .single();

      final updated = WorkRequest.fromJson(response);

      // Listeyi güncelle
      final index = _requests.indexWhere((r) => r.id == requestId);
      if (index >= 0) {
        _requests[index] = updated;
        _requestsController.add(_requests);
      }

      if (_selected?.id == requestId) {
        _selected = updated;
        _selectedController.add(_selected);
      }

      return updated;
    } catch (e) {
      Logger.error('Error adding note: $e');
      rethrow;
    }
  }

  // ============================================
  // STATISTICS
  // ============================================

  /// İstatistikleri getir
  Future<WorkRequestStats> getStats({
    String? siteId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    if (_currentTenantId == null) {
      throw Exception('Tenant context is not set');
    }

    try {
      var query = _supabase
          .from('work_requests')
          .select('status, priority, type')
          .eq('tenant_id', _currentTenantId!);

      if (siteId != null) {
        query = query.eq('site_id', siteId);
      }

      if (fromDate != null) {
        query = query.gte('created_at', fromDate.toIso8601String());
      }

      if (toDate != null) {
        query = query.lte('created_at', toDate.toIso8601String());
      }

      final response = await query;
      final data = response as List;

      int total = data.length;
      int pending = 0;
      int active = 0;
      int completed = 0;

      for (final item in data) {
        final status = WorkRequestStatus.fromString(item['status'] as String?);
        if (status == WorkRequestStatus.draft || status == WorkRequestStatus.submitted) {
          pending++;
        } else if (status.isActionable) {
          active++;
        } else if (status == WorkRequestStatus.completed || status == WorkRequestStatus.closed) {
          completed++;
        }
      }

      return WorkRequestStats(
        totalCount: total,
        pendingCount: pending,
        activeCount: active,
        completedCount: completed,
      );
    } catch (e) {
      Logger.error('Error fetching work request stats: $e');
      rethrow;
    }
  }

  // ============================================
  // PRIVATE METHODS
  // ============================================

  /// Durum güncelle
  Future<WorkRequest> _updateStatus(String id, WorkRequestStatus status) async {
    final data = <String, dynamic>{
      'status': status.value,
      'updated_at': DateTime.now().toIso8601String(),
      'updated_by': _currentUserId,
    };

    return _updateWithData(id, data);
  }

  /// Data ile güncelle
  Future<WorkRequest> _updateWithData(String id, Map<String, dynamic> data) async {
    try {
      final response = await _supabase
          .from('work_requests')
          .update(data)
          .eq('id', id)
          .select()
          .single();

      final request = WorkRequest.fromJson(response);

      // Listeyi güncelle
      final index = _requests.indexWhere((r) => r.id == id);
      if (index >= 0) {
        _requests[index] = request;
        _requestsController.add(_requests);
      }

      if (_selected?.id == id) {
        _selected = request;
        _selectedController.add(_selected);
      }

      await _invalidateCache();

      return request;
    } catch (e) {
      Logger.error('Error updating work request: $e');
      rethrow;
    }
  }

  /// Filtreleri uygula
  List<WorkRequest> _applyFilters({
    WorkRequestStatus? status,
    WorkRequestType? type,
    WorkRequestPriority? priority,
    String? assignedToId,
  }) {
    var filtered = _requests;

    if (status != null) {
      filtered = filtered.where((r) => r.status == status).toList();
    }

    if (type != null) {
      filtered = filtered.where((r) => r.type == type).toList();
    }

    if (priority != null) {
      filtered = filtered.where((r) => r.priority == priority).toList();
    }

    if (assignedToId != null) {
      filtered = filtered.where((r) => r.assignedToId == assignedToId).toList();
    }

    return filtered;
  }

  /// Cache'i temizle
  Future<void> _invalidateCache() async {
    if (_currentTenantId != null) {
      final pattern = 'work_requests_$_currentTenantId';
      await _cacheManager.deleteWhere((key) => key.startsWith(pattern));
    }
  }

  /// Seçili request'i ayarla
  void selectRequest(WorkRequest? request) {
    _selected = request;
    _selectedController.add(_selected);
  }

  /// Temizle
  void dispose() {
    _requestsController.close();
    _selectedController.close();
  }
}
