# Tenant Katmani Detayli Analizi

## Genel Bakis

Tenant katmani, musteri/firma seviyesini temsil eder. Her tenant, kendi organizasyonlari, siteleri, kullanicilari ve verilerini izole bir sekilde yonetir.

## Ana Tablo: tenants

```sql
CREATE TABLE public.tenants (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    active boolean,
    created_by uuid,
    created_at timestamp with time zone,
    row_id integer NOT NULL DEFAULT nextval('tenant_row_id_seq'::regclass),
    updated_by uuid,
    updated_at timestamp with time zone,
    code character varying,
    description character varying,
    name character varying,
    client character varying,
    address character varying,
    city character varying,
    country character varying,
    latitude double precision,
    longitude double precision,
    town character varying,
    zoom integer,
    time_zone character varying,
);
```

**Not:** `tenants` tablosu oldukca minimal. Ek bilgiler iliskili tablolarda tutuluyor.

---

## Tenant Iliskili Tablolar

### 1. Abonelik Yonetimi

#### tenant_subscriptions
Tenant'in abonelik bilgilerini tutar.

```sql
CREATE TABLE public.tenant_subscriptions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL,              -- REFERENCES tenants(id)
    subscription_plan_id uuid NOT NULL,   -- REFERENCES subscription_plans(id)
    status CHECK ('trial', 'active', 'past_due', 'canceled', 'suspended', 'incomplete'),
    trial_starts_at timestamp,
    trial_ends_at timestamp,
    current_period_start timestamp NOT NULL,
    current_period_end timestamp NOT NULL,
    cancel_at_period_end boolean DEFAULT false,
    canceled_at timestamp,
    cancellation_reason text,
    ...
);
```

**Abonelik Durumlari:**
| Durum | Aciklama |
|-------|----------|
| `trial` | Deneme surecinde |
| `active` | Aktif abonelik |
| `past_due` | Odeme gecikmis |
| `canceled` | Iptal edilmis |
| `suspended` | Askiya alinmis |
| `incomplete` | Tamamlanmamis |

#### subscription_plans
Abonelik planlarini tanimlar.

```sql
CREATE TABLE public.subscription_plans (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    plan_code character varying NOT NULL UNIQUE,
    plan_name character varying NOT NULL,
    description text,
    price_monthly numeric,
    price_yearly numeric,
    currency character varying DEFAULT 'TRY',
    trial_days integer DEFAULT 14,
    active boolean DEFAULT true,
    is_public boolean DEFAULT true,
    display_order integer DEFAULT 0,
    ...
);
```

#### plan_quotas
Plan bazli kota limitleri.

```sql
CREATE TABLE public.plan_quotas (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    subscription_plan_id uuid NOT NULL,
    quota_key character varying NOT NULL,
    quota_value integer NOT NULL,
    quota_unit character varying,
    ...
);
```

#### tenant_subscription_history
Abonelik degisiklik gecmisi.

```sql
CREATE TABLE public.tenant_subscription_history (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL,
    tenant_subscription_id uuid,
    change_type CHECK ('created', 'plan_changed', 'status_changed', 'trial_started', 'trial_ended', 'canceled', 'reactivated'),
    old_plan_id uuid,
    new_plan_id uuid,
    old_status character varying,
    new_status character varying,
    change_reason text,
    ...
);
```

---

### 2. Odeme ve Faturalama

#### tenant_billing_info
Fatura bilgileri (1:1 iliski).

```sql
CREATE TABLE public.tenant_billing_info (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL UNIQUE,
    company_name character varying NOT NULL,
    tax_office character varying,
    tax_number character varying,
    billing_address text,
    billing_city character varying,
    billing_country character varying DEFAULT 'TR',
    billing_postal_code character varying,
    billing_email character varying NOT NULL,
    billing_phone character varying,
    ...
);
```

#### tenant_payment_methods
Odeme yontemleri.

