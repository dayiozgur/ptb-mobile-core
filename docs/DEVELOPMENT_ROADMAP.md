# Protoolbag Mobile Core - Geliştirme Yol Haritası

## Genel Bakış

Bu döküman, Protoolbag Mobile Core kütüphanesinin geliştirme fazlarını ve mevcut durumunu tanımlar.

**Son Güncelleme:** 2026-02-02
**Mevcut Versiyon:** 1.3.0

---

## Faz Özeti

| Faz | Durum | Açıklama |
|-----|-------|----------|
| Faz 1 | ✅ Tamamlandı | Core Services & Testing |
| Faz 2 | ✅ Tamamlandı | Realtime & Storage |
| Faz 3 | ✅ Tamamlandı | IoT & Workflow |
| Faz 4 | ⏳ Gelecek | Advanced Modules |

---

## Faz 1 - Core Services & Testing ✅

**Durum:** Tamamlandı (v1.1.0)

### Tamamlanan Görevler

#### 1.1 Localization Service
- [x] Multi-language support (TR, EN, DE)
- [x] Locale persistence
- [x] Number/currency/date formatters
- [x] Interpolation support
- [x] Service registration

#### 1.2 Unit Tests
- [x] LocalizationService tests
- [x] ThemeService tests
- [x] ConnectivityService tests
- [x] OfflineSyncService tests
- [x] NotificationModel tests
- [x] SearchModel tests
- [x] ReportingModel tests

#### 1.3 Integration Tests
- [x] Service integration tests
- [x] Widget integration tests

#### 1.4 Database Migrations
- [x] RLS policies (001_rls_policies.sql)
- [x] Schema improvements (002_schema_improvements.sql)

### Dosyalar
```
lib/src/core/localization/
├── localization_service.dart
└── app_localizations.dart

test/
├── services/
│   ├── localization_service_test.dart
│   ├── theme_service_test.dart
│   ├── connectivity_service_test.dart
│   └── offline_sync_service_test.dart
├── models/
│   ├── notification_model_test.dart
│   ├── search_model_test.dart
│   └── reporting_model_test.dart
└── integration/
    ├── service_integration_test.dart
    └── widget_integration_test.dart

database/migrations/
├── 001_rls_policies.sql
└── 002_schema_improvements.sql
```

---

## Faz 2 - Realtime & Storage ✅

**Durum:** Tamamlandı (v1.2.0)

### Tamamlanan Görevler

#### 2.1 Push Notification Service
- [x] FCM token management
- [x] APNs token management
- [x] Permission handling
- [x] Topic subscriptions
- [x] Notification channels
- [x] Background/foreground handling

#### 2.2 Realtime Service
- [x] Supabase Realtime integration
- [x] Database change subscriptions
- [x] Presence tracking
- [x] Broadcast messaging
- [x] Typed generic handlers

#### 2.3 File Storage Service
- [x] Supabase Storage integration
- [x] Upload with progress
- [x] Download functionality
- [x] URL generation (signed/public)
- [x] Image compression
- [x] Thumbnail generation

#### 2.4 Pagination Helpers
- [x] PaginatedList<T>
- [x] PaginationController
- [x] Cursor-based pagination
- [x] Supabase range helpers

#### 2.5 Error Boundary Widget
- [x] Global error catching
- [x] Fallback UI
- [x] Error reporting
- [x] runAppWithErrorHandler

### Dosyalar
```
lib/src/core/
├── push/
│   └── push_notification_service.dart
├── realtime/
│   └── realtime_service.dart
├── storage/
│   └── file_storage_service.dart
└── pagination/
    └── pagination.dart

lib/src/presentation/widgets/feedback/
└── error_boundary.dart
```

---

## Faz 3 - IoT & Workflow ✅

**Durum:** Tamamlandı (v1.3.0)

### Tamamlanan Görevler

#### 3.1 IoT Layer Models ✅
- [x] Controller model ve service
- [x] Provider model ve service
- [x] Variable model ve service
- [x] Controller-Variable ilişkisi (device_model_id)

#### 3.2 Workflow Management ✅
- [x] Workflow model (860+ satır, kapsamlı)
- [x] WorkflowStep model (Trigger, Action, Condition)
- [x] WorkflowExecution tracking (WorkflowRun)
- [x] State machine implementation

#### 3.3 Work Request System ✅
- [x] WorkRequest model
- [x] WorkRequestService (CRUD + durum geçişleri)
- [x] Status transitions (10 farklı durum)
- [x] Assignment logic (kullanıcı/ekip)
- [x] Onay akışı (approve/reject)
- [x] Not ve ek dosya yönetimi

#### 3.4 Calendar & Events ✅
- [x] CalendarEvent model
- [x] Event recurrence (daily, weekly, monthly, yearly)
- [x] Reminder system (notification, email, sms)
- [x] Katılımcı yönetimi
- [x] CalendarService (CRUD + istatistikler)

#### 3.5 Technical Debt - Flutter Model Updates ✅
- [x] Tenant status field (TenantStatus enum)
- [x] Unit status field (UnitStatus enum)
- [x] UserProfile organization_id ve default_site_id

