import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../utils/logger.dart';
import 'site_model.dart';

/// Site Servisi
///
/// Organization altındaki siteleri (bina/tesis) yönetir.
/// CRUD işlemleri ve cache desteği sağlar.
///
/// Örnek kullanım:
/// ```dart
/// final siteService = SiteService(
///   supabase: Supabase.instance.client,
///   cacheManager: CacheManager(),
/// );
///
/// // Site listesi
/// final sites = await siteService.getSites(organizationId);
///
/// // Site detay
/// final site = await siteService.getSite(siteId);
/// ```
class SiteService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  // State
  Site? _currentSite;
  List<Site> _sites = [];

  // Stream controllers
  final _siteController = StreamController<Site?>.broadcast();
  final _sitesController = StreamController<List<Site>>.broadcast();

  // Cache keys
  static const String _currentSiteKey = 'current_site_id';
  static const String _sitesCacheKey = 'organization_sites';

  // Table names
  static const String _tableName = 'sites';
  static const String _siteTypesTable = 'site_types';
  static const String _siteGroupsTable = 'site_groups';

  SiteService({
    required SupabaseClient supabase,
    required CacheManager cacheManager,
  })  : _supabase = supabase,
        _cacheManager = cacheManager;

  // ============================================
  // GETTERS
  // ============================================

  /// Mevcut seçili site
  Site? get currentSite => _currentSite;

  /// Site ID
  String? get currentSiteId => _currentSite?.id;

  /// Site listesi
  List<Site> get sites => List.unmodifiable(_sites);

  /// Site seçili mi?
  bool get hasSite => _currentSite != null;

  /// Site değişiklik stream'i
  Stream<Site?> get siteStream => _siteController.stream;

  /// Site listesi değişiklik stream'i
  Stream<List<Site>> get sitesStream => _sitesController.stream;

  // ============================================
  // READ OPERATIONS
  // ============================================

  /// Organization'ın sitelerini getir
  Future<List<Site>> getSites(
    String organizationId, {
    bool forceRefresh = false,
    bool activeOnly = true,
  }) async {
    try {
      // Cache'den dene
      if (!forceRefresh) {
        final cached = await _cacheManager.getList<Site>(
          key: '${_sitesCacheKey}_$organizationId',
          fromJson: Site.fromJson,
        );
        if (cached != null && cached.isNotEmpty) {
          _sites = cached;
          _sitesController.add(_sites);
          return cached;
        }
      }

      // Supabase'den getir
      var query = _supabase
          .from(_tableName)
          .select()
          .eq('organization_id', organizationId);

      if (activeOnly) {
        query = query.eq('active', true);
      }

      final response = await query.order('name');

      final sites = response
          .map<Site>((json) => Site.fromJson(json))
          .toList();

      // Cache'e kaydet
      await _cacheManager.setList(
        key: '${_sitesCacheKey}_$organizationId',
        value: sites,
        toJson: (s) => s.toJson(),
        ttl: const Duration(minutes: 30),
      );

      _sites = sites;
      _sitesController.add(_sites);

      Logger.debug('Loaded ${sites.length} sites for organization');
      return sites;
    } catch (e) {
      Logger.error('Failed to get sites', e);
      return [];
    }
  }

  /// Tenant'ın tüm sitelerini getir
  Future<List<Site>> getSitesByTenant(
    String tenantId, {
    bool forceRefresh = false,
    bool activeOnly = true,
  }) async {
    try {
      // Cache'den dene
      if (!forceRefresh) {
        final cached = await _cacheManager.getList<Site>(
          key: 'tenant_sites_$tenantId',
          fromJson: Site.fromJson,
        );
        if (cached != null && cached.isNotEmpty) {
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

      final sites = response
          .map<Site>((json) => Site.fromJson(json))
          .toList();

      // Cache'e kaydet
      await _cacheManager.setList(
        key: 'tenant_sites_$tenantId',
        value: sites,
        toJson: (s) => s.toJson(),
        ttl: const Duration(minutes: 30),
      );

      Logger.debug('Loaded ${sites.length} sites for tenant');
      return sites;
    } catch (e) {
      Logger.error('Failed to get sites by tenant', e);
      return [];
    }
  }

  /// Tek site getir
  Future<Site?> getSite(String siteId) async {
    try {
      // Cache'den dene
      final cached = await _cacheManager.getTyped<Site>(
        key: 'site_$siteId',
        fromJson: Site.fromJson,
      );
      if (cached != null) return cached;

      // Supabase'den getir
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('id', siteId)
          .maybeSingle();

      if (response == null) return null;

      final site = Site.fromJson(response);

      // Cache'e kaydet
      await _cacheManager.set(
        'site_$siteId',
        site.toJson(),
        ttl: const Duration(hours: 1),
      );

      return site;
    } catch (e) {
      Logger.error('Failed to get site: $siteId', e);
      return null;
    }
  }

  /// Site seç
  Future<bool> selectSite(String siteId) async {
    try {
      final site = await getSite(siteId);
      if (site == null) {
        Logger.warning('Site not found: $siteId');
        return false;
      }

      if (!site.active) {
        Logger.warning('Site is not active: $siteId');
        return false;
      }

      _currentSite = site;
      _siteController.add(site);

      Logger.info('Site selected: ${site.name}');
      return true;
    } catch (e) {
      Logger.error('Failed to select site', e);
      return false;
    }
  }

  /// Site seçimini temizle
  void clearSite() {
    _currentSite = null;
    _siteController.add(null);
    Logger.debug('Site cleared');
  }

  // ============================================
  // WRITE OPERATIONS
  // ============================================

  /// Yeni site oluştur
  Future<Site?> createSite({
    required String organizationId,
    required String name,
    required String markerId,
    String? tenantId,
    String? code,
    String? description,
    String? color,
    String? address,
    String? city,
    String? town,
    String? country,
    double? latitude,
    double? longitude,
    double? grossAreaSqm,
    double? netAreaSqm,
    int? floorCount,
    int? yearBuilt,
    String? siteTypeId,
    String? siteGroupId,
    String? createdBy,
  }) async {
    try {
      final data = {
        'organization_id': organizationId,
        'name': name,
        'marker_id': markerId,
        'tenant_id': tenantId,
        'code': code ?? _generateCode(name),
        'description': description,
        'color': color,
        'address': address,
        'city': city,
        'town': town,
        'country': country,
        'latitude': latitude,
        'longitude': longitude,
        'gross_area_sqm': grossAreaSqm,
        'net_area_sqm': netAreaSqm,
        'floor_count': floorCount,
        'year_built': yearBuilt,
        'site_type_id': siteTypeId,
        'site_group_id': siteGroupId,
        'active': true,
        'created_by': createdBy,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from(_tableName)
          .insert(data)
          .select()
          .single();

      final site = Site.fromJson(response);

      // Cache'leri temizle
      await _cacheManager.delete('${_sitesCacheKey}_$organizationId');
      if (tenantId != null) {
        await _cacheManager.delete('tenant_sites_$tenantId');
      }

      Logger.info('Site created: ${site.name}');
      return site;
    } catch (e) {
      Logger.error('Failed to create site', e);
      return null;
    }
  }

  /// Site güncelle
  Future<Site?> updateSite({
    required String siteId,
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
    double? grossAreaSqm,
    double? netAreaSqm,
    int? floorCount,
    int? yearBuilt,
    String? climateZone,
    String? energyCertificateClass,
    String? generalOpenTime,
    String? generalCloseTime,
    bool? workingTimeActive,
    String? siteTypeId,
    String? siteGroupId,
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
      if (grossAreaSqm != null) updateData['gross_area_sqm'] = grossAreaSqm;
      if (netAreaSqm != null) updateData['net_area_sqm'] = netAreaSqm;
      if (floorCount != null) updateData['floor_count'] = floorCount;
      if (yearBuilt != null) updateData['year_built'] = yearBuilt;
      if (climateZone != null) updateData['climate_zone'] = climateZone;
      if (energyCertificateClass != null) {
        updateData['energy_certificate_class'] = energyCertificateClass;
      }
      if (generalOpenTime != null) updateData['general_open_time'] = generalOpenTime;
      if (generalCloseTime != null) updateData['general_close_time'] = generalCloseTime;
      if (workingTimeActive != null) updateData['working_time_active'] = workingTimeActive;
      if (siteTypeId != null) updateData['site_type_id'] = siteTypeId;
      if (siteGroupId != null) updateData['site_group_id'] = siteGroupId;
      if (active != null) updateData['active'] = active;
      if (updatedBy != null) updateData['updated_by'] = updatedBy;

      final response = await _supabase
          .from(_tableName)
          .update(updateData)
          .eq('id', siteId)
          .select()
          .single();

      final site = Site.fromJson(response);

      // Cache'i güncelle
      await _cacheManager.set(
        'site_$siteId',
        site.toJson(),
        ttl: const Duration(hours: 1),
      );

      // Mevcut site ise state'i güncelle
      if (_currentSite?.id == siteId) {
        _currentSite = site;
        _siteController.add(site);
      }

      // Liste cache'lerini temizle
      await _cacheManager.delete('${_sitesCacheKey}_${site.organizationId}');
      if (site.tenantId != null) {
        await _cacheManager.delete('tenant_sites_${site.tenantId}');
      }

      Logger.info('Site updated: ${site.name}');
      return site;
    } catch (e) {
      Logger.error('Failed to update site', e);
      return null;
    }
  }

  /// Site sil (soft delete)
  Future<bool> deleteSite(String siteId) async {
    try {
      // Önce site'ı getir (organization_id için)
      final site = await getSite(siteId);
      if (site == null) return false;

      await _supabase
          .from(_tableName)
          .update({
            'active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', siteId);

      // Cache'leri temizle
      await _cacheManager.delete('site_$siteId');
      await _cacheManager.delete('${_sitesCacheKey}_${site.organizationId}');
      if (site.tenantId != null) {
        await _cacheManager.delete('tenant_sites_${site.tenantId}');
      }

      // Mevcut site ise temizle
      if (_currentSite?.id == siteId) {
        clearSite();
      }

      Logger.info('Site deleted (soft): $siteId');
      return true;
    } catch (e) {
      Logger.error('Failed to delete site', e);
      return false;
    }
  }

  // ============================================
  // SITE TYPES & GROUPS
  // ============================================

  /// Site tiplerini getir
  Future<List<SiteType>> getSiteTypes({bool activeOnly = true}) async {
    try {
      final cached = await _cacheManager.getList<SiteType>(
        key: 'site_types',
        fromJson: SiteType.fromJson,
      );
      if (cached != null && cached.isNotEmpty) return cached;

      var query = _supabase.from(_siteTypesTable).select();

      if (activeOnly) {
        query = query.eq('active', true);
      }

      final response = await query.order('name');

      final types = response
          .map<SiteType>((json) => SiteType.fromJson(json))
          .toList();

      await _cacheManager.setList(
        key: 'site_types',
        value: types,
        toJson: (t) => t.toJson(),
        ttl: const Duration(hours: 24),
      );

      return types;
    } catch (e) {
      Logger.error('Failed to get site types', e);
      return [];
    }
  }

  /// Site gruplarını getir
  Future<List<SiteGroup>> getSiteGroups({bool activeOnly = true}) async {
    try {
      final cached = await _cacheManager.getList<SiteGroup>(
        key: 'site_groups',
        fromJson: SiteGroup.fromJson,
      );
      if (cached != null && cached.isNotEmpty) return cached;

      var query = _supabase.from(_siteGroupsTable).select();

      if (activeOnly) {
        query = query.eq('active', true);
      }

      final response = await query.order('name');

      final groups = response
          .map<SiteGroup>((json) => SiteGroup.fromJson(json))
          .toList();

      await _cacheManager.setList(
        key: 'site_groups',
        value: groups,
        toJson: (g) => g.toJson(),
        ttl: const Duration(hours: 24),
      );

      return groups;
    } catch (e) {
      Logger.error('Failed to get site groups', e);
      return [];
    }
  }

  // ============================================
  // SEARCH & FILTER
  // ============================================

  /// Site ara
  Future<List<Site>> searchSites(
    String organizationId,
    String query,
  ) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('organization_id', organizationId)
          .eq('active', true)
          .or('name.ilike.%$query%,code.ilike.%$query%,address.ilike.%$query%')
          .order('name')
          .limit(20);

      return response
          .map<Site>((json) => Site.fromJson(json))
          .toList();
    } catch (e) {
      Logger.error('Failed to search sites', e);
      return [];
    }
  }

  /// Yakındaki siteleri getir
  Future<List<Site>> getNearbySites({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    int limit = 20,
  }) async {
    try {
      // Basit bir bounding box hesabı (yaklaşık)
      final latDiff = radiusKm / 111.0; // 1 derece ≈ 111 km
      final lonDiff = radiusKm / (111.0 * _cos(latitude));

      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('active', true)
          .gte('latitude', latitude - latDiff)
          .lte('latitude', latitude + latDiff)
          .gte('longitude', longitude - lonDiff)
          .lte('longitude', longitude + lonDiff)
          .limit(limit);

      return response
          .map<Site>((json) => Site.fromJson(json))
          .toList();
    } catch (e) {
      Logger.error('Failed to get nearby sites', e);
      return [];
    }
  }

  double _cos(double degrees) {
    const piOver180 = 3.14159265359 / 180;
    return _cosImpl(degrees * piOver180);
  }

  double _cosImpl(double radians) {
    // Taylor series approximation
    double result = 1.0;
    double term = 1.0;
    for (int i = 1; i <= 10; i++) {
      term *= -radians * radians / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
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
    _siteController.close();
    _sitesController.close();
    Logger.debug('SiteService disposed');
  }
}
