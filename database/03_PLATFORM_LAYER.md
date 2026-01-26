# Platform Katmani Detayli Analizi

## Genel Bakis

Platform katmani, Protoolbag'in SaaS mimarisinin en ust seviyesidir. Farkli uygulamalar (PMS, EMS, CMMS, vb.) bu katmanda tanimlanir ve tenant'lara atanir.

## Platform Tablolari

### 1. platforms (Ana Tablo)

**Amac:** Farkli uygulama/modulleri tanimlar.

```sql
CREATE TABLE public.platforms (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    active boolean,
    code character varying,
    name character varying,
    display_name character varying,
    slug character varying,
    icon_url text,
    color character varying,
    status CHECK ('active', 'deprecated', 'maintenance', 'beta', 'alpha', 'archived'),
    platform_type CHECK ('application', 'module', 'service', 'integration', 'framework'),
    is_core boolean DEFAULT false,
    display_order integer DEFAULT 0,
    metadata jsonb DEFAULT '{}'::jsonb,
    ...
);
```

**Platform Tipleri:**
| Tip | Aciklama | Ornek |
|-----|----------|-------|
| `application` | Bagimsiz uygulama | PMS, EMS, CMMS |
| `module` | Uygulama modulu | Raporlama Modulu |
| `service` | Arka plan servisi | Bildirim Servisi |
| `integration` | Dis entegrasyon | SAP Entegrasyonu |
| `framework` | Temel cerceve | Core Framework |

**Platform Durumlari:**
| Durum | Aciklama |
|-------|----------|
| `active` | Aktif kullanımda |
| `beta` | Beta test asamasinda |
| `alpha` | Alpha test asamasinda |
| `maintenance` | Bakim modunda |
| `deprecated` | Kullanim disi (eski) |
| `archived` | Arsivlenmis |

---

### 2. platform_tenants (Platform-Tenant Iliskisi)

**Amac:** Hangi tenant'in hangi platformu kullandigini yonetir.

```sql
CREATE TABLE public.platform_tenants (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    platform_id uuid NOT NULL,          -- REFERENCES platforms(id)
    tenant_id uuid NOT NULL,            -- REFERENCES tenants(id)
    active boolean DEFAULT true,
    is_trial boolean DEFAULT false,
    subscribed_at timestamp,
    trial_starts_at timestamp,
    trial_ends_at timestamp,
    expires_at timestamp,
    locked_version_id uuid,             -- REFERENCES platform_versions(id)
    auto_upgrade boolean DEFAULT true,
    custom_limits jsonb,
    activated_by uuid,
    deactivated_at timestamp,
    deactivated_by uuid,
    deactivation_reason text,
    ...
);
```

**Ozellikler:**
- **Trial Yonetimi:** `is_trial`, `trial_starts_at`, `trial_ends_at` ile deneme sureci takibi
- **Versiyon Kilitleme:** `locked_version_id` ile belirli versiyonda sabitleyebilme
- **Otomatik Guncelleme:** `auto_upgrade` ile otomatik versiyon yukseltme
- **Ozel Limitler:** `custom_limits` (jsonb) ile tenant'a ozel limitler

---

### 3. platform_versions (Platform Versiyonlari)

**Amac:** Platform surumlerini yonetir.

```sql
CREATE TABLE public.platform_versions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    platform_id uuid,                    -- REFERENCES platforms(id)
    version_number character varying UNIQUE CHECK (~ '^\d+\.\d+\.\d+$'),
    version_name character varying,
    release_date timestamp NOT NULL,
    release_notes text,
    changelog text,
    active boolean DEFAULT true,
    is_current boolean DEFAULT false,
    ...
);
```

**Versiyon Formati:** Semantic Versioning (X.Y.Z)

---

### 4. platform_features (Platform Ozellikleri)

**Amac:** Platform bazli ozellikleri tanimlar.

```sql
CREATE TABLE public.platform_features (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    platform_id uuid NOT NULL,
    feature_key character varying NOT NULL,
    feature_name character varying NOT NULL,
    description text,
    is_default_enabled boolean DEFAULT false,
    is_premium boolean DEFAULT false,
    category character varying,
    ...
);
```

**Feature Flag Sistemi:**
- `is_default_enabled`: Varsayilan olarak acik mi?
- `is_premium`: Premium ozellik mi?
- `tenant_features` tablosu ile tenant bazli override

---

### 5. platform_modules (Platform Modulleri)

**Amac:** Platform icindeki modulleri tanimlar.

```sql
CREATE TABLE public.platform_modules (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    platform_id uuid NOT NULL,
    module_code character varying NOT NULL,
    module_name character varying NOT NULL,
    description text,
    is_core boolean DEFAULT false,
    dependencies ARRAY,                  -- Bagli modullerin ID'leri
    ...
);
```

---

### 6. platform_configurations (Platform Konfigurasyonlari)

**Amac:** Platform geneli konfigurasyonlari saklar.

```sql
CREATE TABLE public.platform_configurations (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    config_key character varying NOT NULL UNIQUE,
    config_value jsonb NOT NULL,
    description text,
    is_encrypted boolean DEFAULT false,
    platform_id uuid,                    -- REFERENCES platforms(id)
    ...
);
```

**Guvenlik:** `is_encrypted` ile hassas verilerin sifrelenmesi

---

### 7. platform_budgets (Platform Butceleri)

**Amac:** Platform bazli butce yonetimi.

