# Veritabanı Senkronizasyon Planı

## Genel Bakış

Bu döküman, Flutter mobil uygulaması ile Supabase veritabanı arasındaki senkronizasyon durumunu ve yapılması gereken işleri tanımlar.

**Son Güncelleme:** 2026-01-26
**Versiyon:** 1.0.0

---

## 1. Mevcut Durum Özeti

### Veritabanı
| Metrik | Değer |
|--------|-------|
| Toplam Tablo | 280 |
| Core Hiyerarşi Tabloları | 8 |
| Oluşturulan Migration | 4 |
| RLS Politikaları | 9+ |
| Performance Indexler | 30+ |

### Flutter Modeller
| Metrik | Değer |
|--------|-------|
| Core Modeller | 8 (Tenant, Organization, Site, Unit, Activity, Notification, Invitation, Permission) |
| Core Servisler | 15+ |
| UI Widget'ları | 30+ |

---

## 2. Migration Durumu

### ✅ Tamamlanan Migration'lar

| Migration | Dosya | Durum |
|-----------|-------|-------|
| Tenant Users | `001_tenant_users.sql` | ✅ Mevcut |
| Invitations & Roles | `002_invitations_and_roles.sql` | ✅ Mevcut |
| RLS Policies | `001_rls_policies.sql` | ✅ Yeni Oluşturuldu |
| Schema Improvements | `002_schema_improvements.sql` | ✅ Yeni Oluşturuldu |

### 🔄 Uygulanması Gereken Migration'lar

Aşağıdaki SQL dosyaları Supabase'de çalıştırılmalıdır:

```
database/migrations/
├── 001_rls_policies.sql      → RLS aktifleştirme ve politikalar
└── 002_schema_improvements.sql → Schema iyileştirmeleri
```

---

## 3. Schema Değişiklikleri - Detaylı Plan

### 3.1 Kritik Değişiklikler (Hemen Yapılmalı)

#### A. Tenant Status Alanı
```sql
ALTER TABLE tenants
ADD COLUMN IF NOT EXISTS status varchar(20) DEFAULT 'active'
CHECK (status IN ('active', 'suspended', 'pending', 'trial', 'cancelled', 'deleted'));
```
**Flutter Model:** `Tenant.status` alanı eklenmeli

#### B. Unit Status Alanı
```sql
ALTER TABLE units
ADD COLUMN IF NOT EXISTS status varchar(20) DEFAULT 'operational'
CHECK (status IN ('operational', 'maintenance', 'closed', 'renovation', 'inactive'));
```
**Flutter Model:** `Unit.status` alanı eklenmeli

