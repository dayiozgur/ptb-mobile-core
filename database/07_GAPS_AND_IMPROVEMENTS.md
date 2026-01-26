# Eksiklikler ve Iyilestirme Onerileri

Bu dokuman, veritabani semasi analizinde tespit edilen eksiklikleri ve iyilestirme onerilerini icerir.

---

## 1. KRITIK Eksiklikler

### 1.1 Variable -> Controller Dogrudan Iliskisi YOK

**Sorun:** `variables` tablosunda `controller_id` foreign key bulunmuyor. Variable'dan Controller'a ulasmak icin `realtimes` tablosu uzerinden gecmek gerekiyor.

**Etki:**
- Performans kaybi (JOIN zorunlulugu)
- Sorgu karmasikligi
- Veri butunlugu riski

**Oneri:**
```sql
ALTER TABLE public.variables
ADD COLUMN controller_id uuid REFERENCES public.controllers(id);

-- Mevcut veriyi migrate et
UPDATE variables v
SET controller_id = r.controller_id
FROM realtimes r
WHERE r.variable_id = v.id;
```

**Alternatif:** Materialized View
```sql
CREATE MATERIALIZED VIEW variable_controller_mapping AS
SELECT DISTINCT
    v.id as variable_id,
    r.controller_id
FROM variables v
JOIN realtimes r ON r.variable_id = v.id;

CREATE UNIQUE INDEX ON variable_controller_mapping(variable_id);
```

---

### 1.2 Tenant Durumu Eksik

**Sorun:** `tenants` tablosunda `status` alani yok. Tenant'in aktif/askiya alinmis/silinmis durumu takip edilemiyor.

**Oneri:**
```sql
ALTER TABLE public.tenants
ADD COLUMN status character varying DEFAULT 'active'
CHECK (status IN ('active', 'suspended', 'pending', 'trial', 'cancelled', 'deleted'));

ALTER TABLE public.tenants
ADD COLUMN suspended_at timestamp with time zone,
ADD COLUMN suspended_reason text,
ADD COLUMN deleted_at timestamp with time zone;
```

---

### 1.3 Redundant tenant_id Alanlari

**Sorun:** Bircok tabloda (sites, units, controllers, vb.) `tenant_id` alani mevcut olmasina ragmen, hiyerarsi uzerinden zaten tenant'a ulasilabiliyor.

**Ornek:**
- `sites.tenant_id` -> Gereksiz, cunku `sites.organization_id -> organizations.tenant_id`
- `controllers.tenant_id` -> Gereksiz, cunku `controllers.site_id -> sites.organization_id -> organizations.tenant_id`

**Etki:**
- Veri tutarsizligi riski
- Guncelleme anomalileri

**Oneri:**
1. **Kisa Vadeli:** Trigger ile senkronizasyon
```sql
CREATE OR REPLACE FUNCTION sync_tenant_id()
RETURNS TRIGGER AS $$
BEGIN
    -- sites icin
    IF TG_TABLE_NAME = 'sites' THEN
        NEW.tenant_id := (SELECT tenant_id FROM organizations WHERE id = NEW.organization_id);
    END IF;
    -- controllers icin
    IF TG_TABLE_NAME = 'controllers' THEN
        NEW.tenant_id := (SELECT o.tenant_id FROM sites s
                          JOIN organizations o ON o.id = s.organization_id
                          WHERE s.id = NEW.site_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

2. **Uzun Vadeli:** Redundant alanlari kaldir, computed column veya view kullan

---

### 1.4 Unit Durum Alani Eksik

**Sorun:** `units` tablosunda operasyonel durumu gosteren alan yok.

**Oneri:**
```sql
ALTER TABLE public.units
ADD COLUMN status character varying DEFAULT 'operational'
CHECK (status IN ('operational', 'maintenance', 'closed', 'renovation', 'inactive'));
```

---

## 2. YUKSEK Oncelikli Iyilestirmeler

### 2.1 Row Level Security (RLS) Eksik

**Sorun:** Tenant izolasyonu veritabani seviyesinde uygulanmiyor. Uygulama katmanina guveniliyor.

**Oneri:**
```sql
-- RLS'yi etkinlestir
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE units ENABLE ROW LEVEL SECURITY;
ALTER TABLE controllers ENABLE ROW LEVEL SECURITY;

