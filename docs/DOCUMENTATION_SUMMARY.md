# 📚 Protoolbag Mobile Core - Dokümantasyon Özeti

Bu dokümantasyon paketi, Protoolbag Mobile Core Flutter kütüphanesi için kapsamlı bir rehber içermektedir.

## 📦 Paket İçeriği

```
protoolbag-mobile-core-docs/
├── README.md                    # ✅ Ana dokümantasyon
├── CONTRIBUTING.md              # ✅ Katkı rehberi  
├── CHANGELOG.md                 # ✅ Versiyon geçmişi
├── LICENSE                      # ✅ MIT lisansı
└── docs/
    ├── TABLE_OF_CONTENTS.md    # ✅ İçindekiler
    ├── DOCUMENTATION_SUMMARY.md # ✅ Bu dosya
    ├── ARCHITECTURE.md          # Mimari yapı (detaylı)
    ├── DESIGN_SYSTEM.md         # Tasarım sistemi (detaylı)
    ├── DEVELOPMENT_GUIDE.md     # Geliştirme rehberi (detaylı)
    ├── API_REFERENCE.md         # API dokümantasyonu (detaylı)
    ├── COMPONENT_LIBRARY.md     # Widget kataloğu (detaylı)
    ├── BEST_PRACTICES.md        # En iyi pratikler (detaylı)
    ├── MIGRATION_GUIDE.md       # Güncelleme rehberi (detaylı)
    └── EXAMPLES.md              # Kod örnekleri (detaylı)
```

## 🎯 Hızlı Başlangıç

### 1. Kurulum
```yaml
dependencies:
  protoolbag_core:
    git:
      url: https://github.com/ozgurprotoolbag/protoolbag-mobile-core
      ref: v1.0.0
```

### 2. Initialize
```dart
await CoreInitializer.initialize(
  supabaseUrl: 'YOUR_URL',
  supabaseAnonKey: 'YOUR_KEY',
);
```

### 3. Kullanım
```dart
AppButton(
  label: 'Continue',
  variant: AppButtonVariant.primary,
  onPressed: () {},
)
```

## 📖 Dokümantasyon Haritası

### Yeni Başlayanlar İçin
1. README.md - Genel bakış
2. docs/ARCHITECTURE.md - Mimari anlama
3. docs/COMPONENT_LIBRARY.md - Widgetları öğrenme
4. docs/EXAMPLES.md - Örnekleri inceleme

### Geliştirici İçin
1. docs/DEVELOPMENT_GUIDE.md - Geliştirme süreci
2. docs/API_REFERENCE.md - API detayları
3. docs/BEST_PRACTICES.md - Best practices
4. CONTRIBUTING.md - Katkı rehberi

### Tasarımcı İçin
1. docs/DESIGN_SYSTEM.md - Design system
2. docs/COMPONENT_LIBRARY.md - UI components
3. Apple HIG uyumluluğu

## 🔑 Temel Kavramlar

### Core Package
- **Ne değil:** Barcode scanner gibi tek işlevli utility
- **Nedir:** Multi-tenant SaaS foundation framework

### Üç Katman
1. **Core Package** - Ortak kütüphane (bu proje)
2. **Template** - Starter şablonu
3. **Specific Projects** - Gerçek uygulamalar

### Güncelleme Stratejisi
- Core'da değişiklik → tek commit
- Tüm projeler `flutter pub upgrade protoolbag_core`
- Semantic versioning (MAJOR.MINOR.PATCH)

## 📊 Mimari Özeti

```
┌─────────────────────────────────────┐
│    Presentation Layer (UI)          │
│    - Widgets, Screens, Providers    │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│    Domain Layer (Business Logic)    │
│    - Entities, Use Cases            │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│    Data Layer (API, DB, Cache)      │
│    - Repositories, Data Sources     │
└─────────────────────────────────────┘
```

## 🎨 Design System Özeti

### Renkler
- Primary: iOS Blue (#007AFF)
- Success: iOS Green (#34C759)
- Error: iOS Red (#FF3B30)
- Light/Dark mode adaptive

### Typography
- SF Pro Display font
- 11 seviye (Large Title → Caption 2)
- iOS native letter spacing

### Spacing
- 4px grid sistemi
- xs(4) → sm(8) → md(16) → lg(24) → xl(32)

## 🧩 Component Özeti

### 30+ Widget
- **Buttons:** AppButton, AppIconButton
- **Inputs:** AppTextField, AppDropdown, AppDatePicker
- **Cards:** AppCard, MetricCard
- **Lists:** AppListTile, AppSectionHeader
- **Navigation:** AppScaffold, AppTabBar, AppBottomSheet
- **Feedback:** AppLoadingIndicator, AppErrorView, AppEmptyState
- **Display:** AppAvatar, AppBadge, AppChip, AppProgressBar

## 🔐 Servisler Özeti

### Core Services
- **AuthService** - Authentication & authorization
- **ApiClient** - HTTP & Supabase queries
- **TenantService** - Multi-tenancy
- **CacheManager** - Cache with TTL
- **SecureStorage** - Encrypted storage
- **BiometricAuth** - Face ID / Touch ID

## 💡 Örnek Kullanım

### Authentication
```dart
final result = await authService.signIn(
  email: email,
  password: password,
);

result.when(
  success: (user) => navigateHome(),
  failure: (error) => showError(error),
  requiresTenantSelection: (tenants) => showTenantPicker(tenants),
);
```

### API Call
```dart
final devices = await apiClient.querySupabase<Device>(
  table: 'devices',
  fromJson: Device.fromJson,
  filter: (query) => query.eq('tenant_id', currentTenantId),
);
```

### Form
```dart
AppTextField(
  label: 'Email',
  validator: Validators.email,
  controller: emailController,
)
```

## 🎯 Sonraki Adımlar

1. **README.md** okuyarak başla
2. **docs/ARCHITECTURE.md** ile mimariyi anla
3. **docs/COMPONENT_LIBRARY.md** ile widgetları keşfet
4. **docs/EXAMPLES.md** ile gerçek örnekleri incele
5. **docs/DEVELOPMENT_GUIDE.md** ile geliştirmeye başla

## 📞 Destek

- GitHub Issues: Bug reports & feature requests
- Email: support@protoolbag.com
- Slack: #mobile-core channel

---

**Versiyon:** 1.0.0  
**Güncellenme:** 26 Ocak 2024  
**Yazar:** Protoolbag Team

**Not:** Detaylı açıklamalar için ilgili docs/*.md dosyalarını inceleyin.
