# Alarm Chart & Log Line Chart Implementasyon Planı

**Tarih:** 2026-01-28
**Branch:** `claude/analyze-docs-structure-7QwfG`
**Kapsam:** UI sayfalarında alarm chartları + resetli alarm listesi, controller logları için line chartlar

---

## Genel Bakış

Bu plan iki ana özelliği kapsar:

| # | Özellik | Açıklama |
|---|---------|----------|
| A | **Alarm Chartları & Resetli Alarm Listesi** | Alarm verilerini görselleştiren chartlar ve reset durumuna göre filtrelenmiş alarm listesi |
| B | **Controller Log Line Chartları** | Controller'a ait log kayıtlarının zaman serisi olarak line chart ile gösterimi |

---

## Mevcut Durum Analizi

### Veri Kaynakları (Hazır)
- `AlarmService` - Aktif alarmlar ve alarm geçmişi (Supabase: `alarms`, `alarm_histories`)
- `IoTLogService` - Operasyonel loglar (Supabase: `logs`)
- `PriorityService` - Alarm öncelik seviyeleri (Supabase: `priorities`)
- `ControllerService` - Controller bilgileri (Supabase: `controllers`)

### Mevcut Modeller (Hazır)
- `Alarm` → `startTime`, `endTime`, `resetTime`, `status`, `priorityId`, `controllerId`
- `AlarmHistory` → Tüm Alarm alanları + `siteId`, `providerId`, `organizationId`
- `IoTLog` → `value`, `dateTime`, `onOff`, `controllerId`, `variableId`
- `Priority` → `level`, `color`, `name`, `code`

### Eksik Parçalar
- Chart kütüphanesi (`fl_chart`) dependency'de yok
- Chart widget'ları yok
- Alarm reset filtreleme service metodu yok
- Log verilerini zaman serisine dönüştüren utility yok

---

## A. ALARM CHARTLARI & RESETLİ ALARM LİSTESİ

### A1. Bağımlılık Ekleme

**Dosya:** `pubspec.yaml`

```yaml
dependencies:
  fl_chart: ^0.69.0  # Flutter chart kütüphanesi
```

> `fl_chart` tercih sebepleri: Saf Dart/Flutter, platform bağımsız, performanslı, aktif bakım, Apple HIG uyumlu özelleştirme desteği.

---

### A2. Alarm Service Genişletmeleri

**Dosya:** `lib/src/core/alarm/alarm_service.dart`

Eklenecek metodlar:

```
1. getResetAlarms({controllerId?, siteId?, limit})
   → resetTime != null olan alarmları getirir
   → Sıralama: reset_time DESC

2. getAlarmCountByPriority({controllerId?, siteId?})
   → Priority bazlı alarm sayılarını döner
   → Return: Map<String, int> (priorityId → count)

3. getAlarmTimeline({controllerId?, siteId?, days = 7})
   → Son N gündeki alarm sayılarını günlük gruplar
   → Return: List<AlarmTimelineEntry> (date, count, byPriority)

4. getAlarmDistribution({controllerId?, siteId?})
   → Aktif/Reset/Acknowledged dağılımını döner
   → Return: AlarmDistribution (active, reset, acknowledged, total)
```

**Yeni Model Dosyası:** `lib/src/core/alarm/alarm_stats_model.dart`

```dart
/// Zaman serisi alarm istatistiği
class AlarmTimelineEntry {
  final DateTime date;
  final int totalCount;
  final Map<String, int> countByPriority; // priorityId → count
}

/// Alarm durum dağılımı
class AlarmDistribution {
  final int activeCount;
  final int resetCount;
  final int acknowledgedCount;
  final int totalCount;
}
```

---

### A3. Chart Widget'ları (Presentation Layer)

#### A3.1 Alarm Bar Chart Widget

**Dosya:** `lib/src/presentation/widgets/charts/alarm_bar_chart.dart`

```
AlarmBarChart
├── Props: List<AlarmTimelineEntry>, Map<String, Priority>?
├── Görünüm: X ekseni = Gün, Y ekseni = Alarm sayısı
├── Priority renkleri ile stacked bar
├── Dokunma ile detay tooltip
├── Responsive boyutlandırma
└── Boş durum: "Bu dönemde alarm kaydı yok"
```

