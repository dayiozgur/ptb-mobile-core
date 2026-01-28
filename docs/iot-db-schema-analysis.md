# IoT Katmanı - Veritabanı Analiz Raporu

## 1. Genel Bakış

Bu doküman, ptb-mobile-core projesindeki IoT katmanının gerçek Supabase veritabanı şemasını
analiz ederek elde edilen bulguları içerir. Dart modelleri ile DB arasındaki farklılıklar
tespit edilmiş ve düzeltme planı oluşturulmuştur.

### Veri Özeti

| Tablo | Kayıt Sayısı | Açıklama |
|-------|-------------|----------|
| providers | 18 | Supervisor/Gateway cihazları |
| controllers | 219 | PLC, RTU, Gateway donanım cihazları |
| variables | 7838 | Variable şablonları (device_model bazlı) |
| realtimes | ~6000+ | Controller-Variable runtime bağlantıları |
| device_models | 36+ | Cihaz model tanımları |
| workflows | 0 | İş akışları (IoT workflow değil, iş emirleri) |
| sites | 13 | Lokasyonlar |
| units | 149 | Alt birimler |

---

## 2. Gerçek DB Tablo Şemaları

### 2.1 providers Tablosu

> **ÖNEMLİ:** Model'deki sınıf adı `DataProvider`, DB tablo adı `providers`.
> DB'de `type` kolonu **YOK**. Protocol tipi `protocol_type_id` FK ile yönetilir.

| Kolon | Tip | Nullable | Açıklama |
|-------|-----|----------|----------|
| id | uuid | NO | PK |
| name | varchar | YES | Provider adı |
| code | varchar | YES | Benzersiz kod |
| description | varchar | YES | Açıklama |
| active | boolean | YES | Aktif durumu |
| ip | varchar | YES | IP adresi |
| hostname | varchar | YES | Hostname |
| password | varchar | YES | Şifre |
| mac | varchar | YES | MAC adresi |
| app_version | varchar | YES | Uygulama versiyonu |
| sys_version | varchar | YES | Sistem versiyonu |
| uptime | varchar | YES | Uptime bilgisi |
| color | varchar | YES | Renk kodu |
| image_path | varchar | YES | Görsel yolu |
| has_alarm | boolean | YES | Alarm durumu |
| life_test | boolean | YES | Yaşam testi |
| **tenant_id** | uuid | YES | FK → tenants |
| **site_id** | uuid | NO | FK → sites |
| **brand_id** | uuid | NO | FK → brands |
| **protocol_type_id** | uuid | NO | FK → protocol_types |
| **supervisor_type_id** | uuid | NO | FK → supervisor_types |
| **language_id** | uuid | NO | FK → languages |
| **marker_id** | uuid | NO | FK → markers |
| **unit_id** | uuid | YES | FK → units |
| **device_id** | uuid | YES | FK → devices |
| **area_id** | uuid | YES | FK → areas |
| **device_item_id** | uuid | YES | FK → items |
| **inventory_item_id** | uuid | YES | FK → inventory_items |
| configuration_time | timestamptz | YES | |
| first_communication_time | timestamptz | YES | |
| first_connection_time | timestamptz | YES | |
| last_communication_time | timestamptz | YES | |
| last_connection_time | timestamptz | YES | |
| ftp_username | varchar | YES | FTP kullanıcı |
| ftp_password | varchar | YES | FTP şifre |
| http_username | varchar | YES | HTTP kullanıcı |
| http_password | varchar | YES | HTTP şifre |
| proxy_prefix | varchar | YES | Proxy prefix |
| created_at | timestamptz | YES | |
| updated_at | timestamptz | YES | |
| created_by | uuid | YES | |
| updated_by | uuid | YES | |

**Model'de olup DB'de olmayan kolonlar:**
- `type` → DB'de `protocol_type_id` (FK) olarak var
- `status` → DB'de yok
- `host` → DB'de `ip` ve `hostname` olarak var
- `port` → DB'de yok
- `connection_string` → DB'de yok
- `collection_mode` → DB'de yok
- `polling_interval` → DB'de yok
- `batch_size` → DB'de yok
- `timeout` → DB'de yok
- `retry_count` → DB'de yok
- `retry_interval` → DB'de yok
- `use_ssl` → DB'de yok
- `certificate_path` → DB'de yok