-- Politika olustur
CREATE POLICY tenant_isolation_organizations ON organizations
    USING (tenant_id = current_setting('app.current_tenant')::uuid);

CREATE POLICY tenant_isolation_sites ON sites
    USING (tenant_id = current_setting('app.current_tenant')::uuid
           OR organization_id IN (
               SELECT id FROM organizations
               WHERE tenant_id = current_setting('app.current_tenant')::uuid
           ));
```

---

### 2.2 Hiyerarsi Traversal View'lari Eksik

**Sorun:** Hiyerarsik veri sorgulari icin hazir view'lar yok.

**Oneri:**
```sql
-- Tenant'dan Variable'a kadar tam yol
CREATE VIEW tenant_hierarchy AS
WITH RECURSIVE unit_tree AS (
    SELECT id, name, site_id, parent_unit_id, 1 as level,
           ARRAY[id] as path
    FROM units WHERE parent_unit_id IS NULL

    UNION ALL

    SELECT u.id, u.name, u.site_id, u.parent_unit_id, ut.level + 1,
           ut.path || u.id
    FROM units u
    JOIN unit_tree ut ON u.parent_unit_id = ut.id
)
SELECT
    t.id as tenant_id,
    t.name as tenant_name,
    o.id as organization_id,
    o.name as organization_name,
    s.id as site_id,
    s.name as site_name,
    ut.id as unit_id,
    ut.name as unit_name,
    ut.level as unit_level,
    ut.path as unit_path
FROM tenants t
JOIN organizations o ON o.tenant_id = t.id
JOIN sites s ON s.organization_id = o.id
LEFT JOIN unit_tree ut ON ut.site_id = s.id;
```

---

### 2.3 Audit Log Standardizasyonu

**Sorun:** Farkli tablolarda farkli audit yaklasimari kullaniliyor.

**Mevcut Durum:**
- `audit_logs` tablosu var ama tum tablolar kullanmiyor
- `created_at`, `updated_at` standart
- `created_by`, `updated_by` bazi tablolarda eksik

**Oneri:**
1. Tum ana tablolara audit alanlari ekle
2. Otomatik doldurma icin trigger yaz
3. Detayli degisiklik takibi icin `audit_logs` tablosunu kullan

```sql
-- Ornek trigger
CREATE OR REPLACE FUNCTION update_audit_fields()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := CURRENT_TIMESTAMP;
    NEW.updated_by := current_setting('app.current_user', true)::uuid;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

---

### 2.4 Indeks Eksiklikleri

**Sorun:** Performans icin kritik indeksler eksik.

**Oneri:**
```sql
-- Hiyerarsi sorgulari icin
CREATE INDEX idx_organizations_tenant_id ON organizations(tenant_id);
CREATE INDEX idx_sites_organization_id ON sites(organization_id);
CREATE INDEX idx_units_site_id ON units(site_id);
CREATE INDEX idx_units_parent_unit_id ON units(parent_unit_id);
CREATE INDEX idx_controllers_site_id ON controllers(site_id);
CREATE INDEX idx_controllers_provider_id ON controllers(provider_id);

-- Zaman bazli sorgular icin
CREATE INDEX idx_alarm_histories_start_time ON alarm_histories(start_time);
CREATE INDEX idx_alarm_histories_tenant_site ON alarm_histories(tenant_id, site_id);

-- Composite indexler
CREATE INDEX idx_controllers_site_active ON controllers(site_id, active) WHERE active = true;
CREATE INDEX idx_variables_device_model_active ON variables(device_model_id, active) WHERE active = true;
```

---

