import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../errors/exceptions.dart';
import '../utils/logger.dart';

/// Cache yönetim servisi
///
/// Hive kullanarak TTL destekli önbellekleme sağlar.
/// API yanıtları, kullanıcı verileri vb. için kullanılır.
///
/// Örnek kullanım:
/// ```dart
/// final cache = CacheManager();
/// await cache.set('users', userData, ttl: Duration(hours: 1));
/// final data = await cache.get<Map<String, dynamic>>('users');
/// ```
class CacheManager {
  static const String _cacheBoxName = 'ptb_cache';
  static const String _metaBoxName = 'ptb_cache_meta';

  Box<String>? _cacheBox;
  Box<int>? _metaBox;

  bool _isInitialized = false;

  /// Cache manager başlat
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Hive.initFlutter();
      _cacheBox = await Hive.openBox<String>(_cacheBoxName);
      _metaBox = await Hive.openBox<int>(_metaBoxName);
      _isInitialized = true;
      Logger.debug('CacheManager initialized');
    } catch (e) {
      throw CacheException(
        message: 'Cache başlatılamadı',
        originalError: e,
      );
    }
  }

  /// Initialization kontrolü
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw const CacheException(
        message: 'CacheManager henüz başlatılmadı. initialize() çağırın.',
      );
    }
  }

  // ============================================
  // BASIC OPERATIONS
  // ============================================

  /// Değer kaydet
  ///
  /// [key] - Önbellek anahtarı
  /// [value] - Kaydedilecek değer (JSON serializable olmalı)
  /// [ttl] - Yaşam süresi (varsayılan: 1 saat)
  Future<void> set<T>(
    String key,
    T value, {
    Duration ttl = const Duration(hours: 1),
  }) async {
    _ensureInitialized();

    try {
      final jsonValue = jsonEncode(value);
      final expiryTime = DateTime.now().add(ttl).millisecondsSinceEpoch;

      await _cacheBox!.put(key, jsonValue);
      await _metaBox!.put(key, expiryTime);

      Logger.debug('Cache set: $key (TTL: ${ttl.inMinutes} min)');
    } catch (e) {
      throw CacheException(
        message: 'Cache yazma hatası: $key',
        originalError: e,
      );
    }
  }

  /// Değer oku
  ///
  /// TTL süresi dolmuşsa null döner ve cache'den siler.
  Future<T?> get<T>(String key) async {
    _ensureInitialized();

    try {
      final expiryTime = _metaBox!.get(key);

      // TTL kontrolü
      if (expiryTime != null &&
          DateTime.now().millisecondsSinceEpoch > expiryTime) {
        Logger.debug('Cache expired: $key');
        await delete(key);
        return null;
      }

      final jsonValue = _cacheBox!.get(key);
      if (jsonValue == null) return null;

      final decoded = jsonDecode(jsonValue);
      Logger.debug('Cache hit: $key');
      return decoded as T;
    } catch (e) {
      Logger.warning('Cache okuma hatası: $key', e);
      return null;
    }
  }

  /// Değer sil
  Future<void> delete(String key) async {
    _ensureInitialized();

    try {
      await _cacheBox!.delete(key);
      await _metaBox!.delete(key);
      Logger.debug('Cache deleted: $key');
    } catch (e) {
      throw CacheException(
        message: 'Cache silme hatası: $key',
        originalError: e,
      );
    }
  }

  /// Tüm cache'i temizle
  Future<void> clear() async {
    _ensureInitialized();

    try {
      await _cacheBox!.clear();
      await _metaBox!.clear();
      Logger.debug('Cache cleared');
    } catch (e) {
      throw CacheException(
        message: 'Cache temizleme hatası',
        originalError: e,
      );
    }
  }

  /// Anahtar var mı kontrol et (TTL dahil)
  Future<bool> has(String key) async {
    _ensureInitialized();

    final expiryTime = _metaBox!.get(key);

    // TTL kontrolü
    if (expiryTime != null &&
        DateTime.now().millisecondsSinceEpoch > expiryTime) {
      await delete(key);
      return false;
    }

    return _cacheBox!.containsKey(key);
  }

  // ============================================
  // ADVANCED OPERATIONS
  // ============================================

  /// Cache'den oku veya fetch et
  ///
  /// Cache'de varsa döner, yoksa [fetchFn] çağrılır ve sonuç cache'lenir.
  Future<T?> getOrFetch<T>({
    required String key,
    required Future<T> Function() fetchFn,
    Duration ttl = const Duration(hours: 1),
    bool forceRefresh = false,
  }) async {
    _ensureInitialized();

    // Force refresh değilse cache'den dene
    if (!forceRefresh) {
      final cached = await get<T>(key);
      if (cached != null) return cached;
    }

    // Fetch et
    try {
      final data = await fetchFn();
      await set(key, data, ttl: ttl);
      return data;
    } catch (e) {
      Logger.error('Cache fetch hatası: $key', e);

      // Hata durumunda eski cache'i dön (varsa)
      if (!forceRefresh) {
        return await get<T>(key);
      }
      rethrow;
    }
  }

  /// Typed cache get (fromJson ile)
  Future<T?> getTyped<T>({
    required String key,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final data = await get<Map<String, dynamic>>(key);
    if (data == null) return null;
    return fromJson(data);
  }

  /// Typed cache get or fetch
  Future<T?> getTypedOrFetch<T>({
    required String key,
    required Future<T> Function() fetchFn,
    required T Function(Map<String, dynamic>) fromJson,
    required Map<String, dynamic> Function(T) toJson,
    Duration ttl = const Duration(hours: 1),
    bool forceRefresh = false,
  }) async {
    _ensureInitialized();

    // Force refresh değilse cache'den dene
    if (!forceRefresh) {
      final cached = await getTyped<T>(key: key, fromJson: fromJson);
      if (cached != null) return cached;
    }

    // Fetch et
    try {
      final data = await fetchFn();
      await set(key, toJson(data), ttl: ttl);
      return data;
    } catch (e) {
      Logger.error('Cache typed fetch hatası: $key', e);
      if (!forceRefresh) {
        return await getTyped<T>(key: key, fromJson: fromJson);
      }
      rethrow;
    }
  }

  /// Liste cache get
  Future<List<T>?> getList<T>({
    required String key,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final data = await get<List<dynamic>>(key);
    if (data == null) return null;
    return data
        .map((item) => fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Liste cache set
  Future<void> setList<T>({
    required String key,
    required List<T> value,
    required Map<String, dynamic> Function(T) toJson,
    Duration ttl = const Duration(hours: 1),
  }) async {
    final jsonList = value.map((item) => toJson(item)).toList();
    await set(key, jsonList, ttl: ttl);
  }

  // ============================================
  // PATTERN OPERATIONS
  // ============================================

  /// Pattern ile eşleşen anahtarları sil
  Future<void> deleteByPattern(String pattern) async {
    _ensureInitialized();

    final regex = RegExp(pattern);
    final keysToDelete = _cacheBox!.keys
        .where((key) => regex.hasMatch(key.toString()))
        .toList();

    for (final key in keysToDelete) {
      await delete(key.toString());
    }

    Logger.debug('Cache deleted by pattern: $pattern (${keysToDelete.length} keys)');
  }

  /// Prefix ile başlayan anahtarları sil
  Future<void> deleteByPrefix(String prefix) async {
    await deleteByPattern('^$prefix');
  }

  /// Koşula göre anahtarları sil
  Future<void> deleteWhere(bool Function(String key) test) async {
    _ensureInitialized();

    final keysToDelete = _cacheBox!.keys
        .where((key) => test(key.toString()))
        .toList();

    for (final key in keysToDelete) {
      await delete(key.toString());
    }

    Logger.debug('Cache deleted by condition (${keysToDelete.length} keys)');
  }

  // ============================================
  // CACHE INFO
  // ============================================

  /// Toplam cache boyutu
  int get size => _cacheBox?.length ?? 0;

  /// Tüm anahtarları getir
  List<String> get keys =>
      _cacheBox?.keys.map((k) => k.toString()).toList() ?? [];

  /// Süresi dolmuş cache'leri temizle
  Future<int> cleanExpired() async {
    _ensureInitialized();

    final now = DateTime.now().millisecondsSinceEpoch;
    final expiredKeys = <String>[];

    for (final key in _metaBox!.keys) {
      final expiryTime = _metaBox!.get(key);
      if (expiryTime != null && now > expiryTime) {
        expiredKeys.add(key.toString());
      }
    }

    for (final key in expiredKeys) {
      await delete(key);
    }

    Logger.debug('Cache cleanup: ${expiredKeys.length} expired keys deleted');
    return expiredKeys.length;
  }

  /// Cache'i kapat
  Future<void> close() async {
    await _cacheBox?.close();
    await _metaBox?.close();
    _isInitialized = false;
    Logger.debug('CacheManager closed');
  }
}

/// Cache key builder helper
class CacheKey {
  CacheKey._();

  /// User specific key
  static String user(String userId, String key) => 'user_${userId}_$key';

  /// Tenant specific key
  static String tenant(String tenantId, String key) => 'tenant_${tenantId}_$key';

  /// API response key
  static String api(String endpoint, [Map<String, dynamic>? params]) {
    if (params == null || params.isEmpty) {
      return 'api_$endpoint';
    }
    final sortedParams = Map.fromEntries(
      params.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return 'api_${endpoint}_${sortedParams.hashCode}';
  }

  /// List with pagination key
  static String list(String name, {int page = 1, int limit = 20}) =>
      'list_${name}_p${page}_l$limit';
}