---

### 2.2 controllers Tablosu

| Kolon | Tip | Nullable | Açıklama |
|-------|-----|----------|----------|
| id | uuid | NO | PK |
| name | varchar | YES | Controller adı |
| code | varchar | YES | Benzersiz kod |
| description | varchar | YES | Açıklama |
| active | boolean | YES | Aktif durumu |
| ip | varchar | YES | IP adresi |
| mac | varchar | YES | MAC adresi |
| serial | varchar | YES | Seri numarası |
| model_code | varchar | YES | Model kodu |
| is_enabled | boolean | YES | Etkin durumu |
| is_canceled | boolean | NO | İptal durumu |
| is_logic | boolean | YES | Mantıksal controller |
| global_index | integer | YES | Global index |
| id_group | integer | YES | Grup ID |
| little_endian | boolean | YES | Byte sırası |
| peripheral | varchar | YES | Peripheral bilgisi |
| line | varchar | YES | Hat bilgisi |
| line_address | varchar | YES | Hat adresi |
| cf_address | integer | YES | CF adresi |
| cf_code | varchar | YES | CF kodu |
| cf_description | varchar | YES | CF açıklaması |
| color | varchar | YES | Renk kodu |
| image_path | varchar | YES | Görsel yolu |
| background_path | varchar | YES | Arkaplan görseli |
| has_alarm | boolean | YES | Alarm durumu |
| life_test | boolean | YES | Yaşam testi |
| **tenant_id** | uuid | YES | FK → tenants |
| **site_id** | uuid | NO | FK → sites |
| **provider_id** | uuid | YES | FK → providers |
| **unit_id** | uuid | YES | FK → units |
| **brand_id** | uuid | NO | FK → brands |
| **device_model_id** | uuid | YES | FK → device_models |
| **protocol_type_id** | uuid | YES | FK → protocol_types |
| **supervisor_type_id** | uuid | YES | FK → supervisor_types |
| **device_id** | uuid | YES | FK → devices |
| **contractor_id** | uuid | YES | FK → contractors |
| **language_id** | uuid | YES | FK → languages |
| **marker_id** | uuid | YES | FK → markers |
| **ftp_user_id** | uuid | YES | FK → ftp_users |
| **area_id** | uuid | YES | FK → areas |
| **device_item_id** | uuid | YES | FK → items |
| **inventory_item_id** | uuid | YES | FK → inventory_items |
| first_communication_time | timestamptz | YES | |
| first_connection_time | timestamptz | YES | |
| last_communication_time | timestamptz | YES | |
| last_connection_time | timestamptz | YES | |
| last_update_time | timestamptz | YES | |
| insert_time | timestamptz | YES | |
| ftp_username/password | varchar | YES | FTP bilgileri |
| http_username/password | varchar | YES | HTTP bilgileri |
| proxy_prefix | varchar | YES | |
| address, city, country, town | varchar | YES | Lokasyon bilgileri |
| latitude, longitude | double | YES | Koordinatlar |
| zoom | integer | YES | |
| created_at | timestamptz | YES | |
| updated_at | timestamptz | YES | |

**Model'de olup DB'de olmayan kolonlar:**
- `type` → DB'de `supervisor_type_id` (FK) olarak var
- `status` → DB'de yok (is_enabled, is_canceled ile yönetilir)
- `protocol` → DB'de `protocol_type_id` (FK) olarak var
- `ip_address` → DB'de `ip` olarak var
- `firmware_version` → DB'de yok
- `connection_timeout` → DB'de yok
- `read_timeout` → DB'de yok
- `retry_count` → DB'de yok
- `retry_interval` → DB'de yok

---

### 2.3 variables Tablosu

> **KRİTİK:** Bu tabloda `controller_id` ve `tenant_id` kolonu **YOK**.
> Controller-Variable ilişkisi `realtimes` tablosu veya `device_model_id` üzerinden sağlanır.

