# Executive Summary - Database Schema Analysis

## Genel Bakis

Protoolbag veritabani semasi, coklu platform ve coklu tenant destegi saglayan, IoT/SCADA tabanli bir bina/enerji yonetim sisteminin veritabani yapisini tanimlar.

## Temel Istatistikler

| Metrik | Deger |
|--------|-------|
| Toplam Tablo | 280 |
| Platform Tablolari | 14 |
| Tenant Tablolari | 18 |
| Core Hiyerarsi Tablolari | 12 |
| Alarm/Monitoring Tablolari | 15+ |
| Workflow/Business Tablolari | 20+ |
| PMP (Project Management) Tablolari | 10 |
| Inventory/Asset Tablolari | 15+ |

## Mimari Yaklasim

### Multi-Platform SaaS Mimarisi

```
+------------------+
|    PLATFORMS     |  <- PMS, EMS, CMMS, vb. uygulamalar
+------------------+
         |
         | platform_tenants (N:N)
         v
+------------------+
|     TENANTS      |  <- Musteriler/Firmalar
+------------------+
         |
         v
+------------------+
|  ORGANIZATIONS   |  <- Alt organizasyonlar
+------------------+
         |
         v
+------------------+
|      SITES       |  <- Fiziksel lokasyonlar
+------------------+
         |
         v
+------------------+
|      UNITS       |  <- Alanlar/Bolumler
+------------------+
         |
         v
+------------------------------------------+
|  CONTROLLERS  |  PROVIDERS  |  DEVICES   |
+------------------------------------------+
         |
         v
+------------------+
|    VARIABLES     |  <- Olcum noktalari
+------------------+
```

## Ana Hiyerarsi Tablolari

| Tablo | Ust Tablo | Iliski | Aciklama |
|-------|-----------|--------|----------|
| `platforms` | - | - | SaaS platformlari (PMS, EMS, vb.) |
| `platform_tenants` | platforms, tenants | N:N | Platform-Tenant iliskisi |
| `tenants` | - | - | Musteriler/Firmalar |
| `organizations` | tenants | 1:N | Alt organizasyonlar |
| `sites` | organizations | 1:N | Fiziksel lokasyonlar |
| `units` | sites, units | 1:N, Self-ref | Alanlar (hiyerarsik) |
| `controllers` | sites, providers | 1:N | IoT kontrolculer |
| `providers` | sites | 1:N | Veri saglayicilar |
| `variables` | device_models | 1:N | Olcum degiskenleri |

## Onemli Bulgular

### 1. Guclu Yonler

- **Kapsamli Multi-Tenant Altyapisi:** Tenant izolasyonu, abonelik, faturalama, kota yonetimi
- **Platform Bagimsizligi:** Farkli projeler (PMS, EMS, CMMS) ayni tenant'i kullanabilir
- **Esnek Hiyerarsi:** Units tablosu self-referencing ile sinirsiz derinlik saglar
- **Zengin Subscription Modeli:** Trial, active, suspended durumlari, tarihce takibi
- **Odeme Entegrasyonu:** iyzico entegrasyonu, kredi sistemi, fatura yonetimi

### 2. Dikkat Gerektiren Noktalar

- **Tenant-Controller Iliskisi:** `controllers` tablosunda `tenant_id` opsiyonel (olmamali)
- **Veri Yolinun Tutarliligi:** Site uzerinden zaten tenant'a ulasilabilirken ayri tenant_id
- **Eksik Constraintler:** Bazi tablolarda foreign key eksik
- **Duplicate Yapilar:** `pmp_*` tablolari ana tablolarla cakisiyor olabilir

### 3. Iyilestirme Alanlari

- Tenant izolasyonu icin Row Level Security (RLS) politikalari
- Hiyerarsi traversal icin recursive CTE view'lari
- Performans icin composite indexler
- Audit logging standardizasyonu

## Sonraki Adimlar

1. Detayli hiyerarsi analizi -> [02_HIERARCHY_ANALYSIS.md](./02_HIERARCHY_ANALYSIS.md)
2. Platform katmani incelemesi -> [03_PLATFORM_LAYER.md](./03_PLATFORM_LAYER.md)
3. Eksiklik ve iyilestirme plani -> [07_GAPS_AND_IMPROVEMENTS.md](./07_GAPS_AND_IMPROVEMENTS.md)
