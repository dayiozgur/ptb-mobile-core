# IoT Model-DB Kolon Eşleştirme Raporu

Bu doküman, Dart model alanlarının gerçek DB kolonlarıyla eşleştirmesini ve uyumsuzlukları detaylı olarak belirtir.
Ana projede model düzeltmeleri yapılırken bu doküman referans alınmalıdır.

---

## 1. DataProvider Model ↔ providers Tablosu

### Eşleşen Alanlar

| Dart Alanı | JSON Key | DB Kolonu | Durum |
|-----------|----------|-----------|-------|
| id | `id` | id (uuid) | ✅ Eşleşiyor |
| name | `name` | name (varchar) | ✅ Eşleşiyor |
| tenantId | `tenant_id` | tenant_id (uuid) | ✅ Eşleşiyor |
| code | `code` | code (varchar) | ✅ Eşleşiyor |
| description | `description` | description (varchar) | ✅ Eşleşiyor |
| active | `active` | active (boolean) | ✅ Eşleşiyor |
| password | `password` | password (varchar) | ✅ Eşleşiyor |
| createdAt | `created_at` | created_at (timestamptz) | ✅ Eşleşiyor |
| updatedAt | `updated_at` | updated_at (timestamptz) | ✅ Eşleşiyor |
| createdBy | `created_by` | created_by (uuid) | ✅ Eşleşiyor |
| updatedBy | `updated_by` | updated_by (uuid) | ✅ Eşleşiyor |

### Uyumsuz Alanlar

| Dart Alanı | JSON Key | DB Karşılığı | Gerekli Aksiyon |
|-----------|----------|--------------|-----------------|
| type | `type` | **YOK** → `protocol_type_id` (FK) | Enum → FK dönüşümü gerekli |
| status | `status` | **YOK** | Kaldırılmalı veya hesaplanan alan olmalı |
| host | `host` | `ip` + `hostname` | İki ayrı alana bölünmeli |
| port | `port` | **YOK** | Kaldırılmalı |
| username | `username` | **YOK** (ftp_username, http_username var) | Bölünmeli |
| useSsl | `use_ssl` | **YOK** | Kaldırılmalı |
| certificatePath | `certificate_path` | **YOK** | Kaldırılmalı |
| connectionString | `connection_string` | **YOK** | Kaldırılmalı |
| collectionMode | `collection_mode` | **YOK** | Kaldırılmalı |
| pollingInterval | `polling_interval` | **YOK** | Kaldırılmalı |
| batchSize | `batch_size` | **YOK** | Kaldırılmalı |
| timeout | `timeout` | **YOK** | Kaldırılmalı |
| retryCount | `retry_count` | **YOK** | Kaldırılmalı |
| retryInterval | `retry_interval` | **YOK** | Kaldırılmalı |
| lastConnectedAt | `last_connected_at` | `last_connection_time` | Rename gerekli |
| lastError | `last_error` | **YOK** | Kaldırılmalı |
| lastErrorAt | `last_error_at` | **YOK** | Kaldırılmalı |
| variableCount | `variable_count` | **YOK** (hesaplanan alan) | Hesaplanan alan olarak kalabilir |
| controllerCount | `controller_count` | **YOK** (hesaplanan alan) | Hesaplanan alan olarak kalabilir |
| config | `config` | **YOK** | Kaldırılmalı |
| tags | `tags` | **YOK** | Kaldırılmalı |

### DB'de Olup Model'de Olmayan Alanlar

