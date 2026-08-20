import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../utils/logger.dart';
import 'menu_item.dart';

/// Mobil menü servisi — DB-tabanlı platform menüsü (Windows-OS modeli).
///
/// Menü kaynağı YALNIZCA `platform_menu_items` tablosudur (menu_source='db').
/// Web `ptb-db-menu.loader.ts` filtre semantiğini birebir yansıtır:
///   1. platform_id + active=true ile yükle, sort_order'a göre sırala,
///   2. coarse rol dışında kalan (roles gate) öğeleri düşür,
///   3. item_key / parent_item_key ile ağaç kur.
///
/// Not: disabled öğeler AĞAÇTA KALIR (görünür ama tıklanamaz) — web davranışı.
/// permission[] gating TODO (öğelerin ~tamamında null).
class MobileMenuService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  /// PMS platform id — varsayılan platform.
  static const String pmsPlatformId = 'f0113c6e-8000-4298-a07c-0fd90e406a7a';

  static const String _table = 'platform_menu_items';
  static const Duration _cacheTtl = Duration(minutes: 30);

  /// Son yüklenen menüyü yayınlar (platform switch / rol değişiminde rebuild).
  final _menuController = StreamController<List<MenuItem>>.broadcast();

  MobileMenuService({
    required SupabaseClient supabase,
    required CacheManager cacheManager,
  })  : _supabase = supabase,
        _cacheManager = cacheManager;

  /// Menü ağacı stream'i (top-level öğeler, çocuklar `children` altında).
  Stream<List<MenuItem>> get menuStream => _menuController.stream;

  String _cacheKey(String platformId) => 'menu_flat_$platformId';

  /// Platform menüsünü yükle, role göre filtrele, ağaç kur.
  ///
  /// [platformId] varsayılan PMS. [coarseRole] ROLE_ADMIN|MANAGER|USER|CUSTOMER.
  /// Dönüş: top-level [MenuItem] listesi (sort_order sıralı, `children` dolu).
  Future<List<MenuItem>> loadMenu({
    String platformId = pmsPlatformId,
    required String? coarseRole,
    bool forceRefresh = false,
  }) async {
    final flat = await _loadFlat(platformId, forceRefresh: forceRefresh);

    // 1) role göre filtrele
    final visible =
        flat.where((m) => m.isVisibleForRole(coarseRole)).toList();

    // 2) ağaç kur
    final tree = _buildTree(visible);

    _menuController.add(tree);
    return tree;
  }

  /// Düz (filtrelenmemiş) menü satırlarını getir — cache-first.
  Future<List<MenuItem>> _loadFlat(
    String platformId, {
    bool forceRefresh = false,
  }) async {
    final key = _cacheKey(platformId);

    if (!forceRefresh) {
      try {
        final cached = await _cacheManager.get<List<dynamic>>(key);
        if (cached != null) {
          return cached
              .map((e) => MenuItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      } catch (e) {
        Logger.warning('Menu cache parse failed: $e');
        await _cacheManager.delete(key);
      }
    }

    try {
      final response = await _supabase
          .from(_table)
          .select()
          .eq('platform_id', platformId)
          .eq('active', true)
          .order('sort_order', ascending: true);

      final rows = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // Cache ham satırlar (rol-bağımsız) — role filtreleme her yüklemede.
      await _cacheManager.set(key, rows, ttl: _cacheTtl);

      return rows.map(MenuItem.fromJson).toList();
    } catch (e) {
      Logger.error('Failed to load platform menu ($platformId): $e');
      // Sessizce boş dönmüyoruz; çağıran boş menüyü ele alır ama hatayı loglar.
      rethrow;
    }
  }

  /// item_key / parent_item_key eşleşmesiyle nested ağaç kur.
  ///
  /// - Girdi sort_order sıralı varsayılır; her seviye sort_order'a göre re-sort.
  /// - Yetim (parent'ı görünmeyen) öğeler top-level'a yükseltilir (kaybolmasın).
  List<MenuItem> _buildTree(List<MenuItem> flat) {
    final byKey = <String, MenuItem>{};
    final childrenOf = <String, List<MenuItem>>{};

    for (final item in flat) {
      byKey[item.itemKey] = item;
    }

    final roots = <MenuItem>[];
    for (final item in flat) {
      final parentKey = item.parentItemKey;
      if (parentKey == null ||
          parentKey.isEmpty ||
          !byKey.containsKey(parentKey)) {
        // top-level ya da yetim → root
        roots.add(item);
      } else {
        childrenOf.putIfAbsent(parentKey, () => <MenuItem>[]).add(item);
      }
    }

    List<MenuItem> attach(List<MenuItem> items) {
      final result = items.map((item) {
        final kids = childrenOf[item.itemKey];
        if (kids == null || kids.isEmpty) return item;
        return item.copyWith(children: attach(kids));
      }).toList();
      result.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return result;
    }

    return attach(roots);
  }

  /// Bir platformun menü cache'ini geçersiz kıl (rol değişimi / re-login sonrası).
  Future<void> invalidateCache([String platformId = pmsPlatformId]) async {
    await _cacheManager.delete(_cacheKey(platformId));
  }

  void dispose() {
    _menuController.close();
  }
}
