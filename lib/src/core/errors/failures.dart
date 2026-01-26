import 'package:equatable/equatable.dart';

/// Base failure sınıfı
///
/// Tüm hata durumlarını temsil eden abstract sınıf.
/// Domain ve Data katmanlarında kullanılır.
abstract class Failure extends Equatable {
  final String message;
  final String? code;
  final dynamic originalError;

  const Failure({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  List<Object?> get props => [message, code];

  @override
  String toString() => 'Failure(message: $message, code: $code)';
}

/// Sunucu hatası
class ServerFailure extends Failure {
  final int? statusCode;

  const ServerFailure({
    required super.message,
    super.code,
    super.originalError,
    this.statusCode,
  });

  @override
  List<Object?> get props => [...super.props, statusCode];
}

/// Ağ bağlantı hatası
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'İnternet bağlantısı yok',
    super.code = 'NETWORK_ERROR',
    super.originalError,
  });
}

/// Cache hatası
class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'Önbellek hatası',
    super.code = 'CACHE_ERROR',
    super.originalError,
  });
}

/// Kimlik doğrulama hatası
class AuthenticationFailure extends Failure {
  const AuthenticationFailure({
    super.message = 'Kimlik doğrulama hatası',
    super.code = 'AUTH_ERROR',
    super.originalError,
  });
}

/// Yetkilendirme hatası
class AuthorizationFailure extends Failure {
  const AuthorizationFailure({
    super.message = 'Bu işlem için yetkiniz yok',
    super.code = 'AUTHORIZATION_ERROR',
    super.originalError,
  });
}

/// Doğrulama hatası
class ValidationFailure extends Failure {
  final Map<String, String>? fieldErrors;

  const ValidationFailure({
    required super.message,
    super.code = 'VALIDATION_ERROR',
    super.originalError,
    this.fieldErrors,
  });

  @override
  List<Object?> get props => [...super.props, fieldErrors];
}

/// Kaynak bulunamadı hatası
class NotFoundFailure extends Failure {
  const NotFoundFailure({
    super.message = 'Kaynak bulunamadı',
    super.code = 'NOT_FOUND',
    super.originalError,
  });
}

/// Timeout hatası
class TimeoutFailure extends Failure {
  const TimeoutFailure({
    super.message = 'İstek zaman aşımına uğradı',
    super.code = 'TIMEOUT',
    super.originalError,
  });
}

/// Bilinmeyen hata
class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'Beklenmeyen bir hata oluştu',
    super.code = 'UNKNOWN_ERROR',
    super.originalError,
  });
}

/// Tenant hatası
class TenantFailure extends Failure {
  const TenantFailure({
    super.message = 'Tenant hatası',
    super.code = 'TENANT_ERROR',
    super.originalError,
  });
}

/// Biyometrik kimlik doğrulama hatası
class BiometricFailure extends Failure {
  const BiometricFailure({
    super.message = 'Biyometrik kimlik doğrulama hatası',
    super.code = 'BIOMETRIC_ERROR',
    super.originalError,
  });
}

/// Rate limit hatası
class RateLimitFailure extends Failure {
  final Duration? retryAfter;

  const RateLimitFailure({
    super.message = 'Çok fazla istek gönderildi',
    super.code = 'RATE_LIMIT',
    super.originalError,
    this.retryAfter,
  });

  @override
  List<Object?> get props => [...super.props, retryAfter];
}

/// Depolama hatası
class StorageFailure extends Failure {
  const StorageFailure({
    super.message = 'Depolama hatası',
    super.code = 'STORAGE_ERROR',
    super.originalError,
  });
}

/// Platform hatası (iOS/Android spesifik)
class PlatformFailure extends Failure {
  const PlatformFailure({
    super.message = 'Platform hatası',
    super.code = 'PLATFORM_ERROR',
    super.originalError,
  });
}