**Tasarım Detayları:**
- Son 7/14/30 gün seçimi (segment control)
- Her bar priority rengine göre stacked
- Tooltip: Tarih + Priority bazlı ayrıntı
- Apple HIG uyumlu renkler ve tipografi
- Dark/Light mode desteği

#### A3.2 Alarm Pie/Donut Chart Widget

**Dosya:** `lib/src/presentation/widgets/charts/alarm_pie_chart.dart`

```
AlarmPieChart
├── Props: AlarmDistribution
├── Görünüm: Donut chart (merkez: toplam sayı)
├── Segmentler: Aktif (kırmızı), Reset (yeşil), Acknowledged (mavi)
├── Legend: Alt kısımda etiketler
└── Animasyonlu geçiş
```

**Tasarım Detayları:**
- Donut chart (iç boşluk %60)
- Merkez: Toplam alarm sayısı (büyük font)
- Segment dokunulunca vurgulama
- Segment renkleri: AppColors sistemi ile uyumlu
- Legend satırı: Renk kutusu + etiket + sayı

#### A3.3 Base Chart Container Widget

**Dosya:** `lib/src/presentation/widgets/charts/chart_container.dart`

```
ChartContainer
├── Props: title, subtitle, trailing (action), child (chart widget)
├── AppCard tabanlı wrapper
├── Header: Başlık + Sağ üst aksiyon (dönem seçimi vb.)
├── Padding ve minimum yükseklik (200px)
└── Loading/Error/Empty state desteği
```

---

### A4. Resetli Alarm Listesi Widget'ı

**Dosya:** `lib/src/presentation/widgets/lists/reset_alarm_list.dart`

```
ResetAlarmList
├── Props: controllerId?, siteId?, limit, onAlarmTap?
├── Veri: AlarmService.getResetAlarms() ile çekilir
├── Her satır:
│   ├── Sol: Priority renk çubuğu (4px dikey)
│   ├── Başlık: Alarm adı (name) + kod (code)
│   ├── Alt başlık: Reset zamanı + Reset eden kullanıcı
│   ├── Sağ: Süre badge (startTime → resetTime)
│   └── Dokunma: Alarm detay bottom sheet
├── Pull-to-refresh
├── Boş durum: "Resetlenmiş alarm kaydı yok"
└── Sayfalama: İlk 20, scroll ile daha fazla
```

**Alarm Detay Bottom Sheet:**
```
AlarmDetailSheet
├── Alarm adı ve kodu
├── Durum badge (Reset / Acknowledged / Active)
├── Zaman çizelgesi:
│   ├── Başlangıç (startTime)
│   ├── Varış (arrivalStartTime → arrivalEndTime)
│   ├── Onay (localAcknowledgeTime / remoteAcknowledgeTime)
│   ├── Reset (resetTime + resetUser)
│   └── Bitiş (endTime)
├── İlişkili Controller & Variable bilgisi
├── Priority bilgisi (seviye + renk)
└── Süre özeti
```

---

### A5. Alarm Dashboard Sayfası

**Dosya:** `example/lib/features/iot/screens/alarm_dashboard_screen.dart`

```
AlarmDashboardScreen (StatefulWidget)
├── AppSliverScaffold
├── Bölüm 1: Özet MetricCardGrid
│   ├── Aktif Alarm Sayısı (kırmızı)
│   ├── Resetli Alarm Sayısı (yeşil)
│   ├── Onaylı Alarm Sayısı (mavi)
│   └── Toplam (bugün) (gri)
│
├── Bölüm 2: Alarm Dağılım Chart
│   └── AlarmPieChart (donut)
│
├── Bölüm 3: Alarm Trend Chart
│   └── AlarmBarChart (7/14/30 gün)
│
├── Bölüm 4: Resetli Alarm Listesi
│   ├── Başlık: "Resetlenmiş Alarmlar"
│   ├── Sağ: "Tümünü Gör" butonu
│   └── ResetAlarmList (limit: 10)
│
└── Bölüm 5: Son Aktif Alarmlar (kısa liste)
```

**Navigasyon Eklentisi:**

```
/iot/alarms          → AlarmDashboardScreen
/iot/alarms/reset    → Tam resetli alarm listesi sayfası
```

