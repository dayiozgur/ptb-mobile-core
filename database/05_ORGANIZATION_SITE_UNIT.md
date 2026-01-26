# Organization, Site ve Unit Analizi

## Genel Bakis

Bu uc tablo, tenant altindaki fiziksel ve mantiksal hiyerarsiyi olusturur:
- **Organization:** Alt organizasyonlar (bolumler, departmanlar)
- **Site:** Fiziksel lokasyonlar (binalar, tesisler)
- **Unit:** Alanlar/Bolumler (katlar, odalar, zonlar)

---

## 1. Organizations (Alt Organizasyonlar)

### Tablo Yapisi

```sql
CREATE TABLE public.organizations (
    id uuid NOT NULL,
    active boolean,
    created_by uuid,
    created_at timestamp with time zone,
    row_id integer NOT NULL,
    updated_by uuid,
    updated_at timestamp with time zone,

    -- Temel Bilgiler
    code character varying,
    description character varying,
    name character varying,
    color character varying,
    image_path character varying,

    -- Konum Bilgileri
    address character varying,
    city character varying,
    country character varying,
    latitude double precision,
    longitude double precision,
    town character varying,
    zoom integer,

    -- Iliskiler
    financial_id uuid UNIQUE,         -- REFERENCES financials(id)
    marker_id uuid,                    -- REFERENCES markers(id)
    tenant_id uuid NOT NULL,           -- REFERENCES tenants(id) [ZORUNLU]
);
```

### Kritik Ozellikler

| Ozellik | Deger | Aciklama |
|---------|-------|----------|
| `tenant_id` | NOT NULL | Her organization bir tenant'a ait olmali |
| `financial_id` | UNIQUE | 1:1 finansal bilgi iliskisi |
| Konum Alanlari | Var | Cografi konum destegi |

### Iliskili Tablolar

#### contractor_organizations (N:N)
```sql
CREATE TABLE public.contractor_organizations (
    contractor_id uuid NOT NULL,
    organizations_id uuid NOT NULL,
    PRIMARY KEY (contractor_id, organizations_id)
);
```

### Organization Hiyerarsisi

```
TENANT
    |
    +-- Organization A (Merkez Ofis)
    |       |
    |       +-- Sites...
    |
    +-- Organization B (Bati Bolge)
    |       |
    |       +-- Sites...
    |
    +-- Organization C (Dogu Bolge)
            |
            +-- Sites...
```

### Eksiklikler

1. **Parent Organization:** `parent_organization_id` yok - alt organizasyon hiyerarsisi kurulamaz
2. **Organization Tipi:** `organization_type` alani yok
3. **Yonetici:** `manager_staff_id` veya benzeri bir alan yok

---

## 2. Sites (Fiziksel Lokasyonlar)

### Tablo Yapisi

```sql
CREATE TABLE public.sites (
    id uuid NOT NULL,
    active boolean,
    created_by uuid,
    created_at timestamp with time zone,
    row_id integer NOT NULL,
    updated_by uuid,
    updated_at timestamp with time zone,

    -- Temel Bilgiler
    code character varying,
    color character varying,
    description character varying,
    image_path character varying,
    name character varying,

    -- Konum Bilgileri
    address character varying,
    city character varying,
    country character varying,
    latitude double precision,
    longitude double precision,
    town character varying,
    zoom integer,

    -- Iliskiler
    tenant_id uuid,                    -- REFERENCES tenants(id) [Opsiyonel]
    organization_id uuid NOT NULL,     -- REFERENCES organizations(id) [ZORUNLU]
    marker_id uuid NOT NULL,           -- REFERENCES markers(id) [ZORUNLU]
    site_group_id uuid,                -- REFERENCES site_groups(id)
    site_type_id uuid,                 -- REFERENCES site_types(id)

    -- Calisma Saatleri
    general_open_time time,
    general_close_time time,
    working_time_active boolean,
    monday_start_time time, monday_end_time time,
    tuesday_start_time time, tuesday_end_time time,
    wednesday_start_time time, wednesday_end_time time,
    thursday_start_time time, thursday_end_time time,
    friday_start_time time, friday_end_time time,
    saturday_start_time time, saturday_end_time time,
    sunday_start_time time, sunday_end_time time,

    -- Fiziksel Ozellikler
    has_main_unit boolean DEFAULT false,
    gross_area_sqm numeric,            -- Brut alan (m2)
    net_area_sqm numeric,              -- Net alan (m2)
    floor_count integer,               -- Kat sayisi
    year_built integer,                -- Yapim yili
    operating_since date,              -- Faaliyet baslangici
    climate_zone character varying,    -- Iklim bolgesi
    energy_certificate_class CHECK ('A+', 'A', 'B', 'C', 'D', 'E', 'F', 'G'),
);
```