## 3. ORTA Oncelikli Iyilestirmeler

### 3.1 Soft Delete Standardizasyonu

**Sorun:** `active` boolean vs `deleted_at` timestamp tutarsizligi.

**Oneri:** Her iki yaklasimi birlestir:
```sql
-- Standart soft delete alanlari
ALTER TABLE {table_name}
ADD COLUMN deleted_at timestamp with time zone,
ADD COLUMN deleted_by uuid;

-- active alani deleted_at'a gore computed olsun
-- veya view kullan
```

---

### 3.2 Constraint Isimlendirme Standardizasyonu

**Sorun:** Foreign key isimleri tutarsiz (`fk1234abc...` vs `tablename_column_fkey`).

**Oneri:** Yeni tablolarda standart isimlendirme kullan:
```
{tablo}__{referans_tablo}__{kolon}_fkey
Ornek: controllers__sites__site_id_fkey
```

---

### 3.3 JSONB Alanlarin Sema Validasyonu

**Sorun:** `metadata`, `custom_limits` gibi JSONB alanlarin sema validasyonu yok.

**Oneri:**
```sql
-- CHECK constraint ile basit validasyon
ALTER TABLE platform_tenants
ADD CONSTRAINT valid_custom_limits
CHECK (
    custom_limits IS NULL OR (
        jsonb_typeof(custom_limits) = 'object' AND
        (custom_limits ? 'max_users' OR custom_limits ? 'max_sites')
    )
);
```

---

### 3.4 Enum Tipler Yerine Lookup Tablolari

**Sorun:** CHECK constraint ile tanimlanan enum degerler degistirilmesi zor.

**Ornek:**
```sql
status CHECK (status IN ('active', 'inactive', ...))
```

**Oneri:** Lookup tablosu kullan:
```sql
CREATE TABLE status_types (
    code character varying PRIMARY KEY,
    name character varying NOT NULL,
    description text,
    display_order integer,
    active boolean DEFAULT true
);

-- Foreign key ile baglanti
ALTER TABLE {table_name}
ADD CONSTRAINT fk_status
FOREIGN KEY (status) REFERENCES status_types(code);
```

---

## 4. DUSUK Oncelikli Iyilestirmeler

### 4.1 Dokumantasyon/Yorum Eksikligi

**Oneri:** Tablo ve kolon aciklamalari ekle:
```sql
COMMENT ON TABLE organizations IS 'Tenant altindaki alt organizasyonlari temsil eder';
COMMENT ON COLUMN organizations.tenant_id IS 'Bu organizasyonun ait oldugu tenant';
```

---

### 4.2 Performans Monitoring Tablolari

**Oneri:**
```sql
CREATE TABLE query_performance_log (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    query_hash character varying,
    query_text text,
    execution_time_ms integer,
    rows_affected integer,
    tenant_id uuid,
    user_id uuid,
    executed_at timestamp with time zone DEFAULT now()
);
```

---

### 4.3 Veri Arsivleme Stratejisi

**Oneri:**
```sql
-- Arsiv tablolari
CREATE TABLE alarm_histories_archive (LIKE alarm_histories INCLUDING ALL);

-- Partition by range
CREATE TABLE alarm_histories_partitioned (LIKE alarm_histories INCLUDING ALL)
PARTITION BY RANGE (created_at);

CREATE TABLE alarm_histories_2024 PARTITION OF alarm_histories_partitioned
FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
```

---

## 5. Workflow ve Is Yonetimi Eksiklikleri

### 5.1 Site Baglantisi Eksik

**Sorun:** `work_requests` ve `workflows` tablolarinda `site_id` alani bulunmuyor.

**Etki:**
- Site bazli is talebi filtrelemesi yapilamiyor
- Raporlama site seviyesinde zorlasiyor

**Oneri:**
```sql
ALTER TABLE work_requests ADD COLUMN site_id uuid REFERENCES sites(id);
ALTER TABLE workflows ADD COLUMN site_id uuid REFERENCES sites(id);
ALTER TABLE projects ADD COLUMN site_id uuid REFERENCES sites(id);
```

