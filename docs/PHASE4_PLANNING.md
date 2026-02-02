# Faz 4 - Advanced Modules (Ertelendi)

> **Durum:** Ertelendi (Mevcut yapıların stabilizasyonu öncelikli)
> **Son Güncelleme:** 2026-02-02
> **Tahmini Başlangıç:** Mevcut modüller stabilize edildikten sonra

---

## Erteleme Nedeni

Faz 4'teki ileri seviye modüller, mevcut yapıların tam olarak çalışır ve stabil hale getirilmesinden sonra ele alınacaktır. Bu karar, proje bütünlüğünü korumak ve teknik borcu minimize etmek amacıyla alınmıştır.

### Öncelikler
1. Faz 1-3 modüllerinin stabilizasyonu
2. Eksik export ve service kayıtlarının tamamlanması
3. Mevcut testlerin geçerli duruma getirilmesi
4. Dokümantasyonun güncel tutulması

---

## Planlanan Modüller

### 4.1 Energy & KPI Module

**Amaç:** Enerji tüketimi takibi ve performans göstergeleri

#### Görevler
- [ ] EnergyConsumption model
- [ ] EnergyService (CRUD + aggregasyonlar)
- [ ] KPI dashboard widget'ları
- [ ] Trend analizi algoritmaları
- [ ] Anomali tespit sistemi
- [ ] Raporlama ve export (CSV, PDF)

#### Teknik Gereksinimler
```dart
// Planlanan model yapısı
class EnergyConsumption {
  final String id;
  final String tenantId;
  final String controllerId;
  final double consumption;
  final String unit; // kWh, m3, etc.
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
}

class KpiMetric {
  final String id;
  final String name;
  final double value;
  final double target;
  final String category;
  final TrendDirection trend;
}
```

#### Veritabanı Tabloları
- `energy_consumption` - Enerji tüketim kayıtları
- `kpi_definitions` - KPI tanımları
- `kpi_values` - KPI değerleri
- `kpi_targets` - Hedef değerler

---

### 4.2 Inventory Module

**Amaç:** Stok ve envanter yönetimi

#### Görevler
- [ ] InventoryItem model
- [ ] InventoryService (CRUD + stok hareketleri)
- [ ] Barcode/QR scanning entegrasyonu
- [ ] Düşük stok uyarıları
- [ ] Transaction history
- [ ] Warehouse/location yönetimi

#### Teknik Gereksinimler
```dart
class InventoryItem {
  final String id;
  final String tenantId;
  final String siteId;
  final String name;
  final String sku;
  final String barcode;
  final double quantity;
  final double minQuantity; // Düşük stok eşiği
  final String unit;
  final String locationId;
  final Map<String, dynamic> properties;
}

class InventoryTransaction {
  final String id;
  final String itemId;
  final TransactionType type; // IN, OUT, TRANSFER, ADJUSTMENT
  final double quantity;
  final String reason;
  final String performedBy;
  final DateTime timestamp;
}
```

#### Veritabanı Tabloları
- `inventory_items` - Envanter öğeleri
- `inventory_transactions` - Stok hareketleri
- `inventory_locations` - Depo/lokasyonlar
- `inventory_alerts` - Stok uyarıları

---

### 4.3 Production Module

**Amaç:** Üretim süreçleri ve OEE takibi

#### Görevler
- [ ] ProductionOrder model
- [ ] ProductionLine model
- [ ] ProductionService
- [ ] OEE (Overall Equipment Effectiveness) hesaplama
- [ ] Downtime tracking
- [ ] Shift yönetimi
- [ ] Production reporting

#### Teknik Gereksinimler
```dart
class ProductionOrder {
  final String id;
  final String tenantId;
  final String productId;
  final double targetQuantity;
  final double producedQuantity;
  final double scrapQuantity;
  final ProductionStatus status;
  final DateTime plannedStart;
  final DateTime plannedEnd;
  final DateTime? actualStart;
  final DateTime? actualEnd;
}

class OeeMetrics {
  final double availability;
  final double performance;
  final double quality;
  final double oee; // availability * performance * quality
}

class DowntimeEvent {
  final String id;
  final String lineId;
  final String reason;
  final DowntimeCategory category; // PLANNED, UNPLANNED, BREAKDOWN
  final DateTime startTime;
  final DateTime? endTime;
  final Duration duration;
}
```

#### Veritabanı Tabloları
- `production_orders` - Üretim emirleri
- `production_lines` - Üretim hatları
- `production_shifts` - Vardiyalar
- `downtime_events` - Duruş kayıtları
- `oee_records` - OEE hesaplamaları

---

### 4.4 Retail Module

**Amaç:** Mağaza ve perakende yönetimi

#### Görevler
- [ ] Store model
- [ ] POS entegrasyonu
- [ ] Sales analytics
- [ ] Customer management
- [ ] Loyalty program desteği
- [ ] Kampanya yönetimi