---

## B. CONTROLLER LOG LINE CHARTLARI

### B1. IoT Log Service Genişletmeleri

**Dosya:** `lib/src/core/iot_log/iot_log_service.dart`

Eklenecek metodlar:

```
1. getLogTimeSeries({controllerId, variableId?, days = 7, interval = 'hour'})
   → Zaman serisi log verileri
   → Return: List<LogTimeSeriesEntry>

2. getLogsByTimeRange({controllerId, variableId?, from, to})
   → Belirli zaman aralığındaki logları getirir
   → Sıralama: date_time ASC (chart için kronolojik)

3. getLogValueStats({controllerId, variableId?, days = 7})
   → Min, Max, Avg, Son değer istatistikleri
   → Return: LogValueStats
```

**Yeni Model Dosyası:** `lib/src/core/iot_log/iot_log_stats_model.dart`

```dart
/// Zaman serisi log verisi
class LogTimeSeriesEntry {
  final DateTime dateTime;
  final double? value;      // Numerik değer (parse edilmiş)
  final int? onOff;         // On/Off durumu
  final String? rawValue;   // Ham string değer
}

/// Log değer istatistikleri
class LogValueStats {
  final double? minValue;
  final double? maxValue;
  final double? avgValue;
  final double? lastValue;
  final int totalCount;
  final DateTime? firstDate;
  final DateTime? lastDate;
}
```

---

### B2. Log Chart Widget'ları

#### B2.1 Log Line Chart Widget

**Dosya:** `lib/src/presentation/widgets/charts/log_line_chart.dart`

```
LogLineChart
├── Props: List<LogTimeSeriesEntry>, String? unit, LogChartConfig?
├── Görünüm: X = Zaman, Y = Değer
├── Çizgi: Smooth bezier curve
├── Noktalar: Veri noktası göstergeleri (opsiyonel)
├── Alan: Çizgi altı gradient dolgu
├── Tooltip: Dokunulunca tam değer + zaman
├── Y ekseni: Otomatik ölçekleme (min-max padding)
├── X ekseni: Akıllı zaman etiketleri (saat/gün/ay)
├── Grid: Yatay noktalı çizgiler
└── Responsive boyutlandırma
```

**Konfigürasyon:**
```dart
class LogChartConfig {
  final Color lineColor;          // Çizgi rengi
  final Color gradientColor;      // Gradient dolgu rengi
  final bool showDots;            // Nokta göstergeleri
  final bool showArea;            // Alan dolgusu
  final bool enableTouch;         // Dokunma etkileşimi
  final double lineWidth;         // Çizgi kalınlığı (default: 2.0)
  final String? yAxisLabel;       // Y ekseni etiketi
  final String? valueUnit;        // Değer birimi (°C, %, kW vb.)
}
```

#### B2.2 Log On/Off Timeline Widget

**Dosya:** `lib/src/presentation/widgets/charts/log_onoff_chart.dart`

```
LogOnOffChart
├── Props: List<LogTimeSeriesEntry>
├── Görünüm: Step chart (ON=1, OFF=0)
├── ON bölgeleri: Yeşil arka plan
├── OFF bölgeleri: Kırmızı/gri arka plan
├── Zaman etiketi: X ekseni
└── Toplam ON/OFF süre özeti
```

#### B2.3 Multi-Variable Chart Widget

**Dosya:** `lib/src/presentation/widgets/charts/multi_line_chart.dart`

```
MultiLineChart
├── Props: Map<String, List<LogTimeSeriesEntry>> (variableName → data)
├── Görünüm: Aynı eksende birden fazla çizgi
├── Her variable farklı renk
├── Legend: Alt kısımda variable adları
├── Toggle: Variable'ları göster/gizle
└── Ortak X ekseni, bağımsız Y scaling
```

---

### B3. Controller Detail Log Bölümü

**Dosya:** `example/lib/features/iot/screens/controller_detail_screen.dart`

Controller detay sayfasına eklenecek bölümler:

```
ControllerDetailScreen (yeni veya mevcut genişletme)
├── Mevcut: Controller bilgileri, durum, bağlantı
│
├── YENİ Bölüm: Log Grafikleri
│   ├── Dönem Seçici (SegmentedControl: 24s / 7g / 30g)
│   │
│   ├── Değer İstatistik Kartları (MetricCardRow)
│   │   ├── Min Değer
│   │   ├── Max Değer
│   │   ├── Ortalama
│   │   └── Son Değer
│   │
│   ├── Ana Line Chart
│   │   └── LogLineChart (seçilen dönem)
│   │
│   ├── On/Off Durumu (varsa)
│   │   └── LogOnOffChart
│   │
│   └── Variable Seçici
│       ├── Variable dropdown/chip listesi
│       └── Seçime göre chart güncelleme
│
├── YENİ Bölüm: Log Listesi
│   ├── Son log kayıtları (tablo formatı)
│   ├── Zaman | Değer | On/Off | Durum
│   └── "Tümünü Gör" navigasyonu
│
└── Navigasyon
    └── /iot/controllers/:id/logs → Tam log listesi + chart sayfası
```

---

### B4. Controller Log Sayfası (Tam Sayfa)

**Dosya:** `example/lib/features/iot/screens/controller_logs_screen.dart`

```
ControllerLogsScreen (StatefulWidget)
├── AppSliverScaffold
│
├── Tab 1: Grafikler
│   ├── Dönem ve Variable seçici
│   ├── LogLineChart (tam genişlik)
│   ├── İstatistik kartları
│   └── Multi-variable overlay (opsiyonel)
│
├── Tab 2: Log Listesi
│   ├── Filtreleme: Variable, tarih aralığı
│   ├── Sıralama: Yeni → Eski
│   ├── Her satır: Zaman | Variable | Değer | On/Off
│   └── Pagination (scroll ile yükleme)
│
└── Tab 3: Karşılaştırma (opsiyonel/gelecek)
    ├── 2 variable seçimi
    └── Yan yana veya overlay chart
```

---

## DOSYA YAPISI ÖZET

```
lib/src/
├── core/
│   ├── alarm/
│   │   ├── alarm_model.dart              (mevcut)
│   │   ├── alarm_history_model.dart       (mevcut)
│   │   ├── alarm_service.dart             (genişletilecek: +4 metod)
│   │   └── alarm_stats_model.dart         (YENİ)
│   │
│   └── iot_log/
│       ├── iot_log_model.dart             (mevcut)
│       ├── iot_log_service.dart           (genişletilecek: +3 metod)
│       └── iot_log_stats_model.dart       (YENİ)
│
├── presentation/
│   └── widgets/
│       └── charts/                        (YENİ dizin)
│           ├── chart_container.dart        (YENİ)
│           ├── alarm_bar_chart.dart        (YENİ)
│           ├── alarm_pie_chart.dart        (YENİ)
│           ├── log_line_chart.dart         (YENİ)
│           ├── log_onoff_chart.dart        (YENİ)
│           └── multi_line_chart.dart       (YENİ)
│
└── presentation/
    └── widgets/
        └── lists/
            └── reset_alarm_list.dart       (YENİ)

example/lib/features/iot/screens/
├── alarm_dashboard_screen.dart             (YENİ)
├── controller_detail_screen.dart           (genişletilecek)
└── controller_logs_screen.dart             (YENİ)
```

---

## İMPLEMENTASYON SIRASI

### Adım 1: Altyapı
- [ ] `pubspec.yaml`'a `fl_chart: ^0.69.0` ekle
- [ ] `alarm_stats_model.dart` oluştur (`AlarmTimelineEntry`, `AlarmDistribution`)
- [ ] `iot_log_stats_model.dart` oluştur (`LogTimeSeriesEntry`, `LogValueStats`)
- [ ] `chart_container.dart` base widget oluştur

### Adım 2: Service Genişletmeleri
- [ ] `AlarmService`'e `getResetAlarms()` ekle
- [ ] `AlarmService`'e `getAlarmCountByPriority()` ekle
- [ ] `AlarmService`'e `getAlarmTimeline()` ekle
- [ ] `AlarmService`'e `getAlarmDistribution()` ekle
- [ ] `IoTLogService`'e `getLogTimeSeries()` ekle
- [ ] `IoTLogService`'e `getLogsByTimeRange()` ekle
- [ ] `IoTLogService`'e `getLogValueStats()` ekle

