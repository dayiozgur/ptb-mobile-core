import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/dio.dart' as dio show MultipartFile;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/exceptions.dart';
import '../utils/logger.dart';
import 'api_response.dart';

/// API Client
///
/// HTTP istekleri ve Supabase sorguları için unified client.
/// Dio tabanlı, interceptor desteği ile.
///
/// Örnek kullanım:
/// ```dart
/// final client = ApiClient(baseUrl: 'https://api.example.com');
///
/// // REST API
/// final response = await client.get<User>('/users/1', fromJson: User.fromJson);
///
/// // Supabase
/// final users = await client.querySupabase<User>(
///   table: 'users',
///   fromJson: User.fromJson,
/// );
/// ```
class ApiClient {
  final Dio _dio;
  final SupabaseClient? _supabase;

  ApiClient({
    required String baseUrl,
    SupabaseClient? supabase,
    List<Interceptor>? interceptors,
    Duration connectTimeout = const Duration(seconds: 30),
    Duration receiveTimeout = const Duration(seconds: 30),
    Duration sendTimeout = const Duration(seconds: 30),
  })  : _supabase = supabase,
        _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: connectTimeout,
            receiveTimeout: receiveTimeout,
            sendTimeout: sendTimeout,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        ) {
    if (interceptors != null) {
      _dio.interceptors.addAll(interceptors);
    }
  }

  /// Dio instance'ı (advanced kullanım için)
  Dio get dio => _dio;

  /// Supabase client
  SupabaseClient? get supabase => _supabase;

  // ============================================
  // REST API METHODS
  // ============================================

  /// GET request
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParams,
    T Function(Map<String, dynamic>)? fromJson,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParams,
        options: options,
        cancelToken: cancelToken,
      );

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return ApiResponse.failure(_handleError(e));
    }
  }

  /// POST request
  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParams,
    T Function(Map<String, dynamic>)? fromJson,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParams,
        options: options,
        cancelToken: cancelToken,
      );

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return ApiResponse.failure(_handleError(e));
    }
  }

  /// PUT request
  Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParams,
    T Function(Map<String, dynamic>)? fromJson,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParams,
        options: options,
        cancelToken: cancelToken,
      );

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return ApiResponse.failure(_handleError(e));
    }
  }

  /// PATCH request
  Future<ApiResponse<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParams,
    T Function(Map<String, dynamic>)? fromJson,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.patch(
        path,
        data: data,
        queryParameters: queryParams,
        options: options,
        cancelToken: cancelToken,
      );

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return ApiResponse.failure(_handleError(e));
    }
  }

  /// DELETE request
  Future<ApiResponse<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParams,
    T Function(Map<String, dynamic>)? fromJson,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParams,
        options: options,
        cancelToken: cancelToken,
      );

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return ApiResponse.failure(_handleError(e));
    }
  }

  /// File upload
  Future<ApiResponse<T>> upload<T>(
    String path, {
    required String filePath,
    String fileField = 'file',
    Map<String, dynamic>? extraData,
    T Function(Map<String, dynamic>)? fromJson,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      final formData = FormData.fromMap({
        fileField: await dio.MultipartFile.fromFile(filePath),
        ...?extraData,
      });

      final response = await _dio.post(
        path,
        data: formData,
        onSendProgress: onProgress,
        cancelToken: cancelToken,
      );

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return ApiResponse.failure(_handleError(e));
    }
  }

  /// File download
  Future<ApiResponse<String>> download(
    String url,
    String savePath, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
      );

      return ApiResponse.success(savePath);
    } catch (e) {
      return ApiResponse.failure(_handleError(e));
    }
  }

  // ============================================
  // SUPABASE METHODS
  // ============================================

  /// Supabase tablo sorgusu
  Future<List<T>> querySupabase<T>({
    required String table,
    required T Function(Map<String, dynamic>) fromJson,
    String? select,
    PostgrestFilterBuilder<List<Map<String, dynamic>>> Function(
      PostgrestFilterBuilder<List<Map<String, dynamic>>>,
    )? filter,
  }) async {
    if (_supabase == null) {
      throw const ServerException(message: 'Supabase client not initialized');
    }

    try {
      var query = _supabase!.from(table).select(select ?? '*');

      if (filter != null) {
        query = filter(query);
      }

      final response = await query;
      return response.map((json) => fromJson(json)).toList();
    } catch (e) {
      Logger.error('Supabase query error: $table', e);
      throw ServerException(
        message: 'Supabase sorgu hatası',
        originalError: e,
      );
    }
  }

  /// Supabase tek kayıt getir
  Future<T?> querySupabaseSingle<T>({
    required String table,
    required T Function(Map<String, dynamic>) fromJson,
    String? select,
    required PostgrestFilterBuilder<List<Map<String, dynamic>>> Function(
      PostgrestFilterBuilder<List<Map<String, dynamic>>>,
    ) filter,
  }) async {
    if (_supabase == null) {
      throw const ServerException(message: 'Supabase client not initialized');
    }

    try {
      var query = _supabase!.from(table).select(select ?? '*');
      query = filter(query);

      final response = await query.maybeSingle();
      if (response == null) return null;
      return fromJson(response);
    } catch (e) {
      Logger.error('Supabase single query error: $table', e);
      throw ServerException(
        message: 'Supabase sorgu hatası',
        originalError: e,
      );
    }
  }

  /// Supabase insert
  Future<T> insertSupabase<T>({
    required String table,
    required Map<String, dynamic> data,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    if (_supabase == null) {
      throw const ServerException(message: 'Supabase client not initialized');
    }

    try {
      final response =
          await _supabase!.from(table).insert(data).select().single();
      return fromJson(response);
    } catch (e) {
      Logger.error('Supabase insert error: $table', e);
      throw ServerException(
        message: 'Supabase insert hatası',
        originalError: e,
      );
    }
  }

  /// Supabase update
  Future<T> updateSupabase<T>({
    required String table,
    required Map<String, dynamic> data,
    required T Function(Map<String, dynamic>) fromJson,
    required PostgrestFilterBuilder<List<Map<String, dynamic>>> Function(
      PostgrestFilterBuilder<List<Map<String, dynamic>>>,
    ) filter,
  }) async {
    if (_supabase == null) {
      throw const ServerException(message: 'Supabase client not initialized');
    }

    try {
      var query = _supabase!.from(table).update(data);
      final response = await filter(query).select().single();
      return fromJson(response);
    } catch (e) {
      Logger.error('Supabase update error: $table', e);
      throw ServerException(
        message: 'Supabase update hatası',
        originalError: e,
      );
    }
  }

  /// Supabase delete
  Future<void> deleteSupabase({
    required String table,
    required PostgrestFilterBuilder<List<Map<String, dynamic>>> Function(
      PostgrestFilterBuilder<List<Map<String, dynamic>>>,
    ) filter,
  }) async {
    if (_supabase == null) {
      throw const ServerException(message: 'Supabase client not initialized');
    }

    try {
      var query = _supabase!.from(table).delete();
      await filter(query);
    } catch (e) {
      Logger.error('Supabase delete error: $table', e);
      throw ServerException(
        message: 'Supabase delete hatası',
        originalError: e,
      );
    }
  }

  // ============================================
  // PRIVATE METHODS
  // ============================================

  /// Response handler
  ApiResponse<T> _handleResponse<T>(
    Response response,
    T Function(Map<String, dynamic>)? fromJson,
  ) {
    final data = response.data;

    if (data == null) {
      return ApiResponse.success(null as T);
    }

    if (fromJson != null && data is Map<String, dynamic>) {
      return ApiResponse.success(fromJson(data));
    }

    return ApiResponse.success(data as T);
  }

  /// Error handler
  ApiError _handleError(dynamic error) {
    if (error is DioException) {
      return _handleDioError(error);
    }

    return ApiError(
      message: error.toString(),
      originalError: error,
    );
  }

  /// Dio error handler
  ApiError _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiError(
          message: 'Bağlantı zaman aşımına uğradı',
          code: 'TIMEOUT',
          originalError: error,
        );

      case DioExceptionType.connectionError:
        return ApiError(
          message: 'İnternet bağlantısı yok',
          code: 'NETWORK_ERROR',
          originalError: error,
        );

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final responseData = error.response?.data;

        String message = 'Sunucu hatası';
        Map<String, dynamic>? details;

        if (responseData is Map<String, dynamic>) {
          message = responseData['message'] as String? ??
              responseData['error'] as String? ??
              message;
          details = responseData['errors'] as Map<String, dynamic>?;
        }

        return ApiError(
          message: message,
          statusCode: statusCode,
          details: details,
          originalError: error,
        );

      case DioExceptionType.cancel:
        return ApiError(
          message: 'İstek iptal edildi',
          code: 'CANCELLED',
          originalError: error,
        );

      default:
        return ApiError(
          message: error.message ?? 'Bilinmeyen hata',
          originalError: error,
        );
    }
  }
}
