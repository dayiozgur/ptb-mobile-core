# CLAUDE.md - AI Assistant Guide for Protoolbag Mobile Core

## Project Overview

**Protoolbag Mobile Core** is an enterprise-grade Flutter SaaS foundation library for the Protoolbag ecosystem. It provides shared infrastructure, UI components, and services for building multi-tenant mobile applications.

- **Type**: Flutter/Dart library (not a standalone application)
- **Version**: 1.0.0
- **Flutter**: 3.19+
- **Dart**: 3.3+
- **License**: MIT
- **Primary Language in Docs**: Turkish (with English technical terms)

### What This Library Provides

- Multi-tenant SaaS infrastructure
- 30+ Apple Human Interface Guidelines-compliant UI widgets
- Authentication & authorization system (Supabase, biometric, social login)
- API client & network layer with Dio
- Offline-first data management
- Theme & design system
- Navigation & routing utilities

## Repository Structure

```
protoolbag-mobile-core/
├── docs/                    # Detailed documentation (10,000+ lines)
│   ├── ARCHITECTURE.md      # System design, Clean Architecture patterns
│   ├── DESIGN_SYSTEM.md     # Apple HIG, colors, typography, spacing
│   ├── DEVELOPMENT_GUIDE.md # Setup, adding widgets/services, testing
│   ├── API_REFERENCE.md     # Complete API documentation
│   ├── COMPONENT_LIBRARY.md # Widget catalog with examples
│   ├── BEST_PRACTICES.md    # Code patterns, anti-patterns
│   ├── EXAMPLES.md          # Real-world usage scenarios
│   └── MIGRATION_GUIDE.md   # Version upgrade instructions
├── lib/                     # Source code (when present)
│   ├── core/                # Core utilities (API, auth, storage, theme)
│   ├── presentation/        # UI components and screens
│   ├── data/                # Data layer (repositories, datasources)
│   └── domain/              # Business logic (entities, use cases)
├── test/                    # Test files
├── example/                 # Example application
├── README.md                # Project overview
├── CONTRIBUTING.md          # Contribution guidelines
├── CHANGELOG.md             # Version history
└── pubspec.yaml             # Dependencies
```

## Common Commands

```bash
# Install dependencies
flutter pub get

# Run code generation (for Drift, JSON serialization, etc.)
dart run build_runner build --delete-conflicting-outputs

# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run static analysis
flutter analyze

# Format code
dart format .

# Run example app
cd example && flutter run
```

## Architecture Patterns

This codebase follows **Clean Architecture** with three layers:

### 1. Presentation Layer (`lib/presentation/`)
- UI widgets, screens, state management
- Uses Riverpod for state management
- ConsumerWidget/ConsumerStatefulWidget for reactive UI

### 2. Domain Layer (`lib/domain/`)
- Pure Dart (no Flutter dependencies)
- Entities, repository interfaces, use cases
- Business logic lives here

### 3. Data Layer (`lib/data/`)
- Repository implementations
- Remote/local data sources
- Models with JSON serialization

### Key Design Patterns Used
- **Repository Pattern**: Abstraction between domain and data
- **Provider Pattern (Riverpod)**: State management
- **Factory Pattern**: Widget variants
- **Singleton Pattern**: Logger, service instances
- **Dependency Injection**: GetIt for service locator

## Code Conventions

### Naming
- Classes: `PascalCase` (e.g., `AuthService`)
- Files: `snake_case` (e.g., `auth_service.dart`)
- Private members: `_leadingUnderscore`
- Constants: `camelCase`

### Import Order
1. Dart imports (`dart:async`, `dart:convert`)
2. Flutter imports (`package:flutter/material.dart`)
3. Package imports (`package:riverpod/riverpod.dart`)
4. Relative imports (`../core/theme/app_colors.dart`)

Each group separated by a blank line.

### Widget Structure
- Prefer `StatelessWidget` for presentation
- Use `ConsumerWidget` for Riverpod integration
- Use `StatefulWidget` only when necessary
- Always dispose resources properly

### Error Handling
- Use `Either<Failure, Success>` pattern
- Sealed classes for result types
- Never expose sensitive data in error messages

## UI Component Guidelines

All widgets follow Apple Human Interface Guidelines:

- **Touch targets**: Minimum 44x44 points
- **Spacing**: 4px grid system (use `AppSpacing.xs`, `sm`, `md`, `lg`, `xl`)
- **Colors**: Use `AppColors` with automatic light/dark mode support
- **Typography**: SF Pro Display scale via `AppTypography`
- **Shadows**: Use `AppShadows` for elevation