```sql
CREATE TABLE public.tenant_payment_methods (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL,
    payment_type CHECK ('credit_card', 'bank_transfer', 'iyzico', 'manual'),
    -- Kredi karti bilgileri
    card_last_4 character varying,
    card_brand character varying,
    card_exp_month integer,
    card_exp_year integer,
    cardholder_name character varying,
    -- Banka bilgileri
    bank_name character varying,
    iban character varying,
    account_holder_name character varying,
    -- Harici odeme
    external_payment_id character varying,
    external_payment_data jsonb,
    is_default boolean DEFAULT false,
    is_verified boolean DEFAULT false,
    ...
);
```

**Desteklenen Odeme Tipleri:**
- `credit_card`: Kredi karti
- `bank_transfer`: Banka havalesi
- `iyzico`: iyzico entegrasyonu
- `manual`: Manuel odeme

#### tenant_payment_transactions
Odeme islemleri.

```sql
CREATE TABLE public.tenant_payment_transactions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL,
    tenant_invoice_id uuid,
    tenant_payment_method_id uuid,
    transaction_type CHECK ('payment', 'refund', 'chargeback', 'adjustment'),
    amount numeric NOT NULL,
    currency character varying DEFAULT 'TRY',
    status CHECK ('pending', 'processing', 'success', 'failed', 'refunded', 'cancelled'),
    external_transaction_id character varying,
    external_conversation_id character varying,
    gateway_name character varying DEFAULT 'iyzico',
    gateway_response jsonb,
    error_code character varying,
    error_message text,
    ...
);
```

#### tenant_invoices
Faturalar.

```sql
CREATE TABLE public.tenant_invoices (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL,
    tenant_subscription_id uuid,
    invoice_number character varying NOT NULL UNIQUE,
    invoice_date date NOT NULL,
    due_date date NOT NULL,
    subtotal numeric NOT NULL,
    tax_rate numeric DEFAULT 20.00,
    tax_amount numeric NOT NULL,
    discount_amount numeric DEFAULT 0,
    total_amount numeric NOT NULL,
    currency character varying DEFAULT 'TRY',
    status CHECK ('draft', 'sent', 'paid', 'partially_paid', 'overdue', 'void', 'refunded'),
    payment_date date,
    paid_amount numeric DEFAULT 0,
    invoice_pdf_url text,
    invoice_xml_url text,
    ...
);
```

---

### 3. Kredi Sistemi

#### tenant_credits
Kredi bakiyesi (1:1 iliski).

```sql
CREATE TABLE public.tenant_credits (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL UNIQUE,
    total_credits integer DEFAULT 0,
    used_credits integer DEFAULT 0,
    available_credits integer,          -- Computed: total - used
    lifetime_purchased_credits integer DEFAULT 0,
    lifetime_bonus_credits integer DEFAULT 0,
    last_purchase_at timestamp,
    ...
);
```

#### credit_packages
Satin alinabilir kredi paketleri.

```sql
CREATE TABLE public.credit_packages (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    package_code character varying NOT NULL UNIQUE,
    package_name character varying NOT NULL,
    description text,
    credit_amount integer NOT NULL,
    price numeric NOT NULL,
    currency character varying DEFAULT 'TRY',
    bonus_credits integer DEFAULT 0,
    total_credits integer,              -- Computed: credit_amount + bonus
    active boolean DEFAULT true,
    is_featured boolean DEFAULT false,
    display_order integer DEFAULT 0,
    badge_text character varying,
    badge_color character varying,
    ...
);
```

#### tenant_credit_transactions
Kredi hareketleri.

```sql
CREATE TABLE public.tenant_credit_transactions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL,
    transaction_type CHECK ('purchase', 'usage', 'refund', 'bonus', 'expiration', 'adjustment', 'gift'),
    credit_amount integer NOT NULL,
    balance_before integer NOT NULL,
    balance_after integer NOT NULL,
    related_entity_type character varying,
    related_entity_id uuid,
    credit_package_id uuid,
    payment_transaction_id uuid,
    description text,
    metadata jsonb,
    ...
);
```

