import 'package:dio/dio.dart';

import '../../utils/logger.dart';

/// Logger interceptor
///
/// API isteklerini ve yanıtlarını loglar.
class LoggerInterceptor extends Interceptor {
  final bool logRequest;
  final bool logResponse;
  final bool logError;
  final bool logHeaders;
  final bool logBody;

  LoggerInterceptor({
    this.logRequest = true,
    this.logResponse = true,
    this.logError = true,
    this.logHeaders = false,
    this.logBody = true,
  });

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (logRequest) {
      Logger.apiRequest(
        method: options.method,
        url: options.uri.toString(),
        headers: logHeaders ? options.headers : null,
        body: logBody ? options.data : null,
      );
    }

    return handler.next(options);
  }

  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    if (logResponse) {
      final duration = response.requestOptions.extra['startTime'] != null
          ? DateTime.now().difference(
              response.requestOptions.extra['startTime'] as DateTime,
            )
          : null;

      Logger.apiResponse(
        method: response.requestOptions.method,
        url: response.requestOptions.uri.toString(),
        statusCode: response.statusCode ?? 0,
        body: logBody ? response.data : null,
        duration: duration,
      );
    }

    return handler.next(response);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    if (logError) {
      Logger.apiError(
        method: err.requestOptions.method,
        url: err.requestOptions.uri.toString(),
        error: err.message ?? err.toString(),
        stackTrace: err.stackTrace,
      );
    }

    return handler.next(err);
  }
}

/// Request timing interceptor
class TimingInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    options.extra['startTime'] = DateTime.now();
    return handler.next(options);
  }
}