### 5.2 PMP Modulu Izole

**Sorun:** `pmp_*` tablolari ana hiyerarsi (`organizations`, `sites`, `units`) ile entegre degil.

**Oneri:**
```sql
-- pmp_organizations ile organizations arasinda kopruleme
CREATE TABLE pmp_organization_mapping (
    pmp_organization_id uuid PRIMARY KEY REFERENCES pmp_organizations(id),
    organization_id uuid NOT NULL REFERENCES organizations(id)
);
```

### 5.3 Hiyerarsi Dogrulama Eksik

**Sorun:** `work_requests.organization_id` ile `work_requests.unit_id` arasinda tutarlilik kontrolu yok.

**Oneri:**
```sql
CREATE OR REPLACE FUNCTION validate_work_request_hierarchy()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.unit_id IS NOT NULL AND NEW.organization_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM units u
            JOIN sites s ON s.id = u.site_id
            WHERE u.id = NEW.unit_id
              AND s.organization_id = NEW.organization_id
        ) THEN
            RAISE EXCEPTION 'Unit does not belong to specified organization';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_work_request_hierarchy
BEFORE INSERT OR UPDATE ON work_requests
FOR EACH ROW EXECUTE FUNCTION validate_work_request_hierarchy();
```

---

## 6. Kullanici Yonetimi Eksiklikleri

### 6.1 Profiles Organization Baglantisi Eksik

**Sorun:** `profiles` tablosunda sadece `tenant_id` var. Organization/Site/Unit baglantisi yok.

**Etki:**
- Kullanici sadece tenant seviyesinde tanimlanabiliyor
- Organization bazli erisim kontrolu yapilamiyor

**Oneri:**
```sql
ALTER TABLE profiles ADD COLUMN organization_id uuid REFERENCES organizations(id);
ALTER TABLE profiles ADD COLUMN default_site_id uuid REFERENCES sites(id);
```

### 6.2 Contractors/Teams Tenant Baglantisi

**Sorun:** `contractors` ve `teams` tablolarinda dogrudan `tenant_id` yok. Iliski bridge tablolari uzerinden kuruluyor.

**Oneri:**
```sql
ALTER TABLE contractors ADD COLUMN primary_tenant_id uuid REFERENCES tenants(id);
ALTER TABLE teams ADD COLUMN tenant_id uuid REFERENCES tenants(id);
```

### 6.3 Kullanici Hiyerarsi View Eksik

**Oneri:**
```sql
CREATE VIEW user_hierarchy AS
SELECT
    p.id as profile_id, p.username, p.email, p.role,
    p.tenant_id, t.name as tenant_name,
    ru.consumer as organization_id, o.name as organization_name,
    s.id as staff_id, s.contractor_id, s.sub_contractor_id
FROM profiles p
LEFT JOIN tenants t ON t.id = p.tenant_id
LEFT JOIN realm_users ru ON ru.profile = p.id
LEFT JOIN organizations o ON o.id = ru.consumer
LEFT JOIN staffs s ON s.profile_id = p.id;
```

---

## 7. Ozet Tablosu