#### credit_quota_costs
Kota artirimi icin kredi maliyetleri.

```sql
CREATE TABLE public.credit_quota_costs (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    quota_key character varying NOT NULL,
    quota_display_name character varying NOT NULL,
    increment_amount integer NOT NULL,
    increment_unit character varying,
    credit_cost integer NOT NULL,
    is_recommended boolean DEFAULT false,
    ...
);
```

---

### 4. Kota ve Kullanim

#### tenant_quotas
Tenant bazli kota degerleri.

```sql
CREATE TABLE public.tenant_quotas (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL,
    quota_key character varying NOT NULL,
    quota_value integer NOT NULL,
    is_custom boolean DEFAULT false,     -- Plan disinda ozel mi?
    effective_from timestamp,
    effective_until timestamp,
    ...
);
```

#### tenant_usage_metrics
Kullanim metrikleri.

```sql
CREATE TABLE public.tenant_usage_metrics (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL,
    metric_key CHECK (
        'active_organizations', 'active_sites', 'active_units',
        'active_variables', 'active_users', 'active_contractors',
        'storage_used_gb', 'api_calls_daily', 'api_calls_monthly'
    ),
    metric_value numeric NOT NULL,
    measured_at timestamp,
    ...
);
```

**Takip Edilen Metrikler:**
| Metrik | Aciklama |
|--------|----------|
| `active_organizations` | Aktif organizasyon sayisi |
| `active_sites` | Aktif site sayisi |
| `active_units` | Aktif unit sayisi |
| `active_variables` | Aktif degisken sayisi |
| `active_users` | Aktif kullanici sayisi |
| `active_contractors` | Aktif yuklenici sayisi |
| `storage_used_gb` | Kullanilan depolama (GB) |
| `api_calls_daily` | Gunluk API cagri sayisi |
| `api_calls_monthly` | Aylik API cagri sayisi |

---

### 5. Ozellik Yonetimi

#### tenant_features
Tenant bazli ozellik aktif/pasif durumu.

```sql
CREATE TABLE public.tenant_features (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL,
    feature_key character varying NOT NULL,
    is_enabled boolean NOT NULL,
    override_reason text,
    enabled_at timestamp,
    disabled_at timestamp,
    enabled_by uuid,
    ...
);
```

---

### 6. Bildirimler ve Yasam Dongusu

#### tenant_notifications
Tenant bildirimleri.

```sql
CREATE TABLE public.tenant_notifications (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL,
    notification_type CHECK (
        'quota_warning', 'quota_exceeded', 'trial_ending_soon', 'trial_ended',
        'payment_failed', 'payment_due', 'invoice_ready', 'subscription_renewed',
        'subscription_canceled', 'feature_announcement', 'system_maintenance', 'security_alert'
    ),
    priority CHECK ('low', 'normal', 'high', 'critical'),
    title character varying NOT NULL,
    message text NOT NULL,
    action_text character varying,
    action_url text,
    is_read boolean DEFAULT false,
    is_dismissed boolean DEFAULT false,
    read_at timestamp,
    dismissed_at timestamp,
    expires_at timestamp,
    ...
);
```

#### tenant_lifecycle_events
Tenant yasam dongusu olaylari.

```sql
CREATE TABLE public.tenant_lifecycle_events (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL,
    event_type CHECK (
        'created', 'activated', 'trial_started', 'trial_ending_soon', 'trial_ended',
        'subscription_started', 'subscription_renewed', 'subscription_upgraded',
        'subscription_downgraded', 'subscription_canceled', 'suspended', 'reactivated',
        'churned', 'deleted'
    ),
    event_data jsonb,
    ...
);
```

---

### 7. Iliski Tablolari

#### tenant_contractors (N:N)
```sql
CREATE TABLE public.tenant_contractors (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    contractor_id uuid,
    tenant_id uuid,
    ...
);
```

