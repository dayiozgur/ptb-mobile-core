import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/logger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../buttons/app_button.dart';

/// Hata bilgisi
class ErrorDetails {
  /// Hata nesnesi
  final Object error;

  /// Stack trace
  final StackTrace? stackTrace;

  /// Oluşma zamanı
  final DateTime occurredAt;

  /// Hata konumu (widget adı vb.)
  final String? context;

  ErrorDetails({
    required this.error,
    this.stackTrace,
    this.context,
  }) : occurredAt = DateTime.now();

  /// Hata mesajı
  String get message => error.toString();

  /// Kısa hata mesajı
  String get shortMessage {
    final msg = message;
    if (msg.length > 100) {
      return '${msg.substring(0, 100)}...';
    }
    return msg;
  }

  @override
  String toString() => 'ErrorDetails(error: $error, context: $context)';
}

/// Hata raporlama callback
typedef ErrorReporter = Future<void> Function(ErrorDetails details);

/// Error Boundary Widget
///
/// Alt widget'larda oluşan hataları yakalar ve fallback UI gösterir.
///
/// Örnek kullanım:
/// ```dart
/// ErrorBoundary(
///   onError: (details) async {
///     // Crashlytics'e gönder
///     await FirebaseCrashlytics.instance.recordError(
///       details.error,
///       details.stackTrace,
///     );
///   },
///   child: MyApp(),
/// )
/// ```
class ErrorBoundary extends StatefulWidget {
  /// Alt widget
  final Widget child;

  /// Hata durumunda gösterilecek widget
  final Widget Function(BuildContext context, ErrorDetails details, VoidCallback retry)?
      errorBuilder;

  /// Hata callback'i
  final ErrorReporter? onError;

  /// Otomatik hata raporlama
  final bool reportErrors;

  /// Hata gösterme modu
  final bool showErrorDetails;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
    this.onError,
    this.reportErrors = true,
    this.showErrorDetails = false,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  ErrorDetails? _error;

  @override
  void initState() {
    super.initState();

    // Flutter hata handler'ını ayarla
    FlutterError.onError = _handleFlutterError;
  }

  void _handleFlutterError(FlutterErrorDetails details) {
    // Widget build hatalarını yakala
    if (mounted) {
      setState(() {
        _error = ErrorDetails(
          error: details.exception,
          stackTrace: details.stack,
          context: details.context?.toDescription(),
        );
      });

      _reportError(_error!);
    }

    // Debug modda orijinal handler'ı çağır
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }
  }

  Future<void> _reportError(ErrorDetails details) async {
    Logger.error('ErrorBoundary caught: ${details.message}', details.error, details.stackTrace);

    if (widget.reportErrors && widget.onError != null) {
      try {
        await widget.onError!(details);
      } catch (e) {
        Logger.error('Failed to report error', e);
      }
    }
  }

  void _retry() {
    setState(() {
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(context, _error!, _retry);
      }
      return _DefaultErrorView(
        error: _error!,
        onRetry: _retry,
        showDetails: widget.showErrorDetails || kDebugMode,
      );
    }

    return widget.child;
  }
}

/// Varsayılan hata görünümü
class _DefaultErrorView extends StatelessWidget {
  final ErrorDetails error;
  final VoidCallback onRetry;
  final bool showDetails;

  const _DefaultErrorView({
    required this.error,
    required this.onRetry,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // İkon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    size: 40,
                    color: AppColors.error,
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Başlık
                Text(
                  'Bir Hata Oluştu',
                  style: AppTypography.title2,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.sm),

                // Mesaj
                Text(
                  'Üzgünüz, beklenmeyen bir hata oluştu.',
                  style: AppTypography.body.copyWith(
                    color: AppColors.secondaryLabel(context),
                  ),
                  textAlign: TextAlign.center,
                ),

                // Detaylar
                if (showDetails) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.systemGray6,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hata Detayı:',
                          style: AppTypography.caption1.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          error.shortMessage,
                          style: AppTypography.caption1.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (error.context != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Konum: ${error.context}',
                            style: AppTypography.caption2.copyWith(
                              color: AppColors.secondaryLabel(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),

                // Yeniden dene butonu
                AppButton(
                  label: 'Tekrar Dene',
                  onPressed: onRetry,
                  icon: Icons.refresh,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Zone tabanlı hata yakalayıcı
///
/// Tüm async hataları da yakalar.
///
/// ```dart
/// void main() {
///   runAppWithErrorHandler(
///     app: MyApp(),
///     onError: (error, stack) async {
///       await Crashlytics.recordError(error, stack);
///     },
///   );
/// }
/// ```
void runAppWithErrorHandler({
  required Widget app,
  Future<void> Function(Object error, StackTrace stack)? onError,
  bool reportErrors = true,
}) {
  // Flutter framework hatalarını yakala
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (reportErrors && onError != null) {
      onError(details.exception, details.stack ?? StackTrace.current);
    }
  };

  // Platform dispatcher hatalarını yakala
  PlatformDispatcher.instance.onError = (error, stack) {
    Logger.error('Platform error', error, stack);
    if (reportErrors && onError != null) {
      onError(error, stack);
    }
    return true;
  };

  // Zone ile async hataları yakala
  runZonedGuarded(
    () => runApp(app),
    (error, stack) {
      Logger.error('Uncaught async error', error, stack);
      if (reportErrors && onError != null) {
        onError(error, stack);
      }
    },
  );
}

/// Try-catch wrapper widget
///
/// Belirli bir widget'ı try-catch ile sarar.
class TryCatch extends StatelessWidget {
  /// Alt widget oluşturucu
  final Widget Function() builder;

  /// Hata durumunda gösterilecek widget
  final Widget Function(Object error)? onError;

  const TryCatch({
    super.key,
    required this.builder,
    this.onError,
  });

  @override
  Widget build(BuildContext context) {
    try {
      return builder();
    } catch (e) {
      Logger.error('TryCatch caught error', e);
      return onError?.call(e) ??
          Center(
            child: Text(
              'Hata: $e',
              style: TextStyle(color: AppColors.error),
            ),
          );
    }
  }
}

/// Async builder için hata yakalamalı wrapper
class SafeFutureBuilder<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  const SafeFutureBuilder({
    super.key,
    required this.future,
    required this.builder,
    this.loadingBuilder,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loadingBuilder?.call(context) ??
              const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          Logger.error('SafeFutureBuilder error', snapshot.error);
          return errorBuilder?.call(context, snapshot.error!) ??
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: AppColors.error, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Bir hata oluştu',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ],
                ),
              );
        }

        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        return builder(context, snapshot.data as T);
      },
    );
  }
}

/// Stream builder için hata yakalamalı wrapper
class SafeStreamBuilder<T> extends StatelessWidget {
  final Stream<T> stream;
  final Widget Function(BuildContext context, T data) builder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final T? initialData;

  const SafeStreamBuilder({
    super.key,
    required this.stream,
    required this.builder,
    this.loadingBuilder,
    this.errorBuilder,
    this.initialData,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: stream,
      initialData: initialData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return loadingBuilder?.call(context) ??
              const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          Logger.error('SafeStreamBuilder error', snapshot.error);
          return errorBuilder?.call(context, snapshot.error!) ??
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: AppColors.error, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Bir hata oluştu',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ],
                ),
              );
        }

        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        return builder(context, snapshot.data as T);
      },
    );
  }
}