```sql
CREATE TABLE public.platform_budgets (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    platform_id uuid NOT NULL,
    budget_year integer NOT NULL,
    budget_quarter integer CHECK (1-4),
    budget_month integer CHECK (1-12),
    development_budget numeric,
    infrastructure_budget numeric,
    marketing_budget numeric,
    support_budget numeric,
    other_budget numeric,
    total_budget numeric,
    -- Harcamalar
    development_spent numeric,
    infrastructure_spent numeric,
    marketing_spent numeric,
    support_spent numeric,
    other_spent numeric,
    total_spent numeric,
    -- Fark analizi
    variance numeric,
    variance_percentage numeric,
    currency character varying DEFAULT 'TRY',
    status CHECK ('draft', 'pending', 'approved', 'active', 'closed', 'cancelled'),
    approved_at timestamp,
    approved_by uuid,
    ...
);
```

---

### 8. platform_change_logs (Degisiklik Gecmisi)

**Amac:** Platform degisikliklerini takip eder.

```sql
CREATE TABLE public.platform_change_logs (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    platform_id uuid NOT NULL,
    platform_version_id uuid,
    change_type CHECK ('feature', 'bugfix', 'improvement', 'security', 'performance', 'deprecation', 'breaking', 'documentation'),
    change_category character varying,
    title character varying NOT NULL,
    description text,
    breaking_change boolean DEFAULT false,
    migration_required boolean DEFAULT false,
    migration_notes text,
    affected_modules ARRAY,
    affected_features ARRAY,
    commit_hash character varying,
    pull_request_url text,
    issue_url text,
    author character varying,
    published_at timestamp,
    ...
);
```

---

### 9. platform_dependencies (Platform Bagimliliklari)

**Amac:** Platformlar arasi bagimliliklari yonetir.

```sql
CREATE TABLE public.platform_dependencies (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    platform_id uuid NOT NULL,
    depends_on_platform_id uuid NOT NULL,
    dependency_type character varying,
    min_version character varying,
    max_version character varying,
    is_optional boolean DEFAULT false,
    ...
);
```

---

### 10. platform_costs (Platform Maliyetleri)

**Amac:** Platform operasyonel maliyetlerini takip eder.

```sql
CREATE TABLE public.platform_costs (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    platform_id uuid NOT NULL,
    cost_date date NOT NULL,
    cost_category character varying NOT NULL,
    cost_amount numeric NOT NULL,
    currency character varying DEFAULT 'TRY',
    description text,
    ...
);
```

---

### 11. platform_metrics (Platform Metrikleri)

**Amac:** Platform performans metriklerini saklar.

```sql
CREATE TABLE public.platform_metrics (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    platform_id uuid NOT NULL,
    metric_key character varying NOT NULL,
    metric_value numeric NOT NULL,
    metric_unit character varying,
    measured_at timestamp,
    ...
);
```

---

### 12. platform_licenses (Platform Lisanslari)

**Amac:** Platform lisans yonetimi.

```sql
CREATE TABLE public.platform_licenses (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    platform_id uuid NOT NULL,
    license_key character varying NOT NULL,
    license_type character varying NOT NULL,
    valid_from timestamp,
    valid_until timestamp,
    max_users integer,
    max_tenants integer,
    features jsonb,
    ...
);
```

---

### 13. platform_files (Platform Dosyalari)

**Amac:** Platform ile iliskili dosyalari yonetir.

```sql
CREATE TABLE public.platform_files (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    platform_id uuid NOT NULL,
    file_type character varying NOT NULL,
    file_name character varying NOT NULL,
    file_path text NOT NULL,
    file_size bigint,
    mime_type character varying,
    version character varying,
    ...
);
```

---

## Platform Tablo Iliskileri

```
                    +------------------+
                    |    platforms     |
                    +------------------+
                           |
       +-------------------+-------------------+
       |                   |                   |
       v                   v                   v
+----------------+  +----------------+  +----------------+
| platform_      |  | platform_      |  | platform_      |
| tenants        |  | versions       |  | features       |
+----------------+  +----------------+  +----------------+
       |                   |
       v                   v
+----------------+  +----------------+
|    tenants     |  | platform_      |
+----------------+  | change_logs    |
                    +----------------+

Diger Iliskiler:
- platform_modules -> platforms
- platform_configurations -> platforms
- platform_budgets -> platforms
- platform_dependencies -> platforms (self-ref)
- platform_costs -> platforms
- platform_metrics -> platforms
- platform_licenses -> platforms
- platform_files -> platforms
```

---

## Eksiklikler ve Oneriler

### 1. Platform-Modul Iliskisi
**Eksik:** `platform_modules` tablosu var ama `platform_features` ile iliskisi net degil.
**Oneri:** `module_id` foreign key eklenebilir.

### 2. Versiyon Uyumlulugu
**Eksik:** `platform_versions` ile `platform_features` arasinda iliski yok.
**Oneri:** Feature versiyonlama eklenebilir (hangi feature hangi versiyonla geldi).

### 3. Kullanim Takibi
**Eksik:** Platform kullanim istatistikleri tenant bazli detayda yok.
**Oneri:** `platform_tenant_usage` tablosu eklenebilir.

### 4. Rol Bazli Erisim
**Eksik:** Platform seviyesinde rol/yetki yonetimi yok.
**Oneri:** `platform_roles` ve `platform_permissions` tablolari eklenebilir.