| DB Kolonu | Tip | Açıklama | Gerekli Aksiyon |
|-----------|-----|----------|-----------------|
| site_id | uuid (FK) | Site bağlantısı | Eklenmeli |
| brand_id | uuid (FK) | Marka referansı | Eklenmeli |
| protocol_type_id | uuid (FK) | Protokol tipi | `type` enum yerine |
| supervisor_type_id | uuid (FK) | Supervisor tipi | Eklenmeli |
| language_id | uuid (FK) | Dil | Eklenmeli |
| marker_id | uuid (FK) | Harita marker'ı | Eklenmeli |
| unit_id | uuid (FK) | Unit bağlantısı | Eklenmeli |
| device_id | uuid (FK) | Cihaz referansı | Eklenmeli |
| area_id | uuid (FK) | Alan referansı | Eklenmeli |
| ip | varchar | IP adresi | `host` yerine |
| hostname | varchar | Hostname | `host` yerine |
| mac | varchar | MAC adresi | Eklenmeli |
| app_version | varchar | Uygulama versiyonu | Eklenmeli |
| sys_version | varchar | Sistem versiyonu | Eklenmeli |
| uptime | varchar | Uptime | Eklenmeli |
| color | varchar | Renk kodu | Eklenmeli |
| image_path | varchar | Görsel | Eklenmeli |
| has_alarm | boolean | Alarm durumu | Eklenmeli |
| life_test | boolean | Yaşam testi | Eklenmeli |
| configuration_time | timestamptz | Konfigürasyon zamanı | Eklenmeli |
| first_communication_time | timestamptz | İlk iletişim | Eklenmeli |

---

## 2. Controller Model ↔ controllers Tablosu

### Eşleşen Alanlar

| Dart Alanı | JSON Key | DB Kolonu | Durum |
|-----------|----------|-----------|-------|
| id | `id` | id (uuid) | ✅ Eşleşiyor |
| name | `name` | name (varchar) | ✅ Eşleşiyor |
| tenantId | `tenant_id` | tenant_id (uuid) | ✅ Eşleşiyor |
| code | `code` | code (varchar) | ✅ Eşleşiyor |
| description | `description` | description (varchar) | ✅ Eşleşiyor |
| active | `active` | active (boolean) | ✅ Eşleşiyor |
| siteId | `site_id` | site_id (uuid) | ✅ Eşleşiyor |
| unitId | `unit_id` | unit_id (uuid) | ✅ Eşleşiyor |
| providerId | `provider_id` | provider_id (uuid) | ✅ Eşleşiyor |
| createdAt | `created_at` | created_at (timestamptz) | ✅ Eşleşiyor |
| updatedAt | `updated_at` | updated_at (timestamptz) | ✅ Eşleşiyor |

### Uyumsuz Alanlar

| Dart Alanı | JSON Key | DB Karşılığı | Gerekli Aksiyon |
|-----------|----------|--------------|-----------------|
| type | `type` | **YOK** → `supervisor_type_id` (FK) | Enum → FK dönüşümü |
| brand | `brand` | `brand_id` (FK) | String → FK dönüşümü |
| model | `model` | `model_code` (varchar) | Rename gerekli |
| serialNumber | `serial_number` | `serial` (varchar) | Rename gerekli |
| firmwareVersion | `firmware_version` | **YOK** | Kaldırılmalı |
| protocol | `protocol` | `protocol_type_id` (FK) | Enum → FK dönüşümü |
| ipAddress | `ip_address` | `ip` (varchar) | Rename gerekli |
| port | `port` | **YOK** | Kaldırılmalı |
| slaveId | `slave_id` | **YOK** | Kaldırılmalı |
| connectionString | `connection_string` | **YOK** | Kaldırılmalı |
| connectionTimeout | `connection_timeout` | **YOK** | Kaldırılmalı |
| readTimeout | `read_timeout` | **YOK** | Kaldırılmalı |
| retryCount | `retry_count` | **YOK** | Kaldırılmalı |
| retryInterval | `retry_interval` | **YOK** | Kaldırılmalı |
| status | `status` | **YOK** → `is_enabled` + `is_canceled` | Bool alanlarına dönüşmeli |
| lastConnectedAt | `last_connected_at` | `last_connection_time` | Rename gerekli |
| lastDataAt | `last_data_at` | `last_communication_time` | Rename gerekli |
| lastError | `last_error` | **YOK** | Kaldırılmalı |
| lastErrorAt | `last_error_at` | **YOK** | Kaldırılmalı |
| uptimeSeconds | `uptime_seconds` | **YOK** | Kaldırılmalı |
| tags | `tags` | **YOK** | Kaldırılmalı |
| metadata | `metadata` | **YOK** | Kaldırılmalı |
| createdBy | `created_by` | **YOK** (audit yok) | Kaldırılmalı |
| updatedBy | `updated_by` | **YOK** (audit yok) | Kaldırılmalı |