#### Teknik Gereksinimler
```dart
class Store {
  final String id;
  final String tenantId;
  final String name;
  final String address;
  final GeoLocation location;
  final StoreType type;
  final String managerId;
}

class SalesTransaction {
  final String id;
  final String storeId;
  final String customerId;
  final List<SalesItem> items;
  final double total;
  final double discount;
  final PaymentMethod paymentMethod;
  final DateTime timestamp;
}

class Customer {
  final String id;
  final String name;
  final String email;
  final String phone;
  final int loyaltyPoints;
  final CustomerTier tier;
}
```

#### Veritabanı Tabloları
- `stores` - Mağaza bilgileri
- `sales_transactions` - Satış işlemleri
- `customers` - Müşteri bilgileri
- `loyalty_programs` - Sadakat programları
- `campaigns` - Kampanyalar

---

### 4.5 Financial Module

**Amaç:** Finansal işlem ve bütçe yönetimi

#### Görevler
- [ ] Invoice model
- [ ] Payment model
- [ ] Budget model
- [ ] Financial reporting
- [ ] Currency handling
- [ ] Tax calculations
- [ ] Expense tracking

#### Teknik Gereksinimler
```dart
class Invoice {
  final String id;
  final String tenantId;
  final String customerId;
  final String invoiceNumber;
  final List<InvoiceItem> items;
  final double subtotal;
  final double taxAmount;
  final double total;
  final String currency;
  final InvoiceStatus status;
  final DateTime issueDate;
  final DateTime dueDate;
}

class Payment {
  final String id;
  final String invoiceId;
  final double amount;
  final String currency;
  final PaymentMethod method;
  final PaymentStatus status;
  final DateTime paymentDate;
}

class Budget {
  final String id;
  final String tenantId;
  final String departmentId;
  final String category;
  final double allocatedAmount;
  final double spentAmount;
  final String currency;
  final DateRange period;
}
```

#### Veritabanı Tabloları
- `invoices` - Faturalar
- `invoice_items` - Fatura kalemleri
- `payments` - Ödemeler
- `budgets` - Bütçeler
- `expenses` - Giderler
- `financial_reports` - Finansal raporlar

---

## Uygulama Stratejisi

### Aşama 1: Planlama
- [ ] Her modül için detaylı gereksinim analizi
- [ ] Veritabanı şema tasarımı
- [ ] API endpoint planlaması
- [ ] UI/UX mockup'ları

### Aşama 2: Geliştirme Sırası
1. **Energy & KPI** - IoT altyapısı mevcut olduğundan en kolay başlangıç
2. **Inventory** - Bağımsız modül, hızlı geliştirme
3. **Production** - IoT ve Inventory modüllerine bağımlı
4. **Retail** - Inventory ve Financial modüllerine bağımlı
5. **Financial** - En kapsamlı, en son

### Aşama 3: Test & Dokümantasyon
- [ ] Her modül için unit testler
- [ ] Entegrasyon testleri
- [ ] API dokümantasyonu
- [ ] Kullanıcı rehberleri

---

## Bağımlılıklar

| Modül | Gerekli Mevcut Modüller |
|-------|-------------------------|
| Energy & KPI | Controller, Variable, IoT Realtime |
| Inventory | Site, Unit |
| Production | Controller, Variable, Inventory |
| Retail | Inventory, User |
| Financial | Tenant, Organization |

---

## Tahmini Çalışma Miktarı

| Modül | Model/Service | UI | Test | Toplam |
|-------|---------------|-----|------|--------|
| Energy & KPI | Orta | Yüksek | Orta | Yüksek |
| Inventory | Orta | Orta | Orta | Orta |
| Production | Yüksek | Yüksek | Yüksek | Çok Yüksek |
| Retail | Yüksek | Yüksek | Orta | Yüksek |
| Financial | Çok Yüksek | Yüksek | Yüksek | Çok Yüksek |

---

## Başlamadan Önce Kontrol Listesi

### Mevcut Modüller Stabilizasyonu
- [ ] Tüm Faz 1-3 modülleri export edilmiş
- [ ] Service'ler DI'a kayıtlı
- [ ] Unit testler geçiyor
- [ ] Dart analyzer uyarısı yok
- [ ] Dokümantasyon güncel

### Teknik Altyapı
- [ ] Database migration stratejisi hazır
- [ ] API versiyonlama planı
- [ ] Error handling standardı
- [ ] Logging stratejisi

---

## Notlar

1. Bu plan, mevcut modüller stabilize edildikten sonra güncellenecektir
2. Modül öncelikleri iş gereksinimlerine göre değişebilir
3. Her modül için ayrı feature branch kullanılacak
4. Geriye dönük uyumluluk korunacak

---

*Bu döküman, Faz 4 çalışmalarına başlandığında detaylandırılacaktır.*
*Son güncelleme: 2026-02-02*
