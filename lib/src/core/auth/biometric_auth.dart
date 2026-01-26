import 'dart:io';

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../utils/logger.dart';

/// Biyometrik authentication türleri
enum BiometricType {
  /// Parmak izi
  fingerprint,

  /// Yüz tanıma (Face ID)
  face,

  /// Iris tarama
  iris,

  /// Güçlü (cihaz tarafından belirlenen en güçlü)
  strong,

  /// Zayıf (PIN, pattern vb.)
  weak,
}

/// Biyometrik authentication durumu
enum BiometricStatus {
  /// Kullanılabilir
  available,

  /// Cihaz desteklemiyor
  notSupported,

  /// Ayarlanmamış
  notEnrolled,

  /// Kilitli (çok fazla deneme)
  lockedOut,

  /// Geçici olarak kilitli
  temporaryLockedOut,

  /// Bilinmeyen durum
  unknown,
}

/// Biyometrik authentication sonucu
class BiometricResult {
  /// Başarılı mı?
  final bool isSuccess;

  /// Durum
  final BiometricStatus status;

  /// Hata mesajı
  final String? errorMessage;

  const BiometricResult._({
    required this.isSuccess,
    required this.status,
    this.errorMessage,
  });

  factory BiometricResult.success() {
    return const BiometricResult._(
      isSuccess: true,
      status: BiometricStatus.available,
    );
  }

  factory BiometricResult.failure({
    required BiometricStatus status,
    String? message,
  }) {
    return BiometricResult._(
      isSuccess: false,
      status: status,
      errorMessage: message,
    );
  }
}

/// Biyometrik Authentication Servisi
///
/// Face ID, Touch ID ve parmak izi doğrulaması için.
///
/// Örnek kullanım:
/// ```dart
/// final biometric = BiometricAuth();
///
/// // Kontrol et
/// if (await biometric.isAvailable()) {
///   // Doğrula
///   final result = await biometric.authenticate(
///     reason: 'Uygulamaya erişmek için doğrulama yapın',
///   );
///   if (result.isSuccess) {
///     // Başarılı
///   }
/// }
/// ```
class BiometricAuth {
  final LocalAuthentication _localAuth;

  BiometricAuth({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  /// Biyometrik authentication kullanılabilir mi?
  Future<bool> isAvailable() async {
    try {
      // Cihaz destekliyor mu?
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return false;

      // Cihaz güvenli mi? (PIN, pattern, şifre ayarlanmış mı?)
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!isDeviceSupported) return false;

      // En az bir biyometrik yöntem kayıtlı mı?
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      Logger.error('Biometric availability check failed', e);
      return false;
    }
  }

  /// Mevcut biyometrik türlerini getir
  Future<List<BiometricType>> getAvailableTypes() async {
    try {
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      return availableBiometrics.map(_mapBiometricType).toList();
    } catch (e) {
      Logger.error('Failed to get available biometrics', e);
      return [];
    }
  }

  /// Biyometrik authentication durumunu kontrol et
  Future<BiometricStatus> checkStatus() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!isDeviceSupported) {
        return BiometricStatus.notSupported;
      }

