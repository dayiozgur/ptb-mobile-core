/// Base exception sınıfı
///
/// Tüm custom exception'ların base sınıfı.
/// Data katmanında throw edilir, domain katmanında Failure'a dönüştürülür.
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const AppException({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => 'AppException(message: $message, code: $code)';
}

/// Sunucu exception
class ServerException extends AppException {
  final int? statusCode;
  final Map<String, dynamic>? responseBody;

  const ServerException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
    this.statusCode,
    this.responseBody,
  });

  @override
  String toString() =>
      'ServerException(message: $message, statusCode: $statusCode)';
}

/// Ağ exception
class NetworkException extends AppException {
  const NetworkException({
    super.message = 'İnternet bağlantısı yok',
    super.code = 'NETWORK_ERROR',
    super.originalError,
    super.stackTrace,
  });
}

/// Cache exception
class CacheException extends AppException {
  const CacheException({
    super.message = 'Önbellek hatası',
    super.code = 'CACHE_ERROR',
    super.originalError,
    super.stackTrace,
  });
}

/// Kimlik doğrulama exception
class AuthenticationException extends AppException {
  const AuthenticationException({
    super.message = 'Kimlik doğrulama hatası',
    super.code = 'AUTH_ERROR',
    super.originalError,
    super.stackTrace,
  });
}

/// Yetkilendirme exception
class AuthorizationException extends AppException {
  const AuthorizationException({
    super.message = 'Bu işlem için yetkiniz yok',
    super.code = 'AUTHORIZATION_ERROR',
    super.originalError,
    super.stackTrace,
  });
}

/// Doğrulama exception
class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  const ValidationException({
    required super.message,
    super.code = 'VALIDATION_ERROR',
    super.originalError,
    super.stackTrace,
    this.fieldErrors,
  });
}

/// Kaynak bulunamadı exception
class NotFoundException extends AppException {
  const NotFoundException({
    super.message = 'Kaynak bulunamadı',
    super.code = 'NOT_FOUND',
    super.originalError,
    super.stackTrace,
  });
}

/// Timeout exception
class TimeoutException extends AppException {
  const TimeoutException({
    super.message = 'İstek zaman aşımına uğradı',
    super.code = 'TIMEOUT',
    super.originalError,
    super.stackTrace,
  });
}

/// Tenant exception
class TenantException extends AppException {
  const TenantException({
    super.message = 'Tenant hatası',
    super.code = 'TENANT_ERROR',
    super.originalError,
    super.stackTrace,
  });
}

/// Biyometrik exception
class BiometricException extends AppException {
  const BiometricException({
    super.message = 'Biyometrik kimlik doğrulama hatası',
    super.code = 'BIOMETRIC_ERROR',
    super.originalError,
    super.stackTrace,
  });
}

/// Rate limit exception
class RateLimitException extends AppException {
  final Duration? retryAfter;

  const RateLimitException({
    super.message = 'Çok fazla istek gönderildi',
    super.code = 'RATE_LIMIT',
    super.originalError,
    super.stackTrace,
    this.retryAfter,
  });
}

/// Depolama exception
class StorageException extends AppException {
  const StorageException({
    super.message = 'Depolama hatası',
    super.code = 'STORAGE_ERROR',
    super.originalError,
    super.stackTrace,
  });
}

/// Parsing exception
class ParsingException extends AppException {
  const ParsingException({
    super.message = 'Veri işleme hatası',
    super.code = 'PARSING_ERROR',
    super.originalError,
    super.stackTrace,
  });
}

/// Platform exception
class PlatformException extends AppException {
  const PlatformException({
    super.message = 'Platform hatası',
    super.code = 'PLATFORM_ERROR',
    super.originalError,
    super.stackTrace,
  });
}
