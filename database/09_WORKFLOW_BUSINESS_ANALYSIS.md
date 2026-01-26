# Workflow ve Business Interaction Analizi

Bu dokuman, is akisi (workflow), is etkilesimleri (business interactions) ve iliskili tablolarin ana hiyerarsi (Platform, Tenant, Organization, Site, Unit) ile iliskilerini analiz eder.

---

## 1. Genel Bakis

Sistemde uc farkli is yonetimi katmani bulunur:

1. **Business Interactions:** Is sureci sablonlarini tanimlar (Tenant bazli)
2. **Work Requests:** Genel is talebi sistemi (Organization/Unit bazli)
3. **PMP (Project Management):** Proje yonetimi modulu (Tenant/Organization bazli)

```
+=====================================================================+
|                         IS YONETIMI KATMANLARI                       |
+=====================================================================+
|                                                                     |
|  +-------------------+     +-------------------+     +-----------+  |
|  | Business          |     | Work Requests     |     | PMP       |  |
|  | Interactions      |     | (Workflows/Tasks/ |     | (Projects)|  |
|  | (Sablonlar)       |     |  Projects)        |     |           |  |
|  +-------------------+     +-------------------+     +-----------+  |
|           |                        |                       |        |
|           |                        |                       |        |
|           v                        v                       v        |
|  +-------------------------------------------------------------- +  |
|  |                      ANA HIYERARSI                            |  |
|  |  Platform -> Tenant -> Organization -> Site -> Unit           |  |
|  +---------------------------------------------------------------+  |
|                                                                     |
+=====================================================================+
```

---

## 2. Business Interactions (Is Etkilesimleri)

### 2.1 Tablo Yapisi

```sql
CREATE TABLE public.business_interactions (
    id uuid NOT NULL,
    code character varying,
    name character varying,
    description character varying,
    input_type CHECK ('BOOLEAN', 'TEXT', 'JSON', 'NONE'),
    output_type CHECK ('BOOLEAN', 'TEXT', 'JSON', 'NONE'),
    sector_id uuid,                    -- REFERENCES sectors(id)
    tenant_id uuid,                    -- REFERENCES tenants(id)
    ...
);
```

### 2.2 Hiyerarsi Iliskisi

| Alan | Iliski | Aciklama |
|------|--------|----------|
| `tenant_id` | tenants | Interaction bu tenant'a ait |
| `sector_id` | sectors | Sektor kategorisi |

**EKSIK:** Organization veya Site baglantisi yok. Interaction'lar tenant seviyesinde tanimlanir.

### 2.3 Alt Tablolar

```
business_interactions
    |
    +-- business_flows (1:N)
    |       |
    |       +-- business_flow_maps (akim baglantilari)
    |       |
    |       +-- business_steps (1:N)
    |               |
    |               +-- business_step_maps (adim baglantilari)
    |               +-- business_step_types (adim tipleri)
    |
    +-- workflow_versions (1:N) - Versiyon takibi
    +-- workflow_executions (1:N) - Calistirma kayitlari
```

### 2.4 Business Flow Yapisi

```
BUSINESS_INTERACTION (Is Sureci Tanimi)
    |
    +-- BUSINESS_FLOW (Akim 1: "Baslangic")
    |       |-- is_next_async: false
    |       |
    |       +-- BUSINESS_STEP (Adim 1.1: "Form Doldur")
    |       +-- BUSINESS_STEP (Adim 1.2: "Onay Iste")
    |
    +-- BUSINESS_FLOW (Akim 2: "Onay Sureci")
    |       |
    |       +-- BUSINESS_STEP (Adim 2.1: "Yonetici Onay")
    |       +-- BUSINESS_STEP (Adim 2.2: "Finans Onay")
    |
    +-- BUSINESS_FLOW (Akim 3: "Tamamlama")
            |
            +-- BUSINESS_STEP (Adim 3.1: "Is Atama")
            +-- BUSINESS_STEP (Adim 3.2: "Kapatma")
```

