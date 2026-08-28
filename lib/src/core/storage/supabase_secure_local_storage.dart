import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';

/// Supabase auth oturumunu (access + refresh JWT) Keychain/Keystore'da tutan
/// güvenli depolama adaptörleri.
///
/// supabase_flutter'ın VARSAYILAN oturum deposu SharedPreferences'tır; yani
/// refresh token cihazda DÜZ METİN durur. Bu dosyadaki adaptörler
/// `Supabase.initialize(authOptions: ...)` üzerinden bağlanır ve oturumu
/// flutter_secure_storage'a (iOS Keychain / Android Keystore-encrypted
/// SharedPreferences) taşır:
///
/// ```dart
/// await Supabase.initialize(
///   url: url,
///   anonKey: anonKey,
///   authOptions: FlutterAuthClientOptions(
///     authFlowType: AuthFlowType.pkce,
///     localStorage: SecureSessionLocalStorage(
///       migrationPersistSessionKey: defaultPersistSessionKeyForUrl(url),
///     ),
///     pkceAsyncStorage: SecurePkceAsyncStorage(),
///   ),
/// );
/// ```
///
/// [SecureSessionLocalStorage.initialize] ayrıca TEK SEFERLİK bir göç yapar:
/// eski sürümlerin SharedPreferences'a yazdığı düz-metin oturum güvenli
/// depoya kopyalanır ve düz-metin kopya SİLİNİR (kullanıcı oturumu düşmez,
/// diskte token kalıntısı kalmaz).

/// [SecureStorage] ile aynı platform seçenekleri: Android'de Keystore-şifreli
/// SharedPreferences, iOS'ta first_unlock_this_device erişilebilirliği.
FlutterSecureStorage createDefaultFlutterSecureStorage() =>
    const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    );

/// supabase_flutter'ın varsayılan SharedPreferences oturum anahtarı
/// (`sb-<host ilk etiketi>-auth-token`). Düz-metin göçü için kullanılır.
String defaultPersistSessionKeyForUrl(String supabaseUrl) =>
    'sb-${Uri.parse(supabaseUrl).host.split('.').first}-auth-token';

/// Oturumu (access + refresh token JSON'u) güvenli depoda tutan [LocalStorage].
class SecureSessionLocalStorage extends LocalStorage {
  SecureSessionLocalStorage({
    FlutterSecureStorage? storage,
    this.migrationPersistSessionKey,
    this.persistSessionKey = defaultSecurePersistSessionKey,
  }) : _storage = storage ?? createDefaultFlutterSecureStorage();

  /// Güvenli depodaki oturum anahtarı.
  static const String defaultSecurePersistSessionKey = 'supabase_session';

  final FlutterSecureStorage _storage;

  /// Güvenli depoda oturumun tutulduğu anahtar.
  final String persistSessionKey;

  /// Eski (düz-metin) SharedPreferences oturum anahtarı. Verilirse
  /// [initialize] sırasında tek seferlik göç + düz-metin temizliği yapılır.
  /// `null` ise göç denenmez.
  final String? migrationPersistSessionKey;

  @override
  Future<void> initialize() async {
    final legacyKey = migrationPersistSessionKey;
    if (legacyKey == null) return;

    // Tek seferlik göç: düz-metin oturum varsa güvenli depoya taşı ve
    // SharedPreferences'taki kopyayı sil. Hata boot'u ASLA düşürmez.
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacySession = prefs.getString(legacyKey);
      if (legacySession == null) return;

      final existing = await _storage.read(key: persistSessionKey);
      if (existing == null) {
        await _storage.write(key: persistSessionKey, value: legacySession);
        Logger.info('Oturum güvenli depoya taşındı (Keychain/Keystore)');
      }
      // Her durumda düz-metin kalıntıyı temizle.
      await prefs.remove(legacyKey);
    } catch (e) {
      Logger.warning('Oturum göçü başarısız (güvenli depoya taşıma)', e);
    }
  }

  @override
  Future<bool> hasAccessToken() async {
    try {
      return await _storage.containsKey(key: persistSessionKey);
    } catch (e) {
      Logger.warning('Güvenli depo okunamadı (hasAccessToken)', e);
      return false;
    }
  }

  @override
  Future<String?> accessToken() async {
    try {
      return await _storage.read(key: persistSessionKey);
    } catch (e) {
      Logger.warning('Güvenli depo okunamadı (accessToken)', e);
      return null;
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await _storage.write(key: persistSessionKey, value: persistSessionString);
  }

  @override
  Future<void> removePersistedSession() async {
    await _storage.delete(key: persistSessionKey);
  }
}

/// PKCE code-verifier'ını güvenli depoda tutan [GotrueAsyncStorage].
///
/// Varsayılanı ([SharedPreferencesGotrueAsyncStorage]) verifier'ı düz-metin
/// SharedPreferences'a yazar; bu sınıf Keychain/Keystore kullanır.
class SecurePkceAsyncStorage extends GotrueAsyncStorage {
  SecurePkceAsyncStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? createDefaultFlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> getItem({required String key}) {
    return _storage.read(key: key);
  }

  @override
  Future<void> setItem({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> removeItem({required String key}) {
    return _storage.delete(key: key);
  }
}
