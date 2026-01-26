# Protoolbag Database Schema Analysis

Bu klasor, Protoolbag projelerinin veritabani semasinin analizini ve mimarisi hakkindaki dokumantasyonu icerir.

## Analiz Dokumanlari

| Dosya | Aciklama |
|-------|----------|
| [01_EXECUTIVE_SUMMARY.md](./01_EXECUTIVE_SUMMARY.md) | Yonetici ozeti ve genel bakis |
| [02_HIERARCHY_ANALYSIS.md](./02_HIERARCHY_ANALYSIS.md) | Hiyerarsik yapi analizi (Platform -> Tenant -> ... -> Variable) |
| [03_PLATFORM_LAYER.md](./03_PLATFORM_LAYER.md) | Platform katmani detayli analizi |
| [04_TENANT_LAYER.md](./04_TENANT_LAYER.md) | Tenant katmani ve iliskili tablolar |
| [05_ORGANIZATION_SITE_UNIT.md](./05_ORGANIZATION_SITE_UNIT.md) | Organization, Site, Unit analizi |
| [06_CONTROLLER_PROVIDER_VARIABLE.md](./06_CONTROLLER_PROVIDER_VARIABLE.md) | Controller, Provider, Variable analizi |
| [07_GAPS_AND_IMPROVEMENTS.md](./07_GAPS_AND_IMPROVEMENTS.md) | Eksiklikler ve iyilestirme onerileri |
| [08_ENTITY_RELATIONSHIP_DIAGRAM.md](./08_ENTITY_RELATIONSHIP_DIAGRAM.md) | Entity-Relationship diyagramlari |
| [09_WORKFLOW_BUSINESS_ANALYSIS.md](./09_WORKFLOW_BUSINESS_ANALYSIS.md) | Workflow, Business Interaction, Work Request analizi |
| [10_USER_PROFILE_MANAGEMENT.md](./10_USER_PROFILE_MANAGEMENT.md) | Kullanici ve Profil Yonetimi, Staffs, Teams analizi |
| [11_SUPPLEMENTARY_TABLES.md](./11_SUPPLEMENTARY_TABLES.md) | Envanter, Alarm, Enerji, Takvim, Perakende, Finansal ve diger tablolar |

## Schema Ozeti

- **Toplam Tablo Sayisi:** 280
- **Toplam Satir:** 5717
- **Ana Hiyerarsi:** Platform -> Tenant -> Organization -> Site -> Unit -> Controller/Provider -> Variable

## Hizli Bakis - Hiyerarsik Yapi

```
PLATFORM (SaaS Katmani)
    |
    +-- platform_tenants (N:N iliskisi)
    |
    v
TENANT (Musteri/Firma)
    |
    +-- tenant_subscriptions (Abonelik yonetimi)
    +-- tenant_billing_info (Faturalama)
    +-- tenant_credits (Kredi sistemi)
    +-- tenant_quotas (Kota yonetimi)
    |
    +-- business_interactions (1:N) -- Is sureci sablonlari
    |       |
    |       +-- business_flows -> business_steps
    |       +-- workflow_versions
    |       +-- workflow_executions
    |
    +-- organizations (1:N)
    |       |
    |       +-- work_requests (organization_id)
    |       +-- projects (organization_id)
    |       +-- tasks (organization_id)
    |       |
    |       +-- sites (1:N)
    |               |
    |               +-- units (1:N, kendi icinde hiyerarsik)
    |                       |
    |                       +-- work_requests (unit_id)
    |                       +-- tasks (unit_id)
    |                       +-- workflow_teams (unit_id)
    |                       |
    |                       +-- controllers (1:N)
    |                       |       |
    |                       |       +-- variables (device_model uzerinden)
    |                       |       +-- realtimes (1:N)
    |                       |       +-- alarms (1:N)
    |                       |
    |                       +-- providers (1:N)
    |                               |
    |                               +-- controllers (1:N)
    |
    +-- contractors (N:N via tenant_contractors)
    |       +-- staffs (contractor_id)
    |       +-- realm_users (contractor)
    |
    +-- teams (N:N via tenant_teams)
    |       +-- team_staffs -> staffs
    |
    +-- profiles (tenant_id) -- Kullanici Profilleri
    |       +-- realm_users (profile) -- Auth entegrasyonu
    |       +-- menu_ids, sub_menu_ids, page_ids -- Erisim yonetimi
    |       +-- notifications (profile_id)
    |
    +-- staffs (tenant_id, organization_id) -- Calisanlar
    |       +-- profile_id -> profiles
    |
    +-- pmp_organizations (Proje Yonetimi Modulu)
    |       +-- pmp_projects -> pmp_sprints
    |       +-- pmp_work_requests -> pmp_tasks
    |
    +-- TAMAMLAYICI MODULLER ----------------+
    |                                        |
    +-- inventories (tenant_id, unit_id)     |
    |       +-- inventory_items -> items     |
    |       +-- inventory_item_movements     |
    |                                        |
    +-- calendar_events (tenant_id)          |
    |       +-- event_attendees -> staffs    |
    |       +-- todo_items                   |
    |                                        |
    +-- retail_chains (tenant)               |
    |       +-- stores                       |
    |                                        |
    +-- invoices (tenant_id, unit_id)        |
    |       +-- invoice_details              |
    |                                        |
    +-- productions (tenant)                 |
    |       +-- production_orders            |
    |                                        |
    +-- energy_consumptions (tenant_id)      |
    |       +-- carbon_emissions             |
    |       +-- emission_reports/targets     |
    |                                        |
    +-- alarm_histories (denormalized)       |
            +-- alarm_patterns/predictions   |
            +-- alarm_statistics             |
```

## Son Guncelleme

**Tarih:** 2026-01-24
**Versiyon:** 1.0.0