---

## 3. Work Requests (Is Talepleri)

### 3.1 Tablo Yapisi

```sql
CREATE TABLE public.work_requests (
    id uuid NOT NULL,
    subject character varying,
    description text,
    status CHECK ('DRAFT', 'PENDING_APPROVAL', 'APPROVED', 'IN_PROGRESS', 'DONE', 'REJECTED'),
    priority CHECK ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL', 'URGENT', ...),
    reason character varying,

    -- HIYERARSI ILISKILERI
    tenant_id uuid,                    -- REFERENCES tenants(id)
    organization_id uuid,              -- REFERENCES organizations(id)
    unit_id uuid,                      -- REFERENCES units(id)

    -- IS SURECI ILISKILERI
    business_interaction_id uuid,      -- REFERENCES business_interactions(id)
    work_request_type_id uuid,         -- REFERENCES work_request_types(id)

    -- KONUM BILGILERI
    city_id uuid,
    country_id uuid,
    location_id uuid,

    -- ACTOR ILISKILERI
    contractor_id uuid,                -- REFERENCES contractors(id)
    staff_id uuid,                     -- REFERENCES staffs(id)
    team_id uuid,                      -- REFERENCES teams(id)
    sub_contractor_id uuid,            -- REFERENCES sub_contractors(id)
    inventory_id uuid,                 -- REFERENCES inventories(id)

    -- PROJE YONETIMI
    sprint_id uuid,                    -- REFERENCES pmp_sprints(id)
    ...
);
```

### 3.2 Hiyerarsi Iliskisi Matrisi

| work_requests -> | Iliski | Zorunlu | Aciklama |
|------------------|--------|---------|----------|
| `tenant_id` | tenants | Hayir | Tenant referansi |
| `organization_id` | organizations | Hayir | Organization referansi |
| `unit_id` | units | Hayir | Unit referansi |
| `business_interaction_id` | business_interactions | Hayir | Is sureci sablonu |

### 3.3 Work Request Alt Tipleri

