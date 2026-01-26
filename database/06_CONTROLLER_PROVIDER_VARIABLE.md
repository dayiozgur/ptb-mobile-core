# Controller, Provider ve Variable Analizi

## Genel Bakis

Bu tablolar, IoT/SCADA sisteminin temelini olusturur:
- **Controller:** Fiziksel kontrol cihazlari (PLC, RTU, vb.)
- **Provider:** Veri toplayici/saglayici cihazlar (Gateway, Hub)
- **Variable:** Olcum noktalari ve parametreler

---

## 1. Controllers (IoT Kontrolculer)

### Tablo Yapisi

```sql
CREATE TABLE public.controllers (
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
    serial character varying,
    mac character varying,
    model_code character varying,

    -- Ag Bilgileri
    ip character varying,
    ip_code character varying,
    proxy_prefix character varying,
    line character varying,
    line_address character varying,

    -- Kimlik Bilgileri
    http_username character varying,
    http_password character varying,
    ftp_username character varying,
    ftp_password character varying,
    ftp_client_username character varying,
    ftp_client_password character varying,

    -- Konfigurasyonlar
    cf_address integer,
    cf_code character varying,
    cf_description character varying,
    global_index integer,
    id_group integer,
    peripheral character varying,
    little_endian boolean,

    -- Durum Bilgileri
    is_enabled boolean,
    is_canceled boolean NOT NULL DEFAULT false,
    is_logic boolean,
    has_alarm boolean,
    life_test boolean,

    -- Zaman Damgalari
    insert_time timestamp,
    first_communication_time timestamp,
    first_connection_time timestamp,
    first_data_alignment_time timestamp,
    first_synchronization_time timestamp,
    last_communication_time timestamp,
    last_connection_time timestamp,
    last_data_alignment_time timestamp,
    last_synchronization_time timestamp,
    last_update_time timestamp,

    -- Gorseller
    background_path character varying,
    image_path character varying,

    -- Konum Bilgileri
    address character varying,
    city character varying,
    country character varying,
    latitude double precision,
    longitude double precision,
    town character varying,
    zoom integer,

    -- ZORUNLU Iliskiler
    site_id uuid NOT NULL,             -- REFERENCES sites(id)
    brand_id uuid NOT NULL,            -- REFERENCES brands(id)

    -- Opsiyonel Iliskiler
    tenant_id uuid,                    -- REFERENCES tenants(id)
    provider_id uuid,                  -- REFERENCES providers(id)
    unit_id uuid,                      -- REFERENCES units(id)
    contractor_id uuid,                -- REFERENCES contractors(id)
    area_id uuid,                      -- REFERENCES areas(id)
    device_id uuid,                    -- REFERENCES devices(id)
    device_model_id uuid,              -- REFERENCES device_models(id)
    device_item_id uuid,               -- REFERENCES items(id)
    inventory_item_id uuid UNIQUE,     -- REFERENCES inventory_items(id)
    ftp_user_id uuid,                  -- REFERENCES ftp_users(id)
    language_id uuid,                  -- REFERENCES languages(id)
    marker_id uuid,                    -- REFERENCES markers(id)
    protocol_type_id uuid,             -- REFERENCES protocol_types(id)
    supervisor_type_id uuid,           -- REFERENCES supervisor_types(id)
);
```

### Kritik Ozellikler

| Ozellik | Deger | Aciklama |
|---------|-------|----------|
| `site_id` | NOT NULL | Her controller bir site'a ait olmali |
| `brand_id` | NOT NULL | Marka zorunlu |
| `tenant_id` | Opsiyonel | Site uzerinden ulasilabilir (redundant ama performans) |
| `provider_id` | Opsiyonel | Veri saglayiciya baglanti |
| `is_canceled` | NOT NULL DEFAULT false | Iptal durumu |

### Controller Iliskili Tablolar

#### controller_device_models (N:N)
Controller - Device Model iliskisi.

```sql
CREATE TABLE public.controller_device_models (
    id uuid NOT NULL,
    controller_id uuid,               -- REFERENCES controllers(id)
    device_model_id uuid,             -- REFERENCES device_models(id)
    ...
);
```

#### supervisor_controllers (N:N)
Controller - Supervisor iliskisi.

```sql
CREATE TABLE public.supervisor_controllers (
    id uuid NOT NULL,
    supervisor_id uuid NOT NULL,      -- REFERENCES supervisors(id)
    controller_id uuid NOT NULL,      -- REFERENCES controllers(id)
    priority integer DEFAULT 1,
    is_primary boolean DEFAULT false,
    assignment_date timestamp,
    is_monitoring boolean DEFAULT true,
    last_monitoring_time timestamp,
    polling_override integer,
    timeout_override integer,
    ...
);
```

