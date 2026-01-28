# Alarm Chart & Log Line Chart Implementasyon Planı

**Tarih:** 2026-01-28 (Revize)
**Branch:** `claude/analyze-docs-structure-7QwfG`
**Kapsam:** UI sayfalarında alarm chartları + resetli alarm listesi, controller logları için line chartlar

---

## Genel Bakış

Bu plan iki ana özelliği kapsar:

| # | Özellik | Açıklama |
|---|---------|----------|
| A | **Alarm Chartları & Resetli Alarm Listesi** | `alarms` tablosundan aktif alarmlar, `alarm_histories` tablosundan resetli alarmlar |
| B | **Controller Log Line Chartları** | Controller'a ait log kayıtlarının zaman serisi olarak line chart ile gösterimi |

---

## Veritabanı Şeması & Tablo Ayrımı

### Kritik Mimari Kural

| Tablo | Kullanım | Açıklama |
|-------|----------|----------|
| **`alarms`** | Aktif Alarmlar | Şu an aktif olan, henüz resetlenmemiş alarmlar. Minimal FK (controller_id, variable_id, priority_id) |
| **`alarm_histories`** | Resetli Alarmlar | Resetlenmiş/kapanmış alarm kayıtları. Denormalize FK (tenant_id, organization_id, site_id, provider_id, controller_id) |
| **`alarm_statistics`** | Önceden Hesaplanmış İstatistik | date_key, hour_key, controller_id bazlı aggregate veriler (total_alarms, avg_duration, critical_alarms, mttr, mtbf) |
| **`priorities`** | Alarm Öncelikleri | level, color, name, code - alarm seviye tanımları |

### `alarms` Tablosu (Aktif Alarmlar)
```
id, name, code, description, status, category, active
start_time, end_time, arrival_start_time, arrival_endtime
inhibit_time, reset_time, last_update
local_acknowledge_time, local_acknowledge_user
remote_acknowledge_time, remote_acknowledge_user
local_delete_time, local_delete_user, reset_user
inhibited, is_logic
controller_id FK → controllers
variable_id FK → variables
priority_id FK → priorities
realtime_id FK → realtimes
```

### `alarm_histories` Tablosu (Resetli Alarmlar)
```
(Tüm alarm alanları) +
tenant_id FK → tenants
organization_id FK → organizations
site_id FK → sites
provider_id FK → providers
contractor_id FK → contractors
canceled_controller_id FK → controllers
is_archive, archive_group, txn_group_id
delete_action_time, delete_action_user
```

### Zaman Aralığı: Son 90 güne kadar desteklenir

---

## A. ALARM CHARTLARI & RESETLİ ALARM LİSTESİ

### A1. Bağımlılık Ekleme

**Dosya:** `pubspec.yaml`

```yaml
dependencies:
  fl_chart: ^0.69.0  # Flutter chart kütüphanesi
```

### A2. Alarm İstatistik Modeli

**Dosya:** `lib/src/core/alarm/alarm_stats_model.dart`

```dart
/// Günlük alarm zaman serisi girişi (chart bar verisi)
class AlarmTimelineEntry {
  final DateTime date;
  final int totalCount;
  final Map<String, int> countByPriority; // priorityId → count
}

/// Alarm durum dağılımı (pie chart verisi)
/// active: alarms tablosundan, reset: alarm_histories tablosundan
class AlarmDistribution {
  final int activeCount;      // alarms tablosu (aktif alarmlar)
  final int resetCount;       // alarm_histories tablosu (resetli alarmlar)
  final int acknowledgedCount;
  final int totalCount;
}
```

### A3. Alarm Service Genişletmeleri

**Dosya:** `lib/src/core/alarm/alarm_service.dart`

| Metod | Tablo | Açıklama |
|-------|-------|----------|
| `getResetAlarms()` | `alarm_histories` | Resetli alarmları getirir, son 90 güne kadar |
| `getAlarmTimeline()` | `alarm_histories` | Son N gün (max 90) günlük alarm sayıları, client-side gruplandırma |
| `getAlarmDistribution()` | `alarms` + `alarm_histories` | Aktif (alarms) + Reset (histories) dağılımı |

### A4. Chart Widget'ları

| Widget | Dosya | Veri Kaynağı |
|--------|-------|--------------|
| `ChartContainer` | `charts/chart_container.dart` | - (wrapper) |
| `AlarmBarChart` | `charts/alarm_bar_chart.dart` | `AlarmTimelineEntry` listesi |
| `AlarmPieChart` | `charts/alarm_pie_chart.dart` | `AlarmDistribution` |
| `ResetAlarmList` | `lists/reset_alarm_list.dart` | `AlarmHistory` listesi (`alarm_histories`) |

### A5. Alarm Dashboard Sayfası

```
AlarmDashboardScreen
├── Özet MetricCards (Aktif[alarms] / Reset[histories] / Toplam)
├── AlarmPieChart (dağılım)
├── AlarmBarChart (90 güne kadar trend, 7/30/90 gün seçimi)
└── ResetAlarmList (alarm_histories, son resetli alarmlar)
```

---

## B. CONTROLLER LOG LINE CHARTLARI

### B1. Log İstatistik Modeli

**Dosya:** `lib/src/core/iot_log/iot_log_stats_model.dart`

