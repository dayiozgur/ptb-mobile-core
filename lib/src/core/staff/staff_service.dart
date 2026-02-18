import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../utils/logger.dart';
import 'staff_model.dart';

/// Staff Service
///
/// Personel, personel tipleri ve departman yonetimi saglar.
class StaffService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  /// Staff listesi stream
  final _staffsController = StreamController<List<Staff>>.broadcast();

  /// Mevcut tenant ID
  String? _currentTenantId;

  /// Mevcut staff listesi
  List<Staff> _staffs = [];

  /// Cache TTL
  static const _cacheTtl = Duration(minutes: 10);

  StaffService({
    required SupabaseClient supabase,
    required CacheManager cacheManager,
  })  : _supabase = supabase,
        _cacheManager = cacheManager;

  // ============================================
  // GETTERS
  // ============================================

  /// Staff listesi stream
  Stream<List<Staff>> get staffsStream => _staffsController.stream;

  /// Mevcut staff listesi
  List<Staff> get staffs => List.unmodifiable(_staffs);

  /// Aktif personeller
  List<Staff> get activeStaffs =>
      _staffs.where((s) => s.isActive).toList();

  // ============================================
  // CONTEXT
  // ============================================

  /// Tenant context ayarla
  void setTenant(String tenantId) {
    if (_currentTenantId != tenantId) {
      _currentTenantId = tenantId;
      _staffs = [];
      _staffsController.add(_staffs);
    }
  }

  /// Context temizle
  void clearContext() {
    _currentTenantId = null;
    _staffs = [];
    _staffsController.add(_staffs);
  }

  // ============================================
  // STAFF OPERATIONS
  // ============================================

  /// Personelleri getir
  Future<List<Staff>> getStaffs({bool forceRefresh = false}) async {
    if (_currentTenantId == null) {
      throw Exception('Tenant context is not set');
    }

    final cacheKey = 'staffs_$_currentTenantId';

    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        try {
          _staffs = cached
              .map((e) => Staff.fromJson(e as Map<String, dynamic>))
              .toList();
          _staffsController.add(_staffs);
          return _staffs;
        } catch (cacheError) {
          Logger.warning('Failed to parse staffs from cache: $cacheError');
          await _cacheManager.delete(cacheKey);
        }
      }
    }

    try {
      final response = await _supabase
          .from('staffs')
          .select()
          .or('tenant_id.eq.$_currentTenantId,tenant_id.is.null')
          .order('name');

      final responseList = response as List;

      Logger.debug('Staffs query returned ${responseList.length} records');

      _staffs = responseList
          .map((e) => Staff.fromJson(e as Map<String, dynamic>))
          .toList();

      await _cacheManager.set(cacheKey, responseList, ttl: _cacheTtl);

      _staffsController.add(_staffs);
      return _staffs;
    } catch (e) {
      Logger.error('Error fetching staffs: $e');
      rethrow;
    }
  }

  /// Tek personel getir
  Future<Staff?> getStaff(String id) async {
    try {
      final response = await _supabase
          .from('staffs')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return Staff.fromJson(response);
    } catch (e) {
      Logger.error('Error fetching staff: $e');
      rethrow;
    }
  }

  /// Profile ID ile personel getir
  Future<Staff?> getStaffByProfileId(String profileId) async {
    try {
      final response = await _supabase
          .from('staffs')
          .select()
          .eq('profile_id', profileId)
          .maybeSingle();

      if (response == null) return null;
      return Staff.fromJson(response);
    } catch (e) {
      Logger.error('Error fetching staff by profile: $e');
      rethrow;
    }
  }

  /// Personel olustur
  Future<Staff> createStaff({
    required String name,
    String? code,
    String? description,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? staffTypeId,
    String? profileId,
    String? userId,
    String? organizationId,
  }) async {
    if (_currentTenantId == null) {
      throw Exception('Tenant context is not set');
    }

    try {
      final data = {
        'name': name,
        'code': code,
        'description': description,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'staff_type_id': staffTypeId,
        'profile_id': profileId,
        'user_id': userId,
        'organization_id': organizationId,
        'tenant_id': _currentTenantId,
        'active': true,
      };

      final response = await _supabase
          .from('staffs')
          .insert(data)
          .select()
          .single();

      final staff = Staff.fromJson(response);

      _staffs.add(staff);
      _staffsController.add(_staffs);

      await _invalidateStaffCache();

      Logger.info('Created staff: ${staff.id}');
      return staff;
    } catch (e) {
      Logger.error('Error creating staff: $e');
      rethrow;
    }
  }

  /// Personel guncelle
  Future<Staff> updateStaff(
    String id, {
    String? name,
    String? code,
    String? description,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? staffTypeId,
    bool? active,
  }) async {
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) data['name'] = name;
      if (code != null) data['code'] = code;
      if (description != null) data['description'] = description;
      if (firstName != null) data['first_name'] = firstName;
      if (lastName != null) data['last_name'] = lastName;
      if (email != null) data['email'] = email;
      if (phone != null) data['phone'] = phone;
      if (staffTypeId != null) data['staff_type_id'] = staffTypeId;
      if (active != null) data['active'] = active;

      final response = await _supabase
          .from('staffs')
          .update(data)
          .eq('id', id)
          .select()
          .single();

      final staff = Staff.fromJson(response);

      final index = _staffs.indexWhere((s) => s.id == id);
      if (index >= 0) {
        _staffs[index] = staff;
        _staffsController.add(_staffs);
      }

      await _invalidateStaffCache();

      Logger.info('Updated staff: $id');
      return staff;
    } catch (e) {
      Logger.error('Error updating staff: $e');
      rethrow;
    }
  }

  /// Personel sil (soft delete)
  Future<void> deleteStaff(String id) async {
    try {
      await _supabase
          .from('staffs')
          .update({
            'active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);

      _staffs.removeWhere((s) => s.id == id);
      _staffsController.add(_staffs);

      await _invalidateStaffCache();

      Logger.info('Deleted staff: $id');
    } catch (e) {
      Logger.error('Error deleting staff: $e');
      rethrow;
    }
  }

  // ============================================
  // STAFF TYPES
  // ============================================

  /// Personel tiplerini getir
  Future<List<StaffType>> getStaffTypes({bool forceRefresh = false}) async {
    const cacheKey = 'staff_types';

    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        try {
          return cached
              .map((e) => StaffType.fromJson(e as Map<String, dynamic>))
              .toList();
        } catch (cacheError) {
          Logger.warning('Failed to parse staff types from cache: $cacheError');
          await _cacheManager.delete(cacheKey);
        }
      }
    }

    try {
      final response = await _supabase
          .from('staff_types')
          .select()
          .order('name');

      final responseList = response as List;

      await _cacheManager.set(cacheKey, responseList, ttl: _cacheTtl);

      return responseList
          .map((e) => StaffType.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('Error fetching staff types: $e');
      rethrow;
    }
  }

  /// Tek personel tipi getir
  Future<StaffType?> getStaffType(String id) async {
    try {
      final response = await _supabase
          .from('staff_types')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return StaffType.fromJson(response);
    } catch (e) {
      Logger.error('Error fetching staff type: $e');
      rethrow;
    }
  }

  // ============================================
  // DEPARTMENTS
  // ============================================

  /// Departmanlari getir
  Future<List<Department>> getDepartments({bool forceRefresh = false}) async {
    if (_currentTenantId == null) {
      throw Exception('Tenant context is not set');
    }

    final cacheKey = 'departments_$_currentTenantId';

    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        try {
          return cached
              .map((e) => Department.fromJson(e as Map<String, dynamic>))
              .toList();
        } catch (cacheError) {
          Logger.warning('Failed to parse departments from cache: $cacheError');
          await _cacheManager.delete(cacheKey);
        }
      }
    }

    try {
      final response = await _supabase
          .from('departments')
          .select()
          .or('tenant_id.eq.$_currentTenantId,tenant_id.is.null')
          .order('name');

      final responseList = response as List;

      await _cacheManager.set(cacheKey, responseList, ttl: _cacheTtl);

      return responseList
          .map((e) => Department.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('Error fetching departments: $e');
      rethrow;
    }
  }

  /// Tek departman getir
  Future<Department?> getDepartment(String id) async {
    try {
      final response = await _supabase
          .from('departments')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return Department.fromJson(response);
    } catch (e) {
      Logger.error('Error fetching department: $e');
      rethrow;
    }
  }

  /// Departman olustur
  Future<Department> createDepartment({
    required String name,
    String? code,
    String? description,
  }) async {
    if (_currentTenantId == null) {
      throw Exception('Tenant context is not set');
    }

    try {
      final data = {
        'name': name,
        'code': code,
        'description': description,
        'tenant_id': _currentTenantId,
        'active': true,
      };

      final response = await _supabase
          .from('departments')
          .insert(data)
          .select()
          .single();

      await _invalidateDeptCache();

      Logger.info('Created department: ${response['id']}');
      return Department.fromJson(response);
    } catch (e) {
      Logger.error('Error creating department: $e');
      rethrow;
    }
  }

  /// Departman guncelle
  Future<Department> updateDepartment(
    String id, {
    String? name,
    String? code,
    String? description,
    bool? active,
  }) async {
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) data['name'] = name;
      if (code != null) data['code'] = code;
      if (description != null) data['description'] = description;
      if (active != null) data['active'] = active;

      final response = await _supabase
          .from('departments')
          .update(data)
          .eq('id', id)
          .select()
          .single();

      await _invalidateDeptCache();

      Logger.info('Updated department: $id');
      return Department.fromJson(response);
    } catch (e) {
      Logger.error('Error updating department: $e');
      rethrow;
    }
  }

  /// Departman sil (soft delete)
  Future<void> deleteDepartment(String id) async {
    try {
      await _supabase
          .from('departments')
          .update({
            'active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);

      await _invalidateDeptCache();

      Logger.info('Deleted department: $id');
    } catch (e) {
      Logger.error('Error deleting department: $e');
      rethrow;
    }
  }

  // ============================================
  // PRIVATE METHODS
  // ============================================

  Future<void> _invalidateStaffCache() async {
    if (_currentTenantId != null) {
      await _cacheManager.deleteWhere(
        (key) => key.startsWith('staffs_$_currentTenantId'),
      );
    }
  }

  Future<void> _invalidateDeptCache() async {
    if (_currentTenantId != null) {
      await _cacheManager.deleteWhere(
        (key) => key.startsWith('departments_$_currentTenantId'),
      );
    }
  }

  /// Temizle
  void dispose() {
    _staffsController.close();
  }
}