### Adım 3: Alarm Chart Widget'ları
- [ ] `AlarmBarChart` widget (stacked bar, 7/14/30 gün)
- [ ] `AlarmPieChart` widget (donut, dağılım)
- [ ] `ResetAlarmList` widget + `AlarmDetailSheet`

### Adım 4: Log Chart Widget'ları
- [ ] `LogLineChart` widget (zaman serisi, gradient, tooltip)
- [ ] `LogOnOffChart` widget (step chart)
- [ ] `MultiLineChart` widget (çoklu variable overlay)

### Adım 5: Example App Sayfaları
- [ ] `AlarmDashboardScreen` oluştur
- [ ] `ControllerDetailScreen`'e log grafikleri bölümü ekle
- [ ] `ControllerLogsScreen` oluştur (tab'lı tam sayfa)
- [ ] Router'a yeni route'lar ekle (`/iot/alarms`, `/iot/controllers/:id/logs`)

### Adım 6: Export & Entegrasyon
- [ ] Yeni widget'ları `protoolbag_core` barrel export'a ekle
- [ ] IoT Dashboard'a alarm chart kısa özet kartı ekle
- [ ] Test: Widget testleri yaz

---

## TEKNİK NOTLAR

### Chart Kütüphanesi: `fl_chart`
- Pure Flutter/Dart - platform bağımsız
- BarChart, PieChart, LineChart desteği
- Touch/interaction built-in
- Animasyon desteği
- Dark/Light mode uyumlu

### Veri Dönüşüm Stratejisi
- `IoTLog.value` alanı `String?` → `double.tryParse()` ile numerik dönüşüm
- Null/parse-fail değerler chart'ta atlanır veya 0 gösterilir
- Zaman gruplandırma: Supabase tarafında yapılabilir veya client-side

### Performans Dikkat Noktaları
- Chart verisi için ayrı cache key (`chart_alarm_timeline_...`)
- 30 günlük veri: Max ~720 nokta (saatlik), ~30 nokta (günlük)
- Büyük veri setlerinde downsampling (her N. nokta)
- Chart widget'larında `RepaintBoundary` kullanımı

### Apple HIG Uyumluluk
- Chart renkleri: `AppColors` sisteminden
- Font: `AppTypography` ile tutarlı
- Spacing: `AppSpacing` ile tutarlı
- Dark mode: Tüm chart'lar brightness-aware
- Haptic feedback: Chart dokunma etkileşimlerinde

---

## BAĞIMLILIK GRAFİĞİ

```
fl_chart (yeni dependency)
    │
    ├── chart_container.dart
    │       │
    │       ├── alarm_bar_chart.dart ─── AlarmService.getAlarmTimeline()
    │       │                                    └── alarm_stats_model.dart
    │       │
    │       ├── alarm_pie_chart.dart ─── AlarmService.getAlarmDistribution()
    │       │                                    └── alarm_stats_model.dart
    │       │
    │       ├── log_line_chart.dart ──── IoTLogService.getLogTimeSeries()
    │       │                                    └── iot_log_stats_model.dart
    │       │
    │       ├── log_onoff_chart.dart ─── IoTLogService.getLogTimeSeries()
    │       │
    │       └── multi_line_chart.dart ── IoTLogService.getLogTimeSeries() × N
    │
    └── Screens
        ├── alarm_dashboard_screen.dart
        │       ├── alarm_bar_chart.dart
        │       ├── alarm_pie_chart.dart
        │       └── reset_alarm_list.dart ── AlarmService.getResetAlarms()
        │
        ├── controller_detail_screen.dart (genişletme)
        │       ├── log_line_chart.dart
        │       └── log_onoff_chart.dart
        │
        └── controller_logs_screen.dart
                ├── log_line_chart.dart
                ├── multi_line_chart.dart
                └── IoTLogService.getLogs()
```

---

## REFERANSLAR

- [ARCHITECTURE.md](ARCHITECTURE.md) - Sistem mimarisi
- [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) - UI/UX kuralları
- [COMPONENT_LIBRARY.md](COMPONENT_LIBRARY.md) - Mevcut bileşen kataloğu
- [iot-data-flow-architecture.md](iot-data-flow-architecture.md) - IoT veri akışı