#### tenant_sub_contractors (N:N)
```sql
CREATE TABLE public.tenant_sub_contractors (
    tenant_id uuid NOT NULL,
    sub_contractor_id uuid NOT NULL
);
```

#### tenant_teams (N:N)
```sql
CREATE TABLE public.tenant_teams (
    tenant_id uuid NOT NULL,
    team_id uuid NOT NULL
);
```

---

## Tenant'a Bagimli Tablolar

Asagidaki tablolar `tenant_id` foreign key ile tenant'a baglidir:

| Tablo | Iliski | Aciklama |
|-------|--------|----------|
| `organizations` | 1:N (ZORUNLU) | Alt organizasyonlar |
| `sites` | 1:N | Fiziksel lokasyonlar |
| `units` | 1:N | Alanlar/Bolumler |
| `controllers` | 1:N | IoT kontrolculer |
| `providers` | 1:N | Veri saglayicilar |
| `staffs` | 1:N | Calisanlar |
| `profiles` | 1:N | Kullanici profilleri |
| `inventories` | 1:N | Envanterler |
| `items` | 1:N | Urunler/Varliklar |
| `catalogs` | 1:N | Kataloglar |
| `invoices` | 1:N | Faturalar |
| `financials` | 1:N | Finansal bilgiler |
| `ftp_users` | 1:N | FTP kullanicilari |
| `validations` | 1:N | Dogrulamalar |
| `business_interactions` | 1:N | Is akislari |
| `calendar_events` | 1:N | Takvim etkinlikleri |
| `todo_items` | 1:N | Yapilacaklar |

---

## Tenant Iliski Diyagrami

```
                        +------------------+
                        |     tenants      |
                        +------------------+
                               |
    +--------------------------+---------------------------+
    |              |           |           |               |
    v              v           v           v               v
+--------+  +----------+  +--------+  +----------+  +----------+
|billing |  |subscript.|  |credits |  | quotas   |  | features |
| _info  |  |          |  |        |  |          |  |          |
+--------+  +----------+  +--------+  +----------+  +----------+
    1:1          1:N          1:1         1:N           1:N

    +--------------------------+---------------------------+
    |              |           |           |               |
    v              v           v           v               v
+--------+  +----------+  +--------+  +----------+  +----------+
|payment |  | invoices |  |notific.|  |lifecycle |  | usage    |
|methods |  |          |  |        |  | events   |  | metrics  |
+--------+  +----------+  +--------+  +----------+  +----------+
    1:N          1:N          1:N         1:N           1:N

                               |
                               v
              +----------------+----------------+
              |                |                |
              v                v                v
        +-----------+    +-----------+    +-----------+
        |contractors|    |   teams   |    |sub_contr. |
        | (N:N)     |    |   (N:N)   |    |   (N:N)   |
        +-----------+    +-----------+    +-----------+
```

---

## Eksiklikler ve Oneriler

### 1. Tenant Durumu
**Eksik:** `tenants` tablosunda durum/status alani yok.
**Oneri:** `status` alani eklenmeli (active, suspended, deleted, vb.)

### 2. Tenant Tipi
**Eksik:** Tenant tipini belirten alan yok.
**Oneri:** `tenant_type` alani eklenmeli (enterprise, sme, startup, vb.)

### 3. Parent Tenant
**Eksik:** Hiyerarsik tenant yapisi yok.
**Oneri:** `parent_tenant_id` ile franchise/holding yapisi desteklenebilir.

### 4. Lokalizasyon
**Eksik:** Dil tercihi ve para birimi yok.
**Oneri:** `preferred_language`, `default_currency` alanlari eklenmeli.

### 5. Onboarding Durumu
**Eksik:** Yeni tenant onboarding sureci takibi yok.
**Oneri:** `onboarding_completed_at`, `onboarding_steps_completed` jsonb alanlari eklenmeli.

### 6. Data Retention
**Eksik:** Veri saklama politikasi yok.
**Oneri:** `data_retention_days` alani veya ayri bir tablo eklenmeli.
