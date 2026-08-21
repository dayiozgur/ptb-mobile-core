import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../utils/logger.dart';
import 'workflow_model.dart';

/// Workflow Service
///
/// IoT otomasyon workflow'larını yönetir.
class WorkflowService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  /// Workflow listesi stream
  final _workflowsController = StreamController<List<Workflow>>.broadcast();

  /// Seçili workflow stream
  final _selectedWorkflow = StreamController<Workflow?>.broadcast();

  /// Çalıştırma bildirimi stream
  final _runNotifications = StreamController<WorkflowRun>.broadcast();

  /// Mevcut tenant ID
  String? _currentTenantId;

  /// Mevcut workflow listesi
  List<Workflow> _workflows = [];

  /// Seçili workflow
  Workflow? _selected;

  WorkflowService({
    required SupabaseClient supabase,
    required CacheManager cacheManager,
  })  : _supabase = supabase,
        _cacheManager = cacheManager;

  // ============================================
  // GETTERS
  // ============================================

  /// Workflow listesi stream
  Stream<List<Workflow>> get workflowsStream => _workflowsController.stream;

  /// Seçili workflow stream
  Stream<Workflow?> get selectedStream => _selectedWorkflow.stream;

  /// Çalıştırma bildirimi stream
  Stream<WorkflowRun> get runNotifications => _runNotifications.stream;

  /// Mevcut workflow listesi
  List<Workflow> get workflows => List.unmodifiable(_workflows);

  /// Seçili workflow
  Workflow? get selected => _selected;

  /// Aktif workflow listesi
  List<Workflow> get activeWorkflows =>
      _workflows.where((w) => w.isRunnable).toList();

  /// Taslak workflow listesi
  List<Workflow> get draftWorkflows =>
      _workflows.where((w) => w.isDraft).toList();

  // ============================================
  // TENANT CONTEXT
  // ============================================

  /// Tenant context'ini ayarla
  void setTenant(String tenantId) {
    if (_currentTenantId != tenantId) {
      _currentTenantId = tenantId;
      _workflows = [];
      _selected = null;
      _workflowsController.add(_workflows);
      _selectedWorkflow.add(_selected);
    }
  }

  /// Tenant context'ini temizle
  void clearTenant() {
    _currentTenantId = null;
    _workflows = [];
    _selected = null;
    _workflowsController.add(_workflows);
    _selectedWorkflow.add(_selected);
  }

  // ============================================
  // CRUD OPERATIONS
  // ============================================

  /// Tüm workflow'ları getir
  Future<List<Workflow>> getAll({
    WorkflowType? type,
    WorkflowStatus? status,
    String? siteId,
    bool forceRefresh = false,
  }) async {
    if (_currentTenantId == null) {
      throw Exception('Tenant context is not set');
    }

    final cacheKey = 'workflows_${_currentTenantId}_${type?.value ?? 'all'}';

    // Cache kontrolü
    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        _workflows = cached
            .map((e) => Workflow.fromJson(e as Map<String, dynamic>))
            .toList();
        _workflowsController.add(_workflows);
        return _workflows;
      }
    }

    try {
      var query = _supabase
          .from('workflows')
          .select()
          .eq('tenant_id', _currentTenantId!);

      if (type != null) {
        query = query.eq('type', type.value);
      }

      if (status != null) {
        query = query.eq('status', status.value);
      }

      if (siteId != null) {
        query = query.eq('site_id', siteId);
      }

      final response = await query.order('name');

      _workflows = (response as List)
          .map((e) => Workflow.fromJson(e as Map<String, dynamic>))
          .toList();

      // Cache'e kaydet
      await _cacheManager.set(
        cacheKey,
        _workflows.map((e) => e.toJson()).toList(),
        ttl: const Duration(minutes: 5),
      );

      _workflowsController.add(_workflows);
      return _workflows;
    } catch (e, stackTrace) {
      Logger.error('Failed to get workflows', e, stackTrace);
      rethrow;
    }
  }

  /// ID ile workflow getir
  Future<Workflow?> getById(String id) async {
    // Önce memory cache'den kontrol
    final cached = _workflows.where((w) => w.id == id).firstOrNull;
    if (cached != null) return cached;

    try {
      final response = await _supabase
          .from('workflows')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      return Workflow.fromJson(response);
    } catch (e, stackTrace) {
      Logger.error('Failed to get workflow by id', e, stackTrace);
      rethrow;
    }
  }

  /// Workflow oluştur
  Future<Workflow> create(Workflow workflow) async {
    if (_currentTenantId == null) {
      throw Exception('Tenant context is not set');
    }

    try {
      final data = workflow.toJson();
      data['tenant_id'] = _currentTenantId;
      data.remove('id');
      data['created_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('workflows')
          .insert(data)
          .select()
          .single();

      final created = Workflow.fromJson(response);

      _workflows.add(created);
      _workflowsController.add(_workflows);

      // Cache'i temizle
      await _invalidateCache();

      Logger.info('Workflow created: ${created.name}');
      return created;
    } catch (e, stackTrace) {
      Logger.error('Failed to create workflow', e, stackTrace);
      rethrow;
    }
  }

  /// Workflow güncelle
  Future<Workflow> update(Workflow workflow) async {
    try {
      final data = workflow.toJson();
      data['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('workflows')
          .update(data)
          .eq('id', workflow.id)
          .select()
          .single();

      final updated = Workflow.fromJson(response);

      // Liste güncelle
      final index = _workflows.indexWhere((w) => w.id == workflow.id);
      if (index != -1) {
        _workflows[index] = updated;
        _workflowsController.add(_workflows);
      }

      // Seçili workflow güncelle
      if (_selected?.id == workflow.id) {
        _selected = updated;
        _selectedWorkflow.add(_selected);
      }

      // Cache'i temizle
      await _invalidateCache();

      Logger.info('Workflow updated: ${updated.name}');
      return updated;
    } catch (e, stackTrace) {
      Logger.error('Failed to update workflow', e, stackTrace);
      rethrow;
    }
  }

  /// Workflow sil
  Future<void> delete(String id) async {
    try {
      await _supabase.from('workflows').delete().eq('id', id);

      _workflows.removeWhere((w) => w.id == id);
      _workflowsController.add(_workflows);

      if (_selected?.id == id) {
        _selected = null;
        _selectedWorkflow.add(_selected);
      }

      // Cache'i temizle
      await _invalidateCache();

      Logger.info('Workflow deleted: $id');
    } catch (e, stackTrace) {
      Logger.error('Failed to delete workflow', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // STATUS OPERATIONS
  // ============================================

  /// Workflow durumunu güncelle
  Future<void> updateStatus(String id, WorkflowStatus status) async {
    try {
      await _supabase.from('workflows').update({
        'status': status.value,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      // Liste güncelle
      final index = _workflows.indexWhere((w) => w.id == id);
      if (index != -1) {
        _workflows[index] = _workflows[index].copyWith(status: status);
        _workflowsController.add(_workflows);
      }

      Logger.debug('Workflow status updated: $id -> ${status.value}');
    } catch (e, stackTrace) {
      Logger.error('Failed to update workflow status', e, stackTrace);
      rethrow;
    }
  }

  /// Workflow'u aktive et
  Future<void> activate(String id) async {
    await updateStatus(id, WorkflowStatus.active);
  }

  /// Workflow'u deaktive et
  Future<void> deactivate(String id) async {
    await updateStatus(id, WorkflowStatus.inactive);
  }

  // ============================================
  // EXECUTION
  // ============================================

  /// Workflow'u manuel çalıştır
  Future<WorkflowRun> runManually(String id) async {
    final workflow = await getById(id);
    if (workflow == null) {
      throw Exception('Workflow not found: $id');
    }

    if (!workflow.hasActions) {
      throw Exception('Workflow has no actions: $id');
    }

    final runId = DateTime.now().millisecondsSinceEpoch.toString();
    final startedAt = DateTime.now();

    try {
      Logger.info('Running workflow manually: ${workflow.name}');

      // Koşulları kontrol et
      if (workflow.conditions.isNotEmpty) {
        final conditionsMet = await _evaluateConditions(workflow);
        if (!conditionsMet) {
          return WorkflowRun(
            id: runId,
            workflowId: id,
            startedAt: startedAt,
            completedAt: DateTime.now(),
            result: WorkflowRunResult.cancelled,
            errorMessage: 'Conditions not met',
          );
        }
      }

      // Eylemleri çalıştır
      final actionResults = <Map<String, dynamic>>[];
      for (final action in workflow.actions.where((a) => a.enabled)) {
        final result = await _executeAction(action);
        actionResults.add(result);

        if (result['success'] != true) {
          // Eylem başarısız oldu
          final run = WorkflowRun(
            id: runId,
            workflowId: id,
            startedAt: startedAt,
            completedAt: DateTime.now(),
            result: WorkflowRunResult.partial,
            errorMessage: result['error'] as String?,
            actionResults: actionResults,
          );

          _runNotifications.add(run);
          return run;
        }
      }

      // Başarılı
      final run = WorkflowRun(
        id: runId,
        workflowId: id,
        startedAt: startedAt,
        completedAt: DateTime.now(),
        result: WorkflowRunResult.success,
        actionResults: actionResults,
      );

      // İstatistikleri güncelle
      await _updateRunStats(id, true);

      _runNotifications.add(run);
      Logger.info('Workflow completed successfully: ${workflow.name}');
      return run;
    } catch (e, stackTrace) {
      Logger.error('Workflow execution failed', e, stackTrace);

      final run = WorkflowRun(
        id: runId,
        workflowId: id,
        startedAt: startedAt,
        completedAt: DateTime.now(),
        result: WorkflowRunResult.failure,
        errorMessage: e.toString(),
      );

      // İstatistikleri güncelle
      await _updateRunStats(id, false);

      _runNotifications.add(run);
      return run;
    }
  }

  /// Koşulları değerlendir
  Future<bool> _evaluateConditions(Workflow workflow) async {
    // Basit implementasyon - gerçek uygulamada variable değerlerini
    // kontrol etmek gerekir
    return true;
  }

  /// Eylemi çalıştır
  Future<Map<String, dynamic>> _executeAction(WorkflowAction action) async {
    // Basit implementasyon - gerçek uygulamada eylem tipine göre
    // farklı işlemler yapılır
    try {
      switch (action.type) {
        case ActionType.delay:
          final delayMs = action.params['delay_ms'] as int? ?? 1000;
          await Future.delayed(Duration(milliseconds: delayMs));
          break;
        case ActionType.writeLog:
          Logger.info('Workflow action log: ${action.value}');
          break;
        default:
          // Diğer eylemler için stub
          break;
      }

      return {
        'action_id': action.id,
        'type': action.type.value,
        'success': true,
        'executed_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'action_id': action.id,
        'type': action.type.value,
        'success': false,
        'error': e.toString(),
        'executed_at': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Çalıştırma istatistiklerini güncelle
  Future<void> _updateRunStats(String id, bool success) async {
    try {
      final workflow = _workflows.where((w) => w.id == id).firstOrNull;
      if (workflow == null) return;

      await _supabase.from('workflows').update({
        'last_run_at': DateTime.now().toIso8601String(),
        'last_run_result': success
            ? WorkflowRunResult.success.value
            : WorkflowRunResult.failure.value,
        'run_count': workflow.runCount + 1,
        'success_count': success ? workflow.successCount + 1 : workflow.successCount,
        'failure_count': success ? workflow.failureCount : workflow.failureCount + 1,
      }).eq('id', id);
    } catch (e) {
      Logger.warning('Failed to update run stats', e);
    }
  }

  // ============================================
  // HISTORY
  // ============================================

  /// Çalıştırma geçmişini getir
  Future<List<WorkflowRun>> getRunHistory(
    String workflowId, {
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from('workflow_runs')
          .select()
          .eq('workflow_id', workflowId)
          .order('started_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((e) => WorkflowRun.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      Logger.error('Failed to get workflow run history', e, stackTrace);
      return [];
    }
  }

  // ============================================
  // SELECTION
  // ============================================

  /// Workflow seç
  void select(Workflow? workflow) {
    _selected = workflow;
    _selectedWorkflow.add(_selected);
  }

  /// ID ile workflow seç
  Future<void> selectById(String id) async {
    final workflow = await getById(id);
    select(workflow);
  }

  // ============================================
  // SEARCH
  // ============================================

  /// Workflow ara
  Future<List<Workflow>> search(String query) async {
    if (_currentTenantId == null) {
      return [];
    }

    if (query.isEmpty) {
      return _workflows;
    }

    final lowerQuery = query.toLowerCase();
    return _workflows.where((w) {
      return w.name.toLowerCase().contains(lowerQuery) ||
          (w.code?.toLowerCase().contains(lowerQuery) ?? false) ||
          (w.description?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  // ============================================
  // APPROVAL GATES (human-in-the-loop)
  // ============================================

  /// Mevcut kullanıcıya atanmış BEKLEYEN workflow onayları — herhangi bir
  /// entity için (leave'e özel değil). Web `WorkflowApprovalsComponent` ile
  /// birebir aynı kaynak: `fn_workflow_my_approvals()` RPC.
  ///
  /// RPC yalnızca `approver_ids` içinde `auth.uid()` bulunan ve
  /// `status='pending'` olan, tenant-scoped `workflow_approvals` satırlarını
  /// döner. UI'a asla exception fırlatmaz — hata/boş durumda `[]` döner.
  Future<List<WorkflowApproval>> pendingApprovals() async {
    try {
      final response = await _supabase.rpc('fn_workflow_my_approvals');
      if (response is List) {
        return response
            .whereType<Map<String, dynamic>>()
            .map(WorkflowApproval.fromJson)
            .toList();
      }
      return [];
    } catch (e, stackTrace) {
      Logger.error('Failed to load pending approvals', e, stackTrace);
      return [];
    }
  }

  /// Bir workflow onay adımına karar ver — web ile aynı sözleşme:
  /// `fn_workflow_approval_decide(p_id, p_decision, p_comment)` RPC.
  ///
  /// NOT: Bu, jenerik workflow-gate sistemidir (`workflow_approvals` +
  /// suspend/resume). İzin (leave) akışındaki `approval-decision` Edge
  /// Function AYRI bir sistemdir (`form_approval_steps`) — buraya bir
  /// `workflow_approvals.id` verilirse eşleşmez. RPC başarıda `{ok:true}`
  /// döner, yetki/durum hatasında exception fırlatır (UI'a iletilir).
  Future<void> decideApproval({
    required String approvalId,
    required bool approve,
    String? note,
  }) async {
    try {
      await _supabase.rpc('fn_workflow_approval_decide', params: {
        'p_id': approvalId,
        'p_decision': approve ? 'approved' : 'rejected',
        'p_comment': (note != null && note.trim().isNotEmpty)
            ? note.trim()
            : null,
      });
    } catch (e, stackTrace) {
      Logger.error('Failed to decide workflow approval', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // HELPERS
  // ============================================

  /// Cache'i temizle
  Future<void> _invalidateCache() async {
    if (_currentTenantId != null) {
      await _cacheManager.deleteByPrefix('workflows_$_currentTenantId');
    }
  }

  /// Servisi temizle
  void dispose() {
    _workflowsController.close();
    _selectedWorkflow.close();
    _runNotifications.close();
  }
}

/// Jenerik workflow onay-gate satırı — `fn_workflow_my_approvals()` çıktısı.
///
/// Herhangi bir entity için bekleyen bir insan-onayını temsil eder (leave'e
/// özel değil). Alanlar RPC'nin döndürdüğü kolonlarla birebir eşleşir.
class WorkflowApproval {
  /// `workflow_approvals.id` — karar RPC'sine (`p_id`) verilecek anahtar.
  final String id;
  final String? workflowId;
  final String? executionId;

  /// Onay kartının başlığı (entity konusu). Boşsa UI varsayılan gösterir.
  final String? title;

  /// Açıklama/gerekçe metni (talep eden vb. gate tarafından yazılır).
  final String? message;

  /// Onaya konu entity tipi (örn. `leave_request`, `purchase_order`).
  final String? entityType;
  final String? entityId;

  /// Onayın zaman aşımına uğrayacağı an (null = süresiz).
  final DateTime? timeoutAt;

  /// Onayın oluşturulma anı.
  final DateTime? createdAt;

  const WorkflowApproval({
    required this.id,
    this.workflowId,
    this.executionId,
    this.title,
    this.message,
    this.entityType,
    this.entityId,
    this.timeoutAt,
    this.createdAt,
  });

  factory WorkflowApproval.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    String? asString(dynamic v) =>
        (v != null && v.toString().isNotEmpty) ? v.toString() : null;

    return WorkflowApproval(
      id: json['id']?.toString() ?? '',
      workflowId: asString(json['workflow_id']),
      executionId: asString(json['execution_id']),
      title: asString(json['title']),
      message: asString(json['message']),
      entityType: asString(json['entity_type']),
      entityId: asString(json['entity_id']),
      timeoutAt: parseDate(json['timeout_at']),
      createdAt: parseDate(json['created_at']),
    );
  }
}
