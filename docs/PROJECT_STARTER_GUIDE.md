# 🚀 Project Starter Guide

> Protoolbag Core kullanarak yeni bir SaaS projesi oluşturma rehberi

## 📋 İçindekiler

1. [Ön Gereksinimler](#ön-gereksinimler)
2. [Proje Oluşturma](#proje-oluşturma)
3. [Core Library Kurulumu](#core-library-kurulumu)
4. [Proje Yapısı](#proje-yapısı)
5. [Environment Yapılandırması](#environment-yapılandırması)
6. [Supabase Kurulumu](#supabase-kurulumu)
7. [Uygulama Başlatma](#uygulama-başlatma)
8. [Authentication Kurulumu](#authentication-kurulumu)
9. [Multi-Tenant Kurulumu](#multi-tenant-kurulumu)
10. [Navigation Kurulumu](#navigation-kurulumu)
11. [İlk Ekranlar](#ilk-ekranlar)
12. [Test ve Doğrulama](#test-ve-doğrulama)

---

## 🔧 Ön Gereksinimler

### Geliştirme Ortamı

```bash
# Flutter SDK (3.19+)
flutter --version

# Dart SDK (3.3+)
dart --version
```

### Gerekli Hesaplar

- [ ] Supabase hesabı (https://supabase.com)
- [ ] Git repository erişimi

### IDE Eklentileri (VS Code)

- Flutter
- Dart
- Error Lens
- GitLens

---

## 📦 Proje Oluşturma

### 1. Flutter Projesi Oluştur

```bash
# Yeni proje oluştur
flutter create --org com.protoolbag my_saas_app
cd my_saas_app

# Gereksiz dosyaları temizle
rm -rf test/widget_test.dart
rm lib/main.dart
```

### 2. Minimum iOS/Android Versiyonları

**ios/Podfile:**
```ruby
platform :ios, '14.0'
```

**android/app/build.gradle:**
```gradle
android {
    defaultConfig {
        minSdkVersion 23
        targetSdkVersion 34
    }
}
```

---

## 📚 Core Library Kurulumu

### 1. pubspec.yaml Güncelle

```yaml
name: my_saas_app
description: A Protoolbag SaaS Application
version: 1.0.0+1

environment:
  sdk: '>=3.3.0 <4.0.0'
  flutter: '>=3.19.0'

dependencies:
  flutter:
    sdk: flutter

  # Protoolbag Core
  protoolbag_core:
    git:
      url: https://github.com/ozgurprotoolbag/protoolbag-mobile-core
      ref: main  # veya specific tag: v1.0.0

  # State Management
  flutter_riverpod: ^2.5.1

  # Navigation
  go_router: ^14.2.0

  # Environment
  flutter_dotenv: ^5.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  build_runner: ^2.4.9

flutter:
  uses-material-design: true

  assets:
    - .env
    - assets/images/
    - assets/icons/
```

### 2. Bağımlılıkları Yükle

```bash
flutter pub get
```

---

## 📁 Proje Yapısı

Önerilen klasör yapısı:

```
my_saas_app/
├── lib/
│   ├── main.dart                 # Entry point
│   ├── app.dart                  # MaterialApp widget
│   │
│   ├── config/
│   │   ├── environment.dart      # Environment variables
│   │   ├── router.dart           # Go Router configuration
│   │   └── providers.dart        # Riverpod providers
│   │
│   ├── features/
│   │   ├── auth/
│   │   │   ├── screens/
│   │   │   │   ├── login_screen.dart
│   │   │   │   ├── register_screen.dart
│   │   │   │   └── forgot_password_screen.dart
│   │   │   ├── providers/
│   │   │   │   └── auth_provider.dart
│   │   │   └── widgets/
│   │   │       └── auth_form.dart
│   │   │
│   │   ├── home/
│   │   │   ├── screens/
│   │   │   │   └── home_screen.dart
│   │   │   └── widgets/
│   │   │       └── dashboard_card.dart
│   │   │
│   │   ├── settings/
│   │   │   └── screens/
│   │   │       └── settings_screen.dart
│   │   │
│   │   └── tenant/
│   │       └── screens/
│   │           └── tenant_selector_screen.dart
│   │
│   └── shared/
│       ├── widgets/              # App-specific shared widgets
│       └── utils/                # App-specific utilities
│
├── assets/
│   ├── images/
│   │   └── logo.png
│   └── icons/
│
├── .env                          # Environment variables (git ignore!)
├── .env.example                  # Example env file
└── pubspec.yaml
```

### Klasörleri Oluştur

```bash
mkdir -p lib/config
mkdir -p lib/features/auth/screens
mkdir -p lib/features/auth/providers
mkdir -p lib/features/auth/widgets
mkdir -p lib/features/home/screens
mkdir -p lib/features/home/widgets
mkdir -p lib/features/settings/screens
mkdir -p lib/features/tenant/screens
mkdir -p lib/shared/widgets
mkdir -p lib/shared/utils
mkdir -p assets/images
mkdir -p assets/icons
```

---

## ⚙️ Environment Yapılandırması

### 1. .env.example Oluştur

```env
# Supabase
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=your-anon-key

# API
API_BASE_URL=https://api.example.com

# App
APP_NAME=My SaaS App
DEBUG_MODE=true
```

### 2. .env Dosyası Oluştur

```bash
cp .env.example .env
# .env dosyasını gerçek değerlerle düzenle
```

### 3. .gitignore Güncelle

```gitignore
# Environment
.env
*.env.local
```

### 4. lib/config/environment.dart

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration
class Environment {
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? '';

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? '';

  static String get appName =>
      dotenv.env['APP_NAME'] ?? 'My App';

  static bool get isDebugMode =>
      dotenv.env['DEBUG_MODE']?.toLowerCase() == 'true';

  /// Validate required variables
  static void validate() {
    final required = [
      'SUPABASE_URL',
      'SUPABASE_ANON_KEY',
    ];

    for (final key in required) {
      if (dotenv.env[key]?.isEmpty ?? true) {
        throw Exception('Missing required environment variable: $key');
      }
    }
  }
}
```

---

## 🗄️ Supabase Kurulumu

### 1. Supabase Projesi Oluştur

1. https://supabase.com adresine git
2. "New Project" oluştur
3. Project URL ve anon key'i kopyala

### 2. Veritabanı Tabloları

```sql
-- Tenants table
CREATE TABLE tenants (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(100) UNIQUE NOT NULL,
  logo_url TEXT,
  domain VARCHAR(255),
  status VARCHAR(50) DEFAULT 'active',
  plan VARCHAR(50) DEFAULT 'free',
  settings JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  trial_ends_at TIMESTAMPTZ,
  subscription_ends_at TIMESTAMPTZ,
  metadata JSONB
);

-- Tenant memberships
CREATE TABLE tenant_memberships (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  role VARCHAR(50) DEFAULT 'member',
  is_active BOOLEAN DEFAULT true,
  invited_at TIMESTAMPTZ,
  accepted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, tenant_id)
);

-- User profiles (extends auth.users)
CREATE TABLE profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  full_name VARCHAR(255),
  avatar_url TEXT,
  phone VARCHAR(50),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

-- Indexes
CREATE INDEX idx_tenant_memberships_user ON tenant_memberships(user_id);
CREATE INDEX idx_tenant_memberships_tenant ON tenant_memberships(tenant_id);
CREATE INDEX idx_tenants_slug ON tenants(slug);
```

### 3. Row Level Security (RLS)

```sql
-- Enable RLS
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- Tenant memberships policies
CREATE POLICY "Users can view own memberships" ON tenant_memberships
  FOR SELECT USING (auth.uid() = user_id);

-- Tenants policies
CREATE POLICY "Users can view their tenants" ON tenants
  FOR SELECT USING (
    id IN (
      SELECT tenant_id FROM tenant_memberships
      WHERE user_id = auth.uid() AND is_active = true
    )
  );
```

### 4. Auth Trigger (Otomatik Profil Oluşturma)

```sql
-- Function to create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

---

## 🚀 Uygulama Başlatma

### lib/main.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import 'app.dart';
import 'config/environment.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');
  Environment.validate();

  // Initialize Protoolbag Core
  final result = await CoreInitializer.initialize(
    config: CoreConfig(
      supabaseUrl: Environment.supabaseUrl,
      supabaseAnonKey: Environment.supabaseAnonKey,
      apiBaseUrl: Environment.apiBaseUrl,
      debugMode: Environment.isDebugMode,
    ),
  );

  if (!result.isSuccess) {
    // Handle initialization error
    Logger.error('Core initialization failed: ${result.errorMessage}');
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}
```

### lib/app.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import 'config/router.dart';
import 'config/environment.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: Environment.appName,
      debugShowCheckedModeBanner: false,

      // Theme from Core
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,

      // Router
      routerConfig: router,
    );
  }
}
```

---

## 🔐 Authentication Kurulumu

### lib/features/auth/providers/auth_provider.dart

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Auth state provider
final authStateProvider = StreamProvider<AuthState>((ref) {
  return authService.authStateStream;
});

/// Current user provider
final currentUserProvider = Provider((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.valueOrNull?.user;
});

/// Is authenticated provider
final isAuthenticatedProvider = Provider((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.valueOrNull?.isAuthenticated ?? false;
});
```

### lib/features/auth/screens/login_screen.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await authService.signInWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    setState(() => _isLoading = false);

    result.when(
      success: (user, session) {
        context.go('/home');
      },
      failure: (error) {
        AppSnackbar.showError(
          context,
          message: error?.message ?? 'Giriş başarısız',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Giriş Yap',
      showBackButton: false,
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),

              // Logo
              Center(
                child: Icon(
                  Icons.business,
                  size: 80,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Email field
              AppEmailField(
                controller: _emailController,
                enabled: !_isLoading,
              ),

              const SizedBox(height: AppSpacing.md),

              // Password field
              AppPasswordField(
                controller: _passwordController,
                enabled: !_isLoading,
              ),

              const SizedBox(height: AppSpacing.lg),

              // Login button
              AppButton(
                label: 'Giriş Yap',
                onPressed: _isLoading ? null : _handleLogin,
                isLoading: _isLoading,
              ),

              const SizedBox(height: AppSpacing.md),

              // Register link
              AppButton(
                label: 'Hesap Oluştur',
                variant: AppButtonVariant.tertiary,
                onPressed: () => context.push('/register'),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Forgot password
              TextButton(
                onPressed: () => context.push('/forgot-password'),
                child: Text(
                  'Şifremi Unuttum',
                  style: AppTypography.footnote.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## 🏢 Multi-Tenant Kurulumu

### lib/features/tenant/screens/tenant_selector_screen.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class TenantSelectorScreen extends ConsumerStatefulWidget {
  const TenantSelectorScreen({super.key});

  @override
  ConsumerState<TenantSelectorScreen> createState() => _TenantSelectorScreenState();
}

class _TenantSelectorScreenState extends ConsumerState<TenantSelectorScreen> {
  List<Tenant> _tenants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTenants();
  }

  Future<void> _loadTenants() async {
    final userId = authService.currentUser?.id;
    if (userId == null) return;

    final tenants = await tenantService.getUserTenants(userId);

    setState(() {
      _tenants = tenants;
      _isLoading = false;
    });

    // Tek tenant varsa otomatik seç
    if (tenants.length == 1) {
      await _selectTenant(tenants.first);
    }
  }

  Future<void> _selectTenant(Tenant tenant) async {
    final success = await tenantService.selectTenant(tenant.id);
    if (success) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Organizasyon Seç',
      showBackButton: false,
      child: _isLoading
          ? const Center(child: AppLoadingIndicator())
          : _tenants.isEmpty
              ? AppEmptyState(
                  icon: Icons.business_outlined,
                  title: 'Organizasyon Bulunamadı',
                  message: 'Henüz bir organizasyona dahil değilsiniz.',
                  actionLabel: 'Yeni Oluştur',
                  onAction: () => _showCreateTenantDialog(),
                )
              : ListView.separated(
                  padding: AppSpacing.screenPadding,
                  itemCount: _tenants.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final tenant = _tenants[index];
                    return AppCard(
                      onTap: () => _selectTenant(tenant),
                      child: AppListTile(
                        leading: AppAvatar(
                          imageUrl: tenant.logoUrl,
                          name: tenant.name,
                          size: AppAvatarSize.medium,
                        ),
                        title: tenant.name,
                        subtitle: tenant.plan.name.toUpperCase(),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                ),
    );
  }

  void _showCreateTenantDialog() {
    // Tenant oluşturma dialog'u
  }
}
```

---

## 🧭 Navigation Kurulumu

### lib/config/router.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/tenant/screens/tenant_selector_screen.dart';

/// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,

    // Redirect logic
    redirect: (context, state) {
      final isAuthenticated = authService.isAuthenticated;
      final hasTenant = tenantService.hasTenant;
      final isAuthRoute = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/register') ||
          state.matchedLocation.startsWith('/forgot-password');
      final isTenantRoute = state.matchedLocation == '/tenant-select';

      // Not authenticated -> login
      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      // Authenticated but no tenant -> tenant select
      if (isAuthenticated && !hasTenant && !isTenantRoute && !isAuthRoute) {
        return '/tenant-select';
      }

      // Authenticated with tenant but on auth route -> home
      if (isAuthenticated && hasTenant && isAuthRoute) {
        return '/home';
      }

      return null;
    },

    routes: [
      // Auth routes
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Tenant selection
      GoRoute(
        path: '/tenant-select',
        name: 'tenant-select',
        builder: (context, state) => const TenantSelectorScreen(),
      ),

      // Main app routes
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],

    // Error page
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text('Sayfa bulunamadı: ${state.matchedLocation}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Ana Sayfaya Git'),
            ),
          ],
        ),
      ),
    ),
  );
});
```

---

## 🏠 İlk Ekranlar

### lib/features/home/screens/home_screen.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = tenantService.currentTenant;
    final user = authService.currentUser;

    return AppScaffold(
      title: tenant?.name ?? 'Ana Sayfa',
      showBackButton: false,
      actions: [
        AppIconButton(
          icon: Icons.settings,
          onPressed: () => context.push('/settings'),
        ),
      ],
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome card
            AppCard(
              child: Padding(
                padding: AppSpacing.cardPadding,
                child: Row(
                  children: [
                    AppAvatar(
                      name: user?.email ?? 'User',
                      size: AppAvatarSize.large,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hoş geldiniz!',
                            style: AppTypography.headline,
                          ),
                          Text(
                            user?.email ?? '',
                            style: AppTypography.subheadline.copyWith(
                              color: AppColors.secondaryLabel(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Dashboard metrics
            AppSectionHeader(title: 'Özet'),
            const SizedBox(height: AppSpacing.sm),

            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    title: 'Toplam',
                    value: '128',
                    icon: Icons.inventory,
                    trend: MetricTrend.up,
                    trendValue: '+12%',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: MetricCard(
                    title: 'Aktif',
                    value: '42',
                    icon: Icons.check_circle,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // Quick actions
            AppSectionHeader(title: 'Hızlı İşlemler'),
            const SizedBox(height: AppSpacing.sm),

            AppCard(
              child: Column(
                children: [
                  AppListTile(
                    leading: Icon(Icons.add_circle, color: AppColors.primary),
                    title: 'Yeni Kayıt Ekle',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  AppListTile(
                    leading: Icon(Icons.search, color: AppColors.primary),
                    title: 'Kayıt Ara',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  AppListTile(
                    leading: Icon(Icons.bar_chart, color: AppColors.primary),
                    title: 'Raporlar',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## ✅ Test ve Doğrulama

### 1. Kod Analizi

```bash
# Lint kontrolü
flutter analyze

# Format kontrolü
dart format lib/ --set-exit-if-changed
```

### 2. Build Test

```bash
# iOS build
flutter build ios --no-codesign

# Android build
flutter build apk --debug
```

### 3. Çalıştırma

```bash
# iOS Simulator
flutter run -d "iPhone 15 Pro"

# Android Emulator
flutter run -d emulator-5554

# Tüm cihazlar
flutter run
```

### 4. Test Checklist

- [ ] Uygulama başarıyla açılıyor
- [ ] Login ekranı görünüyor
- [ ] Kayıt olabiliyorum
- [ ] Giriş yapabiliyorum
- [ ] Tenant seçimi çalışıyor
- [ ] Home ekranı görünüyor
- [ ] Dark mode çalışıyor
- [ ] Logout çalışıyor

---

## 🎯 Sonraki Adımlar

1. **Özel Özellikler Ekle** - Uygulamaya özel feature'ları geliştir
2. **API Entegrasyonu** - Backend API'leri entegre et
3. **Push Notifications** - FCM/APNs kurulumu
4. **Analytics** - Firebase Analytics veya alternatif
5. **Crash Reporting** - Sentry veya Crashlytics

---

## 📞 Yardım

Sorunlarınız için:
- [API Reference](API_REFERENCE.md)
- [Examples](EXAMPLES.md)
- [Best Practices](BEST_PRACTICES.md)

---

**Sonraki:** [Examples →](EXAMPLES.md)
