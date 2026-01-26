# 🔄 Migration Guide

Version upgrade guide for Protoolbag Mobile Core.

## v1.0.0 → v1.1.0

**Release Date:** TBD  
**Breaking Changes:** None  
**Migration Time:** ~5 minutes

### What's New

#### 1. AppIconButton Widget
New icon-only button component.

**Action Required:** None (backward compatible)

**Usage:**
```dart
AppIconButton(
  icon: CupertinoIcons.heart,
  onPressed: () => _toggleFavorite(),
)
```

#### 2. Analytics Service
New analytics tracking service.

**Action Required:** Add to DI setup
```dart
// Add to injection.dart
getIt.registerLazySingleton<AnalyticsService>(
  () => AnalyticsService(getIt<AnalyticsRepository>()),
);
```

### Deprecations

None in this release.

---

## v0.9.0 → v1.0.0

**Release Date:** 2024-01-26  
**Breaking Changes:** Yes  
**Migration Time:** ~30 minutes

### Breaking Changes

#### 1. AppButton API Change

**What Changed:**
- `type` parameter renamed to `variant`
- `ButtonType` enum renamed to `AppButtonVariant`

**Before:**
```dart
AppButton(
  label: 'Continue',
  type: ButtonType.primary,
  onPressed: () {},
)
```

**After:**
```dart
AppButton(
  label: 'Continue',
  variant: AppButtonVariant.primary,
  onPressed: () {},
)
```

**Migration:**
1. Find & replace: `type: ButtonType.` → `variant: AppButtonVariant.`
2. Find & replace: `ButtonType` → `AppButtonVariant`

#### 2. AuthService Method Signature

**What Changed:**
- `login()` now requires `tenantId` parameter (can be null)

**Before:**
```dart
await authService.login(
  email: email,
  password: password,
);
```

**After:**
```dart
await authService.login(
  email: email,
  password: password,
  tenantId: currentTenantId,  // Add this
);
```

**Migration:**
1. Add `tenantId` parameter to all `login()` calls
2. Pass `null` if tenant selection happens after login

#### 3. ApiClient Constructor

**What Changed:**
- Constructor now requires `baseUrl` parameter

**Before:**
```dart
final apiClient = ApiClient(supabase: supabase);
```

**After:**
```dart
final apiClient = ApiClient(
  supabase: supabase,
  baseUrl: Environment.apiBaseUrl,  // Add this
);
```

### New Features

#### 1. Multi-Tenant Support
Full multi-tenancy infrastructure.

**Setup:**
```dart
// Set active tenant
await TenantService.setTenant(tenantId);

// Switch tenant
await TenantService.switchTenant(newTenantId);
```

#### 2. Biometric Authentication
Native biometric support.

**Setup:**
```dart
final canUseBiometric = await BiometricAuth.isAvailable();

if (canUseBiometric) {
  final success = await BiometricAuth.authenticate(
    reason: 'Verify identity',
  );
}
```

### Deprecations

#### 1. OldWidget (Deprecated)
Use `NewWidget` instead.

**Timeline:**
- v1.0.0: Deprecated, still works
- v2.0.0: Will be removed

**Migration:**
```dart
// Old
OldWidget(data: data)

// New
NewWidget(data: data)
```

---

## v0.8.0 → v0.9.0

**Release Date:** 2024-01-15  
**Breaking Changes:** No  
**Migration Time:** ~10 minutes

### What's New

#### 1. Dark Mode Support
Automatic light/dark mode switching.

**Setup:**
```dart
MaterialApp(
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: ThemeMode.system,  // Add this
)
```

#### 2. Offline Support
Local caching and sync.

**Setup:**
```dart
await CoreInitializer.initialize(
  // ... existing config
  enableOfflineMode: true,  // Add this
);
```

---

## Migration Checklist

Use this checklist when upgrading:

### Pre-Migration
- [ ] Read changelog for target version
- [ ] Review breaking changes
- [ ] Create backup branch
- [ ] Run all tests before upgrade

### During Migration
- [ ] Update `pubspec.yaml` version
- [ ] Run `flutter pub get`
- [ ] Fix breaking changes
- [ ] Update deprecated APIs
- [ ] Run code generation if needed
- [ ] Test thoroughly

### Post-Migration
- [ ] Run all tests
- [ ] Manual testing of critical flows
- [ ] Update documentation
- [ ] Commit changes
- [ ] Tag release

### Test Checklist
- [ ] Authentication flows
- [ ] API calls
- [ ] Navigation
- [ ] Form submissions
- [ ] Data persistence
- [ ] Error handling

---

## Getting Help

If you encounter issues during migration:

1. **Check Documentation:** Review the [API Reference](API_REFERENCE.md)
2. **Search Issues:** Look for similar problems on GitHub
3. **Ask Team:** Post in #mobile-core Slack channel
4. **Create Issue:** If bug found, create detailed issue with:
    - Current version
    - Target version
    - Error message
    - Steps to reproduce

---

## Automated Migration Scripts

Some migrations can be automated with scripts.

### v1.0.0 Migration Script
```bash
#!/bin/bash

# Replace ButtonType with AppButtonVariant
find lib -name "*.dart" -type f -exec sed -i '' 's/ButtonType\./AppButtonVariant./g' {} +
find lib -name "*.dart" -type f -exec sed -i '' 's/type: ButtonType/variant: AppButtonVariant/g' {} +

echo "Migration complete. Please review changes."
```

**Usage:**
```bash
chmod +x scripts/migrate_v1.sh
./scripts/migrate_v1.sh
```

---

**Sonraki:** [Examples →](EXAMPLES.md)