| Kolon | Tip | Nullable | Açıklama |
|-------|-----|----------|----------|
| id | uuid | NO | PK |
| name | varchar | YES | Variable adı |
| code | varchar | YES | Benzersiz kod |
| description | varchar | YES | Açıklama |
| active | boolean | YES | Aktif durumu |
| **data_type** | varchar | NO | Veri tipi |
| **status** | varchar | NO | Durum |
| type | varchar | YES | Variable tipi |
| variable_type | varchar | YES | Alt tip |
| value | varchar | YES | Mevcut değer |
| unit | varchar | YES | Birim (°C, kW, vb.) |
| measure_unit | varchar | YES | Ölçü birimi |
| minimum | varchar | YES | Min değer |
| maximum | varchar | YES | Max değer |
| min_value | numeric | YES | Min (numeric) |
| max_value | numeric | YES | Max (numeric) |
| default_value | varchar | YES | Varsayılan değer |
| address_input | integer | YES | Giriş adresi |
| address_output | integer | YES | Çıkış adresi |
| bit_position | integer | YES | Bit pozisyonu |
| dimension | integer | YES | Boyut |
| length | integer | YES | Uzunluk |
| decimal | boolean | YES | Ondalıklı mı |
| signed | boolean | YES | İşaretli mi |
| read_only | boolean | YES | Salt okunur mu |
| read_write | integer | YES | R/W modu |
| func_type_read | integer | YES | Okuma fonksiyon tipi |
| func_type_write | integer | YES | Yazma fonksiyon tipi |
| function_code | varchar | YES | Fonksiyon kodu |
| var_encoding | integer | YES | Encoding |
| is_active | boolean | YES | Aktif mi |
| is_cancelled | boolean | YES | İptal mi |
| is_logged | boolean | YES | Loglanıyor mu |
| is_logic | boolean | YES | Mantıksal mı |
| is_on_change | boolean | YES | Değişiklikte mi |
| ishaccp | boolean | YES | HACCP mi |
| frequency | varchar | YES | Frekans |
| delay | varchar | YES | Gecikme |
| delta | varchar | YES | Delta |
| color | varchar | YES | Renk |
| grp_category | varchar | YES | Grup kategorisi |
| id_group | integer | YES | Grup ID |
| image_on | varchar | YES | ON görseli |
| image_off | varchar | YES | OFF görseli |
| button_path | varchar | YES | Buton yolu |
| to_display | varchar | YES | Gösterilecek |
| time_series_enabled | boolean | YES | Zaman serisi |
| **device_model_id** | uuid | YES | FK → device_models |
| **priority_id** | uuid | YES | FK → priorities |
| **origin_priority_id** | uuid | YES | FK → priorities |
| a_value | double | YES | A katsayısı |
| b_value | double | YES | B katsayısı |
| last_update | timestamptz | YES | Son güncelleme |
| insert_time | timestamptz | YES | |
| created_at | timestamptz | YES | |
| updated_at | timestamptz | YES | |

**Model'de olup DB'de olmayan kolonlar:**
- `controller_id` → **YOK** (realtimes tablosu ile ilişkilendirilir)
- `tenant_id` → **YOK**
- `access_mode` → DB'de `read_only` ve `read_write` olarak var
- `category` → DB'de `grp_category` olarak var
- `address` → DB'de `address_input` ve `address_output` olarak var
- `raw_min/max`, `scaled_min/max` → DB'de `min_value/max_value` + `a_value/b_value`
- `quality` → DB'de yok
- `lolo_limit/lo_limit/hi_limit/hihi_limit` → DB'de yok
- `deadband` → DB'de yok
- `tags` → DB'de yok
- `metadata` → DB'de yok

---

### 2.4 realtimes Tablosu (Junction)

> **KRİTİK:** Controller-Variable ilişkisini sağlayan ana tablo.
> Provider izolasyonu bu tablo üzerinden gerçekleşir.

