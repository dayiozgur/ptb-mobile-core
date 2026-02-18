import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../utils/logger.dart';
import 'todo_model.dart';

/// Todo Service
///
/// Gorev (todo) yonetimi saglar. CRUD operasyonlari,
/// paylasim, istatistik ve filtreleme islemleri.
class TodoService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  /// Todo listesi stream
  final _todosController = StreamController<List<TodoItem>>.broadcast();

  /// Secili todo stream
  final _selectedController = StreamController<TodoItem?>.broadcast();

  /// Mevcut tenant ID
  String? _currentTenantId;

  /// Mevcut kullanici ID
  String? _currentUserId;

  /// Mevcut todo listesi
  List<TodoItem> _todos = [];

  /// Secili todo
  TodoItem? _selected;

  /// Cache TTL
  static const _cacheTtl = Duration(minutes: 5);

  TodoService({
    required SupabaseClient supabase,
    required CacheManager cacheManager,
  })  : _supabase = supabase,
        _cacheManager = cacheManager;

  // ============================================
  // GETTERS
  // ============================================

  /// Todo listesi stream
  Stream<List<TodoItem>> get todosStream => _todosController.stream;

  /// Secili todo stream
  Stream<TodoItem?> get selectedStream => _selectedController.stream;

  /// Mevcut todo listesi
  List<TodoItem> get todos => List.unmodifiable(_todos);

  /// Secili todo
  TodoItem? get selected => _selected;

  /// Bekleyen todolar
  List<TodoItem> get pendingTodos =>
      _todos.where((t) => t.status == TodoStatus.pending && t.active).toList();

  /// Suresi gecmis todolar
  List<TodoItem> get overdueTodos =>
      _todos.where((t) => t.isOverdue && t.active).toList();

  // ============================================
  // CONTEXT
  // ============================================

  /// Tenant context ayarla
  void setTenant(String tenantId) {
    if (_currentTenantId != tenantId) {
      _currentTenantId = tenantId;
      _todos = [];
      _selected = null;
      _todosController.add(_todos);
      _selectedController.add(_selected);
    }
  }

  /// Kullanici context ayarla
  void setUser(String userId) {
    _currentUserId = userId;
  }

  /// Context temizle
  void clearContext() {
    _currentTenantId = null;
    _currentUserId = null;
    _todos = [];
    _selected = null;
    _todosController.add(_todos);
    _selectedController.add(_selected);
  }

  // ============================================
  // CRUD OPERATIONS
  // ============================================

  /// Todolari getir
  Future<List<TodoItem>> getTodos({
    TodoStatus? status,
    TodoPriority? priority,
    String? assignedTo,
    bool? overdue,
    bool forceRefresh = false,
  }) async {
    if (_currentTenantId == null) {
      throw Exception('Tenant context is not set');
    }

    final cacheKey = 'todos_$_currentTenantId';

    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        try {
          _todos = cached
              .map((e) => TodoItem.fromJson(e as Map<String, dynamic>))
              .toList();
          _todosController.add(_todos);
          return _applyFilters(
            status: status,
            priority: priority,
            assignedTo: assignedTo,
            overdue: overdue,
          );
        } catch (cacheError) {
          Logger.warning('Failed to parse todos from cache: $cacheError');
          await _cacheManager.delete(cacheKey);
        }
      }
    }

    try {
      var query = _supabase
          .from('todo_items')
          .select('*, staffs(name)')
          .eq('tenant_id', _currentTenantId!)
          .eq('active', true);

      if (status != null) {
        query = query.eq('status', status.value);
      }

      if (priority != null) {
        query = query.eq('priority', priority.value);
      }

      if (assignedTo != null) {
        query = query.eq('assigned_to', assignedTo);
      }

      final response = await query.order('created_at', ascending: false);
      final responseList = response as List;

      Logger.debug('Todo query returned ${responseList.length} records');

      _todos = responseList
          .map((e) => TodoItem.fromJson(e as Map<String, dynamic>))
          .toList();

      await _cacheManager.set(cacheKey, responseList, ttl: _cacheTtl);

      _todosController.add(_todos);

      if (overdue == true) {
        return _todos.where((t) => t.isOverdue).toList();
      }

      return _todos;
    } catch (e) {
      Logger.error('Error fetching todos: $e');
      rethrow;
    }
  }

  /// Tek todo getir
  Future<TodoItem?> getTodo(String id) async {
    try {
      final response = await _supabase
          .from('todo_items')
          .select('*, staffs(name)')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      final todo = TodoItem.fromJson(response);
      _selected = todo;
      _selectedController.add(_selected);
      return todo;
    } catch (e) {
      Logger.error('Error fetching todo: $e');
      rethrow;
    }
  }

  /// Todo olustur
  Future<TodoItem> createTodo({
    required String title,
    String? description,
    TodoPriority priority = TodoPriority.medium,
    DateTime? dueDate,
    String? assignedTo,
    String? linkedEventId,
  }) async {
    if (_currentTenantId == null) {
      throw Exception('Tenant context is not set');
    }
    if (_currentUserId == null) {
      throw Exception('User context is not set');
    }

    try {
      final data = {
        'title': title,
        'description': description,
        'status': TodoStatus.pending.value,
        'priority': priority.value,
        'due_date': dueDate?.toIso8601String(),
        'tenant_id': _currentTenantId,
        'created_by': _currentUserId,
        'assigned_to': assignedTo,
        'linked_event_id': linkedEventId,
      };

      final response = await _supabase
          .from('todo_items')
          .insert(data)
          .select('*, staffs(name)')
          .single();

      final todo = TodoItem.fromJson(response);

      _todos.insert(0, todo);
      _todosController.add(_todos);

      await _invalidateCache();

      Logger.info('Created todo: ${todo.id}');
      return todo;
    } catch (e) {
      Logger.error('Error creating todo: $e');
      rethrow;
    }
  }

  /// Todo guncelle
  Future<TodoItem> updateTodo(
    String id, {
    String? title,
    String? description,
    TodoStatus? status,
    TodoPriority? priority,
    DateTime? dueDate,
    String? assignedTo,
    String? linkedEventId,
  }) async {
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': _currentUserId,
      };

      if (title != null) data['title'] = title;
      if (description != null) data['description'] = description;
      if (status != null) data['status'] = status.value;
      if (priority != null) data['priority'] = priority.value;
      if (dueDate != null) data['due_date'] = dueDate.toIso8601String();
      if (assignedTo != null) data['assigned_to'] = assignedTo;
      if (linkedEventId != null) data['linked_event_id'] = linkedEventId;

      final response = await _supabase
          .from('todo_items')
          .update(data)
          .eq('id', id)
          .select('*, staffs(name)')
          .single();

      final todo = TodoItem.fromJson(response);

      final index = _todos.indexWhere((t) => t.id == id);
      if (index >= 0) {
        _todos[index] = todo;
        _todosController.add(_todos);
      }

      if (_selected?.id == id) {
        _selected = todo;
        _selectedController.add(_selected);
      }

      await _invalidateCache();

      Logger.info('Updated todo: $id');
      return todo;
    } catch (e) {
      Logger.error('Error updating todo: $e');
      rethrow;
    }
  }

  /// Todo tamamla
  Future<TodoItem> completeTodo(String id) async {
    return updateTodo(
      id,
      status: TodoStatus.completed,
    );
  }

  /// Todo sil (soft delete)
  Future<void> deleteTodo(String id) async {
    try {
      await _supabase
          .from('todo_items')
          .update({
            'active': false,
            'updated_at': DateTime.now().toIso8601String(),
            'updated_by': _currentUserId,
          })
          .eq('id', id);

      _todos.removeWhere((t) => t.id == id);
      _todosController.add(_todos);

      if (_selected?.id == id) {
        _selected = null;
        _selectedController.add(_selected);
      }

      await _invalidateCache();

      Logger.info('Deleted todo: $id');
    } catch (e) {
      Logger.error('Error deleting todo: $e');
      rethrow;
    }
  }

  // ============================================
  // SHARING
  // ============================================

  /// Todo paylas
  Future<TodoShare> shareTodo({
    required String todoId,
    String? sharedWithUser,
    String? sharedWithTeam,
    String? sharedWithDepartment,
    bool canEdit = false,
    bool canDelete = false,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User context is not set');
    }

    try {
      final data = {
        'todo_id': todoId,
        'shared_by': _currentUserId,
        'shared_with_user': sharedWithUser,
        'shared_with_team': sharedWithTeam,
        'shared_with_department': sharedWithDepartment,
        'can_edit': canEdit,
        'can_delete': canDelete,
      };

      final response = await _supabase
          .from('todo_shares')
          .insert(data)
          .select()
          .single();

      Logger.info('Shared todo: $todoId');
      return TodoShare.fromJson(response);
    } catch (e) {
      Logger.error('Error sharing todo: $e');
      rethrow;
    }
  }

  /// Paylasimlari getir
  Future<List<TodoShare>> getShares(String todoId) async {
    try {
      final response = await _supabase
          .from('todo_shares')
          .select()
          .eq('todo_id', todoId);

      return (response as List)
          .map((e) => TodoShare.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('Error fetching todo shares: $e');
      rethrow;
    }
  }

  /// Paylasim kaldir
  Future<void> removeShare(String shareId) async {
    try {
      await _supabase.from('todo_shares').delete().eq('id', shareId);
      Logger.info('Removed todo share: $shareId');
    } catch (e) {
      Logger.error('Error removing todo share: $e');
      rethrow;
    }
  }

  // ============================================
  // STATISTICS
  // ============================================

  /// Todo istatistikleri
  Future<TodoStats> getTodoStats() async {
    if (_currentTenantId == null) {
      throw Exception('Tenant context is not set');
    }

    try {
      final response = await _supabase
          .from('todo_items')
          .select('status, due_date')
          .eq('tenant_id', _currentTenantId!)
          .eq('active', true);

      final data = response as List;
      final now = DateTime.now();

      int pending = 0;
      int inProgress = 0;
      int completed = 0;
      int overdue = 0;

      for (final item in data) {
        final status = TodoStatus.fromString(item['status'] as String?);
        final dueDate = item['due_date'] != null
            ? DateTime.tryParse(item['due_date'] as String)
            : null;

        switch (status) {
          case TodoStatus.pending:
            pending++;
            break;
          case TodoStatus.inProgress:
            inProgress++;
            break;
          case TodoStatus.completed:
            completed++;
            break;
          case TodoStatus.cancelled:
            break;
        }

        if (status.isOpen && dueDate != null && dueDate.isBefore(now)) {
          overdue++;
        }
      }

      return TodoStats(
        total: data.length,
        pending: pending,
        inProgress: inProgress,
        completed: completed,
        overdue: overdue,
      );
    } catch (e) {
      Logger.error('Error fetching todo stats: $e');
      rethrow;
    }
  }

  // ============================================
  // PRIVATE METHODS
  // ============================================

  List<TodoItem> _applyFilters({
    TodoStatus? status,
    TodoPriority? priority,
    String? assignedTo,
    bool? overdue,
  }) {
    var filtered = _todos.where((t) => t.active).toList();

    if (status != null) {
      filtered = filtered.where((t) => t.status == status).toList();
    }
    if (priority != null) {
      filtered = filtered.where((t) => t.priority == priority).toList();
    }
    if (assignedTo != null) {
      filtered = filtered.where((t) => t.assignedTo == assignedTo).toList();
    }
    if (overdue == true) {
      filtered = filtered.where((t) => t.isOverdue).toList();
    }

    return filtered;
  }

  Future<void> _invalidateCache() async {
    if (_currentTenantId != null) {
      final pattern = 'todos_$_currentTenantId';
      await _cacheManager.deleteWhere((key) => key.startsWith(pattern));
    }
  }

  /// Secili todo ayarla
  void selectTodo(TodoItem? todo) {
    _selected = todo;
    _selectedController.add(_selected);
  }

  /// Temizle
  void dispose() {
    _todosController.close();
    _selectedController.close();
  }
}
