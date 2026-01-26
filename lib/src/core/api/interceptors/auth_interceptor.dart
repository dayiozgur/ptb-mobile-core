import 'package:dio/dio.dart';

import '../../storage/secure_storage.dart';
import '../../utils/logger.dart';

/// Auth interceptor
///
/// İsteklere otomatik olarak Authorization header ekler.
/// Token refresh işlemini yönetir.
class AuthInterceptor extends Interceptor {
  final SecureStorage _storage;
  final Future<void> Function()? _onTokenExpired;
  final Future<String?> Function(String refreshToken)? _refreshTokenFn;

  bool _isRefreshing = false;
  final List<RequestOptions> _pendingRequests = [];

  AuthInterceptor({
    required SecureStorage storage,
    Future<void> Function()? onTokenExpired,
    Future<String?> Function(String refreshToken)? refreshTokenFn,
  })  : _storage = storage,
        _onTokenExpired = onTokenExpired,
        _refreshTokenFn = refreshTokenFn;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Public endpoint kontrolü
    if (_isPublicEndpoint(options.path)) {
      return handler.next(options);
    }

    // Token ekle
    final token = await _storage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    return handler.next(options);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // 401 Unauthorized
    if (err.response?.statusCode == 401) {
      Logger.warning('Auth error: 401 Unauthorized');

      // Token refresh dene
      if (_refreshTokenFn != null && !_isRefreshing) {
        final refreshed = await _tryRefreshToken(err.requestOptions);
        if (refreshed) {
          // İsteği tekrarla
          try {
            final response = await _retryRequest(err.requestOptions);
            return handler.resolve(response);
          } catch (e) {
            return handler.reject(err);
          }
        }
      }

      // Token expired callback
      await _onTokenExpired?.call();
    }

    return handler.next(err);
  }

  /// Token refresh dene
  Future<bool> _tryRefreshToken(RequestOptions failedRequest) async {
    if (_isRefreshing) {
      // Zaten refresh yapılıyorsa bekle
      _pendingRequests.add(failedRequest);
      return false;
    }

    _isRefreshing = true;

    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) {
        Logger.warning('No refresh token available');
        return false;
      }

      final newAccessToken = await _refreshTokenFn!(refreshToken);
      if (newAccessToken != null) {
        await _storage.saveAccessToken(newAccessToken);
        Logger.info('Token refreshed successfully');

        // Bekleyen istekleri tekrarla
        _retryPendingRequests(newAccessToken);
        return true;
      }
    } catch (e) {
      Logger.error('Token refresh failed', e);
    } finally {
      _isRefreshing = false;
    }

    return false;
  }

  /// İsteği tekrarla
  Future<Response> _retryRequest(RequestOptions options) async {
    final token = await _storage.getAccessToken();
    options.headers['Authorization'] = 'Bearer $token';

    final dio = Dio();
    return dio.fetch(options);
  }

  /// Bekleyen istekleri tekrarla
  void _retryPendingRequests(String newToken) {
    for (final request in _pendingRequests) {
      request.headers['Authorization'] = 'Bearer $newToken';
      Dio().fetch(request).catchError((_) {});
    }
    _pendingRequests.clear();
  }

  /// Public endpoint mi?
  bool _isPublicEndpoint(String path) {
    const publicPaths = [
      '/auth/login',
      '/auth/register',
      '/auth/forgot-password',
      '/auth/reset-password',
      '/auth/refresh',
      '/health',
      '/version',
    ];

    return publicPaths.any((p) => path.contains(p));
  }
}