| Kategori | Eksiklik | Oncelik | Tahmini Efor |
|----------|----------|---------|--------------|
| Iliski | Variable-Controller FK | KRITIK | Dusuk |
| Veri | Tenant status alani | KRITIK | Dusuk |
| **Workflow** | **work_requests.site_id eksik** | **YUKSEK** | **Dusuk** |
| **Workflow** | **PMP-Ana hiyerarsi entegrasyonu** | **YUKSEK** | **Orta** |
| **Workflow** | **Hiyerarsi dogrulama trigger** | **ORTA** | **Dusuk** |
| **Kullanici** | **profiles.organization_id eksik** | **YUKSEK** | **Dusuk** |
| **Kullanici** | **contractors/teams tenant_id eksik** | **ORTA** | **Dusuk** |
| **Kullanici** | **user_hierarchy view eksik** | **ORTA** | **Dusuk** |
| Tutarlilik | Redundant tenant_id | YUKSEK | Orta |
| Guvenlik | RLS politikalari | YUKSEK | Yuksek |
| Performans | Hiyerarsi view'lari | YUKSEK | Orta |
| Performans | Eksik indeksler | YUKSEK | Dusuk |
| Standart | Audit log tutarliligi | ORTA | Orta |
| Standart | Soft delete | ORTA | Orta |
| Standart | Constraint isimleri | ORTA | Dusuk |
| Veri Kalitesi | JSONB validasyonu | ORTA | Orta |
| Esneklik | Enum -> Lookup | ORTA | Orta |
| Dokumantasyon | Tablo/kolon yorumlari | DUSUK | Dusuk |
| Monitoring | Performance logging | DUSUK | Orta |
| Arsivleme | Partition stratejisi | DUSUK | Yuksek |

---

## 8. Uygulama Yol Haritasi

### Faz 1: Kritik
1. Variable-Controller iliskisi ekle
2. Tenant status alani ekle
3. Temel indeksleri ekle
4. **work_requests, workflows, projects tablolarina site_id ekle**
5. **profiles tablosuna organization_id ekle**

### Faz 2: Yuksek Oncelik
1. RLS politikalari olustur
2. Hiyerarsi view'lari ekle
3. Tenant_id senkronizasyon trigger'lari
4. **Workflow hiyerarsi dogrulama trigger'lari ekle**
5. **PMP-Ana hiyerarsi bridge tablosu olustur**
6. **user_hierarchy view olustur**
7. **Kullanici erisim kontrol fonksiyonlari**

### Faz 3: Standardizasyon
1. Audit logging standardizasyonu
2. Soft delete standardizasyonu
3. Constraint isimlendirme
4. **Is yonetimi view'lari olustur (work_request_hierarchy vb.)**
5. **contractors/teams tablolarina tenant_id ekle**

### Faz 4: Optimizasyon (Ongoing)
1. Performans monitoring
2. Arsivleme stratejisi
3. JSONB validasyonlari
4. **Workflow execution analytics**

---

## 9. Tamamlayici Tablolar Eksiklikleri

### 9.1 Envanter ve Varlik Yonetimi

#### items.current_unit_id Kullanimi
**Olumlu:** `items` tablosunda `current_unit_id` alani mevcut - varlik konum takibi yapiyor.

#### inventory_item_movements Varsayilan Degerler
**Sorun:** FK alanlarinda varsayilan `gen_random_uuid()` kullaniliyor - hatali veri olusturabilir.

**Oneri:**
```sql
ALTER TABLE inventory_item_movements
ALTER COLUMN from_inventory_id DROP DEFAULT,
ALTER COLUMN to_inventory_id DROP DEFAULT,
ALTER COLUMN item_id DROP DEFAULT;
```

### 9.2 Perakende/Magaza Tablolari

#### stores.organization_id/site_id Eksik
**Sorun:** `stores` tablosu ana hiyerarsiye (`organizations`, `sites`, `units`) baglanmiyor.

**Etki:**
- Site bazli magaza filtrelemesi yapilamiyor
- Magaza verileri IoT verileriyle iliskilendirilemiyor

**Oneri:**
```sql
ALTER TABLE stores ADD COLUMN organization_id uuid REFERENCES organizations(id);
ALTER TABLE stores ADD COLUMN site_id uuid REFERENCES sites(id);
```

### 9.3 Takvim ve Todo Tablolari

#### calendar_events/todo_items Organization/Unit Baglantisi Eksik
**Sorun:** Bu tablolar sadece `tenant_id` ile baglanir, organization/unit bazli filtreleme yapilamiyor.