### Kritik Ozellikler

| Ozellik | Deger | Aciklama |
|---------|-------|----------|
| `organization_id` | NOT NULL | Her site bir organization'a ait olmali |
| `marker_id` | NOT NULL | Harita isaretcisi zorunlu |
| `tenant_id` | Opsiyonel | Organization uzerinden ulasilabilir (redundant) |
| Calisma Saatleri | Gun bazli | Her gun icin ayri saat ayarlanabilir |
| Fiziksel Ozellikler | Var | Bina bilgileri destekleniyor |

### Iliskili Tablolar

#### site_groups
Site gruplandirmasi.

```sql
-- site_groups tablosu (varsa)
```

#### site_types
Site tiplerini tanimlar.

```sql
CREATE TABLE public.site_types (
    id uuid NOT NULL,
    name character varying,
    description character varying,
    ...
);
```

### Site Hiyerarsisi

```
ORGANIZATION
    |
    +-- Site A (Merkez Bina)
    |       |-- gross_area: 5000 m2
    |       |-- floor_count: 10
    |       |-- energy_class: B
    |       |
    |       +-- Units...
    |
    +-- Site B (Depo)
    |       |-- gross_area: 2000 m2
    |       |-- floor_count: 1
    |       |
    |       +-- Units...
    |
    +-- Site C (Fabrika)
            |-- gross_area: 15000 m2
            |-- floor_count: 3
            |
            +-- Units...
```

### Eksiklikler

1. **Parent Site:** `parent_site_id` yok - site gruplamasi icin ayri tablo gerekiyor
2. **Koordinat Dogrulamasi:** Lat/Long icin CHECK constraint yok
3. **Timezone:** Site bazli timezone alani yok
4. **Kapasite:** Kisi kapasitesi alani yok

---

## 3. Units (Alanlar/Bolumler)

### Tablo Yapisi

```sql
CREATE TABLE public.units (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    active boolean,
    created_by uuid,
    created_at timestamp with time zone,
    row_id integer NOT NULL,
    updated_by uuid,
    updated_at timestamp with time zone,

    -- Temel Bilgiler
    code character varying,
    description character varying,
    name character varying,
    area_size double precision,
    image_bucket character varying,

    -- Hiyerarsi (Self-Reference)
    parent_unit_id uuid,               -- REFERENCES units(id) [SELF]

    -- Iliskiler
    site_id uuid,                      -- REFERENCES sites(id)
    organization_id uuid,              -- REFERENCES organizations(id)
    tenant_id uuid,                    -- REFERENCES tenants(id)
    contractor_id uuid,                -- REFERENCES contractors(id)
    sub_contractor_id uuid,            -- REFERENCES sub_contractors(id)
    unit_type_id uuid,                 -- REFERENCES unit_types(id)
    area_id uuid,                      -- REFERENCES areas(id)
    financial_id uuid UNIQUE,          -- REFERENCES financials(id)
    location_id uuid UNIQUE,           -- REFERENCES locations(id)
    authorized_staff uuid,             -- REFERENCES staffs(id)

    -- Ozel Alanlar
    is_main_area boolean DEFAULT false,
    is_deletable boolean DEFAULT true,
    original_main_area boolean DEFAULT false,

    -- Calisma Saatleri (Sites ile ayni)
    general_open_time time,
    general_close_time time,
    working_time_active boolean,
    monday_start_time time, monday_end_time time,
    ...
);
```

