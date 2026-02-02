import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../alarm/alarm_service.dart';
import '../auth/auth_service.dart';
import '../connectivity/connectivity_service.dart';
import '../connectivity/offline_sync_service.dart';
import '../controller/controller_service.dart';
import '../iot_log/iot_log_service.dart';
import '../iot_realtime/iot_realtime_service.dart';
import '../localization/localization_service.dart';
import '../notification/notification_service.dart';
import '../organization/organization_service.dart';
import '../provider/provider_service.dart';
import '../push/push_notification_service.dart';
import '../search/search_service.dart';
import '../site/site_service.dart';
import '../storage/cache_manager.dart';
import '../tenant/tenant_service.dart';
import '../theme/theme_service.dart';
import '../unit/unit_service.dart';
import '../utils/logger.dart';
import '../variable/variable_service.dart';
import '../workflow/workflow_service.dart';
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

      // Step 6: Localization Service başlat
      onProgress?.call('Localization Service');
      final localizationService = sl<LocalizationService>();
      await localizationService.initialize();

      // Step 7: Connectivity Service başlat
      onProgress?.call('Connectivity Service');
      final connectivityService = sl<ConnectivityService>();
      await connectivityService.initialize();

      // Step 8: Offline Sync Service başlat
      onProgress?.call('Offline Sync Service');
      final offlineSyncService = sl<OfflineSyncService>();
      await offlineSyncService.initialize();

      // Step 9: Push Notification Service başlat
      onProgress?.call('Push Notification Service');
      final pushNotificationService = sl<PushNotificationService>();
      await pushNotificationService.initialize();

      // Step 10: Session restore
      bool sessionRestored = false;
      if (config.autoRestoreSession) {
        onProgress?.call('Session restore');
        final authService = sl<AuthService>();
        final result = await authService.restoreSession();
        sessionRestored = result.isSuccess;
        Logger.debug('Session restore: ${sessionRestored ? 'success' : 'failed'}');
      }

      // Step 11: Tenant restore
      bool tenantRestored = false;
      if (config.autoRestoreTenant && sessionRestored) {
        onProgress?.call('Tenant restore');
        final tenantService = sl<TenantService>();
        final tenant = await tenantService.restoreLastTenant();
        tenantRestored = tenant != null;
        Logger.debug('Tenant restore: ${tenantRestored ? 'success' : 'failed'}');

        // Tenant context'i IoT servislerine aktar
        if (tenantRestored && tenant != null) {
          _propagateTenantToServices(tenant.id);
        }
      }

      // Step 12: Organization restore
      if (tenantRestored && sessionRestored) {
        onProgress?.call('Organization restore');
        final orgService = sl<OrganizationService>();
        final org = await orgService.restoreLastOrganization();
        Logger.debug('Organization restore: ${org != null ? 'success (${org.name})' : 'failed'}');
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

  /// Tenant context'ini tüm IoT servislerine aktar
  static void _propagateTenantToServices(String tenantId) {
    try {
      sl<ControllerService>().setTenant(tenantId);
      sl<DataProviderService>().setTenant(tenantId);
      sl<VariableService>().setTenant(tenantId);
      sl<IoTRealtimeService>().setTenant(tenantId);
      sl<WorkflowService>().setTenant(tenantId);
      sl<AlarmService>().setTenant(tenantId);
      sl<IoTLogService>().setTenant(tenantId);
      Logger.debug('Tenant propagated to IoT services: $tenantId');
    } catch (e) {
      Logger.warning('Failed to propagate tenant to IoT services: $e');
    }
  }

  /// Organization context'ini tüm IoT servislerine aktar
  ///
  /// Tenant → Organization hiyerarşisinde organization seviyesinde filtreleme
  /// için kullanılır. Opsiyonel izolasyon katmanıdır.
  static void propagateOrganizationToServices(String organizationId) {
    try {
      sl<AlarmService>().setOrganization(organizationId);
      sl<IoTLogService>().setOrganization(organizationId);
      Logger.debug('Organization propagated to IoT services: $organizationId');
    } catch (e) {
      Logger.warning('Failed to propagate organization to IoT services: $e');
    }
  }

  /// Organization context'ini tüm IoT servislerinden temizle
  static void clearOrganizationFromServices() {
    try {
      sl<AlarmService>().clearOrganization();
      sl<IoTLogService>().clearOrganization();
      Logger.debug('Organization cleared from IoT services');
    } catch (e) {
      Logger.warning('Failed to clear organization from IoT services: $e');
    }
  }

  /// Site context'ini tüm IoT servislerine aktar
  ///
  /// Tenant → Organization → Site hiyerarşisinde site seviyesinde filtreleme
  /// için kullanılır. Opsiyonel izolasyon katmanıdır.
  static void propagateSiteToServices(String siteId) {
    try {
      sl<AlarmService>().setSite(siteId);
      sl<IoTLogService>().setSite(siteId);
      Logger.debug('Site propagated to IoT services: $siteId');
    } catch (e) {
      Logger.warning('Failed to propagate site to IoT services: $e');
    }
  }

  /// Site context'ini tüm IoT servislerinden temizle
  static void clearSiteFromServices() {
    try {
      sl<AlarmService>().clearSite();
      sl<IoTLogService>().clearSite();
      Logger.debug('Site cleared from IoT services');
    } catch (e) {
      Logger.warning('Failed to clear site from IoT services: $e');
    }
  }

  /// Tüm izolasyon context'lerini (organization, site) temizle
  ///
  /// Tenant context'i korur, sadece alt seviye izolasyonları temizler.
  static void clearSubTenantContexts() {
    try {
      sl<AlarmService>().clearOrganization();
      sl<AlarmService>().clearSite();
      sl<IoTLogService>().clearOrganization();
      sl<IoTLogService>().clearSite();
      Logger.debug('Sub-tenant contexts cleared from IoT services');
    } catch (e) {
      Logger.warning('Failed to clear sub-tenant contexts: $e');
    }
  }

  /// Core'u sıfırla (test için)
  static Future<void> reset() async {
    if (!_isInitialized) return;

    Logger.debug('Resetting CoreInitializer...');

    // Tüm servisleri temizle
    try {
      // Core services with dispose
      sl<AuthService>().dispose();
      sl<TenantService>().dispose();
      sl<ThemeService>().dispose();
      sl<LocalizationService>().dispose();
      sl<ConnectivityService>().dispose();
      sl<OfflineSyncService>().dispose();
      sl<PushNotificationService>().dispose();

      // Entity services with dispose
      sl<OrganizationService>().dispose();
      sl<SiteService>().dispose();
      sl<UnitService>().dispose();
      sl<NotificationService>().dispose();
      sl<SearchService>().dispose();

      // Cache manager (async close)
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

      // Organization temizle
      final orgService = sl<OrganizationService>();
      await orgService.clearOrganization();

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
  static LocalizationService get localization => sl<LocalizationService>();
  static ConnectivityService get connectivity => sl<ConnectivityService>();
  static OfflineSyncService get offlineSync => sl<OfflineSyncService>();
  static PushNotificationService get pushNotification => sl<PushNotificationService>();
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
