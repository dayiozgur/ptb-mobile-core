# 🏛️ Mimari Dokümantasyon

## İçindekiler

1. [Genel Bakış](#genel-bakış)
2. [Katmanlı Mimari](#katmanlı-mimari)
3. [Modül Yapısı](#modül-yapısı)
4. [Design Patterns](#design-patterns)
5. [State Management](#state-management)
6. [Dependency Injection](#dependency-injection)
7. [Data Flow](#data-flow)
8. [Multi-Tenancy](#multi-tenancy)
9. [Security](#security)

## 🎯 Genel Bakış

Protoolbag Mobile Core, **Clean Architecture** prensiplerine dayalı, **feature-first** organizasyona sahip, modüler bir yapıdadır.

### Temel Prensipler
```
1. Separation of Concerns    - Her katman kendi sorumluluğu
2. Dependency Inversion       - Üst katmanlar alt katmanlara bağımlı değil
3. Single Responsibility      - Her sınıf tek bir işten sorumlu
4. DRY (Don't Repeat Yourself) - Kod tekrarı yok
5. KISS (Keep It Simple)      - Basitlik öncelik
```

## 🏗️ Katmanlı Mimari

### Katman Diyagramı
```
┌─────────────────────────────────────────────────┐
│           PRESENTATION LAYER                     │
│  ┌──────────────────────────────────────────┐  │
│  │ Widgets, Screens, State Management       │  │
│  │ (UI Components, Providers, Controllers)  │  │
│  └──────────────────────────────────────────┘  │
└────────────────┬────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────┐
│            DOMAIN LAYER                          │
│  ┌──────────────────────────────────────────┐  │
│  │ Business Logic, Entities, Use Cases      │  │
│  │ (Pure Dart - No Flutter Dependencies)    │  │
│  └──────────────────────────────────────────┘  │
└────────────────┬────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────┐
│             DATA LAYER                           │
│  ┌──────────────────────────────────────────┐  │
│  │ Repositories, Data Sources, Models       │  │
│  │ (API, Database, Cache)                   │  │
│  └──────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

### 1. Presentation Layer

**Sorumluluk:** UI rendering, user interaction, state management
```dart
lib/presentation/
├── widgets/
│   ├── buttons/
│   │   ├── app_button.dart
│   │   └── icon_button.dart
│   ├── inputs/
│   │   ├── app_text_field.dart
│   │   └── app_dropdown.dart
│   └── cards/
│       └── app_card.dart
├── screens/
│   └── auth/
│       └── login_screen.dart
└── providers/
    └── auth_provider.dart
```

**Örnek:**
```dart
// presentation/screens/auth/login_screen.dart

class LoginScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    
    return AppScaffold(
      child: authState.when(
        data: (user) => _buildLoggedIn(user),
        loading: () => AppLoadingIndicator(),
        error: (error, stack) => AppErrorView(error: error),
      ),
    );
  }
}
```

### 2. Domain Layer

**Sorumluluk:** Business logic, entities, use cases (Pure Dart)
```dart
lib/domain/
├── entities/
│   ├── user.dart
│   └── tenant.dart
├── repositories/
│   └── auth_repository.dart  // Interface
└── usecases/
    ├── login_usecase.dart
    └── logout_usecase.dart
```

**Örnek:**
```dart
// domain/entities/user.dart
class User {
  final String id;
  final String email;
  final String? displayName;
  final List<String> tenantIds;
  
  const User({
    required this.id,
    required this.email,
    this.displayName,
    required this.tenantIds,
  });
}

// domain/usecases/login_usecase.dart
class LoginUseCase {
  final AuthRepository repository;
  
  LoginUseCase(this.repository);
  
  Future<Either<Failure, User>> execute({
    required String email,
    required String password,
  }) async {
    return await repository.login(email: email, password: password);
  }
}
```

### 3. Data Layer

**Sorumluluk:** Data access, API calls, caching
```dart
lib/data/
├── models/
│   └── user_model.dart          // User + JSON serialization
├── repositories/
│   └── auth_repository_impl.dart // AuthRepository implementation
└── datasources/
    ├── remote/
    │   └── auth_remote_datasource.dart
    └── local/
        └── auth_local_datasource.dart
```

**Örnek:**
```dart
// data/repositories/auth_repository_impl.dart
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;
  
  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });
  
  @override
  Future<Either<Failure, User>> login({
    required String email,
    required String password,
  }) async {
    try {
      final userModel = await remoteDataSource.login(email, password);
      await localDataSource.cacheUser(userModel);
      return Right(userModel.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
```

## 📦 Modül Yapısı

### Core Module Organization
```
lib/
├── core/
│   ├── api/                     # Network layer
│   │   ├── api_client.dart
│   │   ├── api_response.dart
│   │   └── interceptors/
│   │       ├── auth_interceptor.dart
│   │       ├── tenant_interceptor.dart
│   │       └── logger_interceptor.dart
│   │
│   ├── auth/                    # Authentication
│   │   ├── auth_service.dart
│   │   ├── token_manager.dart
│   │   └── biometric_auth.dart
│   │
│   ├── storage/                 # Local storage
│   │   ├── secure_storage.dart
│   │   └── cache_manager.dart
│   │
│   ├── theme/                   # Design system
│   │   ├── app_theme.dart
│   │   ├── app_colors.dart
│   │   ├── app_typography.dart
│   │   ├── app_spacing.dart
│   │   └── app_shadows.dart
│   │
│   ├── navigation/              # Routing
│   │   ├── app_router.dart
│   │   └── route_guards.dart
│   │
│   ├── utils/                   # Utilities
│   │   ├── formatters.dart
│   │   ├── validators.dart
│   │   └── logger.dart
│   │
│   └── errors/                  # Error handling
│       ├── exceptions.dart
│       └── failures.dart
│
├── data/                        # Data layer
├── domain/                      # Domain layer
└── presentation/                # Presentation layer
```

## 🎨 Design Patterns

### 1. Repository Pattern
```dart
// Domain layer - Interface
abstract class AuthRepository {
  Future<Either<Failure, User>> login(String email, String password);
  Future<void> logout();
}

// Data layer - Implementation
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;
  
  @override
  Future<Either<Failure, User>> login(String email, String password) async {
    // Implementation
  }
}
```

### 2. Provider Pattern (State Management)
```dart
// Riverpod provider
final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final AuthRepository repository;
  
  AuthNotifier(this.repository) : super(AsyncValue.loading()) {
    _checkAuth();
  }
  
  Future<void> login(String email, String password) async {
    state = AsyncValue.loading();
    
    final result = await repository.login(email, password);
    
    result.fold(
      (failure) => state = AsyncValue.error(failure, StackTrace.current),
      (user) => state = AsyncValue.data(user),
    );
  }
}
```

### 3. Factory Pattern
```dart
class WidgetFactory {
  static Widget createButton(AppButtonVariant variant) {
    switch (variant) {
      case AppButtonVariant.primary:
        return _PrimaryButton();
      case AppButtonVariant.secondary:
        return _SecondaryButton();
      case AppButtonVariant.tertiary:
        return _TertiaryButton();
    }
  }
}
```

### 4. Singleton Pattern
```dart
class Logger {
  static final Logger _instance = Logger._internal();
  
  factory Logger() => _instance;
  
  Logger._internal();
  
  void log(String message) {
    debugPrint('[${DateTime.now()}] $message');
  }
}
```

## 🔄 State Management

### Riverpod Architecture
```dart
// Provider hierarchy
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseProvider));
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUserProvider = FutureProvider<User?>((ref) async {
  final authState = await ref.watch(authStateProvider.future);
  if (authState.isAuthenticated) {
    return ref.watch(authServiceProvider).getCurrentUser();
  }
  return null;
});
```

### State Types

1. **Local State** - Widget içinde
2. **Global State** - App genelinde (Provider)
3. **Cached State** - Persist edilmiş
4. **Stream State** - Realtime güncellemeler

## 💉 Dependency Injection

### GetIt Setup
```dart
// core/di/injection.dart

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  // External
  getIt.registerLazySingleton<SupabaseClient>(
    () => Supabase.instance.client,
  );
  
  // Core Services
  getIt.registerLazySingleton<ApiClient>(
    () => ApiClient(supabase: getIt()),
  );
  
  getIt.registerLazySingleton<AuthService>(
    () => AuthService(supabase: getIt()),
  );
  
  getIt.registerLazySingleton<StorageService>(
    () => StorageService(),
  );
  
  // Repositories
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: getIt(),
      localDataSource: getIt(),
    ),
  );
  
  // Use Cases
  getIt.registerFactory<LoginUseCase>(
    () => LoginUseCase(getIt()),
  );
}
```

## 🌊 Data Flow

### Request Flow
```
User Action (Tap Button)
    ↓
UI Widget triggers event
    ↓
Provider/Notifier called
    ↓
Use Case executed
    ↓
Repository method
    ↓
Data Source (API/DB)
    ↓
Response flows back up
    ↓
UI updates
```

### Example Flow: Login
```dart
// 1. UI Event
AppButton(
  onPressed: () => ref.read(authProvider.notifier).login(email, password),
)

// 2. Provider
class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  Future<void> login(String email, String password) async {
    final useCase = getIt<LoginUseCase>();
    final result = await useCase.execute(email: email, password: password);
    // Update state
  }
}

