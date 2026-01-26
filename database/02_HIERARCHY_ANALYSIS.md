# Hiyerarsik Yapi Analizi

Bu dokuman, Protoolbag veritabani semasindaki hiyerarsik yapinin asagidan yukariya (bottom-up) analizini icerir.

## Hiyerarsi Genel Bakis

```
Seviye 0: PLATFORM         [En ust - SaaS Katmani]
    |
Seviye 1: TENANT           [Musteri/Firma]
    |
Seviye 2: ORGANIZATION     [Alt Organizasyon]
    |
Seviye 3: SITE             [Fiziksel Lokasyon]
    |
Seviye 4: UNIT             [Alan/Bolum - Hiyerarsik]
    |
Seviye 5: CONTROLLER       [IoT Kontrolcu]
    |        |
    |        +-- PROVIDER  [Veri Saglayici]
    |
Seviye 6: VARIABLE         [Olcum Noktasi]
    |
Seviye 7: REALTIME/ALARM   [Canli Veri/Alarm]
```

---

## Seviye 7: REALTIME ve ALARM (En Alt)

### realtimes Tablosu
Canli veri akisini temsil eder.

```sql
CREATE TABLE public.realtimes (
    id uuid NOT NULL,
    controller_id uuid,           -- Controller'a bagli
    variable_id uuid,             -- Variable'a bagli
    device_model_id uuid,         -- Device model referansi
    priority_id uuid,             -- Oncelik seviyesi
    cancelled_controller_id uuid, -- Iptal edilen controller referansi
    ...
);
```

**Baglantilar:**
- `controller_id` -> `controllers(id)`
- `variable_id` -> `variables(id)`
- `device_model_id` -> `device_models(id)`

### alarms ve alarm_histories Tablolari
Alarm yonetimi ve gecmisi.

```sql
CREATE TABLE public.alarms (
    id uuid NOT NULL,
    controller_id uuid,   -- Hangi controller'da
    variable_id uuid,     -- Hangi variable icin
    priority_id uuid,     -- Oncelik
    realtime_id uuid,     -- Canli veri referansi
    ...
);

CREATE TABLE public.alarm_histories (
    id uuid NOT NULL,
    controller_id uuid,
    variable_id uuid,
    provider_id uuid,
    site_id uuid,
    organization_id uuid,
    tenant_id uuid,       -- Dogrudan tenant referansi
    contractor_id uuid,
    ...
);
```

**Onemli:** `alarm_histories` tablosu tum hiyerarsi seviyelerini iceriyor (denormalize).
Bu, performans icin iyi ama veri tutarliligi riski tasir.

---

## Seviye 6: VARIABLE (Olcum Noktasi)

### variables Tablosu
Olcum degiskenlerini tanimlar.

```sql
CREATE TABLE public.variables (
    id uuid NOT NULL,
    device_model_id uuid,         -- Hangi cihaz modeli
    origin_priority_id uuid,      -- Orijinal oncelik
    priority_id uuid,             -- Guncel oncelik
    variable_type CHECK (...),    -- DIGITAL, ANALOG, INTEGER, ALARM, COMMAND, UNDEFINED
    data_type CHECK (...),        -- number, string, boolean
    ...
);
```

**Baglantilar:**
- `device_model_id` -> `device_models(id)` (Zorunlu degil ama onemli)

**EKSIKLIK:** Variable'in dogrudan controller'a baglantisi yok.
Baglanti `realtimes` veya `device_variables` uzerinden kuruluyor.

### Variable -> Controller Yolu
```
Variable -> device_model_id -> device_models
                                    |
                                    v
Controller -> device_model_id -> device_models
```

**Alternatif Yol (realtimes uzerinden):**
```
Variable <- variable_id <- realtimes -> controller_id -> Controller
```

---

## Seviye 5: CONTROLLER ve PROVIDER

### controllers Tablosu
IoT kontrolculerini temsil eder.

```sql
CREATE TABLE public.controllers (
    id uuid NOT NULL,
    site_id uuid NOT NULL,        -- ZORUNLU: Site'a bagli
    provider_id uuid,             -- Opsiyonel: Provider'a bagli
    unit_id uuid,                 -- Opsiyonel: Unit'e bagli
    tenant_id uuid,               -- Opsiyonel: Dogrudan tenant
    contractor_id uuid,           -- Opsiyonel: Yuklenici
    device_model_id uuid,         -- Cihaz modeli
    brand_id uuid NOT NULL,       -- ZORUNLU: Marka
    ...
);
```

**Kritik Baglantilar:**
- `site_id` -> `sites(id)` **ZORUNLU**
- `provider_id` -> `providers(id)`
- `unit_id` -> `units(id)`
- `tenant_id` -> `tenants(id)` (Gereksiz - site uzerinden ulasilabilir)

### providers Tablosu
Veri toplayici/saglayici cihazlar.

```sql
CREATE TABLE public.providers (
    id uuid NOT NULL,
    site_id uuid NOT NULL,        -- ZORUNLU: Site'a bagli
    unit_id uuid,                 -- Opsiyonel: Unit'e bagli
    tenant_id uuid,               -- Opsiyonel: Dogrudan tenant
    brand_id uuid NOT NULL,       -- ZORUNLU: Marka
    ...
);
```