### DB'de Olup Model'de Olmayan Alanlar

| DB Kolonu | Tip | Açıklama | Gerekli Aksiyon |
|-----------|-----|----------|-----------------|
| device_model_id | uuid (FK) | Cihaz modeli | **KRİTİK** - Eklenmeli |
| brand_id | uuid (FK) | Marka referansı | Eklenmeli |
| protocol_type_id | uuid (FK) | Protokol tipi | Eklenmeli |
| supervisor_type_id | uuid (FK) | Supervisor tipi | Eklenmeli |
| device_id | uuid (FK) | Cihaz referansı | Eklenmeli |
| contractor_id | uuid (FK) | Yüklenici | Eklenmeli |
| language_id | uuid (FK) | Dil | Eklenmeli |
| marker_id | uuid (FK) | Harita marker'ı | Eklenmeli |
| ftp_user_id | uuid (FK) | FTP kullanıcısı | Eklenmeli |
| area_id | uuid (FK) | Alan referansı | Eklenmeli |
| mac | varchar | MAC adresi | Eklenmeli |
| serial | varchar | Seri numarası | `serialNumber` yerine |
| model_code | varchar | Model kodu | Eklenmeli |
| is_enabled | boolean | Etkin durumu | `status` yerine |
| is_canceled | boolean | İptal durumu | Eklenmeli |
| is_logic | boolean | Mantıksal | Eklenmeli |
| global_index | integer | Global index | Eklenmeli |
| little_endian | boolean | Byte sırası | Eklenmeli |
| peripheral | varchar | Peripheral | Eklenmeli |
| line, line_address | varchar | Hat bilgileri | Eklenmeli |
| cf_address, cf_code, cf_description | mixed | CF bilgileri | Eklenmeli |
| color | varchar | Renk | Eklenmeli |
| image_path | varchar | Görsel | Eklenmeli |
| has_alarm | boolean | Alarm durumu | Eklenmeli |
| life_test | boolean | Yaşam testi | Eklenmeli |
| address, city, country, town | varchar | Lokasyon | Eklenmeli |
| latitude, longitude | double | Koordinatlar | Eklenmeli |

---

## 3. Variable Model ↔ variables Tablosu

### KRİTİK UYUMSUZLUKLAR

| Dart Alanı | JSON Key | DB Durumu | Önemi |
|-----------|----------|-----------|-------|
| **controllerId** | `controller_id` | **DB'DE YOK** | ❌ KRİTİK - Realtimes üzerinden erişilmeli |
| **tenantId** | `tenant_id` | **DB'DE YOK** | ❌ KRİTİK - Doğrudan filtreleme yapılamaz |

### Eşleşen Alanlar

| Dart Alanı | JSON Key | DB Kolonu | Durum |
|-----------|----------|-----------|-------|
| id | `id` | id (uuid) | ✅ Eşleşiyor |
| name | `name` | name (varchar) | ✅ Eşleşiyor |
| code | `code` | code (varchar) | ✅ Eşleşiyor |
| description | `description` | description (varchar) | ✅ Eşleşiyor |
| dataType | `data_type` | data_type (varchar) | ✅ Eşleşiyor |
| active | `active` | active (boolean) | ✅ Eşleşiyor |
| unit | `unit` | unit (varchar) | ✅ Eşleşiyor |
| bitPosition | `bit_position` | bit_position (integer) | ✅ Eşleşiyor |
| decimals | `decimals` | decimal (boolean) | ⚠️ Tip farkı (int vs bool) |
| createdAt | `created_at` | created_at (timestamptz) | ✅ Eşleşiyor |
| updatedAt | `updated_at` | updated_at (timestamptz) | ✅ Eşleşiyor |

