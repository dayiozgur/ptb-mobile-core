import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../utils/logger.dart';
import 'models/entity_type_config.dart';

/// Entity Config Service
///
/// Low-code builder tarafından tanımlanan entity tiplerini
/// (`entity_type_configs`) yükler. Tenant'a özel bir satır, aynı `code`'a
/// sahip bir sistem satırını geçersiz kılar (override).
class EntityConfigService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  EntityConfigService({
    required SupabaseClient supabase,
    required CacheManager cacheManager,
  })  : _supabase = supabase,
        _cacheManager = cacheManager;

  static const Duration _ttl = Duration(minutes: 10);

  /// Aktif entity tiplerini getir.
  ///
  /// [platformId] verilirse yalnızca o platforma (ya da platform-bağımsız)
  /// yapılandırmalar döner. Aynı `code`'a sahip tenant satırı, sistem
  /// satırını override eder.
  Future<List<EntityTypeConfig>> getConfigs({
    String? platformId,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'entity_configs_${platformId ?? 'all'}';

    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        try {
          return _dedup(cached
              .map((e) => EntityTypeConfig.fromJson(e as Map<String, dynamic>))
              .toList());
        } catch (cacheError) {
          Logger.warning('Failed to parse entity configs from cache: $cacheError');
          await _cacheManager.delete(cacheKey);
        }
      }
    }

    try {
      var query =
          _supabase.from('entity_type_configs').select().eq('active', true);

      if (platformId != null) {
        query = query.or('platform_id.eq.$platformId,platform_id.is.null');
      }

      final response = await query.order('menu_order', ascending: true);
      final responseList = response as List;

      Logger.debug('Entity configs query returned ${responseList.length} rows');

      await _cacheManager.set(cacheKey, responseList, ttl: _ttl);

      return _dedup(responseList
          .map((e) => EntityTypeConfig.fromJson(e as Map<String, dynamic>))
          .toList());
    } catch (e) {
      Logger.error('Error fetching entity configs: $e');
      rethrow;
    }
  }

  /// Belirli bir `code` için entity yapılandırmasını getir.
  Future<EntityTypeConfig?> getByCode(String code) async {
    try {
      final configs = await getConfigs();
      for (final config in configs) {
        if (config.code == code) return config;
      }
      return null;
    } catch (e) {
      Logger.error('Error fetching entity config by code: $e');
      rethrow;
    }
  }

  /// Aynı `code`'a sahip satırlarda tenant satırını (tenant_id != null)
  /// sistem satırına tercih ederek tekilleştir.
  List<EntityTypeConfig> _dedup(List<EntityTypeConfig> configs) {
    final byCode = <String, EntityTypeConfig>{};
    for (final config in configs) {
      final existing = byCode[config.code];
      if (existing == null) {
        byCode[config.code] = config;
      } else if (existing.tenantId == null && config.tenantId != null) {
        // Tenant'a özel satır, sistem satırını override eder.
        byCode[config.code] = config;
      }
    }
    final result = byCode.values.toList();
    result.sort((a, b) => a.menuOrder.compareTo(b.menuOrder));
    return result;
  }

  /// Cache'i temizle.
  Future<void> invalidateCache() async {
    await _cacheManager.deleteWhere((key) => key.startsWith('entity_configs_'));
  }
}
