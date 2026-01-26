import '../errors/failures.dart';

/// API yanıt wrapper'ı
///
/// Success ve failure durumlarını type-safe şekilde yönetir.
/// Either pattern benzeri bir yapı sağlar.
///
/// Örnek kullanım:
/// ```dart
/// final response = await apiClient.get<User>('/users/1');
/// response.when(
///   success: (user) => print(user.name),
///   failure: (error) => print(error.message),
/// );
/// ```
class ApiResponse<T> {
  final T? _data;
  final ApiError? _error;
  final bool _isSuccess;

  const ApiResponse._({
    T? data,
    ApiError? error,
    required bool isSuccess,
  })  : _data = data,
        _error = error,
        _isSuccess = isSuccess;

  /// Success response oluştur
  factory ApiResponse.success(T data) {
    return ApiResponse._(data: data, isSuccess: true);
  }

  /// Failure response oluştur
  factory ApiResponse.failure(ApiError error) {
    return ApiResponse._(error: error, isSuccess: false);
  }

  /// Başarılı mı?
  bool get isSuccess => _isSuccess;

  /// Başarısız mı?
  bool get isFailure => !_isSuccess;

  /// Data (null olabilir)
  T? get data => _data;

  /// Error (null olabilir)
  ApiError? get error => _error;

  /// Data al (hata varsa exception fırlatır)
  T get dataOrThrow {
    if (_isSuccess && _data != null) return _data!;
    throw _error ?? const ApiError(message: 'Unknown error');
  }

  /// Pattern matching
  R when<R>({
    required R Function(T data) success,
    required R Function(ApiError error) failure,
  }) {
    if (_isSuccess && _data != null) {
      return success(_data!);
    }
    return failure(_error ?? const ApiError(message: 'Unknown error'));
  }

  /// Nullable pattern matching
  R? whenOrNull<R>({
    R Function(T data)? success,
    R Function(ApiError error)? failure,
  }) {
    if (_isSuccess && _data != null) {
      return success?.call(_data!);
    }
    return failure?.call(_error ?? const ApiError(message: 'Unknown error'));
  }

  /// Maybe pattern
  R maybeWhen<R>({
    R Function(T data)? success,
    R Function(ApiError error)? failure,
    required R Function() orElse,
  }) {
    if (_isSuccess && _data != null && success != null) {
      return success(_data!);
    }
    if (!_isSuccess && failure != null) {
      return failure(_error ?? const ApiError(message: 'Unknown error'));
    }
    return orElse();
  }

  /// Map success data
  ApiResponse<R> map<R>(R Function(T data) transform) {
    if (_isSuccess && _data != null) {
      return ApiResponse.success(transform(_data!));
    }
    return ApiResponse.failure(
      _error ?? const ApiError(message: 'Unknown error'),
    );
  }

  /// Flat map
  Future<ApiResponse<R>> flatMap<R>(
    Future<ApiResponse<R>> Function(T data) transform,
  ) async {
    if (_isSuccess && _data != null) {
      return transform(_data!);
    }
    return ApiResponse.failure(
      _error ?? const ApiError(message: 'Unknown error'),
    );
  }

  /// Fold (Either style)
  R fold<R>(
    R Function(ApiError error) onFailure,
    R Function(T data) onSuccess,
  ) {
    if (_isSuccess && _data != null) {
      return onSuccess(_data!);
    }
    return onFailure(_error ?? const ApiError(message: 'Unknown error'));
  }

  /// Default değer ile data al
  T getOrElse(T defaultValue) {
    if (_isSuccess && _data != null) return _data!;
    return defaultValue;
  }

  /// Callback ile default değer
  T getOrElseGet(T Function() defaultValue) {
    if (_isSuccess && _data != null) return _data!;
    return defaultValue();
  }

  @override
  String toString() {
    if (_isSuccess) {
      return 'ApiResponse.success($_data)';
    }
    return 'ApiResponse.failure($_error)';
  }
}

/// API hata modeli
class ApiError {
  /// Hata mesajı
  final String message;