| Kolon | Tip | Nullable | Açıklama |
|-------|-----|----------|----------|
| id | uuid | NO | PK |
| name | varchar | YES | Realtime adı |
| code | varchar | YES | Kod |
| description | varchar | YES | Açıklama |
| active | boolean | YES | Aktif durumu |
| is_loggable | boolean | YES | Loglanabilir mi |
| **controller_id** | uuid | YES | FK → controllers |
| **variable_id** | uuid | YES | FK → variables |
| **device_model_id** | uuid | YES | FK → device_models |
| **priority_id** | uuid | YES | FK → priorities |
| **cancelled_controller_id** | uuid | YES | FK → cancelled_controllers |
| created_at | timestamptz | YES | |
| updated_at | timestamptz | YES | |
| created_by | uuid | YES | |
| updated_by | uuid | YES | |

---

### 2.5 device_models Tablosu

| Kolon | Tip | Nullable | Açıklama |
|-------|-----|----------|----------|
| id | uuid | NO | PK |
| name | varchar | YES | Model adı |
| code | varchar | YES | Model kodu |
| description | varchar | YES | Açıklama |
| active | boolean | YES | Aktif durumu |
| protocol | varchar | YES | Protokol |
| version | varchar | YES | Versiyon |
| image_path | varchar | YES | Görsel yolu |
| **brand_id** | uuid | YES | FK → brands |
| **organization_id** | uuid | YES | FK → organizations |
| **device_type_id** | uuid | YES | FK → device_types |
| **language_id** | uuid | YES | FK → languages |
| created_at | timestamptz | YES | |
| updated_at | timestamptz | YES | |

---

### 2.6 workflows Tablosu

> **ÖNEMLİ:** Bu tablo IoT otomasyonu değil, **iş akışı / work request** yönetimi için kullanılır.
> IoT workflow modeli bu tabloyla uyumlu değildir.

| Kolon | Tip | Nullable | Açıklama |
|-------|-----|----------|----------|
| active | boolean | YES | |
| code | varchar | YES | |
| description | varchar | YES | |
| name | varchar | YES | |
| title | varchar | YES | |
| **work_request_id** | uuid | NO | FK → work_requests |
| **tenant_id** | uuid | YES | FK → tenants |
| **business_interaction_id** | uuid | YES | |
| **project_work_request_id** | uuid | YES | |

**NOT:** `id` kolonu bile yok (PK yok). Bu tablo mevcut IoT Workflow modeli ile uyumlu değildir.
Workflow fonksiyonalitesi şimdilik devre dışı bırakılmalıdır.

---

### 2.7 sites Tablosu

| Kolon | Tip | Nullable | Açıklama |
|-------|-----|----------|----------|
| id | uuid | NO | PK |
| name | varchar | YES | Site adı |
| code | varchar | YES | Site kodu |
| description | varchar | YES | Açıklama |
| active | boolean | YES | |
| color | varchar | YES | |
| image_path | varchar | YES | |
| address | varchar | YES | Adres |
| city | varchar | YES | Şehir |
| country | varchar | YES | Ülke |
| town | varchar | YES | İlçe |
| latitude | double | YES | Enlem |
| longitude | double | YES | Boylam |
| zoom | integer | YES | Harita zoom |
| **tenant_id** | uuid | YES | FK → tenants |
| **organization_id** | uuid | NO | FK → organizations |
| **marker_id** | uuid | NO | FK → markers |
| **site_group_id** | uuid | YES | FK → site_groups |
| **site_type_id** | uuid | YES | FK → site_types |
| has_main_unit | boolean | YES | |
| gross_area_sqm | numeric | YES | Brüt alan |
| net_area_sqm | numeric | YES | Net alan |
| floor_count | integer | YES | Kat sayısı |
| year_built | integer | YES | Yapım yılı |
| operating_since | date | YES | |
| climate_zone | varchar | YES | İklim bölgesi |
| energy_certificate_class | varchar | YES | Enerji sınıfı |
| working_time_active | boolean | YES | |
| monday_start_time - sunday_end_time | time | YES | Çalışma saatleri |

---

### 2.8 units Tablosu