**Controller-Provider Iliskisi:**
- Controller, provider_id ile bir provider'a baglanabilir
- Birden fazla controller ayni provider'i kullanabilir (1:N)

---

## Seviye 4: UNIT (Alan/Bolum)

### units Tablosu
Fiziksel alanlari/bolumleri temsil eder. **Self-referencing** ile hiyerarsik.

```sql
CREATE TABLE public.units (
    id uuid NOT NULL,
    site_id uuid,                 -- Site'a bagli
    organization_id uuid,         -- Organization'a bagli
    tenant_id uuid,               -- Tenant'a bagli
    parent_unit_id uuid,          -- UST UNIT (Self-reference)
    contractor_id uuid,           -- Yuklenici
    sub_contractor_id uuid,       -- Alt yuklenici
    unit_type_id uuid,            -- Unit tipi
    is_main_area boolean,         -- Ana alan mi?
    ...
);
```

**Hiyerarsik Yapi:**
```
Site
  |-- Unit (Main Area) [parent_unit_id = NULL, is_main_area = true]
       |-- Unit (Kat 1) [parent_unit_id = Main Area]
       |    |-- Unit (Ofis 101) [parent_unit_id = Kat 1]
       |    |-- Unit (Ofis 102) [parent_unit_id = Kat 1]
       |
       |-- Unit (Kat 2) [parent_unit_id = Main Area]
            |-- Unit (Toplanti Odasi) [parent_unit_id = Kat 2]
```

### unit_types Tablosu
Unit kategorilerini tanimlar.

```sql
category CHECK (...) -- MAIN, FLOOR, SECTION, ROOM, ZONE, PRODUCTION, STORAGE, SERVICE, COMMON, TECHNICAL, OUTDOOR, CUSTOM
```

---

## Seviye 3: SITE (Fiziksel Lokasyon)

### sites Tablosu
Fiziksel lokasyonlari (bina, tesis, vb.) temsil eder.

```sql
CREATE TABLE public.sites (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,  -- ZORUNLU: Organization'a bagli
    tenant_id uuid,                 -- Opsiyonel: Dogrudan tenant
    marker_id uuid NOT NULL,        -- ZORUNLU: Harita isaretcisi
    site_group_id uuid,             -- Site grubu
    site_type_id uuid,              -- Site tipi
    has_main_unit boolean,          -- Ana unit var mi?
    -- Calisma saatleri
    monday_start_time, monday_end_time, ...
    -- Fiziksel ozellikler
    gross_area_sqm, net_area_sqm, floor_count, year_built
    ...
);
```

**Kritik Baglantilar:**
- `organization_id` -> `organizations(id)` **ZORUNLU**
- `tenant_id` -> `tenants(id)` (Gereksiz - organization uzerinden ulasilabilir)

---

## Seviye 2: ORGANIZATION (Alt Organizasyon)

### organizations Tablosu
Tenant altindaki alt organizasyonlari temsil eder.

```sql
CREATE TABLE public.organizations (
    id uuid NOT NULL,
    tenant_id uuid NOT NULL,      -- ZORUNLU: Tenant'a bagli
    financial_id uuid,            -- Finansal bilgiler
    marker_id uuid,               -- Harita isaretcisi
    -- Konum bilgileri
    address, city, country, latitude, longitude, ...
);
```

**Kritik Baglantilar:**
- `tenant_id` -> `tenants(id)` **ZORUNLU**

### contractor_organizations Tablosu
Organization-Contractor iliski tablosu (N:N).

```sql
CREATE TABLE public.contractor_organizations (
    contractor_id uuid NOT NULL,
    organizations_id uuid NOT NULL,
    PRIMARY KEY (contractor_id, organizations_id)
);
```

---

## Seviye 1: TENANT (Musteri/Firma)

### tenants Tablosu
En ust musteri/firma seviyesi.

```sql
CREATE TABLE public.tenants (
    id uuid NOT NULL,
    code character varying,
    name character varying,
    description character varying,
    client character varying,
    time_zone character varying,
    -- Konum bilgileri
    address, city, country, latitude, longitude, ...
);
```

### Tenant Iliskili Tablolar

| Tablo | Iliski | Aciklama |
|-------|--------|----------|
| `tenant_subscriptions` | 1:N | Abonelik kayitlari |
| `tenant_billing_info` | 1:1 | Fatura bilgileri |
| `tenant_credits` | 1:1 | Kredi bakiyesi |
| `tenant_quotas` | 1:N | Kota limitleri |
| `tenant_features` | 1:N | Aktif ozellikler |
| `tenant_payment_methods` | 1:N | Odeme yontemleri |
| `tenant_invoices` | 1:N | Faturalar |
| `tenant_contractors` | N:N | Yuklenici iliskileri |
| `tenant_teams` | N:N | Takim iliskileri |
| `tenant_usage_metrics` | 1:N | Kullanim metrikleri |

---

## Seviye 0: PLATFORM (SaaS Katmani)

