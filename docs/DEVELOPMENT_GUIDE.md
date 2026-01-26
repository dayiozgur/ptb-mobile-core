# 🛠️ Development Guide

## İçindekiler

1. [Geliştirme Ortamı](#geliştirme-ortamı)
2. [Yeni Widget Ekleme](#yeni-widget-ekleme)
3. [Yeni Servis Ekleme](#yeni-servis-ekleme)
4. [Testing](#testing)
5. [Code Style](#code-style)
6. [Git Workflow](#git-workflow)
7. [Release Process](#release-process)
8. [Troubleshooting](#troubleshooting)

## 💻 Geliştirme Ortamı

### Gereksinimler
```bash
Flutter SDK: 3.19 veya üzeri
Dart SDK: 3.3 veya üzeri
IDE: VS Code veya Android Studio
Git: 2.30 veya üzeri
```

### Setup
```bash
# 1. Repository clone
git clone https://github.com/ozgurprotoolbag/protoolbag-mobile-core.git
cd protoolbag-mobile-core

# 2. Dependencies yükle
flutter pub get

# 3. Code generation çalıştır
dart run build_runner build --delete-conflicting-outputs

# 4. Tests çalıştır
flutter test

# 5. Example app çalıştır
cd example
flutter run
```

### VS Code Extensions
```json
{
  "recommendations": [
    "dart-code.dart-code",
    "dart-code.flutter",
    "usernamehw.errorlens",
    "pflannery.vscode-versionlens",
    "github.copilot"
  ]
}
```

### Project Structure
```
protoolbag-mobile-core/
├── lib/
│   ├── core/               # Core utilities
│   ├── presentation/       # UI components
│   ├── data/              # Data layer
│   ├── domain/            # Business logic
│   └── protoolbag_core.dart  # Main export
├── example/               # Example app
├── test/                  # Tests
├── docs/                  # Documentation
├── pubspec.yaml
└── README.md
```

## 🧩 Yeni Widget Ekleme

### 1. Widget Dosyası Oluştur
```dart
// lib/presentation/widgets/buttons/app_icon_button.dart

import 'package:flutter/cupertino.dart';
import 'package:protoolbag_core/core/theme/app_colors.dart';
import 'package:protoolbag_core/core/theme/app_spacing.dart';

/// iOS-style icon button
/// 
/// Example:
/// ```dart
/// AppIconButton(
///   icon: CupertinoIcons.heart,
///   onPressed: () => _handleLike(),
/// )
/// ```
class AppIconButton extends StatelessWidget {
  /// Icon to display
  final IconData icon;
  
  /// Callback when button is pressed
  final VoidCallback? onPressed;
  
  /// Button size
  final double size;
  
  /// Icon color
  final Color? color;
  
  /// Background color
  final Color? backgroundColor;
  
  /// Shows loading indicator
  final bool isLoading;
  
  const AppIconButton({
    Key? key,
    required this.icon,
    this.onPressed,
    this.size = 44.0,
    this.color,
    this.backgroundColor,
    this.isLoading = false,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: isLoading ? null : onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(size / 2),
        ),
        child: Center(
          child: isLoading
              ? CupertinoActivityIndicator()
              : Icon(
                  icon,
                  color: color ?? AppColors.primary,
                  size: size * 0.5,
                ),
        ),
      ),
    );
  }
}
```

### 2. Export Ekle
```dart
// lib/presentation/widgets/buttons/buttons.dart

export 'app_button.dart';
export 'app_icon_button.dart';  // ✅ Yeni widget

// lib/protoolbag_core.dart
export 'presentation/widgets/buttons/buttons.dart';
```

### 3. Test Yaz
```dart
// test/presentation/widgets/buttons/app_icon_button_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

void main() {
  group('AppIconButton', () {
    testWidgets('renders icon correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppIconButton(
            icon: CupertinoIcons.heart,
            onPressed: () {},
          ),
        ),
      );
      
      expect(find.byIcon(CupertinoIcons.heart), findsOneWidget);
    });
    
    testWidgets('calls onPressed when tapped', (tester) async {
      var pressed = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: AppIconButton(
            icon: CupertinoIcons.heart,
            onPressed: () => pressed = true,
          ),
        ),
      );
      
      await tester.tap(find.byType(AppIconButton));
      expect(pressed, isTrue);
    });
    
    testWidgets('shows loading indicator when isLoading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppIconButton(
            icon: CupertinoIcons.heart,
            isLoading: true,
          ),
        ),
      );
      
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.heart), findsNothing);
    });
  });
}
```

### 4. Example Ekle
```dart
// example/lib/pages/buttons_example_page.dart

class ButtonsExamplePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Buttons'),
      ),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(AppSpacing.md),
          children: [
            // Existing examples...
            
            SizedBox(height: AppSpacing.lg),
            Text('Icon Button', style: AppTypography.title3),
            SizedBox(height: AppSpacing.sm),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                AppIconButton(
                  icon: CupertinoIcons.heart,
                  onPressed: () {},
                ),
                AppIconButton(
                  icon: CupertinoIcons.heart_fill,
                  color: AppColors.error,
                  onPressed: () {},
                ),
                AppIconButton(
                  icon: CupertinoIcons.add,
                  backgroundColor: AppColors.primary,
                  color: Colors.white,
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

### 5. Dokümantasyon Güncelle
```markdown
// docs/COMPONENT_LIBRARY.md altına ekle

### AppIconButton

iOS-style icon button with optional background.

**Props:**
- `icon` (IconData, required): Icon to display
- `onPressed` (VoidCallback?): Tap callback
- `size` (double): Button size (default: 44)
- `color` (Color?): Icon color
- `backgroundColor` (Color?): Background color
- `isLoading` (bool): Show loading state

**Example:**
\`\`\`dart
AppIconButton(
  icon: CupertinoIcons.heart_fill,
  color: AppColors.error,
  onPressed: () => _handleLike(),
)
\`\`\`
```

## 🔧 Yeni Servis Ekleme

### 1. Interface Tanımla (Domain Layer)
```dart
// lib/domain/repositories/analytics_repository.dart

abstract class AnalyticsRepository {
  Future<void> trackEvent(String eventName, Map<String, dynamic> properties);
  Future<void> setUserId(String userId);
  Future<void> setUserProperties(Map<String, dynamic> properties);
}
```

### 2. Implementation Yaz (Data Layer)
```dart
// lib/data/repositories/analytics_repository_impl.dart

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final FirebaseAnalytics _analytics;
  
  AnalyticsRepositoryImpl(this._analytics);
  
  @override
  Future<void> trackEvent(
    String eventName,
    Map<String, dynamic> properties,
  ) async {
    await _analytics.logEvent(
      name: eventName,
      parameters: properties,
    );
  }
  
  @override
  Future<void> setUserId(String userId) async {
    await _analytics.setUserId(id: userId);
  }
  
  @override
  Future<void> setUserProperties(Map<String, dynamic> properties) async {
    for (final entry in properties.entries) {
      await _analytics.setUserProperty(
        name: entry.key,
        value: entry.value.toString(),
      );
    }
  }
}
```

### 3. Service Wrapper Oluştur
```dart
// lib/core/analytics/analytics_service.dart

class AnalyticsService {
  final AnalyticsRepository _repository;
  
  AnalyticsService(this._repository);
  
  // High-level methods
  Future<void> logLogin(String method) async {
    await _repository.trackEvent('login', {
      'method': method,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  Future<void> logScreenView(String screenName) async {
    await _repository.trackEvent('screen_view', {
      'screen_name': screenName,
    });
  }
  
  Future<void> logButtonTap(String buttonName) async {
    await _repository.trackEvent('button_tap', {
      'button_name': buttonName,
    });
  }
}
```

### 4. DI Setup
```dart
// lib/core/di/injection.dart

Future<void> setupDependencies() async {
  // ... existing setup
  
  // Analytics
  getIt.registerLazySingleton<FirebaseAnalytics>(
    () => FirebaseAnalytics.instance,
  );
  
  getIt.registerLazySingleton<AnalyticsRepository>(
    () => AnalyticsRepositoryImpl(getIt<FirebaseAnalytics>()),
  );
  
  getIt.registerLazySingleton<AnalyticsService>(
    () => AnalyticsService(getIt<AnalyticsRepository>()),
  );
}
```

### 5. Provider Oluştur
```dart
// lib/core/analytics/analytics_provider.dart

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return getIt<AnalyticsService>();
});
```

### 6. Kullanım
```dart
// Herhangi bir widget'ta
class MyScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(analyticsServiceProvider);
    
    useEffect(() {
      analytics.logScreenView('MyScreen');
      return null;
    }, []);
    
    return AppButton(
      label: 'Submit',
      onPressed: () {
        analytics.logButtonTap('submit_button');
        _handleSubmit();
      },
    );
  }
}
```

## 🧪 Testing

### Test Structure
```
test/
├── unit/
│   ├── core/
│   │   ├── auth/
│   │   │   └── auth_service_test.dart
│   │   └── utils/
│   │       └── validators_test.dart
│   └── data/
│       └── repositories/
│           └── auth_repository_test.dart
├── widget/
│   └── presentation/
│       └── widgets/
│           ├── buttons/
│           │   └── app_button_test.dart
│           └── inputs/
│               └── app_text_field_test.dart
└── integration/
    └── auth_flow_test.dart
```

### Unit Test Example
```dart
// test/core/utils/validators_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/core/utils/validators.dart';

void main() {
  group('Validators', () {
    group('email', () {
      test('returns null for valid email', () {
        expect(Validators.email('test@example.com'), isNull);
        expect(Validators.email('user.name@domain.co.uk'), isNull);
      });
      
      test('returns error for invalid email', () {
        expect(Validators.email('invalid'), isNotNull);
        expect(Validators.email('missing@domain'), isNotNull);
        expect(Validators.email('@domain.com'), isNotNull);
      });
      
      test('returns error for empty email', () {
        expect(Validators.email(''), isNotNull);
        expect(Validators.email(null), isNotNull);
      });
    });
    
    group('password', () {
      test('returns null for valid password', () {
        expect(Validators.password('SecurePass123!'), isNull);
      });
      
      test('returns error for short password', () {
        expect(Validators.password('short'), isNotNull);
      });
      
      test('returns error for password without number', () {
        expect(Validators.password('NoNumberHere!'), isNotNull);
      });
    });
  });
}
```

### Widget Test Example
```dart
// test/widget/presentation/widgets/buttons/app_button_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

void main() {
  group('AppButton', () {
    testWidgets('renders label correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'Test Button',
              onPressed: () {},
            ),
          ),
        ),
      );
      
      expect(find.text('Test Button'), findsOneWidget);
    });
    
    testWidgets('calls onPressed when tapped', (tester) async {
      var pressed = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'Test',
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );
      
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();
      
      expect(pressed, isTrue);
    });
    
    testWidgets('shows loading indicator when isLoading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'Test',
              isLoading: true,
            ),
          ),
        ),
      );
      
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
    
    testWidgets('disables onPressed when isLoading', (tester) async {
      var pressed = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'Test',
              isLoading: true,
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );
      
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();
      
      expect(pressed, isFalse);
    });
  });
}
```

### Mock Setup
```dart
// test/mocks/mock_supabase.dart

import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class MockAuthResponse extends Mock implements AuthResponse {}

// Usage in tests
void main() {
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  
  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    
    when(() => mockSupabase.auth).thenReturn(mockAuth);
  });
  
  test('login success', () async {
    final mockResponse = MockAuthResponse();
    when(() => mockAuth.signInWithPassword(
      email: any(named: 'email'),
      password: any(named: 'password'),
    )).thenAnswer((_) async => mockResponse);
    
    // Test implementation
  });
}
```

### Running Tests
```bash
# All tests
flutter test

# Specific test file
flutter test test/core/utils/validators_test.dart

# With coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html

# Watch mode
flutter test --watch
```

## 📝 Code Style

### Dart Style Guide
```dart
// ✅ DOĞRU - Naming conventions
class UserRepository {}              // PascalCase for classes
const double appSpacing = 16.0;      // camelCase for constants
void getUserData() {}                // camelCase for functions
final String userName = 'John';      // camelCase for variables

// ✅ DOĞRU - Private members
class _InternalWidget {}             // Private class
String _userId;                      // Private field
void _handleSubmit() {}              // Private method

// ✅ DOĞRU - Documentation
/// Validates email format.
///
/// Returns `null` if valid, error message if invalid.
///
/// Example:
/// ```dart
/// final error = Validators.email('test@example.com');
/// if (error != null) {
///   print('Invalid: $error');
/// }
/// ```
String? email(String? value) { ... }

// ✅ DOĞRU - Imports organization
// Dart imports
import 'dart:async';
import 'dart:convert';

// Package imports
import 'package:flutter/material.dart';
import 'package:riverpod/riverpod.dart';

// Relative imports
import '../core/theme/app_colors.dart';
import '../widgets/app_button.dart';
```

### Linting Rules
```yaml
# analysis_options.yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    # Style
    - always_declare_return_types
    - always_put_required_named_parameters_first
    - avoid_print
    - prefer_const_constructors
    - prefer_const_declarations
    - prefer_final_fields
    - prefer_single_quotes
    - sort_constructors_first
    - unnecessary_this
    
    # Documentation
    - public_member_api_docs
    
    # Error prone
    - avoid_dynamic_calls
    - avoid_slow_async_io
    - cancel_subscriptions
    - close_sinks
```

## 🔀 Git Workflow

### Branch Strategy
```
main                 # Production-ready code
├── develop          # Integration branch
    ├── feature/add-analytics    # Feature branches
    ├── feature/new-widget
    ├── fix/button-padding       # Bug fixes
    └── docs/api-reference       # Documentation
```

### Commit Convention
```bash
# Format: <type>(<scope>): <subject>

# Types:
feat:     New feature
fix:      Bug fix
docs:     Documentation
style:    Formatting, no code change
refactor: Code restructuring
test:     Adding tests
chore:    Build, dependencies

# Examples:
git commit -m "feat(widgets): add AppIconButton component"
git commit -m "fix(auth): resolve token refresh issue"
git commit -m "docs: update component library"
git commit -m "test(validators): add email validation tests"
```

### Pull Request Process
```bash
# 1. Create feature branch
git checkout -b feature/add-analytics

# 2. Make changes and commit
git add .
git commit -m "feat(analytics): add analytics service"

# 3. Push to remote
git push origin feature/add-analytics

# 4. Create PR on GitHub
- Title: Clear, descriptive
- Description: What, why, how
- Link issues if applicable
- Request reviewers

# 5. Address review comments
git add .
git commit -m "refactor: address PR feedback"
git push

# 6. After approval, squash and merge
```

### PR Template
```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests added/updated
- [ ] Widget tests added/updated
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] No new warnings
- [ ] Tests pass locally

## Screenshots (if applicable)
[Add screenshots here]
```

## 🚀 Release Process

### Version Numbering
```
MAJOR.MINOR.PATCH

1.0.0 → 1.0.1   # Patch: bug fixes
1.0.1 → 1.1.0   # Minor: new features, non-breaking
1.1.0 → 2.0.0   # Major: breaking changes
```

### Release Steps
```bash
# 1. Update version in pubspec.yaml
version: 1.1.0

# 2. Update CHANGELOG.md
## [1.1.0] - 2024-01-26
### Added
- AppIconButton component
- Analytics service
### Fixed
- Button padding issue
### Changed
- Updated dependencies

# 3. Commit version bump
git add .
git commit -m "chore: bump version to 1.1.0"

# 4. Create tag
git tag v1.1.0
git push origin v1.1.0

# 5. Create GitHub release
- Go to GitHub Releases
- Create new release from tag
- Copy CHANGELOG content
- Publish release

# 6. Notify projects
- Post in team Slack
- Update project documentation
```

### Migration Guide Template
```markdown
# Migration Guide: v1.0.0 → v1.1.0

## Breaking Changes

### AppButton API Change
The `type` parameter has been renamed to `variant`.

**Before:**
\`\`\`dart
AppButton(type: ButtonType.primary)
\`\`\`

**After:**
\`\`\`dart
AppButton(variant: AppButtonVariant.primary)
\`\`\`

## New Features

### AppIconButton
New icon button component available.

\`\`\`dart
AppIconButton(
  icon: CupertinoIcons.heart,
  onPressed: () {},
)
\`\`\`

## Deprecations

### OldWidget (deprecated in 1.1.0, will be removed in 2.0.0)
Use NewWidget instead.
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Build Errors
```bash
# Clean and rebuild
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Clear caches
rm -rf .dart_tool/
rm pubspec.lock
flutter pub get
```

#### 2. Import Errors
```dart
// ❌ YANLIŞ
import 'package:protoolbag_core/presentation/widgets/app_button.dart';

// ✅ DOĞRU
import 'package:protoolbag_core/protoolbag_core.dart';
```

#### 3. Version Conflicts
```yaml
# pubspec.yaml
dependency_overrides:
  some_package: ^2.0.0  # Force specific version
```

#### 4. Test Failures
```bash
# Run specific test with verbose output
flutter test test/path/to/test.dart --verbose

# Debug test
flutter test --pause-after-load
# Attach debugger in IDE
```

### Getting Help

1. **Check Documentation**: Review relevant docs first
2. **Search Issues**: GitHub issues for similar problems
3. **Ask Team**: Slack channel #mobile-core
4. **Create Issue**: If bug found, create detailed issue

---

**Sonraki:** [API Reference →](API_REFERENCE.md)