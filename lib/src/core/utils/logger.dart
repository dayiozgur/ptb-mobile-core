import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Log seviyeleri
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Uygulama loglama yardımcısı
///
/// Debug modunda konsola, release modunda ise
/// yapılandırılmış log servisine yazar.
class Logger {
  Logger._();

  /// Minimum log seviyesi
  static LogLevel _minLevel = LogLevel.debug;

  /// Log callback (harici servisler için)
  static void Function(LogLevel level, String message, Object? error)?
      _onLog;

  /// Logger yapılandırması
  static void configure({
    LogLevel minLevel = LogLevel.debug,
    void Function(LogLevel level, String message, Object? error)? onLog,
  }) {
    _minLevel = minLevel;
    _onLog = onLog;
  }

  /// Minimum log seviyesini ayarla
  static void setMinLevel(LogLevel level) {
    _minLevel = level;
  }

  /// Mevcut minimum log seviyesini al
  static LogLevel get minLevel => _minLevel;

  /// Debug log
  static void debug(String message, [Object? data]) {
    _log(LogLevel.debug, message, data);
  }

  /// Info log
  static void info(String message, [Object? data]) {
    _log(LogLevel.info, message, data);
  }

  /// Warning log
  static void warning(String message, [Object? error]) {
    _log(LogLevel.warning, message, error);
  }

  /// Error log
  static void error(
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    _log(LogLevel.error, message, error, stackTrace);
  }

  /// API request log
  static void apiRequest({
    required String method,
    required String url,
    Map<String, dynamic>? headers,
    dynamic body,
  }) {
    if (_shouldLog(LogLevel.debug)) {
      final buffer = StringBuffer();
      buffer.writeln('┌── API REQUEST ──────────────────────');
      buffer.writeln('│ $method $url');
      if (headers != null && headers.isNotEmpty) {
        buffer.writeln('│ Headers: $headers');
      }
      if (body != null) {
        buffer.writeln('│ Body: $body');
      }
      buffer.write('└─────────────────────────────────────');
      _printLog(LogLevel.debug, buffer.toString());
    }
  }

  /// API response log
  static void apiResponse({
    required String method,
    required String url,
    required int statusCode,
    dynamic body,
    Duration? duration,
  }) {
    if (_shouldLog(LogLevel.debug)) {
      final buffer = StringBuffer();
      buffer.writeln('┌── API RESPONSE ─────────────────────');
      buffer.writeln('│ $method $url');
      buffer.writeln('│ Status: $statusCode');
      if (duration != null) {
        buffer.writeln('│ Duration: ${duration.inMilliseconds}ms');
      }
      if (body != null) {
        final bodyStr = body.toString();
        if (bodyStr.length > 500) {
          buffer.writeln('│ Body: ${bodyStr.substring(0, 500)}...');
        } else {
          buffer.writeln('│ Body: $bodyStr');
        }
      }
      buffer.write('└─────────────────────────────────────');

      final level = statusCode >= 400 ? LogLevel.warning : LogLevel.debug;
      _printLog(level, buffer.toString());
    }
  }

  /// API error log
  static void apiError({
    required String method,
    required String url,
    required Object error,
    StackTrace? stackTrace,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('┌── API ERROR ────────────────────────');
    buffer.writeln('│ $method $url');
    buffer.writeln('│ Error: $error');
    buffer.write('└─────────────────────────────────────');
    _log(LogLevel.error, buffer.toString(), error, stackTrace);
  }

  /// Navigation log
  static void navigation(String route, {Map<String, dynamic>? params}) {
    if (_shouldLog(LogLevel.debug)) {
      final buffer = StringBuffer();
      buffer.write('🧭 Navigation: $route');
      if (params != null && params.isNotEmpty) {
        buffer.write(' | Params: $params');
      }
      _printLog(LogLevel.debug, buffer.toString());
    }
  }

  /// State change log
  static void state(String name, {dynamic oldValue, dynamic newValue}) {
    if (_shouldLog(LogLevel.debug)) {
      final buffer = StringBuffer();
      buffer.write('📦 State: $name');
      if (oldValue != null) {
        buffer.write(' | Old: $oldValue');
      }
      if (newValue != null) {
        buffer.write(' | New: $newValue');
      }
      _printLog(LogLevel.debug, buffer.toString());
    }
  }

  /// Performance log
  static void performance(String operation, Duration duration) {
    if (_shouldLog(LogLevel.debug)) {
      _printLog(
        LogLevel.debug,
        '⏱️ Performance: $operation took ${duration.inMilliseconds}ms',
      );
    }
  }

  /// Measure execution time
  static Future<T> measure<T>(
    String operation,
    Future<T> Function() action,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      stopwatch.stop();
      performance(operation, stopwatch.elapsed);
    }
  }

  // ============================================
  // PRIVATE METHODS
  // ============================================

  static bool _shouldLog(LogLevel level) {
    return level.index >= _minLevel.index;
  }

  static void _log(
    LogLevel level,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (!_shouldLog(level)) return;

    _printLog(level, message, error, stackTrace);
    _onLog?.call(level, message, error);
  }

  static void _printLog(
    LogLevel level,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (!kDebugMode) return;

    final prefix = _getPrefix(level);
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);

    developer.log(
      '$prefix [$timestamp] $message',
      name: 'PTBCore',
      error: error,
      stackTrace: stackTrace,
      level: _getDeveloperLogLevel(level),
    );
  }

  static String _getPrefix(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🔍';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
    }
  }

  static int _getDeveloperLogLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }
}