### Controller Hiyerarsisi

```
SITE
    |
    +-- PROVIDER (Gateway)
    |       |
    |       +-- CONTROLLER A (PLC #1)
    |       |       |-- device_model: Siemens S7-1200
    |       |       |-- protocol: Modbus TCP
    |       |       |-- Variables...
    |       |
    |       +-- CONTROLLER B (PLC #2)
    |               |-- device_model: Allen-Bradley
    |               |-- protocol: EtherNet/IP
    |               |-- Variables...
    |
    +-- CONTROLLER C (Standalone RTU)
            |-- provider_id: NULL
            |-- Variables...
```

---

## 2. Providers (Veri Saglayicilar)

### Tablo Yapisi

```sql
CREATE TABLE public.providers (
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
    hostname character varying,
    mac character varying,
    app_version character varying,
    sys_version character varying,
    uptime character varying,
    password character varying,

    -- Ag Bilgileri
    ip character varying,
    ip_code character varying,
    proxy_prefix character varying,

    -- Kimlik Bilgileri
    http_username character varying,
    http_password character varying,
    ftp_username character varying,
    ftp_password character varying,
    ftp_client_username character varying,
    ftp_client_password character varying,

    -- Durum Bilgileri
    has_alarm boolean,
    life_test boolean,

    -- Zaman Damgalari
    configuration_time timestamp,
    first_communication_time timestamp,
    first_connection_time timestamp,
    first_data_alignment_time timestamp,
    first_synchronization_time timestamp,
    last_communication_time timestamp,
    last_connection_time timestamp,
    last_data_alignment_time timestamp,
    last_synchronization_time timestamp,

    -- Konum Bilgileri
    address character varying,
    city character varying,
    country character varying,
    latitude double precision,
    longitude double precision,
    town character varying,
    zoom integer,
    image_path character varying,

    -- ZORUNLU Iliskiler
    site_id uuid NOT NULL,             -- REFERENCES sites(id)
    brand_id uuid NOT NULL,            -- REFERENCES brands(id)
    language_id uuid NOT NULL,         -- REFERENCES languages(id)
    marker_id uuid NOT NULL,           -- REFERENCES markers(id)
    protocol_type_id uuid NOT NULL,    -- REFERENCES protocol_types(id)
    supervisor_type_id uuid NOT NULL,  -- REFERENCES supervisor_types(id)

    -- Opsiyonel Iliskiler
    tenant_id uuid,                    -- REFERENCES tenants(id)
    unit_id uuid,                      -- REFERENCES units(id)
    area_id uuid,                      -- REFERENCES areas(id)
    device_id uuid,                    -- REFERENCES devices(id)
    device_item_id uuid,               -- REFERENCES items(id)
    inventory_item_id uuid UNIQUE,     -- REFERENCES inventory_items(id)
);
```

### Kritik Ozellikler

| Ozellik | Deger | Aciklama |
|---------|-------|----------|
| `site_id` | NOT NULL | Her provider bir site'a ait olmali |
| `brand_id` | NOT NULL | Marka zorunlu |
| `language_id` | NOT NULL | Dil zorunlu |
| `marker_id` | NOT NULL | Harita isaretcisi zorunlu |
| `protocol_type_id` | NOT NULL | Protokol tipi zorunlu |
| `supervisor_type_id` | NOT NULL | Supervisor tipi zorunlu |

### Provider vs Controller

| Ozellik | Provider | Controller |
|---------|----------|------------|
| Rol | Veri toplayici/Gateway | Saha kontrolcusu |
| Controller baglantisi | - | `provider_id` ile Provider'a bagli |
| Zorunlu alanlar | 6 adet | 2 adet |
| Variable iliskisi | Dolayli (Controller uzerinden) | Dogrudan |

---

## 3. Variables (Olcum Noktalari)

### Tablo Yapisi

