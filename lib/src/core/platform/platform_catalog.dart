import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../utils/logger.dart';

/// Kullanıcının erişebildiği bir platform (Windows-OS "uygulama" kataloğu).
///
/// `fn_my_platform_catalog()` çıktısının bir satırı. `owned=true` = abone
/// (platform switcher'da yalnız bunlar listelenir).
class PlatformCatalogEntry {
  /// Platform id (uuid) — MenuService platform_id kaynağı.
  final String platformId;

  /// Kısa kod (PMS, CRM, FIXFLOW, PEM, PHR, PMP, PTB...).
  final String code;

  /// Görünen ad.
  final String name;

  final String? description;
  final String? iconUrl;

  /// Marka rengi (hex) — UI vurgusu için.
  final String? color;

  final num? priceMonthly;
  final String? currency;

  /// Abone/sahip mi? (owned=true).
  final bool owned;

  /// Durum (active/trial/...).
  final String? status;

  /// Deneme sürümü mü?
  final bool isTrial;

  const PlatformCatalogEntry({
    required this.platformId,
    required this.code,
    required this.name,
    this.description,
    this.iconUrl,
    this.color,
    this.priceMonthly,
    this.currency,
    this.owned = false,
    this.status,
    this.isTrial = false,
  });

  factory PlatformCatalogEntry.fromJson(Map<String, dynamic> json) {
    return PlatformCatalogEntry(
      platformId: json['platform_id'] as String,
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ?? (json['code'] as String?) ?? '',
      description: json['description'] as String?,
      iconUrl: json['icon_url'] as String?,
      color: json['color'] as String?,
      priceMonthly: json['price_monthly'] as num?,
      currency: json['currency'] as String?,
      owned: json['owned'] as bool? ?? false,
      status: json['status'] as String?,
      isTrial: json['is_trial'] as bool? ?? false,
    );
  }

  @override
  String toString() =>
      'PlatformCatalogEntry($code, owned=$owned, id=$platformId)';
}

/// Platform kataloğu servisi — `fn_my_platform_catalog()`.
class PlatformCatalogService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  static const String _cacheKey = 'platform_catalog';
  static const Duration _cacheTtl = Duration(minutes: 15);

  PlatformCatalogService({
    required SupabaseClient supabase,
    required CacheManager cacheManager,
  })  : _supabase = supabase,
        _cacheManager = cacheManager;

  /// Kullanıcının erişebildiği platformları getir.
  Future<List<PlatformCatalogEntry>> getCatalog({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      try {
        final cached = await _cacheManager.get<List<dynamic>>(_cacheKey);
        if (cached != null) {
          return cached
              .map((e) =>
                  PlatformCatalogEntry.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      } catch (e) {
        Logger.warning('Platform catalog cache parse failed: $e');
        await _cacheManager.delete(_cacheKey);
      }
    }

    try {
      final dynamic response = await _supabase.rpc('fn_my_platform_catalog');
      final rows = response is List
          ? response.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];

      await _cacheManager.set(_cacheKey, rows, ttl: _cacheTtl);
      return rows.map(PlatformCatalogEntry.fromJson).toList();
    } catch (e) {
      Logger.error('Failed to load platform catalog: $e');
      rethrow;
    }
  }

  /// Yalnızca sahip olunan (abone) platformlar — switcher için.
  Future<List<PlatformCatalogEntry>> getOwnedPlatforms({
    bool forceRefresh = false,
  }) async {
    final all = await getCatalog(forceRefresh: forceRefresh);
    return all.where((p) => p.owned).toList();
  }

  Future<void> invalidateCache() => _cacheManager.delete(_cacheKey);
}
