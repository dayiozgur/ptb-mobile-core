import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../activity/activity_service.dart';
import '../api/api_client.dart';
import '../connectivity/connectivity_service.dart';
import '../connectivity/offline_sync_service.dart';
import '../notification/notification_service.dart';
import '../reporting/reporting_service.dart';
import '../search/search_service.dart';
import '../theme/theme_service.dart';
import '../api/interceptors/auth_interceptor.dart';
import '../api/interceptors/logger_interceptor.dart';
import '../api/interceptors/tenant_interceptor.dart';
import '../auth/auth_service.dart';
import '../auth/biometric_auth.dart';
import '../organization/organization_service.dart';
import '../site/site_service.dart';
import '../storage/cache_manager.dart';
import '../storage/secure_storage.dart';
import '../tenant/tenant_service.dart';
import '../unit/unit_service.dart';
import '../utils/logger.dart';

/// Service Locator (Dependency Injection)
///
/// get_it kullanarak dependency injection sağlar.
///
/// Örnek kullanım:
/// ```dart
/// // Servis al
/// final authService = sl<AuthService>();
///
/// // Manuel kayıt (test için)
/// sl.registerSingleton<MyService>(MockMyService());
/// ```
final GetIt sl = GetIt.instance;

/// Service Locator kurulumu
///
/// Uygulama başlangıcında çağrılmalıdır.
Future<void> setupServiceLocator({
  required String supabaseUrl,
  required String supabaseAnonKey,
  required String apiBaseUrl,
  bool enableLogging = true,
}) async {
  Logger.debug('Setting up Service Locator...');

  // ============================================
  // EXTERNAL SERVICES
  // ============================================

  // Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  sl.registerSingleton<SupabaseClient>(Supabase.instance.client);

  // ============================================
  // CORE SERVICES
  // ============================================

  // Secure Storage
  sl.registerLazySingleton<SecureStorage>(() => SecureStorage());

  // Cache Manager
  sl.registerLazySingleton<CacheManager>(() => CacheManager());

  // Biometric Auth
  sl.registerLazySingleton<BiometricAuth>(() => BiometricAuth());

  // ============================================
  // INTERCEPTORS
  // ============================================

  sl.registerLazySingleton<AuthInterceptor>(
    () => AuthInterceptor(storage: sl<SecureStorage>()),
  );

  sl.registerLazySingleton<TenantInterceptor>(
    () => TenantInterceptor(storage: sl<SecureStorage>()),
  );

  if (enableLogging) {
    sl.registerLazySingleton<LoggerInterceptor>(() => LoggerInterceptor());
  }

  // ============================================
  // API CLIENT
  // ============================================

  sl.registerLazySingleton<ApiClient>(() {
    final interceptors = [
      sl<AuthInterceptor>(),
      sl<TenantInterceptor>(),
      if (enableLogging) sl<LoggerInterceptor>(),
    ];

    return ApiClient(
      baseUrl: apiBaseUrl,
      supabase: sl<SupabaseClient>(),
      interceptors: interceptors,
    );
  });

  // ============================================
  // AUTH SERVICE
  // ============================================

  sl.registerLazySingleton<AuthService>(
    () => AuthService(
      supabase: sl<SupabaseClient>(),
      secureStorage: sl<SecureStorage>(),
      biometricAuth: sl<BiometricAuth>(),
    ),
  );

  // ============================================
  // TENANT SERVICE
  // ============================================

  sl.registerLazySingleton<TenantService>(
    () => TenantService(
      supabase: sl<SupabaseClient>(),
      secureStorage: sl<SecureStorage>(),
      cacheManager: sl<CacheManager>(),
      apiClient: sl<ApiClient>(),
    ),
  );

  // ============================================
  // ORGANIZATION SERVICE
  // ============================================

  sl.registerLazySingleton<OrganizationService>(
    () => OrganizationService(
      supabase: sl<SupabaseClient>(),
      cacheManager: sl<CacheManager>(),
    ),
  );

  // ============================================
  // SITE SERVICE
  // ============================================

  sl.registerLazySingleton<SiteService>(
    () => SiteService(
      supabase: sl<SupabaseClient>(),
      cacheManager: sl<CacheManager>(),
    ),
  );

  // ============================================
  // UNIT SERVICE
  // ============================================

  sl.registerLazySingleton<UnitService>(
    () => UnitService(
      supabase: sl<SupabaseClient>(),
      cacheManager: sl<CacheManager>(),
    ),
  );

  // ============================================
  // ACTIVITY SERVICE
  // ============================================

  sl.registerLazySingleton<ActivityService>(
    () => ActivityService(
      supabase: sl<SupabaseClient>(),
      cacheManager: sl<CacheManager>(),
    ),
  );

  // ============================================
  // NOTIFICATION SERVICE
  // ============================================

  sl.registerLazySingleton<NotificationService>(
    () => NotificationService(
      supabase: sl<SupabaseClient>(),
      cacheManager: sl<CacheManager>(),
    ),
  );

  // ============================================
  // CONNECTIVITY SERVICE
  // ============================================

  sl.registerLazySingleton<ConnectivityService>(
    () => ConnectivityService(),
  );

  // ============================================
  // OFFLINE SYNC SERVICE
  // ============================================

  sl.registerLazySingleton<OfflineSyncService>(
    () => OfflineSyncService(
      connectivityService: sl<ConnectivityService>(),
    ),
  );

  // ============================================
  // REPORTING SERVICE
  // ============================================

  sl.registerLazySingleton<ReportingService>(
    () => ReportingService(
      supabase: sl<SupabaseClient>(),
      cacheManager: sl<CacheManager>(),
    ),
  );

  // ============================================
  // SEARCH SERVICE
  // ============================================

  sl.registerLazySingleton<SearchService>(
    () => SearchService(
      supabase: sl<SupabaseClient>(),
      cacheManager: sl<CacheManager>(),
    ),
  );

  // ============================================
  // THEME SERVICE
  // ============================================

  sl.registerLazySingleton<ThemeService>(
    () => ThemeService(
      storage: sl<SecureStorage>(),
    ),
  );

  Logger.debug('Service Locator setup complete');
}