      if (!canCheck) {
        return BiometricStatus.notEnrolled;
      }

      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        return BiometricStatus.notEnrolled;
      }

      return BiometricStatus.available;
    } catch (e) {
      Logger.error('Failed to check biometric status', e);
      return BiometricStatus.unknown;
    }
  }

  /// Biyometrik doğrulama yap
  ///
  /// [reason] - Kullanıcıya gösterilecek açıklama
  /// [useErrorDialogs] - Hata dialog'larını göster
  /// [stickyAuth] - Uygulama arka plana giderse doğrulamayı sürdür
  /// [biometricOnly] - Sadece biyometrik (PIN/şifre kabul etme)
  Future<BiometricResult> authenticate({
    required String reason,
    bool useErrorDialogs = true,
    bool stickyAuth = true,
    bool biometricOnly = false,
  }) async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: biometricOnly,
        ),
      );

      if (authenticated) {
        Logger.debug('Biometric authentication successful');
        return BiometricResult.success();
      } else {
        Logger.debug('Biometric authentication cancelled');
        return BiometricResult.failure(
          status: BiometricStatus.unknown,
          message: 'Doğrulama iptal edildi',
        );
      }
    } on PlatformException catch (e) {
      Logger.error('Biometric authentication failed', e);
      return _handlePlatformException(e);
    } catch (e) {
      Logger.error('Biometric authentication error', e);
      return BiometricResult.failure(
        status: BiometricStatus.unknown,
        message: e.toString(),
      );
    }
  }

  /// Doğrulamayı iptal et
  Future<bool> cancelAuthentication() async {
    try {
      return await _localAuth.stopAuthentication();
    } catch (e) {
      Logger.error('Failed to cancel authentication', e);
      return false;
    }
  }

  /// Platform'a göre biyometrik türü adını getir
  String getBiometricTypeName(BiometricType type) {
    if (Platform.isIOS) {
      switch (type) {
        case BiometricType.face:
          return 'Face ID';
        case BiometricType.fingerprint:
          return 'Touch ID';
        default:
          return 'Biyometrik';
      }
    } else {
      switch (type) {
        case BiometricType.face:
          return 'Yüz Tanıma';
        case BiometricType.fingerprint:
          return 'Parmak İzi';
        case BiometricType.iris:
          return 'Iris Tarama';
        default:
          return 'Biyometrik';
      }
    }
  }

  /// Mevcut en güçlü biyometrik türünün adını getir
  Future<String> getPrimaryBiometricName() async {
    final types = await getAvailableTypes();
    if (types.isEmpty) return 'Biyometrik';

    // Face ID/Yüz tanıma öncelikli
    if (types.contains(BiometricType.face)) {
      return getBiometricTypeName(BiometricType.face);
    }
    // Sonra parmak izi
    if (types.contains(BiometricType.fingerprint)) {
      return getBiometricTypeName(BiometricType.fingerprint);
    }
    // Diğer
    return getBiometricTypeName(types.first);
  }

  BiometricType _mapBiometricType(BiometricType systemType) {
    switch (systemType) {
      case BiometricType.face:
        return BiometricType.face;
      case BiometricType.fingerprint:
        return BiometricType.fingerprint;
      case BiometricType.iris:
        return BiometricType.iris;
      case BiometricType.strong:
        return BiometricType.strong;
      case BiometricType.weak:
        return BiometricType.weak;
    }
  }

  BiometricResult _handlePlatformException(PlatformException e) {
    switch (e.code) {
      case 'NotAvailable':
        return BiometricResult.failure(
          status: BiometricStatus.notSupported,
          message: 'Biyometrik doğrulama bu cihazda kullanılamıyor',
        );
      case 'NotEnrolled':
        return BiometricResult.failure(
          status: BiometricStatus.notEnrolled,
          message: 'Biyometrik veri kayıtlı değil. Cihaz ayarlarından ekleyin',
        );
      case 'LockedOut':
        return BiometricResult.failure(
          status: BiometricStatus.lockedOut,
          message: 'Çok fazla başarısız deneme. Cihaz şifresi ile giriş yapın',
        );
      case 'PermanentlyLockedOut':
        return BiometricResult.failure(
          status: BiometricStatus.lockedOut,
          message: 'Biyometrik doğrulama kilitlendi. Cihaz şifresi gerekli',
        );
      default:
        return BiometricResult.failure(
          status: BiometricStatus.unknown,
          message: e.message ?? 'Bilinmeyen hata',
        );
    }
  }
}

/// Biyometrik ayarları
class BiometricSettings {
  /// Biyometrik giriş aktif mi?
  final bool isEnabled;

  /// Son kullanım zamanı
  final DateTime? lastUsed;

  /// Tercih edilen tür
  final BiometricType? preferredType;

  const BiometricSettings({
    this.isEnabled = false,
    this.lastUsed,
    this.preferredType,
  });

  BiometricSettings copyWith({
    bool? isEnabled,
    DateTime? lastUsed,
    BiometricType? preferredType,
  }) {
    return BiometricSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      lastUsed: lastUsed ?? this.lastUsed,
      preferredType: preferredType ?? this.preferredType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'lastUsed': lastUsed?.toIso8601String(),
      'preferredType': preferredType?.name,
    };
  }

  factory BiometricSettings.fromJson(Map<String, dynamic> json) {
    return BiometricSettings(
      isEnabled: json['isEnabled'] as bool? ?? false,
      lastUsed: json['lastUsed'] != null
          ? DateTime.parse(json['lastUsed'] as String)
          : null,
      preferredType: json['preferredType'] != null
          ? BiometricType.values.firstWhere(
              (e) => e.name == json['preferredType'],
              orElse: () => BiometricType.fingerprint,
            )
          : null,
    );
  }
}