**Oneri:**
```sql
ALTER TABLE calendar_events ADD COLUMN organization_id uuid REFERENCES organizations(id);
ALTER TABLE calendar_events ADD COLUMN unit_id uuid REFERENCES units(id);

ALTER TABLE todo_items ADD COLUMN organization_id uuid REFERENCES organizations(id);
ALTER TABLE todo_items ADD COLUMN unit_id uuid REFERENCES units(id);
```

### 9.4 Enerji ve KPI Tablolari

#### energy_groups/kpi_groups/kpi_reports Tenant Baglantisi Eksik
**Sorun:** Bu tablolarda `tenant_id` alani bulunmuyor.

**Oneri:**
```sql
ALTER TABLE energy_groups ADD COLUMN tenant_id uuid REFERENCES tenants(id);
ALTER TABLE kpi_groups ADD COLUMN tenant_id uuid REFERENCES tenants(id);
ALTER TABLE kpi_reports ADD COLUMN tenant_id uuid REFERENCES tenants(id);
```

### 9.5 Uretim Tablolari

#### productions/production_orders Hiyerarsi Baglantisi Eksik
**Sorun:** Bu tablolar sadece tenant seviyesinde - organization/unit baglantisi yok.

**Oneri:**
```sql
ALTER TABLE productions ADD COLUMN organization_id uuid REFERENCES organizations(id);
ALTER TABLE productions ADD COLUMN unit_id uuid REFERENCES units(id);
ALTER TABLE production_orders ADD COLUMN unit_id uuid REFERENCES units(id);
```

### 9.6 Index Onerileri (Tamamlayici Tablolar)

```sql
-- Sik sorgulanan alanlara index
CREATE INDEX idx_alarm_histories_tenant_date ON alarm_histories(tenant_id, created_at);
CREATE INDEX idx_stores_retail_chain ON stores(retail_chain_id);
CREATE INDEX idx_items_current_unit ON items(current_unit_id);
CREATE INDEX idx_todo_items_tenant_status ON todo_items(tenant_id, status);
CREATE INDEX idx_calendar_events_tenant_time ON calendar_events(tenant_id, start_time);
CREATE INDEX idx_inventory_items_stock_status ON inventory_items(stock_status);
CREATE INDEX idx_energy_readings_controller_time ON new_energy_readings(controller_id, time);
CREATE INDEX idx_invoice_tenant_status ON invoices(tenant_id, payment_status);
```

---

## 10. Guncellenmiş Ozet Tablosu

| Kategori | Eksiklik | Oncelik | Tahmini Efor |
|----------|----------|---------|--------------|
| Iliski | Variable-Controller FK | KRITIK | Dusuk |
| Veri | Tenant status alani | KRITIK | Dusuk |
| Workflow | work_requests.site_id eksik | YUKSEK | Dusuk |
| Workflow | PMP-Ana hiyerarsi entegrasyonu | YUKSEK | Orta |
| Kullanici | profiles.organization_id eksik | YUKSEK | Dusuk |
| **Perakende** | **stores organization/site baglantisi** | **YUKSEK** | **Dusuk** |
| **Takvim** | **calendar_events organization/unit** | **ORTA** | **Dusuk** |
| **Todo** | **todo_items organization/unit** | **ORTA** | **Dusuk** |
| **Enerji** | **energy_groups/kpi tenant_id** | **ORTA** | **Dusuk** |
| **Uretim** | **productions hiyerarsi baglantisi** | **ORTA** | **Dusuk** |
| **Envanter** | **inventory_item_movements FK defaults** | **DUSUK** | **Dusuk** |
| Tutarlilik | Redundant tenant_id | YUKSEK | Orta |
| Guvenlik | RLS politikalari | YUKSEK | Yuksek |
| Performans | Hiyerarsi view'lari | YUKSEK | Orta |
| Performans | Eksik indeksler | YUKSEK | Dusuk |
| Standart | Audit log tutarliligi | ORTA | Orta |

---

## 11. Son Guncelleme

**Tarih:** 2026-01-24
**Versiyon:** 1.1.0
