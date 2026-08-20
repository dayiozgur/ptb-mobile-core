import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../entity/models/entity_type_config.dart';
import '../localization/localization_service.dart';
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

  /// Low-code entity tipleri — web menü sızdırmasının mobil kaynağı.
  static const String _entityTable = 'entity_type_configs';

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
  String _entityCacheKey(String platformId) => 'menu_entity_$platformId';

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

    // 0) entity_type_configs (show_in_menu) → sentez menü öğeleri.
    //    Web menü sızdırmasını (`entity_type_configs`) mobilde yansıtır:
    //    admin yeni bir entity tipi eklediğinde, menü-seed / app güncellemesi
    //    OLMADAN mobilde belirir. Elle seed edilmiş (platform_menu_items'ta
    //    `/entities/<code>` yolu olan) tipler tekrar sentezlenmez (dedup).
    final existingKeys = flat.map((m) => m.itemKey).toSet();
    final existingEntityCodes = <String>{};
    for (final m in flat) {
      final code = _entityCodeFromPath(m.path);
      if (code != null) existingEntityCodes.add(code.toLowerCase());
    }
    final entityRows =
        await _loadEntityConfigRows(platformId, forceRefresh: forceRefresh);
    final entityItems = _buildEntityMenuItems(
      entityRows,
      existingKeys: existingKeys,
      existingEntityCodes: existingEntityCodes,
    );

    // Merge ET — rol filtrelemesi + ağaç kurulumu entity öğelerine de uygulanır.
    final merged = <MenuItem>[...flat, ...entityItems];

    // 1) role göre filtrele
    final visible =
        merged.where((m) => m.isVisibleForRole(coarseRole)).toList();

    // 2) ağaç kur
    final tree = _buildTree(visible);

    _menuController.add(tree);
    return tree;
  }

  /// `entity_type_configs` ham satırlarını getir — cache-first (30dk, menü ile
  /// aynı TTL). STRICT `platform_id = platformId` (platform-bağımsız/null
  /// satırlar HARİÇ) — böylece show_in_menu tipi olmayan platformlar (PMS)
  /// etkilenmez; PHR kendi `hr_*` tiplerini alır.
  Future<List<Map<String, dynamic>>> _loadEntityConfigRows(
    String platformId, {
    bool forceRefresh = false,
  }) async {
    final key = _entityCacheKey(platformId);

    if (!forceRefresh) {
      try {
        final cached = await _cacheManager.get<List<dynamic>>(key);
        if (cached != null) {
          return cached
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      } catch (e) {
        Logger.warning('Entity menu cache parse failed: $e');
        await _cacheManager.delete(key);
      }
    }

    try {
      final response = await _supabase
          .from(_entityTable)
          .select()
          .eq('platform_id', platformId)
          .eq('active', true)
          .eq('show_in_menu', true)
          .order('menu_order', ascending: true);

      final rows = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      await _cacheManager.set(key, rows, ttl: _cacheTtl);
      return rows;
    } catch (e) {
      // Entity menü hatası ANA menüyü düşürmez — sessizce boş dön.
      Logger.warning('Failed to load entity menu items ($platformId): $e');
      return const [];
    }
  }

  /// Ham `entity_type_configs` satırlarından sentez [MenuItem] listesi kur.
  ///
  /// - Aynı `code` için tenant satırı sistem satırını override eder (web dedup).
  /// - [existingEntityCodes]'de olan (elle seed edilmiş) kodlar atlanır.
  /// - `menu_parent` yüklü bir item_key ise altına nest'lenir; değilse üst
  ///   seviye. `sort_order = 900 + menu_order` (elle yazılan öğelerin altına).
  List<MenuItem> _buildEntityMenuItems(
    List<Map<String, dynamic>> rows, {
    required Set<String> existingKeys,
    required Set<String> existingEntityCodes,
  }) {
    // code bazında dedup — tenant satırı sistem satırını geçersiz kılar.
    final byCode = <String, EntityTypeConfig>{};
    for (final row in rows) {
      final cfg = EntityTypeConfig.fromJson(row);
      if (cfg.code.isEmpty) continue;
      final existing = byCode[cfg.code];
      if (existing == null ||
          (existing.tenantId == null && cfg.tenantId != null)) {
        byCode[cfg.code] = cfg;
      }
    }

    final langCodes = _localeLookupKeys();

    final items = <MenuItem>[];
    for (final cfg in byCode.values) {
      // DEDUP: platform_menu_items'ta zaten `/entities/<code>` yolu varsa atla.
      if (existingEntityCodes.contains(cfg.code.toLowerCase())) continue;

      final parent = cfg.menuParent;
      final parentKey =
          (parent != null && parent.isNotEmpty && existingKeys.contains(parent))
              ? parent
              : null;

      items.add(MenuItem(
        itemKey: 'entity/${cfg.code}',
        parentItemKey: parentKey,
        // Literal ad (i18n anahtarı değil); renderer'ın translate()'i olduğu
        // gibi döndürür — bu doğru davranış.
        title: _localizedEntityTitle(cfg, langCodes),
        icon: (cfg.icon != null && cfg.icon!.isNotEmpty)
            ? cfg.icon
            : 'bi-collection',
        path: '/entities/${cfg.code}',
        roles: const ['ROLE_USER', 'ROLE_ADMIN'],
        module: 'entity',
        sortOrder: 900 + cfg.menuOrder,
      ));
    }
    return items;
  }

  /// Mevcut dile göre `name_i18n` arama anahtarları (öncelik sıralı).
  /// DB anahtarları çoğunlukla `<lang>` (örn `tr`); bazı satırlar
  /// `<lang>-<CC>` (örn `tr-TR`) kullanabilir — ikisini de dener.
  List<String> _localeLookupKeys() {
    try {
      final loc = sl<LocalizationService>().currentLocale;
      return <String>['${loc.languageCode}-${loc.countryCode}', loc.languageCode];
    } catch (_) {
      return const ['tr-TR', 'tr'];
    }
  }

  /// Yerelleştirilmiş entity başlığı: sıralı [langCodes] içinden ilk dolu
  /// `name_i18n` değeri; yoksa `name`.
  String _localizedEntityTitle(EntityTypeConfig cfg, List<String> langCodes) {
    for (final code in langCodes) {
      final v = cfg.nameI18n[code];
      if (v != null && v.isNotEmpty) return v;
    }
    return cfg.name;
  }

  /// Bir menü yolundan entity tipini çıkar — screen_resolver `_parseEntityType`
  /// ile birebir (dedup için). `.../entities/<type>` veya `?type=<type>`.
  static String? _entityCodeFromPath(String? path) {
    if (path == null || path.isEmpty) return null;
    final uri = Uri.tryParse(path);
    final queryType = uri?.queryParameters['type'];
    if (queryType != null && queryType.isNotEmpty) return queryType;

    final noQuery = path.split('?').first;
    const marker = '/entities/';
    final idx = noQuery.toLowerCase().indexOf(marker);
    if (idx >= 0) {
      final rest = noQuery.substring(idx + marker.length);
      final seg = rest.split('/').firstWhere(
            (s) => s.isNotEmpty,
            orElse: () => '',
          );
      if (seg.isNotEmpty) return seg;
    }
    return null;
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
    await _cacheManager.delete(_entityCacheKey(platformId));
  }

  void dispose() {
    _menuController.close();
  }
}
