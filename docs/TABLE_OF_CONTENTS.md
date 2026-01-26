# 📚 Protoolbag Mobile Core - Dokümantasyon İçeriği

## 📖 Ana Dokümantasyon

1. **README.md** - Genel bakış ve hızlı başlangıç
2. **CONTRIBUTING.md** - Katkı rehberi
3. **CHANGELOG.md** - Versiyon geçmişi
4. **LICENSE** - MIT lisansı

## 📂 Detaylı Dokümantasyon (docs/)

### 1. ARCHITECTURE.md
- Mimari prensipler
- Katmanlı yapı (Presentation, Domain, Data)
- Design patterns
- State management
- Dependency injection
- Multi-tenancy
- Security

### 2. DESIGN_SYSTEM.md
- Apple Human Interface Guidelines
- Renk sistemi
- Typography (SF Pro)
- Spacing & layout
- Iconography
- Shadows & elevation
- Animation & motion
- Accessibility
- Dark mode

### 3. DEVELOPMENT_GUIDE.md
- Geliştirme ortamı kurulumu
- Yeni widget ekleme
- Yeni servis ekleme
- Testing stratejisi
- Code style guidelines
- Git workflow
- Release process
- Troubleshooting

### 4. API_REFERENCE.md
- Core Module
- Authentication (AuthService, BiometricAuth)
- API Client (ApiClient, Interceptors)
- Storage (SecureStorage, CacheManager)
- Theme (AppTheme, AppColors, AppTypography)
- Utilities (Validators, Formatters, Logger)
- Widgets (30+ component API)

### 5. COMPONENT_LIBRARY.md
- Buttons (AppButton, AppIconButton)
- Inputs (AppTextField, AppDropdown, AppDatePicker)
- Cards & Containers (AppCard, MetricCard)
- Lists (AppListTile, AppSectionHeader)
- Navigation (AppScaffold, AppTabBar, AppBottomSheet)
- Feedback (AppLoadingIndicator, AppErrorView, AppEmptyState)
- Data Display (AppAvatar, AppProgressBar, AppChip, AppBadge)

### 6. BEST_PRACTICES.md
- Code organization
- State management patterns
- Performance optimization
- Security guidelines
- Error handling
- Testing practices
- Accessibility
- Common pitfalls

### 7. MIGRATION_GUIDE.md
- v1.0.0 → v1.1.0
- v0.9.0 → v1.0.0
- Breaking changes
- Deprecations
- Migration checklist
- Automated scripts

### 8. EXAMPLES.md
- Authentication flow (complete login implementation)
- API integration (CRUD operations)
- Form handling (validation)
- List management (infinite scroll)
- Real-time data (Supabase subscriptions)
- Offline support (offline-first repository)
- Multi-tenant (tenant management)

## 🎯 Kullanım Senaryoları

### Yeni Proje Başlatma
1. `pubspec.yaml`'a dependency ekle
2. `CoreInitializer.initialize()` çağır
3. `AppTheme` kullan
4. UI componentleri ile sayfa oluştur

### Widget Ekleme
1. `lib/presentation/widgets/` altına dosya oluştur
2. Export ekle
3. Test yaz
4. Example ekle
5. Dokümante et

### Servis Ekleme
1. Domain layer'da interface tanımla
2. Data layer'da implementation yaz
3. DI setup
4. Provider oluştur
5. Test yaz

## 📋 Hızlı Referans

### Temel Imports
```dart
import 'package:protoolbag_core/protoolbag_core.dart';
```

### En Çok Kullanılan Widgetlar
- AppButton
- AppTextField
- AppCard
- AppListTile
- AppScaffold
- AppLoadingIndicator
- AppErrorView

### En Çok Kullanılan Servisler
- AuthService
- ApiClient
- TenantService
- CacheManager
- SecureStorage

### En Çok Kullanılan Utilities
- Validators.email()
- Formatters.currency()
- AppColors.primary
- AppTypography.title1
- AppSpacing.md

## 🔗 Harici Kaynaklar

- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- [Apple HIG](https://developer.apple.com/design/human-interface-guidelines/)
- [Supabase Docs](https://supabase.com/docs)
- [Riverpod Docs](https://riverpod.dev/)

---

**Not:** Tüm dokümantasyon dosyaları bu pakette mevcuttur. Her dosya detaylı açıklamalar ve kod örnekleri içerir.
