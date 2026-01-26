import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../errors/exceptions.dart';

/// Güvenli anahtar-değer depolama servisi
///
/// Hassas veriler (token, şifre vb.) için şifreli depolama sağlar.
/// iOS Keychain ve Android Keystore kullanır.
///
/// Örnek kullanım:
/// ```dart
/// final storage = SecureStorage();
/// await storage.write(key: 'token', value: 'abc123');
/// final token = await storage.read('token');
/// ```
class SecureStorage {
  final FlutterSecureStorage _storage;

  SecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  // ============================================
  // BASIC OPERATIONS
  // ============================================

  /// Değer yaz
  Future<void> write({
    required String key,
    required String value,
  }) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      throw StorageException(
        message: 'Değer yazılamadı: $key',
        originalError: e,
      );
    }
  }

  /// Değer oku
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      throw StorageException(
        message: 'Değer okunamadı: $key',
        originalError: e,
      );
    }
  }

  /// Değer sil
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      throw StorageException(
        message: 'Değer silinemedi: $key',
        originalError: e,
      );
    }
  }

  /// Tüm değerleri sil
  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      throw StorageException(
        message: 'Tüm değerler silinemedi',
        originalError: e,
      );
    }
  }

  /// Anahtar var mı kontrol et
  Future<bool> containsKey(String key) async {
    try {
      return await _storage.containsKey(key: key);
    } catch (e) {
      throw StorageException(
        message: 'Anahtar kontrol edilemedi: $key',
        originalError: e,
      );
    }
  }

  /// Tüm anahtarları getir
  Future<Map<String, String>> readAll() async {
    try {
      return await _storage.readAll();
    } catch (e) {
      throw StorageException(
        message: 'Tüm değerler okunamadı',
        originalError: e,
      );
    }
  }

  // ============================================
  // JSON OPERATIONS
  // ============================================

  /// JSON objesi yaz
  Future<void> writeJson({
    required String key,
    required Map<String, dynamic> value,
  }) async {
    final jsonString = jsonEncode(value);
    await write(key: key, value: jsonString);
  }

  /// JSON objesi oku
  Future<Map<String, dynamic>?> readJson(String key) async {
    final jsonString = await read(key);
    if (jsonString == null) return null;

    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      throw StorageException(
        message: 'JSON parse hatası: $key',
        originalError: e,
      );
    }
  }

  /// JSON listesi yaz
  Future<void> writeJsonList({
    required String key,
    required List<Map<String, dynamic>> value,
  }) async {
    final jsonString = jsonEncode(value);
    await write(key: key, value: jsonString);
  }

  /// JSON listesi oku
  Future<List<Map<String, dynamic>>?> readJsonList(String key) async {
    final jsonString = await read(key);
    if (jsonString == null) return null;

    try {
      final list = jsonDecode(jsonString) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      throw StorageException(
        message: 'JSON list parse hatası: $key',
        originalError: e,
      );
    }
  }

  // ============================================
  // TYPED OPERATIONS
  // ============================================

  /// Boolean yaz
  Future<void> writeBool({required String key, required bool value}) async {
    await write(key: key, value: value.toString());
  }

  /// Boolean oku
  Future<bool?> readBool(String key) async {
    final value = await read(key);
    if (value == null) return null;
    return value.toLowerCase() == 'true';
  }

  /// Integer yaz
  Future<void> writeInt({required String key, required int value}) async {
    await write(key: key, value: value.toString());
  }

  /// Integer oku
  Future<int?> readInt(String key) async {
    final value = await read(key);
    if (value == null) return null;
    return int.tryParse(value);
  }

  /// Double yaz
  Future<void> writeDouble({required String key, required double value}) async {
    await write(key: key, value: value.toString());
  }

  /// Double oku
  Future<double?> readDouble(String key) async {
    final value = await read(key);
    if (value == null) return null;
    return double.tryParse(value);
  }

  /// DateTime yaz
  Future<void> writeDateTime({
    required String key,
    required DateTime value,
  }) async {
    await write(key: key, value: value.toIso8601String());
  }

  /// DateTime oku
  Future<DateTime?> readDateTime(String key) async {
    final value = await read(key);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  // ============================================
  // PREDEFINED KEYS
  // ============================================

  /// Access token kaydet
  Future<void> saveAccessToken(String token) async {
    await write(key: StorageKeys.accessToken, value: token);
  }

  /// Access token oku
  Future<String?> getAccessToken() async {
    return read(StorageKeys.accessToken);
  }

  /// Access token sil
  Future<void> deleteAccessToken() async {
    await delete(StorageKeys.accessToken);
  }

  /// Refresh token kaydet
  Future<void> saveRefreshToken(String token) async {
    await write(key: StorageKeys.refreshToken, value: token);
  }

  /// Refresh token oku
  Future<String?> getRefreshToken() async {
    return read(StorageKeys.refreshToken);
  }

  /// Refresh token sil
  Future<void> deleteRefreshToken() async {
    await delete(StorageKeys.refreshToken);
  }

  /// User ID kaydet
  Future<void> saveUserId(String userId) async {
    await write(key: StorageKeys.userId, value: userId);
  }

  /// User ID oku
  Future<String?> getUserId() async {
    return read(StorageKeys.userId);
  }

  /// Tenant ID kaydet
  Future<void> saveTenantId(String tenantId) async {
    await write(key: StorageKeys.tenantId, value: tenantId);
  }

  /// Tenant ID oku
  Future<String?> getTenantId() async {
    return read(StorageKeys.tenantId);
  }

  /// Biometric enabled kaydet
  Future<void> saveBiometricEnabled(bool enabled) async {
    await writeBool(key: StorageKeys.biometricEnabled, value: enabled);
  }

  /// Biometric enabled oku
  Future<bool> getBiometricEnabled() async {
    return await readBool(StorageKeys.biometricEnabled) ?? false;
  }

  /// Auth bilgilerini temizle
  Future<void> clearAuthData() async {
    await Future.wait([
      delete(StorageKeys.accessToken),
      delete(StorageKeys.refreshToken),
      delete(StorageKeys.userId),
      delete(StorageKeys.tenantId),
    ]);
  }
}

/// Önceden tanımlı storage anahtarları
class StorageKeys {
  StorageKeys._();

  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String userId = 'user_id';
  static const String tenantId = 'tenant_id';
  static const String biometricEnabled = 'biometric_enabled';
  static const String biometricCredentials = 'biometric_credentials';
  static const String userProfile = 'user_profile';
  static const String appSettings = 'app_settings';
  static const String lastSyncTime = 'last_sync_time';
  static const String fcmToken = 'fcm_token';
}