### Button Variants
```dart
AppButton(
  label: 'Submit',
  variant: AppButtonVariant.primary,  // primary, secondary, tertiary, destructive
  onPressed: () {},
)
```

### Common Widgets
- `AppButton`, `AppIconButton` - Buttons
- `AppTextField`, `AppDropdown`, `AppDatePicker` - Inputs
- `AppCard`, `MetricCard` - Cards
- `AppScaffold`, `AppTabBar`, `AppBottomSheet` - Navigation
- `AppLoadingIndicator`, `AppErrorView`, `AppEmptyState` - Feedback

## Multi-Tenancy

This library supports multi-tenant SaaS architecture:

- `TenantContext` manages current tenant ID
- `TenantInterceptor` automatically injects tenant headers
- Supabase RLS (Row Level Security) for data isolation
- All API queries are automatically filtered by tenant

## State Management (Riverpod)

```dart
// Provider hierarchy example
final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

// Usage in widgets
class MyScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    return authState.when(
      data: (user) => ...,
      loading: () => AppLoadingIndicator(),
      error: (e, st) => AppErrorView(error: e),
    );
  }
}
```

## Testing Requirements

- **All new features must have tests**
- **Target code coverage: >80%**
- **Test types**:
  - Unit tests: Business logic, utilities
  - Widget tests: UI component behavior
  - Integration tests: Feature workflows

### Test File Location
```
test/
├── unit/
│   ├── core/
│   └── data/
├── widget/
│   └── presentation/
└── integration/
```

## Git Workflow

### Branch Naming
- `feature/feature-name` - New features
- `fix/bug-fix-name` - Bug fixes
- `docs/documentation-updates` - Documentation

### Commit Messages (Conventional Commits)
```
<type>(<scope>): <subject>

Types:
- feat: New feature
- fix: Bug fix
- docs: Documentation
- style: Formatting (no code change)
- refactor: Code restructuring
- test: Adding tests
- chore: Build, dependencies

Examples:
feat(widgets): add AppIconButton component
fix(auth): resolve token refresh issue
docs: update component library examples
```

### Pull Request Checklist
- [ ] Code follows style guidelines
- [ ] Tests added/updated and passing
- [ ] Documentation updated
- [ ] No new warnings from `flutter analyze`
- [ ] Self-review completed

## Key Files Reference

| File | Purpose |
|------|---------|
| `docs/ARCHITECTURE.md` | System architecture, design patterns |
| `docs/DESIGN_SYSTEM.md` | UI/UX rules, Apple HIG compliance |
| `docs/DEVELOPMENT_GUIDE.md` | Setup, adding features, testing |
| `docs/API_REFERENCE.md` | All class/method documentation |
| `docs/COMPONENT_LIBRARY.md` | Widget catalog with examples |
| `docs/BEST_PRACTICES.md` | Code patterns, anti-patterns |
| `docs/EXAMPLES.md` | Real-world code examples |
| `CONTRIBUTING.md` | Contribution process |
| `CHANGELOG.md` | Version history |

## Dependencies Overview

- **flutter_riverpod**: State management
- **supabase_flutter**: Backend integration
- **dio**: HTTP client
- **get_it**: Dependency injection
- **flutter_secure_storage**: Encrypted storage
- **drift**: Local database
- **google_fonts**: Typography (SF Pro Display)
- **build_runner**: Code generation

## Consumer Projects

This library is used by:
- Protoolbag Monitoring (IoT energy monitoring)
- FixFlow Mobile (Ticket & asset management)
- PMS Mobile (Project management system)

## Important Notes for AI Assistants

1. **Read docs first**: The `docs/` folder contains comprehensive documentation. Reference it before making changes.

2. **Follow Clean Architecture**: Keep presentation, domain, and data layers separate. Domain layer must be pure Dart.

3. **Apple HIG compliance**: All UI components must follow Apple Human Interface Guidelines (not Material Design).

4. **Multi-tenancy awareness**: All data operations must respect tenant isolation.

5. **Test coverage**: Every new feature needs corresponding tests targeting >80% coverage.

6. **Turkish documentation**: Main documentation is in Turkish. Technical terms remain in English.

7. **Widget exports**: New widgets must be exported through barrel files and added to `COMPONENT_LIBRARY.md`.

8. **Service registration**: New services must be registered in the DI container (`core/di/injection.dart`).

9. **Version updates**: Changes must be documented in `CHANGELOG.md` following semantic versioning.

10. **No public API**: This is an internal library for Protoolbag ecosystem, not for public use.
