import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../storage/cache_manager.dart';
import '../tenant/tenant_service.dart';
import '../theme/theme_service.dart';
import '../utils/logger.dart';
import 'service_locator.dart';

/// Core konfigürasyonu
class CoreConfig {
  /// Supabase URL
  final String supabaseUrl;

  /// Supabase Anon Key
  final String supabaseAnonKey;

  /// API Base URL
  final String apiBaseUrl;

  /// Debug modu
  final bool debugMode;

  /// Logging aktif mi?
  final bool enableLogging;

  /// Cache otomatik temizleme
  final bool enableCacheCleanup;

  /// Otomatik session restore
  final bool autoRestoreSession;

  /// Otomatik tenant restore
  final bool autoRestoreTenant;

  const CoreConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.apiBaseUrl,
    this.debugMode = kDebugMode,
    this.enableLogging = kDebugMode,
    this.enableCacheCleanup = true,
    this.autoRestoreSession = true,
    this.autoRestoreTenant = true,
  });

  /// Geliştirme ortamı için
  factory CoreConfig.development({
    required String supabaseUrl,
    required String supabaseAnonKey,
    String apiBaseUrl = 'http://localhost:3000/api',
  }) {
    return CoreConfig(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      apiBaseUrl: apiBaseUrl,
      debugMode: true,
      enableLogging: true,
    );
  }

  /// Production ortamı için
  factory CoreConfig.production({
    required String supabaseUrl,
    required String supabaseAnonKey,
    required String apiBaseUrl,
  }) {
    return CoreConfig(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      apiBaseUrl: apiBaseUrl,
      debugMode: false,
      enableLogging: false,
    );
  }
}

/// Başlatma sonucu
class InitializationResult {
  /// Başarılı mı?
  final bool isSuccess;

  /// Hata mesajı
  final String? errorMessage;

  /// Session restore edildi mi?
  final bool sessionRestored;

  /// Tenant restore edildi mi?
  final bool tenantRestored;

  /// Başlatma süresi
  final Duration duration;

  const InitializationResult({
    required this.isSuccess,
    this.errorMessage,
    this.sessionRestored = false,
    this.tenantRestored = false,
    required this.duration,
  });

  factory InitializationResult.success({
    bool sessionRestored = false,
    bool tenantRestored = false,
    required Duration duration,
  }) {
    return InitializationResult(
      isSuccess: true,
      sessionRestored: sessionRestored,
      tenantRestored: tenantRestored,
      duration: duration,
    );
  }

  factory InitializationResult.failure({
    required String errorMessage,
    required Duration duration,
  }) {
    return InitializationResult(
      isSuccess: false,
      errorMessage: errorMessage,
      duration: duration,
    );
  }
}

/// Core Initializer
///
/// Protoolbag Core kütüphanesini başlatmak için ana sınıf.
///
/// Örnek kullanım:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   final result = await CoreInitializer.initialize(
///     config: CoreConfig(
///       supabaseUrl: 'https://xxx.supabase.co',
///       supabaseAnonKey: 'your-anon-key',
///       apiBaseUrl: 'https://api.example.com',
///     ),
///   );
///
///   if (!result.isSuccess) {
///     // Hata işle
///     print('Initialization failed: ${result.errorMessage}');
///   }
///
///   runApp(MyApp());
/// }
/// ```
class CoreInitializer {
  static bool _isInitialized = false;
  static CoreConfig? _config;

  /// Başlatıldı mı?
  static bool get isInitialized => _isInitialized;

  /// Mevcut konfigürasyon
  static CoreConfig? get config => _config;