Work Requests, 3 alt tipe ayrilir (hepsi ayni work_request'i extend eder):

```
                    +------------------+
                    |  work_requests   |
                    +------------------+
                           |
       +-------------------+-------------------+
       |                   |                   |
       v                   v                   v
+------------+      +------------+      +------------+
|  projects  |      |   tasks    |      | workflows  |
| (PK: work_ |      | (PK: work_ |      | (PK: work_ |
| request_id)|      | request_id)|      | request_id)|
+------------+      +------------+      +------------+
```

---

## 4. Projects (Projeler)

### 4.1 Tablo Yapisi

```sql
CREATE TABLE public.projects (
    work_request_id uuid NOT NULL,     -- PK, REFERENCES work_requests(id)
    code character varying,
    name character varying,
    description character varying,

    -- HIYERARSI ILISKILERI
    tenant_id uuid,                    -- REFERENCES tenants(id)
    organization_id uuid,              -- REFERENCES organizations(id)

    -- KONUM
    city_id uuid,
    country_id uuid,
    location_id uuid,
    ...
);
```

### 4.2 Project Iliskileri

| projects -> | Iliski | Aciklama |
|-------------|--------|----------|
| `tenant_id` | tenants | Proje bu tenant'a ait |
| `organization_id` | organizations | Proje bu organization altinda |
| `work_request_id` | work_requests | Ana is talebi |

### 4.3 Project Iliski Tablolari

```
projects
    |
    +-- project_contractors (N:N) - Yukleniciler
    +-- project_staffs (N:N) - Personel
    +-- project_teams (N:N) - Takimlar
    +-- project_sub_contractors (N:N) - Alt yukleniciler
    +-- project_units (N:N) - Iliskili unitler
```

**ONEMLI:** `project_units` tablosu, bir projenin birden fazla unit ile iliskilendirilmesine izin verir.

---

## 5. Tasks (Gorevler)

### 5.1 Tablo Yapisi

```sql
CREATE TABLE public.tasks (
    work_request_id uuid NOT NULL,     -- PK, REFERENCES work_requests(id)
    title character varying,
    code character varying,
    description text,
    status CHECK ('CREATED', 'ASSIGNED', 'IN_PROGRESS', 'COMPLETED', 'REJECTED', 'STOPPED', 'CANCELED'),
    priority CHECK ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL', ...),
    progress double precision,

    -- TARIHLER
    start_date timestamp,
    end_date timestamp,
    due_date timestamp,
    duration numeric,

    -- HIYERARSI ILISKILERI
    tenant_id uuid,                    -- REFERENCES tenants(id)
    organization_id uuid,              -- REFERENCES organizations(id)
    unit_id uuid,                      -- REFERENCES units(id)

    -- UST YAPILAR
    project_work_request_id uuid,      -- REFERENCES projects(work_request_id)
    workflow_work_request_id uuid,     -- REFERENCES workflows(work_request_id)

    -- ACTOR ILISKILERI
    contractor_id uuid,
    staff_id uuid,
    team_id uuid,
    sub_contractor_id uuid,
    ...
);
```

### 5.2 Task Hiyerarsi Iliskisi

| tasks -> | Iliski | Aciklama |
|----------|--------|----------|
| `tenant_id` | tenants | Gorev bu tenant'a ait |
| `organization_id` | organizations | Gorev bu organization altinda |
| `unit_id` | units | Gorev bu unit icin |
| `project_work_request_id` | projects | Ust proje |
| `workflow_work_request_id` | workflows | Ust is akisi |

---

## 6. Workflows (Is Akislari)

### 6.1 Tablo Yapisi

```sql
CREATE TABLE public.workflows (
    work_request_id uuid NOT NULL,     -- PK, REFERENCES work_requests(id)
    code character varying,
    name character varying,
    title character varying,
    description character varying,

    -- HIYERARSI ILISKILERI
    tenant_id uuid,                    -- REFERENCES tenants(id)

    -- IS SURECI
    business_interaction_id uuid,      -- REFERENCES business_interactions(id)

    -- UST YAPI
    project_work_request_id uuid,      -- REFERENCES projects(work_request_id)
    ...
);
```

### 6.2 Workflow Alt Tablolari

```
workflows
    |
    +-- workflow_stages (1:N) - Asamalar
    |       |
    |       +-- workflow_steps (1:N) - Adimlar
    |
    +-- workflow_contractors (N:N) - Yukleniciler
    +-- workflow_staffs (N:N) - Personel
    +-- workflow_teams (N:N) - Takimlar (+ unit_id!)
    +-- workflow_sub_contractors (N:N) - Alt yukleniciler
    +-- workflow_executions (1:N) - Calistirma kayitlari
    +-- workflow_histories (1:N) - Durum degisiklik gecmisi
```

### 6.3 workflow_teams Ozel Durumu

```sql
CREATE TABLE public.workflow_teams (
    id uuid NOT NULL,
    team_id uuid,                      -- REFERENCES teams(id)
    workflow_work_request_id uuid,     -- REFERENCES workflows(work_request_id)
    unit_id uuid,                      -- REFERENCES units(id) *** ONEMLI ***
    ...
);
```

**ONEMLI:** `workflow_teams` tablosu, takim atamalarinda `unit_id` ile belirli bir unit'e baglanti kurar. Bu, is akislarinin unit bazli yonetilmesine olanak tanir.

---

## 7. PMP (Project Management Platform)

### 7.1 Tablo Yapisi

PMP, ayri bir proje yonetim modulu olarak calisir:

```
pmp_organizations (Tenant bazli)
    |
    +-- pmp_projects (1:N)
    |       |
    |       +-- pmp_sprints (1:N)
    |       |
    |       +-- pmp_teams (1:N)
    |       |
    |       +-- pmp_work_requests (1:N)
    |               |
    |               +-- pmp_tasks (1:N)
    |
    +-- pmp_staffs (Calisanlar)
```

### 7.2 PMP - Ana Hiyerarsi Iliskisi

| PMP Tablosu | Hiyerarsi Iliskisi |
|-------------|-------------------|
| `pmp_organizations` | `tenant_id` -> tenants |
| `pmp_projects` | `tenant_id` -> tenants, `consumer` -> pmp_organizations |
| `pmp_work_requests` | `project_id` -> pmp_projects, `consumer` -> pmp_organizations |

**EKSIK:** PMP tablolari, ana `organizations`, `sites`, `units` tablolari ile dogrudan iliskili degil. Bu bir izolasyon veya entegrasyon eksikligi olabilir.

---

## 8. Hiyerarsi Iliski Haritasi

### 8.1 Is Yonetimi -> Ana Hiyerarsi

```
+==================================================================================+
|                                ANA HIYERARSI                                     |
+==================================================================================+
|                                                                                  |
|    TENANT                                                                        |
|       |                                                                          |
|       +-- business_interactions (tenant_id)                                      |
|       |       |                                                                  |
|       |       +-- workflows.business_interaction_id                              |
|       |       +-- work_requests.business_interaction_id                          |
|       |       +-- workflow_executions.interaction_id                             |
|       |       +-- workflow_versions.interaction_id                               |
|       |                                                                          |
|       +-- ORGANIZATION                                                           |
|       |       |                                                                  |
|       |       +-- work_requests (organization_id)                                |
|       |       +-- projects (organization_id)                                     |
|       |       +-- tasks (organization_id)                                        |
|       |       |                                                                  |
|       |       +-- SITE                                                           |
|       |               |                                                          |
|       |               +-- (work_requests'te site_id YOK!)                        |
|       |               |                                                          |
|       |               +-- UNIT                                                   |
|       |                       |                                                  |
|       |                       +-- work_requests (unit_id)                        |
|       |                       +-- tasks (unit_id)                                |
|       |                       +-- workflow_teams (unit_id)                       |
|       |                       +-- project_units (N:N)                            |
|       |                                                                          |
|       +-- pmp_organizations (tenant_id)                                          |
|               |                                                                  |
|               +-- pmp_projects                                                   |
|                       |                                                          |
|                       +-- pmp_work_requests                                      |
|                               +-- pmp_tasks                                      |
|                                                                                  |
+==================================================================================+
```

### 8.2 Eksik Iliskiler

| Tablo | Eksik Iliski | Onem |
|-------|--------------|------|
| `work_requests` | `site_id` | YUKSEK - Site bazli is talebi filtrelemesi yok |
| `workflows` | `organization_id`, `unit_id` | ORTA - Dolayli olarak work_request uzerinden |
| `projects` | `site_id`, `unit_id` | ORTA - Sadece organization seviyesinde |
| `business_interactions` | `organization_id` | DUSUK - Sablonlar tenant genelinde |
| `pmp_*` | `organizations`, `sites`, `units` | YUKSEK - Izole modul |

---

## 9. Veri Akisi Ornekleri

### 9.1 Is Talebi Olusturma

```
1. Kullanici bir Unit icin is talebi olusturur
   |
   v
2. work_requests INSERT
   - tenant_id: <current_tenant>
   - organization_id: <unit.organization_id>  -- Unit'ten turetilmeli
   - unit_id: <selected_unit>
   - business_interaction_id: <selected_template>
   |
   v
3. workflows INSERT (eger is akisi baslatilirsa)
   - work_request_id: <work_request.id>
   - tenant_id: <work_request.tenant_id>
   - business_interaction_id: <work_request.business_interaction_id>
   |
   v
4. workflow_stages ve workflow_steps olusturulur
   (business_flows ve business_steps'ten kopyalanir)
```

### 9.2 Unit Bazli Is Raporlama

```sql
-- Bir Unit'e ait tum is taleplerini getir
SELECT
    wr.id,
    wr.subject,
    wr.status,
    wr.priority,
    t.title as task_title,
    t.progress,
    p.name as project_name
FROM work_requests wr
LEFT JOIN tasks t ON t.work_request_id = wr.id
LEFT JOIN projects p ON t.project_work_request_id = p.work_request_id
WHERE wr.unit_id = '<unit_id>'
  AND wr.active = true;
```

---

## 10. Eksiklikler ve Oneriler

### 10.1 Kritik Eksiklikler

| # | Eksiklik | Etki | Oneri |
|---|----------|------|-------|
| 1 | `work_requests.site_id` yok | Site bazli filtreleme imkansiz | Site FK ekle |
| 2 | `workflows` sadece tenant_id | Organization/Unit izolasyonu yok | Iliski alanlari ekle |
| 3 | PMP izole | Ana hiyerarsi ile entegrasyon yok | Bridge tablolari ekle |

### 10.2 Veri Tutarliligi Riskleri

1. **work_requests.organization_id vs unit_id:**
   - Unit'in organization'i ile work_request.organization_id uyusmazligi olabilir
   - **Oneri:** Trigger ile dogrulama

```sql
CREATE OR REPLACE FUNCTION check_work_request_hierarchy()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.unit_id IS NOT NULL THEN
        -- Unit'in organization'ini kontrol et
        IF NOT EXISTS (
            SELECT 1 FROM units u
            JOIN sites s ON s.id = u.site_id
            WHERE u.id = NEW.unit_id
              AND s.organization_id = NEW.organization_id
        ) THEN
            RAISE EXCEPTION 'Unit organization mismatch';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### 10.3 Onerilen Iyilestirmeler

1. **Site Baglantisi Ekle:**
```sql
ALTER TABLE work_requests ADD COLUMN site_id uuid REFERENCES sites(id);
ALTER TABLE workflows ADD COLUMN site_id uuid REFERENCES sites(id);
```

2. **PMP Entegrasyonu:**
```sql
-- Bridge tablosu
CREATE TABLE pmp_organization_mapping (
    pmp_organization_id uuid REFERENCES pmp_organizations(id),
    organization_id uuid REFERENCES organizations(id),
    PRIMARY KEY (pmp_organization_id)
);
```

3. **Hiyerarsi View'i:**
```sql
CREATE VIEW work_request_hierarchy AS
SELECT
    wr.id as work_request_id,
    wr.subject,
    wr.status,
    u.id as unit_id,
    u.name as unit_name,
    s.id as site_id,
    s.name as site_name,
    o.id as organization_id,
    o.name as organization_name,
    t.id as tenant_id,
    t.name as tenant_name
FROM work_requests wr
LEFT JOIN units u ON u.id = wr.unit_id
LEFT JOIN sites s ON s.id = u.site_id
LEFT JOIN organizations o ON o.id = COALESCE(wr.organization_id, s.organization_id)
LEFT JOIN tenants t ON t.id = COALESCE(wr.tenant_id, o.tenant_id);
```

---

## 11. Sonuc

### 11.1 Guclu Yanlar

- Is sureci sablonlari (business_interactions) tenant bazli tanimlanabiliyor
- Work requests, projects, tasks, workflows birbirine baglanabiliyor
- Esnek actor atamalari (contractor, staff, team, sub_contractor)
- workflow_teams uzerinden unit bazli atama mumkun

### 11.2 Zayif Yanlar

- Site seviyesi is yonetiminde eksik
- PMP modulu izole calisir
- Hiyerarsi dogrulamasi otomatik degil
- Redundant tenant_id alanlari tutarsizlik riski tasiyor

### 11.3 Aksiyon Onerileri

| Oncelik | Aksiyon |
|---------|---------|
| YUKSEK | work_requests'e site_id ekle |
| YUKSEK | Hiyerarsi dogrulama trigger'lari ekle |
| ORTA | PMP-Ana hiyerarsi bridge'i olustur |
| ORTA | Workflow'lara organization_id/unit_id ekle |
| DUSUK | View'lar ile sorgulama kolaylastir |