#### C. Variable-Controller İlişkisi
```sql
ALTER TABLE variables
ADD COLUMN IF NOT EXISTS controller_id uuid REFERENCES controllers(id);
```
**Flutter Model:** Yeni model gerekli (Faz 3'te)

### 3.2 Yüksek Öncelikli Değişiklikler

#### A. Profile Organization İlişkisi
```sql
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES organizations(id),
ADD COLUMN IF NOT EXISTS default_site_id uuid REFERENCES sites(id);
```
**Flutter Model:** `UserProfile` modeli güncellenmeli

#### B. Work Request Site İlişkisi
```sql
ALTER TABLE work_requests
ADD COLUMN IF NOT EXISTS site_id uuid REFERENCES sites(id);
```
**Flutter Model:** Faz 3'te WorkRequest modeli oluşturulacak

### 3.3 RLS Politikaları (Güvenlik)

Aşağıdaki tablolara RLS politikaları uygulanmalı:

| Tablo | Politika | Durum |
|-------|----------|-------|
| tenants | tenant_isolation | ✅ Hazır |
| organizations | organization_tenant_isolation | ✅ Hazır |
| sites | site_tenant_isolation | ✅ Hazır |
| units | unit_tenant_isolation | ✅ Hazır |
| controllers | controller_tenant_isolation | ✅ Hazır |
| profiles | profile_self_access | ✅ Hazır |
| notifications | notification_owner_access | ✅ Hazır |
| activities | activity_tenant_isolation | ✅ Hazır |
| invitations | invitation_tenant_isolation | ✅ Hazır |

### 3.4 Performance İndeksleri

30+ indeks oluşturulmalı:
- Hiyerarşi traversal indeksleri
- Zaman bazlı sorgu indeksleri
- Composite indeksler

---

## 4. Flutter Model Güncellemeleri

### 4.1 Mevcut Modellerde Yapılacak Değişiklikler

#### Tenant Model (`tenant_model.dart`)
```dart
// Eklenecek alanlar:
final TenantStatus? status;
final DateTime? suspendedAt;
final String? suspendedReason;
final DateTime? deletedAt;

enum TenantStatus {
  active, suspended, pending, trial, cancelled, deleted
}
```

#### Unit Model (`unit_model.dart`)
```dart
// Eklenecek alanlar:
final UnitStatus? status;

enum UnitStatus {
  operational, maintenance, closed, renovation, inactive
}
```

#### Organization Model (`organization_model.dart`)
```dart
// Eklenecek alanlar:
final String? createdBy;
final String? updatedBy;
```

#### Site Model (`site_model.dart`)
```dart
// Eklenecek alanlar:
final String? createdBy;
final String? updatedBy;
```

### 4.2 Yeni Modeller (Faz 3)

| Model | Tablo | Öncelik |
|-------|-------|---------|
| Controller | controllers | Yüksek |
| Provider | providers | Yüksek |
| Variable | variables | Yüksek |
| WorkRequest | work_requests | Orta |
| Workflow | workflows | Orta |
| CalendarEvent | calendar_events | Orta |
| InventoryItem | inventory_items | Düşük |

---

## 5. Senkronizasyon Adımları

### Adım 1: Veritabanı Migration'larını Çalıştır
```bash
# Supabase SQL Editor'da sırasıyla çalıştırın:
1. database/migrations/001_rls_policies.sql
2. database/migrations/002_schema_improvements.sql
```

### Adım 2: Flutter Modellerini Güncelle
1. Tenant status alanı ekle
2. Unit status alanı ekle
3. Organization/Site audit alanları ekle

### Adım 3: Service'leri Güncelle
1. TenantService - status filtreleme
2. UnitService - status filtreleme
3. API çağrılarında yeni alanları ekle

### Adım 4: Test Et
1. RLS politikalarını test et (farklı tenant'lar)
2. Yeni alanların çalıştığını doğrula
3. İndeks performansını kontrol et

---

## 6. Doğrulama Kontrol Listesi

### Veritabanı Tarafı
- [ ] RLS politikaları aktif
- [ ] Tenant status alanı mevcut
- [ ] Unit status alanı mevcut
- [ ] Profile organization_id mevcut
- [ ] İndeksler oluşturuldu
- [ ] Trigger'lar aktif
- [ ] View'lar oluşturuldu

### Flutter Tarafı
- [ ] Tenant model güncellendi
- [ ] Unit model güncellendi
- [ ] Organization model güncellendi
- [ ] Site model güncellendi
- [ ] Service'ler güncellendi
- [ ] Testler geçiyor

---

## 7. Bilinen Eksiklikler (Gelecek Fazlar)

### Faz 3'te Ele Alınacak
| Eksiklik | Açıklama |
|----------|----------|
| Controller/Provider Modelleri | IoT katmanı modelleri |
| Workflow Sistemi | İş akışı yönetimi |
| Calendar Modülü | Takvim ve etkinlikler |
| Inventory Modülü | Envanter yönetimi |

### Faz 4'te Ele Alınacak
| Eksiklik | Açıklama |
|----------|----------|
| Energy/KPI Modülleri | Enerji ve performans takibi |
| Production Modülü | Üretim yönetimi |
| Retail Modülü | Mağaza yönetimi |
| Financial Modülü | Finansal işlemler |

---

## 8. Notlar

1. **RLS Önemli:** Migration'ları çalıştırmadan önce test ortamında deneyin
2. **Backup:** Production'da çalıştırmadan önce backup alın
3. **Sıra:** Migration'lar sırayla çalıştırılmalı
4. **Rollback:** Her migration için rollback planı hazırlayın

---

## Ekler

- [001_rls_policies.sql](migrations/001_rls_policies.sql)
- [002_schema_improvements.sql](migrations/002_schema_improvements.sql)
- [07_GAPS_AND_IMPROVEMENTS.md](07_GAPS_AND_IMPROVEMENTS.md)