  /// Core'u başlat
  static Future<InitializationResult> initialize({
    required CoreConfig config,
    VoidCallback? onInitialized,
    void Function(String step)? onProgress,
  }) async {
    if (_isInitialized) {
      Logger.warning('CoreInitializer already initialized');
      return InitializationResult.success(duration: Duration.zero);
    }

    final stopwatch = Stopwatch()..start();

    try {
      _config = config;

      // Logger ayarla
      if (config.debugMode) {
        Logger.setMinLevel(LogLevel.debug);
      } else {
        Logger.setMinLevel(LogLevel.info);
      }

      Logger.info('Initializing Protoolbag Core...');

      // Step 1: Flutter binding
      onProgress?.call('Flutter binding');
      WidgetsFlutterBinding.ensureInitialized();

      // Step 2: Service Locator kurulumu
      onProgress?.call('Service Locator');
      await setupServiceLocator(
        supabaseUrl: config.supabaseUrl,
        supabaseAnonKey: config.supabaseAnonKey,
        apiBaseUrl: config.apiBaseUrl,
        enableLogging: config.enableLogging,
      );

      // Step 3: Cache Manager başlat
      onProgress?.call('Cache Manager');
      final cacheManager = sl<CacheManager>();
      await cacheManager.initialize();

      // Step 4: Expired cache temizle
      if (config.enableCacheCleanup) {
        onProgress?.call('Cache cleanup');
        await cacheManager.cleanExpired();
      }

      // Step 5: Theme Service başlat
      onProgress?.call('Theme Service');
      final themeService = sl<ThemeService>();
      await themeService.initialize();

      // Step 6: Session restore
      bool sessionRestored = false;
      if (config.autoRestoreSession) {
        onProgress?.call('Session restore');
        final authService = sl<AuthService>();
        final result = await authService.restoreSession();
        sessionRestored = result.isSuccess;
        Logger.debug('Session restore: ${sessionRestored ? 'success' : 'failed'}');
      }

      // Step 7: Tenant restore
      bool tenantRestored = false;
      if (config.autoRestoreTenant && sessionRestored) {
        onProgress?.call('Tenant restore');
        final tenantService = sl<TenantService>();
        final tenant = await tenantService.restoreLastTenant();
        tenantRestored = tenant != null;
        Logger.debug('Tenant restore: ${tenantRestored ? 'success' : 'failed'}');
      }

      stopwatch.stop();
      _isInitialized = true;

      Logger.info(
        'Protoolbag Core initialized in ${stopwatch.elapsedMilliseconds}ms',
      );

      onInitialized?.call();

      return InitializationResult.success(
        sessionRestored: sessionRestored,
        tenantRestored: tenantRestored,
        duration: stopwatch.elapsed,
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      Logger.error('Core initialization failed', e, stackTrace);

      return InitializationResult.failure(
        errorMessage: e.toString(),
        duration: stopwatch.elapsed,
      );
    }
  }

  /// Core'u sıfırla (test için)
  static Future<void> reset() async {
    if (!_isInitialized) return;

    Logger.debug('Resetting CoreInitializer...');

    // Servisleri temizle
    try {
      sl<AuthService>().dispose();
      sl<TenantService>().dispose();
      await sl<CacheManager>().close();
    } catch (e) {
      Logger.warning('Error disposing services', e);
    }

    // Service Locator sıfırla
    await resetServiceLocator();

    _isInitialized = false;
    _config = null;

    Logger.debug('CoreInitializer reset complete');
  }

  /// Çıkış yap ve temizle
  static Future<void> signOut() async {
    if (!_isInitialized) return;

    try {
      // Auth çıkış
      final authService = sl<AuthService>();
      await authService.signOut();

      // Tenant temizle
      final tenantService = sl<TenantService>();
      await tenantService.clearTenant();

      // Cache temizle
      final cacheManager = sl<CacheManager>();
      await cacheManager.clear();

      Logger.info('User signed out and data cleared');
    } catch (e) {
      Logger.error('Error during sign out', e);
    }
  }
}

/// Core servislerine kolay erişim
extension CoreServices on CoreInitializer {
  static AuthService get auth => sl<AuthService>();
  static TenantService get tenant => sl<TenantService>();
  static CacheManager get cache => sl<CacheManager>();
  static ThemeService get theme => sl<ThemeService>();
}

/// Hızlı başlatma helper'ı
///
/// ```dart
/// await initializeCore(
///   supabaseUrl: 'https://xxx.supabase.co',
///   supabaseAnonKey: 'your-key',
///   apiBaseUrl: 'https://api.example.com',
/// );
/// ```
Future<InitializationResult> initializeCore({
  required String supabaseUrl,
  required String supabaseAnonKey,
  required String apiBaseUrl,
  bool debugMode = kDebugMode,
}) {
  return CoreInitializer.initialize(
    config: CoreConfig(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      apiBaseUrl: apiBaseUrl,
      debugMode: debugMode,
    ),
  );
}
