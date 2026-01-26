# 📖 API Reference

## İçindekiler

1. [Core Module](#core-module)
2. [Authentication](#authentication)
3. [API Client](#api-client)
4. [Storage](#storage)
5. [Theme](#theme)
6. [Utilities](#utilities)
7. [Widgets](#widgets)

## 🔧 Core Module

### CoreInitializer

Initialize all core services.
```dart
class CoreInitializer {
  static Future<void> initialize({
    required String supabaseUrl,
    required String supabaseAnonKey,
    String? environment,
  })
}
```

**Parameters:**
- `supabaseUrl`: Supabase project URL
- `supabaseAnonKey`: Supabase anonymous key
- `environment`: Environment name (dev/staging/prod)

**Example:**
```dart
await CoreInitializer.initialize(
  supabaseUrl: 'https://xxx.supabase.co',
  supabaseAnonKey: 'eyJxxx...',
  environment: 'production',
);
```

---

## 🔐 Authentication

### AuthService

Main authentication service.
```dart
class AuthService {
  // Sign in with email/password
  Future<AuthResult> signIn({
    required String email,
    required String password,
    String? tenantId,
  })
  
  // Sign up new user
  Future<AuthResult> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  })
  
  // Sign out
  Future<void> signOut()
  
  // Reset password
  Future<void> resetPassword(String email)
  
  // Get current user
  User? get currentUser
  
  // Auth state stream
  Stream<AuthState> get authStateChanges
  
  // Social login
  Future<AuthResult> signInWithGoogle()
  Future<AuthResult> signInWithApple()
  
  // Biometric
  Future<bool> enableBiometric()
  Future<AuthResult> signInWithBiometric()
}
```

**Example:**
```dart
final authService = getIt<AuthService>();

// Email login
final result = await authService.signIn(
  email: 'user@example.com',
  password: 'SecurePass123!',
);

result.when(
  success: (user) => print('Logged in: ${user.email}'),
  failure: (error) => print('Error: $error'),
  requiresTenantSelection: (tenants) => _showTenantPicker(tenants),
);

// Listen to auth changes
authService.authStateChanges.listen((state) {
  if (state.isAuthenticated) {
    // Navigate to home
  } else {
    // Navigate to login
  }
});
```

### AuthResult

Authentication result wrapper.
```dart
class AuthResult {
  static AuthResult success(User user)
  static AuthResult failure(String error)
  static AuthResult requiresTenantSelection(List<Tenant> tenants)
  
  T when<T>({
    required T Function(User) success,
    required T Function(String) failure,
    required T Function(List<Tenant>) requiresTenantSelection,
  })
}
```

### BiometricAuth

Biometric authentication helper.
```dart
class BiometricAuth {
  // Check if biometric is available
  Future<bool> isAvailable()
  
  // Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics()
  
  // Authenticate
  Future<bool> authenticate({
    required String reason,
    bool stickyAuth = true,
  })
}
```

---

## 🌐 API Client

### ApiClient

Generic HTTP client with Supabase integration.
```dart
class ApiClient {
  // GET request
  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    T Function(Map<String, dynamic>)? fromJson,
  })
  
  // POST request
  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    Map<String, dynamic>? data,
    T Function(Map<String, dynamic>)? fromJson,
  })
  
  // PUT request
  Future<ApiResponse<T>> put<T>(
    String endpoint, {
    Map<String, dynamic>? data,
    T Function(Map<String, dynamic>)? fromJson,
  })
  
  // DELETE request
  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    T Function(Map<String, dynamic>)? fromJson,
  })
  
  // Supabase query
  Future<List<T>> querySupabase<T>({
    required String table,
    required T Function(Map<String, dynamic>) fromJson,
    String? select,
    PostgrestFilterBuilder Function(PostgrestFilterBuilder)? filter,
  })
}
```

**Example:**
```dart
final apiClient = getIt<ApiClient>();

// REST API call
final response = await apiClient.get<Device>(
  '/api/devices',
  queryParams: {'status': 'online'},
  fromJson: (json) => Device.fromJson(json),
);

response.when(
  success: (device) => print('Device: $device'),
  failure: (error) => print('Error: $error'),
);

// Supabase query
final devices = await apiClient.querySupabase<Device>(
  table: 'devices',
  fromJson: (json) => Device.fromJson(json),
  filter: (query) => query
    .eq('tenant_id', currentTenantId)
    .eq('status', 'online')
    .order('created_at', ascending: false),
);
```

### ApiResponse

API response wrapper.
```dart
class ApiResponse<T> {
  static ApiResponse<T> success<T>(T data)
  static ApiResponse<T> failure<T>(ApiError error)
  
  T when<T>({
    required T Function(T data) success,
    required T Function(ApiError error) failure,
  })
}
```

### Interceptors

Request/response interceptors.
```dart
// Auth Interceptor
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler)
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler)
}

// Tenant Interceptor
class TenantInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler)
}

// Logger Interceptor
class LoggerInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler)
  
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler)
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler)
}
```

---

## 💾 Storage

### SecureStorage

Secure key-value storage.
```dart
class SecureStorage {
  // Write
  Future<void> write({
    required String key,
    required String value,
  })
  
  // Read
  Future<String?> read(String key)
  
  // Delete
  Future<void> delete(String key)
  
  // Delete all
  Future<void> deleteAll()
  
  // Check if contains
  Future<bool> containsKey(String key)
}
```

**Example:**
```dart
final storage = getIt<SecureStorage>();

// Save token
await storage.write(
  key: 'access_token',
  value: token,
);

// Read token
final token = await storage.read('access_token');

// Delete token
await storage.delete('access_token');
```

### CacheManager

Cache management with TTL support.
```dart
class CacheManager {
  // Get with cache
  Future<T?> getCached<T>({
    required String key,
    required Future<T> Function() fetchFn,
    required T Function(Map<String, dynamic>) fromJson,
    Duration? ttl,
  })
  
  // Set cache
  Future<void> setCache(
    String key,
    dynamic data, {
    Duration? ttl,
  })
  
  // Invalidate
  Future<void> invalidate(String key)
  
  // Clear all
  Future<void> clearAll()
}
```

**Example:**
```dart
final cache = getIt<CacheManager>();

// Get with automatic caching
final user = await cache.getCached<User>(
  key: 'user_${userId}',
  fetchFn: () => apiClient.getUser(userId),
  fromJson: (json) => User.fromJson(json),
  ttl: Duration(hours: 1),
);

// Manual cache set
await cache.setCache(
  'config',
  configData,
  ttl: Duration(days: 1),
);

// Invalidate
await cache.invalidate('user_${userId}');
```

---

## 🎨 Theme

### AppTheme

Application theme configuration.
```dart
class AppTheme {
  static ThemeData light
  static ThemeData dark
  
  static ThemeData customLight({
    Color? primaryColor,
    Color? accentColor,
  })
  
  static ThemeData customDark({
    Color? primaryColor,
    Color? accentColor,
  })
}
```

### AppColors

Color constants.
```dart
class AppColors {
  // Brand
  static const Color primary
  static const Color secondary
  static const Color accent
  
  // Semantic
  static const Color success
  static const Color warning
  static const Color error
  static const Color info
  
  // Neutral (Light)
  static const Color backgroundLight
  static const Color surfaceLight
  static const Color textPrimaryLight
  static const Color textSecondaryLight
  
  // Neutral (Dark)
  static const Color backgroundDark
  static const Color surfaceDark
  static const Color textPrimaryDark
  static const Color textSecondaryDark
}
```

### AppTypography

Typography styles.
```dart
class AppTypography {
  static const TextStyle largeTitle
  static const TextStyle title1
  static const TextStyle title2
  static const TextStyle title3
  static const TextStyle headline
  static const TextStyle body
  static const TextStyle callout
  static const TextStyle subhead
  static const TextStyle footnote
  static const TextStyle caption1
  static const TextStyle caption2
}
```

### AppSpacing

Spacing constants.
```dart
class AppSpacing {
  static const double xs = 4.0
  static const double sm = 8.0
  static const double md = 16.0
  static const double lg = 24.0
  static const double xl = 32.0
  static const double xxl = 48.0
}
```

---

## 🛠️ Utilities

### Validators

Form validators.
```dart
class Validators {
  // Email validation
  static String? email(String? value)
  
  // Password validation
  static String? password(String? value, {
    int minLength = 8,
    bool requireNumber = true,
    bool requireSpecialChar = true,
  })
  
  // Required field
  static String? required(String? value, {
    String? fieldName,
  })
  
  // Min length
  static String? minLength(String? value, int length)
  
  // Max length
  static String? maxLength(String? value, int length)
  
  // Phone number
  static String? phone(String? value)
  
  // URL
  static String? url(String? value)
}
```

**Example:**
```dart
AppTextField(
  label: 'Email',
  validator: Validators.email,
)

AppTextField(
  label: 'Password',
  validator: (value) => Validators.password(
    value,
    minLength: 12,
    requireSpecialChar: true,
  ),
)
```

### Formatters

Data formatters.
```dart
class Formatters {
  // Currency
  static String currency(
    double amount, {
    String symbol = '\$',
    int decimals = 2,
  })
  
  // Number
  static String number(
    num value, {
    int decimals = 0,
    bool useGrouping = true,
  })
  
  // Percentage
  static String percentage(
    double value, {
    int decimals = 1,
  })
  
  // Date
  static String date(
    DateTime date, {
    String format = 'dd/MM/yyyy',
  })
  
  // Relative time
  static String relativeTime(DateTime date)
  
  // File size
  static String fileSize(int bytes)
}
```

**Example:**
```dart
Formatters.currency(1234.56)           // "$1,234.56"
Formatters.number(1000000)             // "1,000,000"
Formatters.percentage(0.856)           // "85.6%"
Formatters.date(DateTime.now())        // "26/01/2024"
Formatters.relativeTime(yesterday)     // "1 day ago"
Formatters.fileSize(1536000)           // "1.5 MB"
```

### Logger

Logging utility.
```dart
class Logger {
  static void debug(String message)
  static void info(String message)
  static void warning(String message)
  static void error(String message, [Object? error, StackTrace? stackTrace])
}
```

---

## 🧩 Widgets

### AppButton

Primary button component.
```dart
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.isFullWidth = false,
    this.icon,
  })
}

enum AppButtonVariant { primary, secondary, tertiary, destructive }
enum AppButtonSize { small, medium, large }
```

### AppTextField

Text input field.
```dart
class AppTextField extends StatelessWidget {
  const AppTextField({
    this.label,
    this.placeholder,
    this.controller,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
  })
}
```

### AppCard

Card container.
```dart
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding,
    this.backgroundColor,
    this.showShadow = true,
    this.showBorder = false,
  })
}
```

### AppListTile

List item.
```dart
class AppListTile extends StatelessWidget {
  const AppListTile({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showDivider = true,
    this.showChevron = false,
  })
}
```

### AppBottomSheet

Bottom sheet dialog.
```dart
class AppBottomSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool isDismissible = true,
    bool showDragHandle = true,
  })
}
```

**Full widget API reference:** See [Component Library](COMPONENT_LIBRARY.md)

---

**Sonraki:** [Component Library →](COMPONENT_LIBRARY.md)