### platforms Tablosu
Farkli uygulamalari/modulleri temsil eder (PMS, EMS, CMMS, vb.).

```sql
CREATE TABLE public.platforms (
    id uuid NOT NULL,
    code character varying,
    name character varying,
    display_name character varying,
    slug character varying,
    platform_type CHECK (...),    -- application, module, service, integration, framework
    status CHECK (...),           -- active, deprecated, maintenance, beta, alpha, archived
    is_core boolean,              -- Cekirdek platform mi?
    ...
);
```

### platform_tenants Tablosu
Platform-Tenant iliskisini yonetir (N:N).

```sql
CREATE TABLE public.platform_tenants (
    id uuid NOT NULL,
    platform_id uuid NOT NULL,    -- Hangi platform
    tenant_id uuid NOT NULL,      -- Hangi tenant
    is_trial boolean,             -- Deneme surumu mu?
    subscribed_at timestamp,      -- Abone olma tarihi
    trial_starts_at timestamp,    -- Deneme baslangici
    trial_ends_at timestamp,      -- Deneme bitisi
    expires_at timestamp,         -- Son kullanim tarihi
    auto_upgrade boolean,         -- Otomatik yukseltme
    custom_limits jsonb,          -- Ozel limitler
    ...
);
```

---

## Asagidan Yukariya Yol Haritasi

Bir Variable'dan Platform'a ulasma yolu:

```
VARIABLE
    |
    +-- [device_model_id] --> device_models
    |
    +-- [realtimes.variable_id] --> REALTIMES
                                        |
                                        +-- [controller_id] --> CONTROLLER
                                                                    |
                                                                    +-- [site_id] --> SITE
                                                                                        |
                                                                                        +-- [organization_id] --> ORGANIZATION
                                                                                                                    |
                                                                                                                    +-- [tenant_id] --> TENANT
                                                                                                                                            |
                                                                                                                                            +-- [platform_tenants.tenant_id] --> PLATFORM
```

## Kritik Notlar

1. **Veri Yolu Tutarsizligi:** Bazi tablolarda hem ust tablo referansi hem de atlanmis seviye referanslari var (ornegin site'da hem organization_id hem tenant_id). Bu:
   - Pro: Sorgu performansi
   - Con: Veri tutarliligi riski

2. **Zorunlu Alanlar:**
   - `controllers.site_id` - ZORUNLU
   - `sites.organization_id` - ZORUNLU
   - `organizations.tenant_id` - ZORUNLU

3. **Opsiyonel ama Kritik:**
   - `controllers.tenant_id` - Opsiyonel ama olmali
   - `variables` -> `controllers` dogrudan baglanti YOK

---

## Is Yonetimi Katmani (Workflow/Business)

Ana hiyerarsiye ek olarak, is yonetimi tablolari da hiyerarsi ile iliskilidir:

### Business Interactions (Tenant Seviyesi)

```
TENANT
    |
    +-- business_interactions (tenant_id)
            |
            +-- business_flows
            |       +-- business_steps
            |
            +-- workflow_versions
            +-- workflow_executions
```

**Baglanti:** Sadece `tenant_id` ile Tenant'a baglidir. Organization/Site/Unit baglantisi yoktur.

### Work Requests (Organization/Unit Seviyesi)

```
work_requests
    |
    +-- tenant_id --> TENANT
    +-- organization_id --> ORGANIZATION
    +-- unit_id --> UNIT
    +-- business_interaction_id --> business_interactions
```

**Alt Tipler:**
- `projects` (work_request_id) -> organization_id var, site_id/unit_id YOK
- `tasks` (work_request_id) -> organization_id, unit_id var
- `workflows` (work_request_id) -> sadece tenant_id, business_interaction_id

### Workflow-Unit Iliskisi

```
workflow_teams
    |
    +-- workflow_work_request_id --> workflows
    +-- team_id --> teams
    +-- unit_id --> UNIT  <-- Onemli: Unit bazli atama
```

### Is Yonetimi Yol Haritasi

```
WORK_REQUEST
    |
    +-- [unit_id] --> UNIT
    |                   |
    |                   +-- [site_id] --> SITE
    |                                       |
    |                                       +-- [organization_id] --> ORGANIZATION
    |
    +-- [organization_id] --> ORGANIZATION (dogrudan)
    |                              |
    |                              +-- [tenant_id] --> TENANT
    |
    +-- [business_interaction_id] --> BUSINESS_INTERACTION
                                            |
                                            +-- [tenant_id] --> TENANT
```

### Eksik Iliskiler

| Tablo | Eksik | Etki |
|-------|-------|------|
| `work_requests` | `site_id` | Site bazli filtreleme imkansiz |
| `workflows` | `organization_id`, `unit_id` | Sadece tenant seviyesinde |
| `projects` | `site_id`, `unit_id` | Sadece organization seviyesinde |
| `business_interactions` | `organization_id` | Sablonlar tenant genelinde |

Detayli analiz icin: [09_WORKFLOW_BUSINESS_ANALYSIS.md](./09_WORKFLOW_BUSINESS_ANALYSIS.md)