| Kolon | Tip | Nullable | Açıklama |
|-------|-----|----------|----------|
| id | uuid | NO | PK |
| name | varchar | YES | Unit adı |
| code | varchar | YES | Unit kodu |
| description | varchar | YES | |
| active | boolean | YES | |
| area_size | double | YES | Alan boyutu |
| **tenant_id** | uuid | YES | FK → tenants |
| **site_id** | uuid | YES | FK → sites |
| **organization_id** | uuid | YES | FK → organizations |
| **parent_unit_id** | uuid | YES | FK → units (self) |
| **unit_type_id** | uuid | YES | FK → unit_types |
| **area_id** | uuid | YES | FK → areas |
| **contractor_id** | uuid | YES | FK → contractors |
| is_main_area | boolean | YES | Ana alan mı |
| is_deletable | boolean | YES | Silinebilir mi |
| image_bucket | varchar | YES | Görsel bucket |
| working_time_active | boolean | YES | |
| monday_start_time - sunday_end_time | time | YES | Çalışma saatleri |

---

## 3. Lookup Tabloları (FK Referansları)

Aşağıdaki tablolar DB'de FK olarak kullanılır, model'lerde enum olarak tanımlıdır:

| FK Kolonu | DB Tablosu | Model'deki Enum | Durum |
|-----------|-----------|-----------------|-------|
| protocol_type_id | protocol_types | CommunicationProtocol | ❌ Uyumsuz |
| supervisor_type_id | supervisor_types | ControllerType | ❌ Uyumsuz |
| brand_id | brands | - | Model'de yok |
| device_type_id | device_types | - | Model'de yok |
| marker_id | markers | - | Model'de yok |
| priority_id | priorities | - | Model'de yok |
| site_type_id | site_types | - | Model'de yok |
| unit_type_id | unit_types | - | Model'de yok |
| site_group_id | site_groups | - | Model'de yok |

---

## 4. Tablo İlişkileri

### 4.1 Controllers FK İlişkileri

| FK Kolon | Hedef Tablo | Açıklama |
|----------|-------------|----------|
| provider_id | providers | Veri sağlayıcı |
| brand_id | brands | Marka |
| device_model_id | device_models | Cihaz modeli |
| device_id | devices | Fiziksel cihaz |
| protocol_type_id | protocol_types | İletişim protokolü |
| site_id | sites | Lokasyon |
| tenant_id | tenants | Kiracı |
| contractor_id | contractors | Yüklenici |
| supervisor_type_id | supervisor_types | Controller tipi |
| marker_id | markers | Harita marker'ı |
| unit_id | units | Alt birim |
| ftp_user_id | ftp_users | FTP kullanıcısı |
| area_id | areas | Alan |
| device_item_id | items | Envanter öğesi |
| inventory_item_id | inventory_items | Stok öğesi |

### 4.2 Variables FK İlişkileri

| FK Kolon | Hedef Tablo | Açıklama |
|----------|-------------|----------|
| device_model_id | device_models | Cihaz modeli (template bağlantısı) |
| origin_priority_id | priorities | Orijinal öncelik |
| priority_id | priorities | Mevcut öncelik |

---

## 5. Tüm DB Tabloları

DB'deki toplam tablo sayısı: **250+**

### IoT İlişkili Tablolar
```
providers
controllers
controller_device_models
variables
variable_templates
variable_reports
variable_report_controllers
variable_report_realtimes
realtimes
report_template_realtimes
report_template_controllers
report_template_variables
device_models
device_properties
device_types
device_variables
devices
cancelled_controllers
supervisor_controllers
supervisor_types
compressor_group_controllers
compressor_group_templates
compressor_variables
compressor_groups
energy_group_controllers
energy_group_templates
energy_groups
energy_variables
energy_configurations
energy_consumptions
kpi_group_controllers
kpi_groups
log_report_controllers
log_reports
provider_device_infos
provider_device_info_histories
provider_monitoring_configs
provider_preferences
protocol_types
brands
alarms
alarm_histories
alarm_statistics
alarm_anomalies
alarm_correlations
alarm_patterns
alarm_predictions
```

### Organizasyon Tabloları
```
tenants
organizations
sites
site_types
site_groups
site_group_memberships
units
unit_types
areas
```

### Workflow / İş Emri Tabloları
```
workflows
workflow_stages
workflow_steps
workflow_templates
workflow_versions
workflow_executions
workflow_histories
workflow_contractors
workflow_staffs
workflow_teams
workflow_sub_contractors
work_requests
work_request_types
work_request_characteristics
```