/// Service Locator'ı sıfırla (test için)
Future<void> resetServiceLocator() async {
  await sl.reset();
}

/// Lazy singleton olarak kaydet
void registerLazySingleton<T extends Object>(T Function() factory) {
  if (!sl.isRegistered<T>()) {
    sl.registerLazySingleton<T>(factory);
  }
}

/// Factory olarak kaydet
void registerFactory<T extends Object>(T Function() factory) {
  if (!sl.isRegistered<T>()) {
    sl.registerFactory<T>(factory);
  }
}

/// Singleton olarak kaydet
void registerSingleton<T extends Object>(T instance) {
  if (!sl.isRegistered<T>()) {
    sl.registerSingleton<T>(instance);
  }
}

/// Test için mock kaydet
void registerMock<T extends Object>(T instance) {
  if (sl.isRegistered<T>()) {
    sl.unregister<T>();
  }
  sl.registerSingleton<T>(instance);
}

/// Convenience getters
AuthService get authService => sl<AuthService>();
TenantService get tenantService => sl<TenantService>();
OrganizationService get organizationService => sl<OrganizationService>();
SiteService get siteService => sl<SiteService>();
UnitService get unitService => sl<UnitService>();
ActivityService get activityService => sl<ActivityService>();
NotificationService get notificationService => sl<NotificationService>();
ConnectivityService get connectivityService => sl<ConnectivityService>();
OfflineSyncService get offlineSyncService => sl<OfflineSyncService>();
ReportingService get reportingService => sl<ReportingService>();
SearchService get searchService => sl<SearchService>();
ThemeService get themeService => sl<ThemeService>();
ApiClient get apiClient => sl<ApiClient>();
SecureStorage get secureStorage => sl<SecureStorage>();
CacheManager get cacheManager => sl<CacheManager>();
SupabaseClient get supabase => sl<SupabaseClient>();