### Kritik Ozellikler

| Ozellik | Deger | Aciklama |
|---------|-------|----------|
| `parent_unit_id` | Self-Reference | Sinirsiz derinlikte hiyerarsi |
| `site_id` | Opsiyonel | Her unit bir site'a baglanabilir |
| `is_main_area` | Boolean | Ana alan mi? |
| `is_deletable` | Boolean | Silinebilir mi? |
| `authorized_staff` | Staff FK | Yetkili personel |

### Unit Types (Birim Tipleri)

```sql
CREATE TABLE public.unit_types (
    id uuid NOT NULL,
    active boolean,
    description character varying,
    name character varying,
    code character varying,
    is_main_area boolean DEFAULT false,
    is_system_type boolean DEFAULT false,
    category CHECK (
        'MAIN', 'FLOOR', 'SECTION', 'ROOM', 'ZONE',
        'PRODUCTION', 'STORAGE', 'SERVICE', 'COMMON',
        'TECHNICAL', 'OUTDOOR', 'CUSTOM'
    ),
    allowed_site_types jsonb,
    ...
);
```

**Kategori Aciklamalari:**
| Kategori | Aciklama | Ornek |
|----------|----------|-------|
| `MAIN` | Ana alan | Tum bina |
| `FLOOR` | Kat | Kat 1, Bodrum |
| `SECTION` | Bolum | A Blok, Guney Kanat |
| `ROOM` | Oda | Ofis 101, Toplanti Odasi |
| `ZONE` | Zon | Soguk Oda, Temiz Oda |
| `PRODUCTION` | Uretim | Montaj Hatti |
| `STORAGE` | Depolama | Hammadde Deposu |
| `SERVICE` | Servis | Kazan Dairesi |
| `COMMON` | Ortak Alan | Lobi, Koridor |
| `TECHNICAL` | Teknik | Elektrik Odasi |
| `OUTDOOR` | Dis Mekan | Otopark, Bahce |
| `CUSTOM` | Ozel | Kullanici tanimli |

### Unit Hiyerarsisi (Ornek)

```
SITE (Merkez Bina)
    |
    +-- UNIT: Ana Alan (is_main_area=true, parent=NULL)
            |
            +-- UNIT: Bodrum Kat (category=FLOOR)
            |       |
            |       +-- UNIT: Otopark (category=STORAGE)
            |       +-- UNIT: Kazan Dairesi (category=TECHNICAL)
            |
            +-- UNIT: Zemin Kat (category=FLOOR)
            |       |
            |       +-- UNIT: Lobi (category=COMMON)
            |       +-- UNIT: Guvenlik (category=SERVICE)
            |       +-- UNIT: Cafe (category=COMMON)
            |
            +-- UNIT: 1. Kat (category=FLOOR)
            |       |
            |       +-- UNIT: A Blok (category=SECTION)
            |       |       |
            |       |       +-- UNIT: Ofis 101 (category=ROOM)
            |       |       +-- UNIT: Ofis 102 (category=ROOM)
            |       |
            |       +-- UNIT: B Blok (category=SECTION)
            |               |
            |               +-- UNIT: Toplanti Odasi (category=ROOM)
            |               +-- UNIT: Server Odasi (category=TECHNICAL)
            |
            +-- UNIT: 2. Kat (category=FLOOR)
                    |
                    +-- ...
```

### Iliskili Tablolar

#### unit_characteristics
Unit ozellikleri.