// 3. Use Case
class LoginUseCase {
  Future<Either<Failure, User>> execute(...) async {
    return await repository.login(...);
  }
}

// 4. Repository
class AuthRepositoryImpl implements AuthRepository {
  Future<Either<Failure, User>> login(...) async {
    return await remoteDataSource.login(...);
  }
}

// 5. Data Source
class AuthRemoteDataSource {
  Future<UserModel> login(...) async {
    final response = await supabase.auth.signInWithPassword(...);
    return UserModel.fromJson(response.user);
  }
}
```

## 🏢 Multi-Tenancy

### Tenant Context
```dart
class TenantContext {
  static String? _currentTenantId;
  
  static String? get currentTenantId => _currentTenantId;
  
  static void setTenant(String tenantId) {
    _currentTenantId = tenantId;
    // Trigger app-wide rebuild
  }
  
  static void clearTenant() {
    _currentTenantId = null;
  }
}
```

### Tenant Interceptor
```dart
class TenantInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final tenantId = TenantContext.currentTenantId;
    
    if (tenantId != null) {
      options.headers['X-Tenant-ID'] = tenantId;
      options.queryParameters['tenant_id'] = tenantId;
    }
    
    handler.next(options);
  }
}
```

### RLS (Row Level Security) Support
```sql
-- Supabase RLS Policy
CREATE POLICY tenant_isolation ON devices
  FOR ALL
  USING (tenant_id = current_setting('app.tenant_id')::uuid);
