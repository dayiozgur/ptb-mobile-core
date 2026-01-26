# 🚀 Protoolbag Mobile Core

> Enterprise-grade Flutter SaaS foundation library for Protoolbag ecosystem

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/ozgurprotoolbag/protoolbag-mobile-core)
[![Flutter](https://img.shields.io/badge/Flutter-3.19+-02569B.svg?logo=flutter)](https://flutter.dev)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

## 📋 İçindekiler

- [Genel Bakış](#genel-bakış)
- [Özellikler](#özellikler)
- [Kurulum](#kurulum)
- [Hızlı Başlangıç](#hızlı-başlangıç)
- [Dokümantasyon](#dokümantasyon)
- [Projeler](#projeler)
- [Katkıda Bulunma](#katkıda-bulunma)
- [Lisans](#lisans)

## 🎯 Genel Bakış

Protoolbag Mobile Core, tüm Protoolbag SaaS uygulamaları için ortak foundation sağlayan, Apple Human Interface Guidelines'a uygun, enterprise-grade bir Flutter kütüphanesidir.

### Ne Değildir?

- ❌ Barcode scanner gibi tek işlevli bir utility değildir
- ❌ Hazır bir uygulama şablonu değildir
- ❌ Public kullanım için tasarlanmamıştır

### Nedir?

- ✅ Multi-tenant SaaS altyapısı
- ✅ Apple-style UI component library (30+ widget)
- ✅ Authentication & authorization sistemi
- ✅ API client & network layer
- ✅ Offline-first data management
- ✅ Theme & design system
- ✅ Navigation & routing utilities

## ✨ Özellikler

### 🎨 Design System
- Apple Human Interface Guidelines uyumlu
- Light/Dark mode support
- Responsive design system
- SF Pro Display typography
- Consistent spacing & shadows

### 🔐 Authentication
- Multi-tenant login
- Biometric authentication
- Social login (Apple, Google)
- JWT token management
- Role-based access control

### 🌐 Networking
- Supabase integration
- Generic HTTP client (Dio)
- Request/response interceptors
- Automatic retry mechanism
- Offline queue management

### 💾 Data Management
- Local database (Drift)
- Secure storage
- Cache management
- Offline-first sync
- Multi-tenant data isolation

### 🧩 UI Components
- 30+ production-ready widgets
- Form components
- Navigation elements
- Data visualization
- Loading & error states

### 🛠️ Utilities
- Date/time formatters
- Currency formatters
- Validators
- String extensions
- Image utilities

## 📦 Kurulum

### 1. Git Dependency

```yaml
# pubspec.yaml
dependencies:
  protoolbag_core:
    git:
      url: https://github.com/ozgurprotoolbag/protoolbag-mobile-core
      ref: v1.0.0
```

### 2. Install

```bash
flutter pub get
```

### 3. Import

```dart
import 'package:protoolbag_core/protoolbag_core.dart';
```

## 🚀 Hızlı Başlangıç

### Temel Kurulum

```dart
import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Core servislerini başlat
  await CoreInitializer.initialize(
    supabaseUrl: 'YOUR_SUPABASE_URL',
    supabaseAnonKey: 'YOUR_SUPABASE_ANON_KEY',
  );
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Protoolbag App',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: LoginScreen(),
    );
  }
}
```

### Widgetları Kullanma

```dart
import 'package:protoolbag_core/protoolbag_core.dart';

class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'My Screen',
      child: Column(
        children: [
          AppCard(
            child: Text('Hello World'),
          ),
          SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Submit',
            variant: AppButtonVariant.primary,
            onPressed: () => _handleSubmit(),
          ),
        ],
      ),
    );
  }
}
```

## 📚 Dokümantasyon

Detaylı dokümantasyon için:

- [**Mimari Yapı**](docs/ARCHITECTURE.md) - Sistem mimarisi ve tasarım prensipleri
- [**Tasarım Sistemi**](docs/DESIGN_SYSTEM.md) - UI/UX kuralları ve Apple guidelines
- [**Geliştirme Rehberi**](docs/DEVELOPMENT_GUIDE.md) - Yeni özellik ekleme ve best practices
- [**API Reference**](docs/API_REFERENCE.md) - Tüm sınıflar ve metodlar
- [**Component Library**](docs/COMPONENT_LIBRARY.md) - Widget katalog ve örnekleri
- [**Migration Guide**](docs/MIGRATION_GUIDE.md) - Versiyon yükseltme rehberi
- [**Best Practices**](docs/BEST_PRACTICES.md) - En iyi pratikler ve anti-patterns
- [**Examples**](docs/EXAMPLES.md) - Gerçek kullanım senaryoları

## 🏗️ Projeler

Bu core library kullanan projeler:

| Proje | Açıklama | Core Version | Status |
|-------|----------|-------------|--------|
| Protoolbag Monitoring | IoT enerji izleme | v1.0.0 | ✅ Active |
| FixFlow Mobile | Ticket & asset yönetimi | v1.0.0 | ✅ Active |
| PMS Mobile | Proje yönetim sistemi | v1.0.0 | 🚧 In Progress |

## 🤝 Katkıda Bulunma

Bu proje Protoolbag ekosistemi için geliştirilmektedir. Katkı kuralları için [CONTRIBUTING.md](CONTRIBUTING.md) dosyasına bakın.

### Development Setup

```bash
# Repository'yi clone'la
git clone https://github.com/ozgurprotoolbag/protoolbag-mobile-core.git
cd protoolbag-mobile-core

# Dependencies yükle
flutter pub get

# Testleri çalıştır
flutter test

# Example app'i çalıştır
cd example
flutter run
```

## 📝 Changelog

Tüm önemli değişiklikler [CHANGELOG.md](CHANGELOG.md) dosyasında takip edilmektedir.

## 📄 Lisans

Bu proje MIT lisansı altında lisanslanmıştır - detaylar için [LICENSE](LICENSE) dosyasına bakın.

## 🔗 Bağlantılar

- [Protoolbag Ana Sayfa](https://protoolbag.com)
- [Dokümantasyon](https://docs.protoolbag.com/mobile)
- [Issue Tracker](https://github.com/ozgurprotoolbag/protoolbag-mobile-core/issues)

## 👥 Ekip

- **ÖZGÜR** - *Founder & Lead Developer*

## 📞 İletişim

Sorularınız için: support@protoolbag.com

---

Made with ❤️ by Protoolbag Team
