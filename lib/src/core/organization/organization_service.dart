import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../storage/secure_storage.dart';
import '../utils/logger.dart';
import 'organization_model.dart';

/// Organization Servisi
///
/// Tenant altındaki organizasyonları yönetir.
/// CRUD işlemleri ve cache desteği sağlar.
///
/// Örnek kullanım:
/// ```dart
/// final orgService = OrganizationService(
///   supabase: Supabase.instance.client,
///   cacheManager: CacheManager(),
/// );
///
/// // Organizasyon listesi
/// final orgs = await orgService.getOrganizations(tenantId);
///
/// // Organizasyon detay
/// final org = await orgService.getOrganization(orgId);
/// ```
class OrganizationService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;
  final SecureStorage _secureStorage;

  // State
  Organization? _currentOrganization;
  List<Organization> _organizations = [];

  // Stream controllers
  final _organizationController = StreamController<Organization?>.broadcast();
  final _organizationsController = StreamController<List<Organization>>.broadcast();

  // Cache keys
  static const String _currentOrgKey = 'current_organization_id';
  static const String _orgsCacheKey = 'tenant_organizations';

  // Table name
  static const String _tableName = 'organizations';

  OrganizationService({
    required SupabaseClient supabase,
    required CacheManager cacheManager,
    required SecureStorage secureStorage,
  })  : _supabase = supabase,
        _cacheManager = cacheManager,
        _secureStorage = secureStorage;

  // ============================================
  // GETTERS
  // ============================================

  /// Mevcut seçili organizasyon
  Organization? get currentOrganization => _currentOrganization;

  /// Organization ID
  String? get currentOrganizationId => _currentOrganization?.id;

  /// Organizasyon listesi
  List<Organization> get organizations => List.unmodifiable(_organizations);

  /// Organizasyon seçili mi?
  bool get hasOrganization => _currentOrganization != null;

  /// Organizasyon değişiklik stream'i
  Stream<Organization?> get organizationStream => _organizationController.stream;

  /// Organizasyon listesi değişiklik stream'i
  Stream<List<Organization>> get organizationsStream => _organizationsController.stream;

  // ============================================
  // READ OPERATIONS
  // ============================================

  /// Tenant'ın organizasyonlarını getir
  Future<List<Organization>> getOrganizations(
    String tenantId, {
    bool forceRefresh = false,
    bool activeOnly = true,
  }) async {
    try {
      // Cache'den dene
      if (!forceRefresh) {
        final cached = await _cacheManager.getList<Organization>(
          key: '${_orgsCacheKey}_$tenantId',
          fromJson: Organization.fromJson,
        );
        if (cached != null && cached.isNotEmpty) {
          _organizations = cached;
          _organizationsController.add(_organizations);
          return cached;
        }
      }

      // Supabase'den getir
      var query = _supabase
          .from(_tableName)
          .select()
          .eq('tenant_id', tenantId);

      if (activeOnly) {
        query = query.eq('active', true);
      }

      final response = await query.order('name');

      final organizations = response
          .map<Organization>((json) => Organization.fromJson(json))
          .toList();

      // Cache'e kaydet
      await _cacheManager.setList(
        key: '${_orgsCacheKey}_$tenantId',
        value: organizations,
        toJson: (o) => o.toJson(),
        ttl: const Duration(minutes: 30),
      );

      _organizations = organizations;
      _organizationsController.add(_organizations);

      Logger.debug('Loaded ${organizations.length} organizations for tenant');
      return organizations;
    } catch (e) {
      Logger.error('Failed to get organizations', e);
      return [];
    }
  }

  /// Tek organizasyon getir
  Future<Organization?> getOrganization(String organizationId) async {
    try {
      // Cache'den dene
      final cached = await _cacheManager.getTyped<Organization>(
        key: 'organization_$organizationId',
        fromJson: Organization.fromJson,
      );
      if (cached != null) return cached;

      // Supabase'den getir
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('id', organizationId)
          .maybeSingle();

      if (response == null) return null;

      final organization = Organization.fromJson(response);

      // Cache'e kaydet
      await _cacheManager.set(
        'organization_$organizationId',
        organization.toJson(),
        ttl: const Duration(hours: 1),
      );

      return organization;
    } catch (e) {
      Logger.error('Failed to get organization: $organizationId', e);
      return null;
    }
  }

  /// Organizasyon seç ve persistent olarak kaydet
  Future<bool> selectOrganization(String organizationId) async {
    try {
      final organization = await getOrganization(organizationId);
      if (organization == null) {
        Logger.warning('Organization not found: $organizationId');
        return false;
      }

      if (!organization.active) {
        Logger.warning('Organization is not active: $organizationId');
        return false;
      }

      _currentOrganization = organization;
      _organizationController.add(organization);

      // SecureStorage'a kaydet (uygulama yeniden açıldığında hatırlansın)
      await _secureStorage.write(key: _currentOrgKey, value: organizationId);

      Logger.info('Organization selected: ${organization.name}');
      return true;
    } catch (e) {
      Logger.error('Failed to select organization', e);
      return false;
    }
  }

  /// Son seçili organizasyonu geri yükle
  Future<Organization?> restoreLastOrganization() async {
    try {
      final organizationId = await _secureStorage.read(_currentOrgKey);
      if (organizationId == null) {
        Logger.debug('No saved organization to restore');
        return null;
      }

      // Cache'den dene
      final cached = await _cacheManager.getTyped<Organization>(
        key: 'organization_$organizationId',
        fromJson: Organization.fromJson,
      );
      if (cached != null && cached.active) {
        _currentOrganization = cached;
        _organizationController.add(cached);
        Logger.debug('Organization restored from cache: ${cached.name}');
        return cached;
      }

      // Supabase'den getir
      final organization = await getOrganization(organizationId);
      if (organization != null && organization.active) {
        _currentOrganization = organization;
        _organizationController.add(organization);
        Logger.debug('Organization restored from API: ${organization.name}');
        return organization;
      }

      // Organizasyon artık geçerli değil, temizle
      Logger.debug('Saved organization no longer valid, clearing');
      await _secureStorage.write(key: _currentOrgKey, value: '');
      return null;
    } catch (e) {
      Logger.warning('Failed to restore organization: $e');
      return null;
    }
  }

  /// Organizasyon seçimini temizle
  Future<void> clearOrganization() async {
    _currentOrganization = null;
    _organizationController.add(null);
    try {
      await _secureStorage.write(key: _currentOrgKey, value: '');
    } catch (_) {}
    Logger.debug('Organization cleared');
  }

  // ============================================
  // WRITE OPERATIONS
  // ============================================

  /// Yeni organizasyon oluştur
  Future<Organization?> createOrganization({
    required String tenantId,
    required String name,
    String? code,
    String? description,
    String? color,
    String? address,
    String? city,
    String? town,
    String? country,
    double? latitude,
    double? longitude,
    String? createdBy,
  }) async {
    try {
      final data = {
        'tenant_id': tenantId,
        'name': name,
        'code': code ?? _generateCode(name),
        'description': description,
        'color': color,
        'address': address,
        'city': city,
        'town': town,
        'country': country,
        'latitude': latitude,
        'longitude': longitude,
        'active': true,
        'created_by': createdBy,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from(_tableName)
          .insert(data)
          .select()
          .single();

      final organization = Organization.fromJson(response);

      // Cache'i temizle
      await _cacheManager.delete('${_orgsCacheKey}_$tenantId');

      Logger.info('Organization created: ${organization.name}');
      return organization;
    } catch (e) {
      Logger.error('Failed to create organization', e);
      return null;
    }
  }

  /// Organizasyon güncelle
  Future<Organization?> updateOrganization({
    required String organizationId,
    String? name,
    String? code,
    String? description,
    String? color,
    String? imagePath,
    String? address,
    String? city,
    String? town,
    String? country,
    double? latitude,
    double? longitude,
    int? zoom,
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
      if (color != null) updateData['color'] = color;
      if (imagePath != null) updateData['image_path'] = imagePath;
      if (address != null) updateData['address'] = address;
      if (city != null) updateData['city'] = city;
      if (town != null) updateData['town'] = town;
      if (country != null) updateData['country'] = country;
      if (latitude != null) updateData['latitude'] = latitude;
      if (longitude != null) updateData['longitude'] = longitude;
      if (zoom != null) updateData['zoom'] = zoom;
      if (active != null) updateData['active'] = active;
      if (updatedBy != null) updateData['updated_by'] = updatedBy;

      final response = await _supabase
          .from(_tableName)
          .update(updateData)
          .eq('id', organizationId)
          .select()
          .single();

      final organization = Organization.fromJson(response);

      // Cache'i güncelle
      await _cacheManager.set(
        'organization_$organizationId',
        organization.toJson(),
        ttl: const Duration(hours: 1),
      );

      // Mevcut organizasyon ise state'i güncelle
      if (_currentOrganization?.id == organizationId) {
        _currentOrganization = organization;
        _organizationController.add(organization);
      }

      // Liste cache'ini temizle
      await _cacheManager.delete('${_orgsCacheKey}_${organization.tenantId}');

      Logger.info('Organization updated: ${organization.name}');
      return organization;
    } catch (e) {
      Logger.error('Failed to update organization', e);
      return null;
    }
  }

  /// Organizasyon sil (soft delete)
  Future<bool> deleteOrganization(String organizationId) async {
    try {
      // Önce organizasyonu getir (tenant_id için)
      final org = await getOrganization(organizationId);
      if (org == null) return false;

      await _supabase
          .from(_tableName)
          .update({
            'active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', organizationId);

      // Cache'leri temizle
      await _cacheManager.delete('organization_$organizationId');
      await _cacheManager.delete('${_orgsCacheKey}_${org.tenantId}');

      // Mevcut organizasyon ise temizle
      if (_currentOrganization?.id == organizationId) {
        await clearOrganization();
      }

      Logger.info('Organization deleted (soft): $organizationId');
      return true;
    } catch (e) {
      Logger.error('Failed to delete organization', e);
      return false;
    }
  }

  // ============================================
  // SEARCH & FILTER
  // ============================================

  /// Organizasyon ara
  Future<List<Organization>> searchOrganizations(
    String tenantId,
    String query,
  ) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('tenant_id', tenantId)
          .eq('active', true)
          .or('name.ilike.%$query%,code.ilike.%$query%,description.ilike.%$query%')
          .order('name')
          .limit(20);

      return response
          .map<Organization>((json) => Organization.fromJson(json))
          .toList();
    } catch (e) {
      Logger.error('Failed to search organizations', e);
      return [];
    }
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

  // ============================================
  // CLEANUP
  // ============================================

  /// Servisi kapat
  void dispose() {
    _organizationController.close();
    _organizationsController.close();
    Logger.debug('OrganizationService disposed');
  }
}
