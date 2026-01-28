import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../utils/logger.dart';
import 'variable_model.dart';

/// Variable Service
///
/// IoT değişkenlerini/tagları yönetir.
///
/// NOT: Variables tablosunda tenant_id ve controller_id kolonları YOKTUR.
/// Variables, device_model bazlı şablonlardır.
/// Controller bağlantısı için IoTRealtimeService kullanılmalıdır.
class VariableService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  /// Variable listesi stream
  final _variablesController = StreamController<List<Variable>>.broadcast();

  /// Seçili variable stream
  final _selectedVariable = StreamController<Variable?>.broadcast();

  /// Değer güncelleme stream
  final _valueUpdates = StreamController<VariableValueUpdate>.broadcast();

  /// Mevcut tenant ID (geriye uyumluluk için tutulur ama DB sorgularında kullanılmaz)
  String? _currentTenantId;

  /// Mevcut variable listesi
  List<Variable> _variables = [];

  /// Seçili variable
  Variable? _selected;

  VariableService({
    required SupabaseClient supabase,
    required CacheManager cacheManager,
  })  : _supabase = supabase,
        _cacheManager = cacheManager;

  // ============================================
  // GETTERS
  // ============================================

  /// Variable listesi stream
  Stream<List<Variable>> get variablesStream => _variablesController.stream;

  /// Seçili variable stream
  Stream<Variable?> get selectedStream => _selectedVariable.stream;

  /// Değer güncelleme stream
  Stream<VariableValueUpdate> get valueUpdates => _valueUpdates.stream;

  /// Mevcut variable listesi
  List<Variable> get variables => List.unmodifiable(_variables);

  /// Seçili variable
  Variable? get selected => _selected;

  // ============================================
  // TENANT CONTEXT
  // ============================================

  /// Tenant context'ini ayarla
  void setTenant(String tenantId) {
    if (_currentTenantId != tenantId) {
      _currentTenantId = tenantId;
      _variables = [];
      _selected = null;
      _variablesController.add(_variables);
      _selectedVariable.add(_selected);
    }
  }

  /// Tenant context'ini temizle
  void clearTenant() {
    _currentTenantId = null;
    _variables = [];
    _selected = null;
    _variablesController.add(_variables);
    _selectedVariable.add(_selected);
  }

  // ============================================
  // CRUD OPERATIONS
  // ============================================

  /// Tüm variable'ları getir
  ///
  /// NOT: DB'de tenant_id yok, bu yüzden tüm variable'ları döndürür.
  /// Daha iyi performans için getByDeviceModel kullanın.
  Future<List<Variable>> getAll({
    String? deviceModelId,
    VariableCategory? category,
    bool forceRefresh = false,
    int limit = 1000,
  }) async {
    final cacheKey = 'variables_${deviceModelId ?? 'all'}_${category?.value ?? 'all'}';

    // Cache kontrolü
    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        _variables = cached
            .map((e) => Variable.fromJson(e as Map<String, dynamic>))
            .toList();
        _variablesController.add(_variables);
        return _variables;
      }
    }

    try {
      var query = _supabase.from('variables').select();

      if (deviceModelId != null) {
        query = query.eq('device_model_id', deviceModelId);
      }

      if (category != null) {
        query = query.eq('grp_category', category.value);
      }

      final response = await query.order('name').limit(limit);

      _variables = (response as List)
          .map((e) => Variable.fromJson(e as Map<String, dynamic>))
          .toList();

      // Cache'e kaydet
      await _cacheManager.set(
        cacheKey,
        _variables.map((e) => e.toJson()).toList(),
        ttl: const Duration(minutes: 2),
      );

      _variablesController.add(_variables);
      return _variables;
    } catch (e, stackTrace) {
      Logger.error('Failed to get variables', e, stackTrace);
      rethrow;
    }
  }

  /// Device model'e ait variable'ları getir
  ///
  /// Variables, device_model bazlı şablonlardır.
  /// Aynı device_model'e sahip controller'lar bu variable setini paylaşır.
  Future<List<Variable>> getByDeviceModel(
    String deviceModelId, {
    bool forceRefresh = false,
  }) async {
    return getAll(deviceModelId: deviceModelId, forceRefresh: forceRefresh);
  }

  /// Birden fazla device model için variable'ları getir
  Future<List<Variable>> getByDeviceModels(
    List<String> deviceModelIds, {
    bool forceRefresh = false,
  }) async {
    if (deviceModelIds.isEmpty) return [];

    final cacheKey = 'variables_multi_${deviceModelIds.join('_')}';

    // Cache kontrolü
    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        return cached
            .map((e) => Variable.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }

    try {
      final response = await _supabase
          .from('variables')
          .select()
          .inFilter('device_model_id', deviceModelIds)
          .order('name');

      final result = (response as List)
          .map((e) => Variable.fromJson(e as Map<String, dynamic>))
          .toList();

      // Cache'e kaydet
      await _cacheManager.set(
        cacheKey,
        result.map((e) => e.toJson()).toList(),
        ttl: const Duration(minutes: 2),
      );

      return result;
    } catch (e, stackTrace) {
      Logger.error('Failed to get variables by device models', e, stackTrace);
      rethrow;
    }
  }

  /// ID ile variable getir
  Future<Variable?> getById(String id) async {
    // Önce memory cache'den kontrol
    final cached = _variables.where((v) => v.id == id).firstOrNull;
    if (cached != null) return cached;

    try {
      final response = await _supabase
          .from('variables')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      return Variable.fromJson(response);
    } catch (e, stackTrace) {
      Logger.error('Failed to get variable by id', e, stackTrace);
      rethrow;
    }
  }

  /// Variable oluştur
  Future<Variable> create(Variable variable) async {
    try {
      final data = variable.toJson();
      data.remove('id');
      data['created_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('variables')
          .insert(data)
          .select()
          .single();

      final created = Variable.fromJson(response);

      _variables.add(created);
      _variablesController.add(_variables);

      // Cache'i temizle
      await _invalidateCache();

      Logger.info('Variable created: ${created.name}');
      return created;
    } catch (e, stackTrace) {
      Logger.error('Failed to create variable', e, stackTrace);
      rethrow;
    }
  }

  /// Variable güncelle
  Future<Variable> update(Variable variable) async {
    try {
      final data = variable.toJson();
      data['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('variables')
          .update(data)
          .eq('id', variable.id)
          .select()
          .single();

      final updated = Variable.fromJson(response);

      // Liste güncelle
      final index = _variables.indexWhere((v) => v.id == variable.id);
      if (index != -1) {
        _variables[index] = updated;
        _variablesController.add(_variables);
      }

      // Seçili variable güncelle
      if (_selected?.id == variable.id) {
        _selected = updated;
        _selectedVariable.add(_selected);
      }

      // Cache'i temizle
      await _invalidateCache();

      Logger.info('Variable updated: ${updated.name}');
      return updated;
    } catch (e, stackTrace) {
      Logger.error('Failed to update variable', e, stackTrace);
      rethrow;
    }
  }

  /// Variable sil
  Future<void> delete(String id) async {
    try {
      await _supabase.from('variables').delete().eq('id', id);

      _variables.removeWhere((v) => v.id == id);
      _variablesController.add(_variables);

      if (_selected?.id == id) {
        _selected = null;
        _selectedVariable.add(_selected);
      }

      // Cache'i temizle
      await _invalidateCache();

      Logger.info('Variable deleted: $id');
    } catch (e, stackTrace) {
      Logger.error('Failed to delete variable', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // VALUE OPERATIONS
  // ============================================

  /// Variable değerini güncelle
  Future<void> updateValue(String id, String? value) async {
    try {
      final now = DateTime.now();

      await _supabase.from('variables').update({
        'value': value,
        'last_update': now.toIso8601String(),
      }).eq('id', id);

      // Memory'deki listeyi güncelle
      final index = _variables.indexWhere((v) => v.id == id);
      if (index != -1) {
        _variables[index] = _variables[index].copyWith(
          value: value,
          lastUpdate: now,
        );
        _variablesController.add(_variables);
      }

      // Stream'e güncelleme gönder
      _valueUpdates.add(VariableValueUpdate(
        variableId: id,
        value: value,
        timestamp: now,
      ));

      Logger.debug('Variable value updated: $id = $value');
    } catch (e, stackTrace) {
      Logger.error('Failed to update variable value', e, stackTrace);
      rethrow;
    }
  }

  /// Birden fazla variable değerini toplu güncelle
  Future<void> updateValues(List<VariableValueUpdate> updates) async {
    try {
      for (final update in updates) {
        // Memory'deki listeyi güncelle
        final index = _variables.indexWhere((v) => v.id == update.variableId);
        if (index != -1) {
          _variables[index] = _variables[index].copyWith(
            value: update.value,
            lastUpdate: update.timestamp,
          );
        }

        // Stream'e güncelleme gönder
        _valueUpdates.add(update);
      }

      _variablesController.add(_variables);

      Logger.debug('Bulk variable values updated: ${updates.length} variables');
    } catch (e, stackTrace) {
      Logger.error('Failed to bulk update variable values', e, stackTrace);
      rethrow;
    }
  }

  /// Variable'a değer yaz
  Future<bool> writeValue(String id, String value) async {
    try {
      final variable = await getById(id);
      if (variable == null) {
        throw Exception('Variable not found: $id');
      }

      if (!variable.isWritable) {
        throw Exception('Variable is not writable: $id');
      }

      // Değer yazma işlemi (gerçek uygulamada controller'a gönderilir)
      await updateValue(id, value);

      Logger.info('Variable value written: $id = $value');
      return true;
    } catch (e, stackTrace) {
      Logger.error('Failed to write variable value', e, stackTrace);
      return false;
    }
  }

  // ============================================
  // SELECTION
  // ============================================

  /// Variable seç
  void select(Variable? variable) {
    _selected = variable;
    _selectedVariable.add(_selected);
  }

  /// ID ile variable seç
  Future<void> selectById(String id) async {
    final variable = await getById(id);
    select(variable);
  }

  // ============================================
  // SEARCH & FILTER
  // ============================================

  /// Variable ara
  Future<List<Variable>> search(String query) async {
    if (query.isEmpty) {
      return _variables;
    }

    final lowerQuery = query.toLowerCase();
    return _variables.where((v) {
      return v.name.toLowerCase().contains(lowerQuery) ||
          (v.code?.toLowerCase().contains(lowerQuery) ?? false) ||
          (v.address?.contains(query) ?? false) ||
          (v.unit?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  /// Kategoriye göre filtrele
  List<Variable> filterByCategory(VariableCategory category) {
    return _variables.where((v) => v.category == category).toList();
  }

  /// Device model'e göre filtrele (memory)
  List<Variable> filterByDeviceModel(String deviceModelId) {
    return _variables.where((v) => v.deviceModelId == deviceModelId).toList();
  }

  // ============================================
  // STATISTICS
  // ============================================

  /// Variable istatistiklerini getir
  Map<String, int> getStats() {
    return {
      'total': _variables.length,
      'active': _variables.where((v) => v.active).length,
      'readable': _variables.where((v) => v.isReadable).length,
      'writable': _variables.where((v) => v.isWritable).length,
    };
  }

  // ============================================
  // HELPERS
  // ============================================

  /// Cache'i temizle
  Future<void> _invalidateCache() async {
    await _cacheManager.deleteByPrefix('variables_');
  }

  /// Servisi temizle
  void dispose() {
    _variablesController.close();
    _selectedVariable.close();
    _valueUpdates.close();
  }
}