  /// Hata kodu
  final String? code;

  /// HTTP status kodu
  final int? statusCode;

  /// Detaylı hata bilgisi
  final Map<String, dynamic>? details;

  /// Orijinal hata
  final dynamic originalError;

  const ApiError({
    required this.message,
    this.code,
    this.statusCode,
    this.details,
    this.originalError,
  });

  /// Server error mu?
  bool get isServerError => statusCode != null && statusCode! >= 500;

  /// Client error mu?
  bool get isClientError =>
      statusCode != null && statusCode! >= 400 && statusCode! < 500;

  /// Unauthorized mu?
  bool get isUnauthorized => statusCode == 401;

  /// Forbidden mu?
  bool get isForbidden => statusCode == 403;

  /// Not found mu?
  bool get isNotFound => statusCode == 404;

  /// Validation error mu?
  bool get isValidationError => statusCode == 422;

  /// Rate limited mu?
  bool get isRateLimited => statusCode == 429;

  /// Network error mu?
  bool get isNetworkError => code == 'NETWORK_ERROR';

  /// Timeout mu?
  bool get isTimeout => code == 'TIMEOUT';

  /// Failure'a dönüştür
  Failure toFailure() {
    if (isNetworkError) {
      return NetworkFailure(message: message, originalError: originalError);
    }
    if (isTimeout) {
      return TimeoutFailure(message: message, originalError: originalError);
    }
    if (isUnauthorized) {
      return AuthenticationFailure(message: message, originalError: originalError);
    }
    if (isForbidden) {
      return AuthorizationFailure(message: message, originalError: originalError);
    }
    if (isNotFound) {
      return NotFoundFailure(message: message, originalError: originalError);
    }
    if (isValidationError) {
      return ValidationFailure(
        message: message,
        originalError: originalError,
        fieldErrors: details?.map((k, v) => MapEntry(k, v.toString())),
      );
    }
    if (isRateLimited) {
      return RateLimitFailure(message: message, originalError: originalError);
    }
    return ServerFailure(
      message: message,
      statusCode: statusCode,
      originalError: originalError,
    );
  }

  @override
  String toString() {
    return 'ApiError(message: $message, code: $code, statusCode: $statusCode)';
  }
}

/// Paginated response wrapper
class PaginatedResponse<T> {
  /// Data listesi
  final List<T> data;

  /// Mevcut sayfa
  final int page;

  /// Sayfa başına öğe sayısı
  final int perPage;

  /// Toplam öğe sayısı
  final int total;

  /// Toplam sayfa sayısı
  final int totalPages;

  /// Sonraki sayfa var mı?
  final bool hasMore;

  const PaginatedResponse({
    required this.data,
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
    required this.hasMore,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final dataList = (json['data'] as List?) ?? [];
    final meta = json['meta'] as Map<String, dynamic>? ?? json;

    return PaginatedResponse(
      data: dataList.map((e) => fromJson(e as Map<String, dynamic>)).toList(),
      page: meta['page'] as int? ?? meta['current_page'] as int? ?? 1,
      perPage: meta['per_page'] as int? ?? meta['limit'] as int? ?? 20,
      total: meta['total'] as int? ?? dataList.length,
      totalPages: meta['total_pages'] as int? ?? meta['last_page'] as int? ?? 1,
      hasMore: meta['has_more'] as bool? ??
          (meta['page'] as int? ?? 1) < (meta['total_pages'] as int? ?? 1),
    );
  }

  /// Empty response oluştur
  factory PaginatedResponse.empty() {
    return const PaginatedResponse(
      data: [],
      page: 1,
      perPage: 20,
      total: 0,
      totalPages: 0,
      hasMore: false,
    );
  }

  /// İlk sayfa mı?
  bool get isFirstPage => page == 1;

  /// Son sayfa mı?
  bool get isLastPage => page >= totalPages;

  /// Boş mu?
  bool get isEmpty => data.isEmpty;

  /// Boş değil mi?
  bool get isNotEmpty => data.isNotEmpty;
}
