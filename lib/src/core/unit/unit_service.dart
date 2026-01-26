import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../utils/logger.dart';
import 'unit_model.dart';

/// Unit Servisi
///
/// Site altındaki unitleri (alan/bölüm) yönetir.
/// Self-referencing hiyerarşi desteği ve cache yönetimi sağlar.
///
/// Örnek kullanım:
/// ```dart
/// final unitService = UnitService(
///   supabase: Supabase.instance.client,
///   cacheManager: CacheManager(),
/// );
///
/// // Site'ın unitlerini getir
/// final units = await unitService.getUnits(siteId);
///
/// // Hiyerarşik yapı
/// final tree = await unitService.getUnitTree(siteId);
///
/// // Ana alanı getir
/// final mainUnit = await unitService.getMainUnit(siteId);
/// ```
class UnitService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  // State
  Unit? _currentUnit;
  List<Unit> _units = [];
  UnitTree? _unitTree;

  // Stream controllers
  final _unitController = StreamController<Unit?>.broadcast();
  final _unitsController = StreamController<List<Unit>>.broadcast();

  // Cache keys
  static const String _unitsCacheKey = 'site_units';
  static const String _unitTypesCacheKey = 'unit_types';

  // Table names
  static const String _tableName = 'units';
  static const String _unitTypesTable = 'unit_types';

  UnitService({
    required SupabaseClient supabase,
    required CacheManager cacheManager,
  })  : _supabase = supabase,
        _cacheManager = cacheManager;

  // ============================================
  // GETTERS
  // ============================================

  /// Mevcut seçili unit
  Unit? get currentUnit => _currentUnit;

  /// Unit ID
  String? get currentUnitId => _currentUnit?.id;

  /// Unit listesi
  List<Unit> get units => List.unmodifiable(_units);

  /// Unit ağacı
  UnitTree? get unitTree => _unitTree;

  /// Unit seçili mi?
  bool get hasUnit => _currentUnit != null;

  /// Unit değişiklik stream'i
  Stream<Unit?> get unitStream => _unitController.stream;

  /// Unit listesi değişiklik stream'i
  Stream<List<Unit>> get unitsStream => _unitsController.stream;

  // ============================================
  // READ OPERATIONS
  // ============================================

  /// Site'ın unitlerini getir
  Future<List<Unit>> getUnits(
    String siteId, {
    bool forceRefresh = false,
    bool activeOnly = true,
    bool includeType = true,
  }) async {
    try {
      // Cache'den dene
      if (!forceRefresh) {
        final cached = await _cacheManager.getList<Unit>(
          key: '${_unitsCacheKey}_$siteId',
          fromJson: Unit.fromJson,
        );
        if (cached != null && cached.isNotEmpty) {
          _units = cached;
          _unitTree = UnitTree.fromList(cached);
          _unitsController.add(_units);
          return cached;
        }
      }

      // Supabase'den getir
      String selectQuery = '*';
      if (includeType) {
        selectQuery = '*, unit_type:unit_types(*)';
      }

      var query = _supabase
          .from(_tableName)
          .select(selectQuery)
          .eq('site_id', siteId);

      if (activeOnly) {
        query = query.eq('active', true);
      }

      final response = await query.order('name');

      final units = response
          .map<Unit>((json) => Unit.fromJson(json))
          .toList();

      // Cache'e kaydet
      await _cacheManager.setList(
        key: '${_unitsCacheKey}_$siteId',
        value: units,
        toJson: (u) => u.toJson(),
        ttl: const Duration(minutes: 30),
      );

      _units = units;
      _unitTree = UnitTree.fromList(units);
      _unitsController.add(_units);

      Logger.debug('Loaded ${units.length} units for site');
      return units;
    } catch (e) {
      Logger.error('Failed to get units', e);
      return [];
    }
  }

  /// Organization'ın tüm unitlerini getir
  Future<List<Unit>> getUnitsByOrganization(
    String organizationId, {
    bool forceRefresh = false,
    bool activeOnly = true,
  }) async {
    try {
      // Cache'den dene
      if (!forceRefresh) {
        final cached = await _cacheManager.getList<Unit>(
          key: 'org_units_$organizationId',
          fromJson: Unit.fromJson,
        );
        if (cached != null && cached.isNotEmpty) {
          return cached;
        }
      }

      // Supabase'den getir
      var query = _supabase
          .from(_tableName)
          .select('*, unit_type:unit_types(*)')
          .eq('organization_id', organizationId);

      if (activeOnly) {
        query = query.eq('active', true);
      }

      final response = await query.order('name');

      final units = response
          .map<Unit>((json) => Unit.fromJson(json))
          .toList();

      // Cache'e kaydet
      await _cacheManager.setList(
        key: 'org_units_$organizationId',
        value: units,
        toJson: (u) => u.toJson(),
        ttl: const Duration(minutes: 30),
      );

      Logger.debug('Loaded ${units.length} units for organization');
      return units;
    } catch (e) {
      Logger.error('Failed to get units by organization', e);
      return [];
    }
  }

  /// Unit ağacını getir
  Future<UnitTree?> getUnitTree(
    String siteId, {
    bool forceRefresh = false,
  }) async {
    final units = await getUnits(siteId, forceRefresh: forceRefresh);
    if (units.isEmpty) return null;
    return UnitTree.fromList(units);
  }

  /// Tek unit getir
  Future<Unit?> getUnit(String unitId, {bool includeType = true}) async {
    try {
      // Cache'den dene
      final cached = await _cacheManager.getTyped<Unit>(
        key: 'unit_$unitId',
        fromJson: Unit.fromJson,
      );
      if (cached != null) return cached;

      // Supabase'den getir
      String selectQuery = '*';
      if (includeType) {
        selectQuery = '*, unit_type:unit_types(*)';
      }

      final response = await _supabase
          .from(_tableName)
          .select(selectQuery)
          .eq('id', unitId)
          .maybeSingle();

      if (response == null) return null;

      final unit = Unit.fromJson(response);

      // Cache'e kaydet
      await _cacheManager.set(
        'unit_$unitId',
        unit.toJson(),
        ttl: const Duration(hours: 1),
      );

      return unit;
    } catch (e) {
      Logger.error('Failed to get unit: $unitId', e);
      return null;
    }
  }

  /// Ana alanı getir
  Future<Unit?> getMainUnit(String siteId) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('*, unit_type:unit_types(*)')
          .eq('site_id', siteId)
          .eq('is_main_area', true)
          .eq('active', true)
          .maybeSingle();

      if (response == null) return null;
      return Unit.fromJson(response);
    } catch (e) {
      Logger.error('Failed to get main unit for site: $siteId', e);
      return null;
    }
  }

  /// ID ile unit getir
  Future<Unit?> getUnitById(String unitId) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('*, unit_type:unit_types(*)')
          .eq('id', unitId)
          .maybeSingle();

      if (response == null) return null;
      return Unit.fromJson(response);
    } catch (e) {
      Logger.error('Failed to get unit: $unitId', e);
      return null;
    }
  }

  /// Alt unitleri getir
  Future<List<Unit>> getChildUnits(String parentUnitId) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('*, unit_type:unit_types(*)')
          .eq('parent_unit_id', parentUnitId)
          .eq('active', true)
          .order('name');

      return response
          .map<Unit>((json) => Unit.fromJson(json))
          .toList();
    } catch (e) {
      Logger.error('Failed to get child units', e);
      return [];
    }
  }

  /// Belirli kategorideki unitleri getir
  Future<List<Unit>> getUnitsByCategory(
    String siteId,
    UnitCategory category,
  ) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('*, unit_type:unit_types!inner(*)')
          .eq('site_id', siteId)
          .eq('unit_type.category', category.value)
          .eq('active', true)
          .order('name');

      return response
          .map<Unit>((json) => Unit.fromJson(json))
          .toList();
    } catch (e) {
      Logger.error('Failed to get units by category', e);
      return [];
    }
  }

  /// Unit seç
  Future<bool> selectUnit(String unitId) async {
    try {
      final unit = await getUnit(unitId);
      if (unit == null) {
        Logger.warning('Unit not found: $unitId');
        return false;
      }

      if (!unit.active) {
        Logger.warning('Unit is not active: $unitId');
        return false;
      }

      _currentUnit = unit;
      _unitController.add(unit);

      Logger.info('Unit selected: ${unit.name}');
      return true;
    } catch (e) {
      Logger.error('Failed to select unit', e);
      return false;
    }
  }

  /// Unit seçimini temizle
  void clearUnit() {
    _currentUnit = null;
    _unitController.add(null);
    Logger.debug('Unit cleared');
  }

  // ============================================
  // WRITE OPERATIONS
  // ============================================

  /// Yeni unit oluştur
  Future<Unit?> createUnit({
    required String siteId,
    required String name,
    String? parentUnitId,
    String? organizationId,
    String? tenantId,
    String? code,
    String? description,
    double? areaSize,
    String? unitTypeId,
    bool isMainArea = false,
    String? createdBy,
  }) async {
    try {
      final data = {
        'site_id': siteId,
        'name': name,
        'parent_unit_id': parentUnitId,
        'organization_id': organizationId,
        'tenant_id': tenantId,
        'code': code ?? _generateCode(name),
        'description': description,
        'area_size': areaSize,
        'unit_type_id': unitTypeId,
        'is_main_area': isMainArea,
        'is_deletable': !isMainArea,
        'active': true,
        'created_by': createdBy,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from(_tableName)
          .insert(data)
          .select('*, unit_type:unit_types(*)')
          .single();

      final unit = Unit.fromJson(response);

      // Cache'leri temizle
      await _invalidateSiteCache(siteId);

      Logger.info('Unit created: ${unit.name}');
      return unit;
    } catch (e) {
      Logger.error('Failed to create unit', e);
      return null;
    }
  }

  /// Unit güncelle
  Future<Unit?> updateUnit({
    required String unitId,
    String? name,
    String? code,
    String? description,
    double? areaSize,
    String? imageBucket,
    String? parentUnitId,
    String? unitTypeId,
    String? generalOpenTime,
    String? generalCloseTime,
    bool? workingTimeActive,
    bool? active,
    String? updatedBy,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) updateData['name'] = name;
      if (code != null) updateData['code'] = code;
      if (description != null) updateData['description'] = description;
      if (areaSize != null) updateData['area_size'] = areaSize;
      if (imageBucket != null) updateData['image_bucket'] = imageBucket;
      if (parentUnitId != null) updateData['parent_unit_id'] = parentUnitId;
      if (unitTypeId != null) updateData['unit_type_id'] = unitTypeId;
      if (generalOpenTime != null) updateData['general_open_time'] = generalOpenTime;
      if (generalCloseTime != null) updateData['general_close_time'] = generalCloseTime;
      if (workingTimeActive != null) updateData['working_time_active'] = workingTimeActive;
      if (active != null) updateData['active'] = active;
      if (updatedBy != null) updateData['updated_by'] = updatedBy;

      final response = await _supabase
          .from(_tableName)
          .update(updateData)
          .eq('id', unitId)
          .select('*, unit_type:unit_types(*)')
          .single();

      final unit = Unit.fromJson(response);

      // Cache'i güncelle
      await _cacheManager.set(
        'unit_$unitId',
        unit.toJson(),
        ttl: const Duration(hours: 1),
      );

      // Mevcut unit ise state'i güncelle
      if (_currentUnit?.id == unitId) {
        _currentUnit = unit;
        _unitController.add(unit);
      }

      // Liste cache'ini temizle
      if (unit.siteId != null) {
        await _invalidateSiteCache(unit.siteId!);
      }

      Logger.info('Unit updated: ${unit.name}');
      return unit;
    } catch (e) {
      Logger.error('Failed to update unit', e);
      return null;
    }
  }

  /// Unit sil (soft delete)
  Future<bool> deleteUnit(String unitId) async {
    try {
      // Önce unit'i getir
      final unit = await getUnit(unitId);
      if (unit == null) return false;

      // Silinebilir mi kontrol et
      if (!unit.isDeletable) {
        Logger.warning('Unit is not deletable: $unitId');
        return false;
      }

      await _supabase
          .from(_tableName)
          .update({
            'active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', unitId);

      // Cache'leri temizle
      await _cacheManager.delete('unit_$unitId');
      if (unit.siteId != null) {
        await _invalidateSiteCache(unit.siteId!);
      }

      // Mevcut unit ise temizle
      if (_currentUnit?.id == unitId) {
        clearUnit();
      }

      Logger.info('Unit deleted (soft): $unitId');
      return true;
    } catch (e) {
      Logger.error('Failed to delete unit', e);
      return false;
    }
  }

  /// Unit taşı (parent değiştir)
  Future<bool> moveUnit(String unitId, String? newParentId) async {
    try {
      // Circular reference kontrolü
      if (newParentId != null) {
        final wouldCreateCycle = await _wouldCreateCycle(unitId, newParentId);
        if (wouldCreateCycle) {
          Logger.warning('Cannot move unit: would create cycle');
          return false;
        }
      }

      await _supabase
          .from(_tableName)
          .update({
            'parent_unit_id': newParentId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', unitId);

      // Cache'leri temizle
      final unit = await getUnit(unitId);
      if (unit?.siteId != null) {
        await _invalidateSiteCache(unit!.siteId!);
      }

      Logger.info('Unit moved: $unitId -> parent: $newParentId');
      return true;
    } catch (e) {
      Logger.error('Failed to move unit', e);
      return false;
    }
  }

  // ============================================
  // UNIT TYPES
  // ============================================

  /// Unit tiplerini getir
  Future<List<UnitType>> getUnitTypes({
    bool activeOnly = true,
    UnitCategory? category,
  }) async {
    try {
      final cacheKey = category != null
          ? '${_unitTypesCacheKey}_${category.value}'
          : _unitTypesCacheKey;

      final cached = await _cacheManager.getList<UnitType>(
        key: cacheKey,
        fromJson: UnitType.fromJson,
      );
      if (cached != null && cached.isNotEmpty) return cached;

      var query = _supabase.from(_unitTypesTable).select();

      if (activeOnly) {
        query = query.eq('active', true);
      }

      if (category != null) {
        query = query.eq('category', category.value);
      }

      final response = await query.order('name');

      final types = response
          .map<UnitType>((json) => UnitType.fromJson(json))
          .toList();

      await _cacheManager.setList(
        key: cacheKey,
        value: types,
        toJson: (t) => t.toJson(),
        ttl: const Duration(hours: 24),
      );

      return types;
    } catch (e) {
      Logger.error('Failed to get unit types', e);
      return [];
    }
  }

  /// Tek unit tipi getir
  Future<UnitType?> getUnitType(String typeId) async {
    try {
      final response = await _supabase
          .from(_unitTypesTable)
          .select()
          .eq('id', typeId)
          .maybeSingle();

      if (response == null) return null;
      return UnitType.fromJson(response);
    } catch (e) {
      Logger.error('Failed to get unit type', e);
      return null;
    }
  }

  // ============================================
  // SEARCH & FILTER
  // ============================================

  /// Unit ara
  Future<List<Unit>> searchUnits(
    String siteId,
    String query,
  ) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('*, unit_type:unit_types(*)')
          .eq('site_id', siteId)
          .eq('active', true)
          .or('name.ilike.%$query%,code.ilike.%$query%,description.ilike.%$query%')
          .order('name')
          .limit(20);

      return response
          .map<Unit>((json) => Unit.fromJson(json))
          .toList();
    } catch (e) {
      Logger.error('Failed to search units', e);
      return [];
    }
  }

  // ============================================
  // STATISTICS
  // ============================================

  /// Site için unit istatistikleri
  Future<UnitStats> getUnitStats(String siteId) async {
    try {
      final units = await getUnits(siteId);

      int totalCount = units.length;
      double totalArea = 0;
      Map<UnitCategory, int> categoryCount = {};

      for (final unit in units) {
        if (unit.areaSize != null) {
          totalArea += unit.areaSize!;
        }
        if (unit.category != null) {
          categoryCount[unit.category!] = (categoryCount[unit.category] ?? 0) + 1;
        }
      }

      return UnitStats(
        totalCount: totalCount,
        totalArea: totalArea,
        categoryCount: categoryCount,
        mainUnitExists: units.any((u) => u.isMainArea),
        maxDepth: _calculateMaxDepth(units),
      );
    } catch (e) {
      Logger.error('Failed to get unit stats', e);
      return UnitStats.empty();
    }
  }

  int _calculateMaxDepth(List<Unit> units) {
    final tree = UnitTree.fromList(units);
    int maxDepth = 0;

    void traverse(List<Unit> nodes, int depth) {
      if (depth > maxDepth) maxDepth = depth;
      for (final node in nodes) {
        if (node.hasChildren) {
          traverse(node.children, depth + 1);
        }
      }
    }

    traverse(tree.rootUnits, 0);
    return maxDepth;
  }

  // ============================================
  // HELPERS
  // ============================================

  /// İsimden kod oluştur
  String _generateCode(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  /// Site cache'ini temizle
  Future<void> _invalidateSiteCache(String siteId) async {
    await _cacheManager.delete('${_unitsCacheKey}_$siteId');
  }

  /// Circular reference kontrolü
  Future<bool> _wouldCreateCycle(String unitId, String newParentId) async {
    if (unitId == newParentId) return true;

    // newParentId'nin tüm parent chain'ini kontrol et
    String? currentId = newParentId;
    final visited = <String>{};

    while (currentId != null) {
      if (currentId == unitId) return true;
      if (visited.contains(currentId)) return true; // Mevcut cycle
      visited.add(currentId);

      final parent = await getUnit(currentId);
      currentId = parent?.parentUnitId;
    }

    return false;
  }

  // ============================================
  // CLEANUP
  // ============================================

  /// Servisi kapat
  void dispose() {
    _unitController.close();
    _unitsController.close();
    Logger.debug('UnitService disposed');
  }
}

/// Unit istatistikleri
class UnitStats {
  final int totalCount;
  final double totalArea;
  final Map<UnitCategory, int> categoryCount;
  final bool mainUnitExists;
  final int maxDepth;

  UnitStats({
    required this.totalCount,
    required this.totalArea,
    required this.categoryCount,
    required this.mainUnitExists,
    required this.maxDepth,
  });

  factory UnitStats.empty() => UnitStats(
        totalCount: 0,
        totalArea: 0,
        categoryCount: {},
        mainUnitExists: false,
        maxDepth: 0,
      );

  /// Toplam alan formatlanmış
  String get totalAreaFormatted {
    if (totalArea == 0) return '0 m²';
    return '${totalArea.toStringAsFixed(totalArea % 1 == 0 ? 0 : 1)} m²';
  }
}