```sql
CREATE TABLE public.unit_characteristics (
    id uuid NOT NULL,
    value character varying,
    characteristic_id uuid,            -- REFERENCES characteristics(id)
    unit_id uuid,                      -- REFERENCES units(id)
    ...
);
```

#### unit_schedules
Unit bazli zamanlamalar.

```sql
CREATE TABLE public.unit_schedules (
    id uuid NOT NULL,
    name character varying NOT NULL,
    description text,
    schedule_type CHECK ('POSTPONE', 'FOR_EACH'),
    priority integer NOT NULL,
    is_active boolean NOT NULL,
    days_of_week text,
    start_day integer, end_day integer,
    start_month integer, end_month integer,
    open_start_time time, open_end_time time,
    work_start_time time, work_end_time time,
    valid_from timestamp, valid_until timestamp,
    unit_id uuid NOT NULL,             -- REFERENCES units(id)
    ...
);
```

#### periods
Unit bazli periyotlar.

```sql
CREATE TABLE public.periods (
    id uuid NOT NULL,
    name character varying,
    description character varying,
    short_code character varying,
    start_time time,
    end_time time,
    unit_id uuid,                      -- REFERENCES units(id)
    ...
);
```

---

## Iliski Diyagrami

```
+------------------+
|     tenants      |
+------------------+
         |
         | 1:N (ZORUNLU)
         v
+------------------+
|  organizations   |
+------------------+
         |
         | 1:N (ZORUNLU)
         v
+------------------+
|      sites       |
+------------------+
         |
         | 1:N (opsiyonel)
         v
+------------------+
|      units       |<----+
+------------------+     |
         |               | self-reference
         +---------------+ (parent_unit_id)
         |
         | 1:N
         v
+-------------------------------------------+
|  controllers  |  providers  |  items      |
+-------------------------------------------+
```

---

## Veri Yolu Analizi

### Yukaridan Asagiya (Top-Down)

```
Tenant -> Organizations (tenant_id)
       -> Sites (organization_id)
       -> Units (site_id veya organization_id)
       -> Controllers/Providers (unit_id veya site_id)
```

### Asagidan Yukariya (Bottom-Up)

```
Controller -> unit_id -> Unit
                      -> parent_unit_id -> Parent Unit -> ... -> Root Unit
          -> site_id -> Site
                     -> organization_id -> Organization
                                        -> tenant_id -> Tenant
```

---

## Eksiklikler ve Oneriler

### Organizations

| Eksik | Oneri | Oncelik |
|-------|-------|---------|
| Parent organization | `parent_organization_id` ekle | Orta |
| Organization tipi | `organization_type` ekle | Dusuk |
| Yonetici | `manager_staff_id` ekle | Orta |
| Aktif/Pasif tarihleri | `activated_at`, `deactivated_at` ekle | Dusuk |

### Sites

| Eksik | Oneri | Oncelik |
|-------|-------|---------|
| Timezone | `timezone` ekle | Yuksek |
| Kisi kapasitesi | `capacity` ekle | Orta |
| Koordinat validasyonu | CHECK constraint ekle | Dusuk |
| Acil durum kontagi | `emergency_contact` ekle | Orta |

### Units

| Eksik | Oneri | Oncelik |
|-------|-------|---------|
| Seviye/Derinlik | `hierarchy_level` ekle (computed) | Orta |
| Full path | `full_path` ekle (materialized) | Orta |
| Sira numarasi | `sort_order` ekle | Dusuk |
| Kapasite | `capacity` ekle | Orta |
| Durum | `status` ekle (operational, maintenance, closed) | Yuksek |

### Genel

| Konu | Oneri | Oncelik |
|------|-------|---------|
| Recursive CTE | Hiyerarsi sorgusu icin view olustur | Yuksek |
| Soft Delete | Tum tablolarda `deleted_at` standardize et | Orta |
| Audit Trail | Degisiklik takibi icin trigger ekle | Orta |
