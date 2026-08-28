import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../utils/logger.dart';
import 'supabase_secure_local_storage.dart';

/// Hive kutularını AES-256 ile şifreli açan yardımcı.
///
/// 256-bit anahtar flutter_secure_storage'da (Keychain/Keystore) tutulur:
/// yoksa [Hive.generateSecureKey] ile üretilip kaydedilir, varsa okunur.
/// Böylece diskteki Hive dosyaları (cache + offline kuyruk: konum/izin/bordro
/// gibi PII içerebilir) şifreli durur.
///
/// Kullanım:
/// ```dart
/// final box = await HiveEncryption.openEncryptedBox<String>('ptb_cache');
/// ```
///
/// Eski (şifresiz) kutu göçü: kutu şifreli açılamazsa önce düz-metin olarak
/// okunup içerik şifreli kutuya taşınır; o da olmazsa kutu diskten silinip
/// boş+şifreli açılır (cache için kayıpsız, kuyruk için son çare).
class HiveEncryption {
  HiveEncryption._();

  /// Güvenli depoda AES anahtarının tutulduğu anahtar adı.
  static const String keyStorageKey = 'hive_encryption_key';

  static List<int>? _cachedKey;
  static bool _hiveInitialized = false;

  /// Test izolasyonu için içi durumu sıfırla.
  static void resetForTesting() {
    _cachedKey = null;
    _hiveInitialized = false;
  }

  /// AES-256 anahtarını güvenli depodan getir (yoksa üret + kaydet).
  static Future<List<int>> obtainKey({FlutterSecureStorage? storage}) async {
    final cached = _cachedKey;
    if (cached != null) return cached;

    final secure = storage ?? createDefaultFlutterSecureStorage();
    final stored = await secure.read(key: keyStorageKey);
    if (stored != null) {
      final key = base64Url.decode(stored);
      _cachedKey = key;
      return key;
    }

    final key = Hive.generateSecureKey();
    await secure.write(key: keyStorageKey, value: base64UrlEncode(key));
    _cachedKey = key;
    Logger.info('Hive AES-256 anahtarı üretildi ve güvenli depoya kaydedildi');
    return key;
  }

  /// Kutuyu [HiveAesCipher] ile şifreli aç; eski şifresiz kutuyu göç ettir.
  static Future<Box<T>> openEncryptedBox<T>(
    String name, {
    FlutterSecureStorage? storage,
  }) async {
    if (!_hiveInitialized) {
      await Hive.initFlutter();
      _hiveInitialized = true;
    }

    final cipher = HiveAesCipher(await obtainKey(storage: storage));

    try {
      return await Hive.openBox<T>(name, encryptionCipher: cipher);
    } catch (e) {
      Logger.warning(
          'Hive kutusu şifreli açılamadı, düz-metin göçü deneniyor: $name', e);
    }

    // Eski şifresiz kutu: içeriği okuyup şifreli kutuya taşı.
    try {
      final legacy = await Hive.openBox<T>(name);
      final entries = <dynamic, T>{
        for (final key in legacy.keys)
          if (legacy.get(key) is T) key: legacy.get(key) as T,
      };
      await legacy.deleteFromDisk();
      final box = await Hive.openBox<T>(name, encryptionCipher: cipher);
      await box.putAll(entries);
      Logger.info(
          'Hive kutusu şifreli depoya taşındı: $name (${entries.length} kayıt)');
      return box;
    } catch (e) {
      Logger.warning(
          'Hive düz-metin göçü başarısız, kutu sıfırlanıyor: $name', e);
    }

    // Son çare: bozuk/okunamayan kutuyu sil, boş + şifreli aç.
    await Hive.deleteBoxFromDisk(name);
    return Hive.openBox<T>(name, encryptionCipher: cipher);
  }
}
