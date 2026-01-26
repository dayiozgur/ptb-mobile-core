import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api/api_client.dart';
import '../api/interceptors/auth_interceptor.dart';
import '../api/interceptors/logger_interceptor.dart';
import '../api/interceptors/tenant_interceptor.dart';
import '../auth/auth_service.dart';
import '../auth/biometric_auth.dart';
import '../storage/cache_manager.dart';
import '../storage/secure_storage.dart';
import '../tenant/tenant_service.dart';
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
    () => AuthInterceptor(secureStorage: sl<SecureStorage>()),
  );

  sl.registerLazySingleton<TenantInterceptor>(
    () => TenantInterceptor(),
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
ApiClient get apiClient => sl<ApiClient>();
SecureStorage get secureStorage => sl<SecureStorage>();
CacheManager get cacheManager => sl<CacheManager>();
SupabaseClient get supabase => sl<SupabaseClient>();
