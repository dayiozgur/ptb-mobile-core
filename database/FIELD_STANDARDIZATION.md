# Database Field Standardization Guide

Bu dokuman, veritabaninda bulunan legacy ve current alan isimlerini ve bunlarin Flutter model'lerinde nasil ele alindigini dokumante eder.

## Dual Column Yapilari

Veritabaninda bazi tablolarda ayni veriyi temsil eden iki farkli kolon bulunmaktadir. Bu durum, backend'in verileri hangi kolona yazdiginin bilinemediginden dolayi her iki kolonun da desteklenmesini gerektirir.

### 1. logs Tablosu

| Current (Tercih Edilen) | Legacy | Aciklama |
|------------------------|--------|----------|
| `date_time` | `datetime` | Log zaman damgasi |
| `on_off` | `onoff` | On/Off durumu (integer) |

**Model Kullanimi:**
```dart
// IoTLog.fromJson() icinde
onOff: DbFieldHelpers.parseLogOnOff(json),
dateTime: DbFieldHelpers.parseLogDateTime(json),
```

### 2. alarms Tablosu

| Current (Tercih Edilen) | Legacy | Aciklama |
|------------------------|--------|----------|
| `arrival_end_time` | `arrival_endtime` | Alarm varis bitis zamani |

**Not:** `arrival_start_time` tutarli, sadece end_time tutarsiz.

**Model Kullanimi:**
```dart
// Alarm.fromJson() icinde
arrivalEndTime: DbFieldHelpers.parseAlarmArrivalEndTime(json),
```

### 3. controllers Tablosu

| Current (Tercih Edilen) | Legacy | Aciklama |
|------------------------|--------|----------|
| `model` | `model_code` | Controller model kodu |
| `serial_number` | `serial` | Seri numarasi |
| `ip_address` | `ip` | IP adresi |
| `last_connected_at` | `last_connection_time` | Son baglanti zamani |
| `last_data_at` | `last_communication_time` | Son veri zamani |

**Model Kullanimi:**
```dart
// Controller.fromJson() icinde
model: DbFieldHelpers.parseControllerModel(json),
serialNumber: DbFieldHelpers.parseControllerSerial(json),
ipAddress: DbFieldHelpers.parseControllerIp(json),
lastConnectedAt: DbFieldHelpers.parseControllerLastConnection(json),
lastDataAt: DbFieldHelpers.parseControllerLastData(json),
```

### 4. providers Tablosu

| Current (Tercih Edilen) | Legacy | Aciklama |
|------------------------|--------|----------|
| `ip` | `host` | IP adresi |
| `last_connected_at` | `last_connection_time` | Son baglanti zamani |

## DbFieldHelpers Kullanimi

`lib/src/core/utils/db_field_helpers.dart` dosyasi, dual column handling icin yardimci fonksiyonlar saglar:

```dart
import '../utils/db_field_helpers.dart';

// DateTime alani parse et
final dateTime = DbFieldHelpers.parseDateTime(json, 'date_time', 'datetime');

// Integer alani parse et
final onOff = DbFieldHelpers.parseInt(json, 'on_off', 'onoff');

// String alani parse et
final model = DbFieldHelpers.parseString(json, 'model_code', 'model');

// Ozel helper'lar
final logDateTime = DbFieldHelpers.parseLogDateTime(json);
final logOnOff = DbFieldHelpers.parseLogOnOff(json);
final alarmEndTime = DbFieldHelpers.parseAlarmArrivalEndTime(json);
```

## toJson() Standardlari

Model'lerin `toJson()` metodlari **current** (tercih edilen) alan isimlerini kullanmalidir:

```dart
Map<String, dynamic> toJson() {
  return {
    'date_time': dateTime?.toIso8601String(),  // current isimlendirme
    'on_off': onOff,                            // current isimlendirme
    // ...
  };
}
```

## Yeni Model Olusturma Rehberi

Yeni bir model olusturulurken:

1. **fromJson()** icinde DbFieldHelpers kullanarak dual column destegi saglayin
2. **toJson()** icinde current (tercih edilen) alan isimlerini kullanin
3. Model dosyasinin basina ilgili dual column bilgisini dokumante edin
4. Bu dokumana yeni dual column mapping'leri ekleyin

## Bilinen Diger Tutarsizliklar

### API Response Pagination

| Field Set 1 | Field Set 2 | Aciklama |
|-------------|-------------|----------|
| `page` | `current_page` | Mevcut sayfa numarasi |
| `per_page` | `limit` | Sayfa basina kayit sayisi |
| `total_pages` | `last_page` | Toplam sayfa sayisi |

### Tenant

| Current | Legacy | Aciklama |
|---------|--------|----------|
| `logo_url` | `image_path` | Tenant logosu |

### Variable

| Current | Legacy | Aciklama |
|---------|--------|----------|
| `grp_category` | `category` | Degisken kategorisi |

## Onerilen Veritabani Migrasyon

Uzun vadede, DB seviyesinde standardizasyon saglamak icin:

1. Legacy kolonlarin current kolonlara migrate edilmesi
2. Uygulama katmaninda gecis sureci sonrasi legacy desteginin kaldirilmasi
3. Veritabani constraint'lerinin guncellenmesi

Bu degisiklik backend ekibiyle koordineli yapilmalidir.