### Uyumsuz Alanlar

| Dart Alanı | JSON Key | DB Karşılığı | Gerekli Aksiyon |
|-----------|----------|--------------|-----------------|
| controllerId | `controller_id` | **YOK** | Kaldırılmalı, realtimes üzerinden |
| tenantId | `tenant_id` | **YOK** | Kaldırılmalı |
| accessMode | `access_mode` | `read_only` (bool) + `read_write` (int) | Ayrı alanlara bölünmeli |
| category | `category` | `grp_category` (varchar) | Rename gerekli |
| address | `address` | `address_input` + `address_output` | İkiye bölünmeli |
| registerType | `register_type` | **YOK** | Kaldırılmalı |
| byteOrder | `byte_order` | **YOK** | Kaldırılmalı |
| rawMin | `raw_min` | `min_value` (numeric) | Rename gerekli |
| rawMax | `raw_max` | `max_value` (numeric) | Rename gerekli |
| scaledMin | `scaled_min` | `a_value` (double) | Dönüşüm mantığı farklı |
| scaledMax | `scaled_max` | `b_value` (double) | Dönüşüm mantığı farklı |
| loLoLimit | `lolo_limit` | **YOK** | Kaldırılmalı |
| loLimit | `lo_limit` | **YOK** | Kaldırılmalı |
| hiLimit | `hi_limit` | **YOK** | Kaldırılmalı |
| hiHiLimit | `hihi_limit` | **YOK** | Kaldırılmalı |
| deadband | `deadband` | **YOK** | Kaldırılmalı |
| currentValue | `current_value` | `value` (varchar) | Rename gerekli |
| quality | `quality` | **YOK** | Kaldırılmalı |
| lastUpdatedAt | `last_updated_at` | `last_update` | Rename gerekli |
| lastChangedAt | `last_changed_at` | **YOK** | Kaldırılmalı |
| unitId | `unit_id` | **YOK** | Kaldırılmalı |
| tags | `tags` | **YOK** | Kaldırılmalı |
| metadata | `metadata` | **YOK** | Kaldırılmalı |
| createdBy | `created_by` | **YOK** | Kaldırılmalı |
| updatedBy | `updated_by` | **YOK** | Kaldırılmalı |

### DB'de Olup Model'de Olmayan Alanlar

| DB Kolonu | Tip | Açıklama | Gerekli Aksiyon |
|-----------|-----|----------|-----------------|
| device_model_id | uuid (FK) | Cihaz modeli bağlantısı | **KRİTİK** - Eklenmeli |
| priority_id | uuid (FK) | Öncelik | Eklenmeli |
| origin_priority_id | uuid (FK) | Orijinal öncelik | Eklenmeli |
| status | varchar | Durum | Eklenmeli |
| type | varchar | Tip | Eklenmeli |
| variable_type | varchar | Alt tip | Eklenmeli |
| measure_unit | varchar | Ölçü birimi | Eklenmeli |
| minimum, maximum | varchar | Min/Max (string) | Eklenmeli |
| default_value | varchar | Varsayılan değer | Eklenmeli |
| dimension | integer | Boyut | Eklenmeli |
| length | integer | Uzunluk | Eklenmeli |
| signed | boolean | İşaretli | Eklenmeli |
| read_write | integer | R/W modu | Eklenmeli |
| func_type_read | integer | Okuma fonksiyon tipi | Eklenmeli |
| func_type_write | integer | Yazma fonksiyon tipi | Eklenmeli |
| function_code | varchar | Fonksiyon kodu | Eklenmeli |
| var_encoding | integer | Encoding | Eklenmeli |
| is_active | boolean | Aktif mi | `active` ile çakışma kontrolü |
| is_cancelled | boolean | İptal | Eklenmeli |
| is_logged | boolean | Loglanıyor mu | Eklenmeli |
| is_logic | boolean | Mantıksal | Eklenmeli |
| is_on_change | boolean | Değişiklikte | Eklenmeli |
| ishaccp | boolean | HACCP | Eklenmeli |
| frequency | varchar | Frekans | Eklenmeli |
| delay | varchar | Gecikme | Eklenmeli |
| delta | varchar | Delta | Eklenmeli |
| color | varchar | Renk | Eklenmeli |
| image_on, image_off | varchar | ON/OFF görselleri | Eklenmeli |
| button_path | varchar | Buton yolu | Eklenmeli |
| to_display | varchar | Gösterilecek | Eklenmeli |
| time_series_enabled | boolean | Zaman serisi | Eklenmeli |
| a_value, b_value | double | Katsayılar | Eklenmeli |