```dart
class LogTimeSeriesEntry {
  final DateTime dateTime;
  final double? value;
  final int? onOff;
  final String? rawValue;
}

class LogValueStats {
  final double? minValue, maxValue, avgValue, lastValue;
  final int totalCount;
  final DateTime? firstDate, lastDate;
}
```

### B2. IoT Log Service Genişletmeleri

| Metod | Açıklama |
|-------|----------|
| `getLogTimeSeries()` | Zaman serisi log verileri (value → double parse) |
| `getLogsByTimeRange()` | Tarih aralığına göre loglar (ASC sıralı) |
| `getLogValueStats()` | Min/Max/Avg/Son değer istatistikleri |

### B3. Log Chart Widget'ları

| Widget | Dosya | Açıklama |
|--------|-------|----------|
| `LogLineChart` | `charts/log_line_chart.dart` | Smooth bezier line, gradient dolgu, tooltip |
| `LogOnOffChart` | `charts/log_onoff_chart.dart` | Step chart (ON=yeşil, OFF=gri) |
| `MultiLineChart` | `charts/multi_line_chart.dart` | Çoklu variable overlay |

### B4. Controller Log Sayfası

```
ControllerLogsScreen (Tab yapısı)
├── Tab 1: Grafikler (LogLineChart + istatistik kartları)
├── Tab 2: Log Listesi (filtrelenebilir tablo)
└── Dönem Seçici: 24s / 7g / 30g / 90g
```

---

## İMPLEMENTASYON SIRASI

### Adım 1: Altyapı
- [ ] `pubspec.yaml`'a `fl_chart: ^0.69.0` ekle
- [ ] `alarm_stats_model.dart` oluştur
- [ ] `iot_log_stats_model.dart` oluştur
- [ ] `chart_container.dart` base widget oluştur

### Adım 2: Service Genişletmeleri
- [ ] `AlarmService` → `getResetAlarms()` (alarm_histories tablosu, 90 gün)
- [ ] `AlarmService` → `getAlarmTimeline()` (alarm_histories, client-side gruplandırma)
- [ ] `AlarmService` → `getAlarmDistribution()` (alarms + alarm_histories)
- [ ] `IoTLogService` → `getLogTimeSeries()`, `getLogsByTimeRange()`, `getLogValueStats()`

### Adım 3: Alarm Chart Widget'ları
- [ ] `AlarmBarChart` (stacked bar, 7/30/90 gün)
- [ ] `AlarmPieChart` (donut, aktif vs reset)
- [ ] `ResetAlarmList` + detay bottom sheet

### Adım 4: Log Chart Widget'ları
- [ ] `LogLineChart` (zaman serisi, gradient, tooltip)
- [ ] `LogOnOffChart` (step chart)
- [ ] `MultiLineChart` (çoklu variable)

### Adım 5: Example App Sayfaları
- [ ] `AlarmDashboardScreen`
- [ ] `ControllerLogsScreen`
- [ ] Router + export güncellemeleri

---

## DOSYA YAPISI

```
lib/src/
├── core/
│   ├── alarm/
│   │   ├── alarm_model.dart              (mevcut - alarms tablosu)
│   │   ├── alarm_history_model.dart       (mevcut - alarm_histories tablosu)
│   │   ├── alarm_service.dart             (genişletilecek: +3 metod)
│   │   └── alarm_stats_model.dart         (YENİ)
│   │
│   └── iot_log/
│       ├── iot_log_model.dart             (mevcut)
│       ├── iot_log_service.dart           (genişletilecek: +3 metod)
│       └── iot_log_stats_model.dart       (YENİ)
│
└── presentation/
    └── widgets/
        ├── charts/                        (YENİ dizin)
        │   ├── chart_container.dart
        │   ├── alarm_bar_chart.dart
        │   ├── alarm_pie_chart.dart
        │   ├── log_line_chart.dart
        │   ├── log_onoff_chart.dart
        │   └── multi_line_chart.dart
        │
        └── lists/
            └── reset_alarm_list.dart       (YENİ)

example/lib/features/iot/screens/
├── alarm_dashboard_screen.dart             (YENİ)
└── controller_logs_screen.dart             (YENİ)
```

---

## TEKNİK NOTLAR

### Tablo Kullanım Kuralları
- **Aktif alarm sayısı** → `alarms` tablosu (`active = true`)
- **Resetli alarm listesi** → `alarm_histories` tablosu
- **Alarm trend chartı** → `alarm_histories` (zaman serisinde kapanmış alarmlar anlamlı)
- **Alarm dağılım chartı** → Her iki tablo birlikte (aktif + reset)
- **Zaman filtresi** → Max 90 gün geriye gidilebilir

### Performans
- 90 günlük veri: Max ~2160 nokta (saatlik), ~90 nokta (günlük)
- `alarm_histories` sorgusu: `start_time >= now() - 90 days` filtresi
- Client-side gruplandırma (günlük): Supabase aggregate yerine
- Cache TTL: 5 dakika (service pattern ile tutarlı)

### Apple HIG Uyumluluk
- Chart renkleri: `AppColors` sisteminden
- Dark/Light mode: Tüm chart'lar brightness-aware
- Spacing: `AppSpacing` sabitleri ile tutarlı