```sql
CREATE TABLE public.variables (
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
    unit character varying,            -- Olcum birimi (C, kW, %, vb.)

    -- Deger Bilgileri
    value character varying,           -- Guncel deger
    default_value character varying,   -- Varsayilan deger
    minimum character varying,         -- Minimum limit
    maximum character varying,         -- Maksimum limit
    min_value numeric,
    max_value numeric,

    -- Tip Bilgileri
    variable_type CHECK (
        'DIGITAL', 'ANALOG', 'INTEGER',
        'ALARM', 'COMMAND', 'UNDEFINED'
    ),
    data_type CHECK ('number', 'string', 'boolean') DEFAULT 'number',
    type character varying,

    -- Adres Bilgileri
    address_input integer,
    address_output integer,
    bit_position integer,
    func_type_read integer,
    func_type_write integer,
    function_code character varying,
    length integer,
    var_encoding integer,

    -- Davranis Ozellikleri
    decimal boolean,
    read_only boolean,
    read_write integer,
    signed boolean,
    is_active boolean,
    is_cancelled boolean,
    is_logged boolean,
    is_logic boolean,
    is_on_change boolean,
    ishaccp boolean,
    time_series_enabled boolean,

    -- Formul/Donusum
    a_value double precision,          -- Y = aX + b icin 'a'
    b_value double precision,          -- Y = aX + b icin 'b'
    delta character varying,
    delay character varying,
    frequency character varying,

    -- Gruplama
    id_group integer,
    grp_category character varying,
    idhsvariable integer,

    -- Gorseller
    button_path character varying,
    image_off character varying,
    image_on character varying,
    to_display character varying,
    measure_unit character varying,
    rack_compressor_name character varying,

    -- Ozel Tipler
    working_time_variable_type CHECK (
        'COMPRESSOR_STATUS', 'DEFROST_STATUS',
        'ACTIVE_ENERGY_VARIABLE', 'POWER_VARIABLE',
        'RACK_COMPRESSOR_VARIABLE', 'RACK_DEFROST_VARIABLE'
    ),
    status CHECK ('active', 'inactive') DEFAULT 'active',

    -- Zaman Damgalari
    insert_time timestamp,
    last_update timestamp,

    -- Iliskiler
    device_model_id uuid,              -- REFERENCES device_models(id)
    origin_priority_id uuid,           -- REFERENCES priorities(id)
    priority_id uuid,                  -- REFERENCES priorities(id)
);
```

### Variable Tipleri

| Tip | Aciklama | Ornek |
|-----|----------|-------|
| `DIGITAL` | Dijital I/O | On/Off, True/False |
| `ANALOG` | Analog deger | Sicaklik, Basinc |
| `INTEGER` | Tam sayi | Sayac, Indeks |
| `ALARM` | Alarm degiskeni | Hata, Uyari |
| `COMMAND` | Komut degiskeni | Start, Stop |
| `UNDEFINED` | Tanimsiz | - |

### Calisma Zamani Tipleri

| Tip | Aciklama |
|-----|----------|
| `COMPRESSOR_STATUS` | Kompressor durumu |
| `DEFROST_STATUS` | Defrost durumu |
| `ACTIVE_ENERGY_VARIABLE` | Aktif enerji |
| `POWER_VARIABLE` | Guc |
| `RACK_COMPRESSOR_VARIABLE` | Rack kompressor |
| `RACK_DEFROST_VARIABLE` | Rack defrost |

### Variable -> Controller Yolu

**ONEMLI:** Variables tablosunda dogrudan `controller_id` YOKTUR!

Baglanti su yollarla kurulur:

#### Yol 1: Realtimes Uzerinden
```
Variable <- variable_id <- Realtimes -> controller_id -> Controller
```

#### Yol 2: Device Model Uzerinden
```
Variable -> device_model_id -> Device_Models <- device_model_id <- Controller
```

#### Yol 3: Device Variables Uzerinden
```
Variable <- variable_id <- Device_Variables -> device_property_id -> Device_Properties -> device_model_id -> ...
```

---

## 4. Realtimes (Canli Veri)

### Tablo Yapisi

```sql
CREATE TABLE public.realtimes (
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
    is_loggable boolean,

    -- Iliskiler
    controller_id uuid,                -- REFERENCES controllers(id)
    variable_id uuid,                  -- REFERENCES variables(id)
    device_model_id uuid,              -- REFERENCES device_models(id)
    priority_id uuid,                  -- REFERENCES priorities(id)
    cancelled_controller_id uuid,      -- REFERENCES cancelled_controllers(id)
);
```

### Realtimes Rolu

Realtimes tablosu, Variable ile Controller arasindaki **kopru** gorevini gorur:

```
+----------+         +----------+         +------------+
| Variable |<--------| Realtime |-------->| Controller |
+----------+         +----------+         +------------+
     |                    |
     v                    v
  Deger              Fiziksel
 Tanimi               Baglanti
```

---

## 5. Device Models ve Device Types

### device_models Tablosu

```sql
CREATE TABLE public.device_models (
    id uuid NOT NULL,
    active boolean,
    code character varying,
    description character varying,
    name character varying,
    image_path character varying,
    protocol character varying,
    version character varying,
    brand_id uuid,                     -- REFERENCES brands(id)
    organization_id uuid,              -- REFERENCES organizations(id)
    device_type_id uuid,               -- REFERENCES device_types(id)
    language_id uuid,                  -- REFERENCES languages(id)
    ...
);
```