---

## 4. Workflow Model ↔ workflows Tablosu

### TAMAMEN UYUMSUZ

Dart'taki Workflow modeli IoT otomasyon workflow'u olarak tasarlanmıştır.
DB'deki workflows tablosu ise **iş emri (work request)** yönetimi için kullanılmaktadır.

| Dart Model | DB Gerçeği |
|-----------|------------|
| IoT otomasyon (trigger, action, condition) | İş emri yönetimi (work_request_id) |
| id (uuid, PK) | id kolonu **YOK** |
| type (automation, scheduled, event_driven) | **YOK** |
| status (draft, active, paused) | **YOK** |
| triggers, actions, conditions (nested) | **YOK** |
| cronExpression, startDate, endDate | **YOK** |

**Aksiyon:** Workflow ekranı şimdilik devre dışı bırakılmalı veya tamamen farklı bir model ile yeniden tasarlanmalıdır.

---

## 5. Yeni Model İhtiyacı: Realtime

DB'de `realtimes` tablosu mevcuttur ve controller-variable junction tablosu olarak çalışır.
Dart tarafında bu model **henüz yoktur** ve oluşturulmalıdır.

### Önerilen Realtime Model

```dart
class Realtime {
  final String id;
  final String? name;
  final String? code;
  final String? description;
  final bool active;
  final bool? isLoggable;
  final String? controllerId;    // FK → controllers
  final String? variableId;      // FK → variables
  final String? deviceModelId;   // FK → device_models
  final String? priorityId;      // FK → priorities
  final String? cancelledControllerId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  // İlişkili nesneler (Supabase select ile)
  final Variable? variable;
  final Controller? controller;
}
```

---

## 6. Özet: Düzeltme Öncelik Sırası

### Yüksek Öncelik (Veri Görüntüleme İçin Gerekli)

1. **Realtime model oluştur** - Controller-Variable bağlantısı için zorunlu
2. **Variable model'den `controllerId` ve `tenantId` kaldır** - DB'de yok
3. **Variable model'e `deviceModelId` ekle** - DB'de var, model'de yok
4. **Controller model'e `deviceModelId` ekle** - DB'de var, model'de yok
5. **VariableService'i realtimes üzerinden çalışacak şekilde güncelle**

### Orta Öncelik (Doğru Veri Gösterimi İçin)

6. **Provider model'deki `type` enum'unu `protocolTypeId` FK'sına çevir**
7. **Controller model'deki `type` ve `protocol` enum'larını FK'lara çevir**
8. **Controller model'deki `status` → `isEnabled` + `isCanceled` dönüşümü**
9. **Variable model'deki `address` → `addressInput` + `addressOutput` dönüşümü**
10. **Variable model'deki `currentValue` → `value` rename**

### Düşük Öncelik (Tüm Alanlar İçin)

11. Tüm olmayan alanları kaldır (tags, metadata, alarm limitleri, vb.)
12. DB'de olup model'de olmayan alanları ekle
13. Lookup tabloları için service/model oluştur (brands, protocol_types, vb.)
14. Workflow modelini iş emri yönetimine göre yeniden tasarla veya devre dışı bırak