```
```dart
// Set tenant before query
await supabase.rpc('set_tenant', params: {'tenant_id': tenantId});

// Query with RLS
final devices = await supabase
  .from('devices')
  .select('*');  // RLS otomatik filter eder
```

## 🔒 Security

### 1. Token Storage
```dart
class SecureStorage {
  final FlutterSecureStorage _storage;
  
  Future<void> saveToken(String token) async {
    await _storage.write(
      key: 'access_token',
      value: token,
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
  }
}
```

### 2. Certificate Pinning
```dart
class ApiClient {
  Dio _createDio() {
    return Dio()
      ..httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (cert, host, port) {
            return cert.sha256.toString() == EXPECTED_CERT_SHA256;
          };
          return client;
        },
      );
  }
}
```

### 3. Encryption
```dart
class DataEncryption {
  static String encrypt(String data) {
    final key = Key.fromUtf8(ENCRYPTION_KEY);
    final iv = IV.fromLength(16);
    final encrypter = Encrypter(AES(key));
    return encrypter.encrypt(data, iv: iv).base64;
  }
}
```

## 📊 Performance

### 1. Lazy Loading
```dart
final userProvider = FutureProvider.family<User, String>((ref, userId) async {
  // Cache check
  final cached = await ref.watch(cacheProvider).getUser(userId);
  if (cached != null) return cached;
  
  // Fetch if not cached
  return await ref.watch(apiProvider).getUser(userId);
});
```

### 2. Pagination
```dart
class PaginatedList<T> {
  final List<T> items;
  final int page;
  final bool hasMore;
  
  Future<PaginatedList<T>> loadMore() async {
    final newItems = await _fetchPage(page + 1);
    return PaginatedList(
      items: [...items, ...newItems],
      page: page + 1,
      hasMore: newItems.isNotEmpty,
    );
  }
}
```

### 3. Image Caching
```dart
CachedNetworkImage(
  imageUrl: url,
  cacheKey: 'device_${device.id}',
  memCacheWidth: 400,  // Resize for performance
  placeholder: (context, url) => ShimmerPlaceholder(),
  errorWidget: (context, url, error) => Icon(Icons.error),
)
```

---

**Sonraki:** [Design System →](DESIGN_SYSTEM.md)