### Dosyalar
```
lib/src/core/
├── controller/
│   ├── controller_model.dart      ✅ (640 satır)
│   └── controller_service.dart    ✅
├── provider/
│   ├── provider_model.dart        ✅
│   └── provider_service.dart      ✅
├── variable/
│   ├── variable_model.dart        ✅ (739 satır)
│   └── variable_service.dart      ✅
├── workflow/
│   ├── workflow_model.dart        ✅ (860 satır)
│   └── workflow_service.dart      ✅
├── work_request/
│   ├── work_request_model.dart    ✅ (850+ satır) - YENİ
│   └── work_request_service.dart  ✅ (570+ satır) - YENİ
├── calendar/
│   ├── calendar_event_model.dart  ✅ (650+ satır) - YENİ
│   └── calendar_service.dart      ✅ (500+ satır) - YENİ
└── user/
    └── user_profile.dart          ✅ (güncellendi: org_id, site_id)
```

---

## Faz 4 - Advanced Modules ⏸️

**Durum:** Ertelendi (Stabilizasyon öncelikli)
**Detaylı Plan:** [PHASE4_PLANNING.md](PHASE4_PLANNING.md)

> **Not:** Faz 4, mevcut modüllerin tam olarak stabilize edilmesinden sonra başlayacaktır.
> Proje bütünlüğünü korumak ve teknik borcu minimize etmek amacıyla bu karar alınmıştır.

### Ertelenen Modüller

#### 4.1 Energy & KPI Module
- [ ] Energy consumption tracking
- [ ] KPI dashboard widgets
- [ ] Trend analysis
- [ ] Anomaly detection
- [ ] Reports and exports

#### 4.2 Inventory Module
- [ ] InventoryItem model
- [ ] Stock management
- [ ] Barcode scanning integration
- [ ] Low stock alerts
- [ ] Transaction history

#### 4.3 Production Module
- [ ] Production order model
- [ ] Line management
- [ ] OEE calculations
- [ ] Downtime tracking

#### 4.4 Retail Module
- [ ] Store management
- [ ] POS integration
- [ ] Sales analytics
- [ ] Customer management

#### 4.5 Financial Module
- [ ] Invoice model
- [ ] Payment tracking
- [ ] Budget management
- [ ] Financial reports

### Başlama Koşulları
- [ ] Faz 1-3 modülleri %100 stabil
- [ ] Tüm testler geçiyor
- [ ] Dokümantasyon güncel
- [ ] Teknik borç minimize edilmiş

---

## Teknik Borç & İyileştirmeler

### Yüksek Öncelik
- [x] Tenant status field to Flutter model ✅ (v1.3.0)
- [x] Unit status field to Flutter model ✅ (v1.3.0)
- [x] Profile organization_id relationship ✅ (v1.3.0)
- [ ] Comprehensive API documentation (devam ediyor)

### Orta Öncelik
- [ ] Performance profiling
- [ ] Memory optimization
- [ ] Network request caching
- [ ] Offline sync improvements

### Düşük Öncelik
- [ ] Accessibility improvements
- [ ] Animation refinements
- [ ] Dark mode edge cases
- [ ] Tablet layout optimizations

---

## Veritabanı Senkronizasyonu

Detaylı senkronizasyon planı için: [DATABASE_SYNC_PLAN.md](../database/DATABASE_SYNC_PLAN.md)

### Özet
| Kategori | Veritabanı | Flutter | Durum |
|----------|------------|---------|-------|
| Toplam Tablo | 280 | - | - |
| Core Modeller | 8 | 8 | ✅ Eşleşti |
| IoT Modeller | 3 | 3 | ✅ Eşleşti |
| Workflow | 5+ | 5+ | ✅ Eşleşti |
| WorkRequest | 1 | 1 | ✅ YENİ |
| Calendar | 1 | 1 | ✅ YENİ |
| RLS Politikaları | 9+ | - | ✅ Hazır |

---

## Release Notları

### v1.3.0 (Mevcut)
- **Phase 3 tamamlandı**
- WorkRequest model ve service (iş talebi yönetimi)
- CalendarEvent model ve service (takvim yönetimi)
- UserProfile organization_id ve default_site_id
- Teknik borçlar giderildi (Tenant/Unit status)
- IoT Layer modelleri (Controller, Provider, Variable)
- Workflow yönetimi (Trigger, Action, Condition)

### v1.2.0
- Phase 2 tamamlandı
- Push notification service
- Realtime service
- File storage service
- Pagination helpers
- Error boundary widget

### v1.1.0
- Phase 1 tamamlandı
- Localization service
- Unit & integration tests
- Database migrations

### v1.0.0
- İlk stabil release
- Core authentication
- UI components
- API client

---

## Katkıda Bulunma

Yeni özellik eklerken:

1. İlgili faz altında görev oluştur
2. Model → Service → Test sırasını takip et
3. Dokümantasyonu güncelle
4. CHANGELOG.md'ye ekle
5. PR açmadan önce lint ve test çalıştır

---

## Referanslar

- [ARCHITECTURE.md](ARCHITECTURE.md) - Sistem mimarisi
- [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) - UI/UX kuralları
- [API_REFERENCE.md](API_REFERENCE.md) - API dökümantasyonu
- [DATABASE_SYNC_PLAN.md](../database/DATABASE_SYNC_PLAN.md) - DB sync planı