### device_types Tablosu

```sql
CREATE TABLE public.device_types (
    id uuid NOT NULL,
    active boolean,
    code character varying,
    description character varying,
    icon character varying,
    image character varying,
    name character varying,
    category character varying,
    measurement_unit character varying,
    is_energy_meter boolean DEFAULT false,
    is_controllable boolean DEFAULT false,
    communication_protocols ARRAY,
    typical_parameters jsonb,
    installation_type character varying,
    certification_standards ARRAY,
    power_consumption character varying,
    operating_temperature character varying,
    dimensions jsonb,
    weight character varying,
    manufacturer_codes ARRAY,
    related_device_types ARRAY,
    monitoring_capabilities ARRAY,
    control_capabilities ARRAY,
    typical_applications ARRAY,
    display_order integer DEFAULT 0,
    is_system_type boolean DEFAULT false,
    parent_type_id uuid,               -- REFERENCES device_types(id) [SELF]
    metadata jsonb,
    ...
);
```

---

## Iliski Diyagrami

```
                    +------------------+
                    |      brands      |
                    +------------------+
                           |
       +-------------------+-------------------+
       |                                       |
       v                                       v
+------------------+                  +------------------+
|  device_models   |                  |  device_types    |
+------------------+                  +------------------+
       |                                       |
       |                                       |
       v                                       |
+------------------+     +------------------+  |
|    variables     |<--->|    realtimes     |  |
+------------------+     +------------------+  |
       ^                        |              |
       |                        v              |
       |                 +------------------+  |
       |                 |   controllers    |<-+
       |                 +------------------+
       |                        |
       |                        v
       |                 +------------------+
       +-----------------|    providers     |
                         +------------------+
                                |
                                v
                         +------------------+
                         |      sites       |
                         +------------------+
```

---

## Veri Akisi

### Okuma Akisi (Site'dan Variable'a)

```
1. Site secilir
2. Site'a bagli Controllers listelenir
3. Controller'a bagli Realtimes listelenir
4. Realtime'daki variable_id ile Variables alinir
5. Variable degerleri gosterilir
```

### Yazma Akisi (Komut Gonderme)

```
1. Variable secilir (variable_type = 'COMMAND')
2. Realtimes uzerinden Controller bulunur
3. Controller'in IP/protokol bilgileri alinir
4. Provider uzerinden (varsa) komut gonderilir
5. Variable.value guncellenir
```

---

## Eksiklikler ve Oneriler

### Controllers

| Eksik | Oneri | Oncelik |
|-------|-------|---------|
| Durum enum | `status` CHECK constraint ekle | Yuksek |
| Son hata bilgisi | `last_error`, `last_error_time` ekle | Orta |
| Yeniden baslama sayaci | `restart_count` ekle | Dusuk |
| Firmware versiyonu | `firmware_version` ekle | Orta |

### Providers

| Eksik | Oneri | Oncelik |
|-------|-------|---------|
| Controller sayisi | `controller_count` (computed) ekle | Dusuk |
| Baglanti durumu | `connection_status` enum ekle | Yuksek |
| Son basarili sync | `last_successful_sync` ekle | Orta |

### Variables

| Eksik | Oneri | Oncelik |
|-------|-------|---------|
| **Controller FK** | `controller_id` EKLE! | KRITIK |
| Son okunan deger | `last_read_value`, `last_read_time` ekle | Yuksek |
| Alarm limitleri | `low_alarm`, `high_alarm` ekle | Orta |
| Trend bilgisi | `trend_direction`, `trend_rate` ekle | Dusuk |
| Kalibrasyon | `calibration_date`, `calibration_factor` ekle | Orta |

### Genel

| Konu | Oneri | Oncelik |
|------|-------|---------|
| Variable-Controller iliskisi | Dogrudan FK ekle veya view olustur | KRITIK |
| Device entegrasyonu | `devices` tablosu ile daha iyi entegrasyon | Orta |
| Protokol detaylari | Protokol bazli konfigurasyonlar icin ayri tablo | Dusuk |

---

## Onerilen View: controller_variables

```sql
CREATE VIEW controller_variables AS
SELECT
    c.id as controller_id,
    c.name as controller_name,
    c.site_id,
    v.id as variable_id,
    v.name as variable_name,
    v.variable_type,
    v.value,
    v.unit,
    r.id as realtime_id
FROM controllers c
JOIN realtimes r ON r.controller_id = c.id
JOIN variables v ON v.id = r.variable_id
WHERE c.active = true
  AND r.active = true
  AND v.active = true;
```

Bu view, Variable-Controller iliskisini kolaylastirir.
