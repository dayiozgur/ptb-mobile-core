# IoT Veri Akış Mimarisi

## 1. Veri Hiyerarşisi

```
Tenant
  └── Organization
       └── Site
            ├── Unit (alt birimler, self-referencing)
            └── Provider (Supervisor/Gateway)
                 └── Controller (PLC/RTU)
                      └── device_model_id → device_models
                           └── Variables (ŞABLON - model bazlı)
                               └── Realtimes (INSTANCE - controller bazlı)
```

### Kritik Kavramlar

| Kavram | Açıklama |
|--------|----------|
| **Variable** | Bir device model'e ait şablon tanımıdır. Sensör adresi, veri tipi, birim gibi meta bilgileri tutar. Doğrudan bir controller'a bağlı **DEĞİLDİR**. |
| **Realtime** | Bir controller ile bir variable arasındaki çalışma zamanı (runtime) bağlantısıdır. `realtimes` tablosu bu junction rolünü üstlenir. |
| **Device Model** | Controller ve variable'ları birbirine bağlayan şablon modeldir. Aynı device model'e sahip controller'lar aynı variable setini paylaşır. |
| **Provider** | Supervisor veya Gateway olarak görev yapan üst seviye cihaz. Controller'ları yönetir. |

---

## 2. Controller-Variable İlişki Mekanizmaları

### 2.1 Realtimes Tablosu (Birincil Yöntem - Kullanılacak)

```
Controller ──(controller_id)──► Realtimes ◄──(variable_id)── Variable
                                    │
                                    └── device_model_id (ek referans)
```

**Avantajları:**
- Controller-level izolasyon sağlar
- Farklı provider'lar aynı device_model'i kullansa bile çakışma olmaz
- Her controller'ın kendi variable instance'ları vardır
- `is_loggable`, `priority_id` gibi instance-level özellikler tanımlanabilir

**Sorgu Örneği:**
```sql
-- Bir controller'ın variable'larını getir
SELECT v.*, r.id as realtime_id
FROM realtimes r
JOIN variables v ON v.id = r.variable_id
WHERE r.controller_id = :controller_id;
```

### 2.2 Device Model ID (Şablon Yöntemi - Yedek)

```
Controller ──(device_model_id)──► device_models ◄──(device_model_id)── Variable
```

**Avantajları:**
- Basit JOIN ile tüm variable şablonlarına erişim
- Device model bazlı gruplama

**Dezavantajları:**
- Provider izolasyonu **YOK** - aynı device_model code'unu kullanan tüm controller'lar aynı variable setini görür
- Instance-level özelleştirme yapılamaz

---

## 3. Provider İzolasyon Problemi

### Problem

Device model'ler `code` bazında benzersizdir. Örnek:
- Provider A (Adana Depo) → Controller X → device_model code: `208` (mcella_v1)
- Provider B (Antalya Depo) → Controller Y → device_model code: `208` (mcella_v1)

Eğer yalnızca `device_model_id` üzerinden JOIN yapılırsa:
- Provider A'nın controller'ı, Provider B'nin de variable'larını görür
- Senkronizasyonda bir provider'daki değişiklik tüm provider'ları etkiler

### Çözüm: Realtimes Tablosu

```
realtimes tablosu controller_id kullanarak izolasyon sağlar:

Provider A → Controller X (id: abc) → realtimes WHERE controller_id = 'abc'
Provider B → Controller Y (id: xyz) → realtimes WHERE controller_id = 'xyz'
```

Her controller kendi realtime kayıtlarına sahiptir. Böylece:
- Provider A'daki değişiklikler sadece Provider A'nın controller'larını etkiler
- Variable şablonları paylaşımlı olsa bile runtime verileri izole kalır

---

## 4. Mobil Uygulama Veri Akışı (Realtimes Yaklaşımı)

### 4.1 Site Bazlı Görüntüleme

```
1. Kullanıcı site seçer
2. Site'a ait controller'ları getir:
   SELECT * FROM controllers WHERE site_id = :site_id

3. Her controller için realtimes üzerinden variable'ları getir:
   SELECT v.*, r.*
   FROM realtimes r
   JOIN variables v ON v.id = r.variable_id
   WHERE r.controller_id = :controller_id

4. Provider bilgisini controller üzerinden getir:
   SELECT p.* FROM providers p
   JOIN controllers c ON c.provider_id = p.id
   WHERE c.id = :controller_id
```

### 4.2 Provider Bazlı Görüntüleme

```
1. Kullanıcı provider seçer
2. Provider'a ait controller'ları getir:
   SELECT * FROM controllers WHERE provider_id = :provider_id

3. Her controller için realtimes üzerinden variable'ları getir:
   (aynı sorgu - controller_id bazlı)
```

### 4.3 Optimizasyon: Tek Sorgu ile Tam Veri

```sql
SELECT
    c.id as controller_id,
    c.name as controller_name,
    p.name as provider_name,
    dm.name as device_model_name,
    v.id as variable_id,
    v.name as variable_name,
    v.data_type,
    v.unit,
    v.value,
    r.id as realtime_id,
    r.active as realtime_active
FROM controllers c
JOIN realtimes r ON r.controller_id = c.id
JOIN variables v ON v.id = r.variable_id
LEFT JOIN providers p ON p.id = c.provider_id
LEFT JOIN device_models dm ON dm.id = c.device_model_id
WHERE c.site_id = :site_id
ORDER BY c.name, v.name;
```

---

## 5. Dart Servis Değişiklik Planı

### 5.1 VariableService Güncellemesi

Mevcut durum (hatalı):
```dart
// variables tablosunda controller_id YOK
final response = await supabase
    .from('variables')
    .select()
    .eq('controller_id', controllerId); // HATALI - bu kolon yok
```

Olması gereken (realtimes üzerinden):
```dart
// Realtimes junction tablosu üzerinden
final response = await supabase
    .from('realtimes')
    .select('*, variables(*)')
    .eq('controller_id', controllerId);
```

### 5.2 ControllerService Güncellemesi

Mevcut servis çalışıyor ancak eksik bilgiler var:
```dart
// Provider bilgisi ile birlikte
final response = await supabase
    .from('controllers')
    .select('*, providers(id, name), device_models(id, name, code)')
    .eq('site_id', siteId);
```

### 5.3 Yeni RealtimeService İhtiyacı

```dart
class RealtimeService {
  // Controller'ın variable'larını getir
  Future<List<Realtime>> getByController(String controllerId);

  // Site'ın tüm realtime verilerini getir
  Future<List<Realtime>> getBySite(String siteId);
}
```

---

## 6. Veri Modeli Diyagramı

```
┌──────────┐     ┌──────────────┐     ┌──────────────┐
│ tenants  │────►│organizations │────►│    sites      │
└──────────┘     └──────────────┘     └──────┬───────┘
                                              │
                                    ┌─────────┴─────────┐
                                    │                   │
                              ┌─────▼──────┐    ┌──────▼──────┐
                              │   units    │    │ controllers  │
                              └────────────┘    └──────┬───────┘
                                                       │
                                          ┌────────────┼────────────┐
                                          │            │            │
                                   ┌──────▼───┐ ┌─────▼──────┐ ┌──▼───────────┐
                                   │providers │ │device_models│ │  realtimes   │
                                   └──────────┘ └─────┬──────┘ └──┬───────────┘
                                                      │           │
                                                ┌─────▼──────┐   │
                                                │ variables  │◄──┘
                                                └────────────┘
```

---

## 7. Bilinen Kısıtlamalar ve Notlar

1. **Variables tablosunda `controller_id` yok** - Dart model'deki `controllerId` alanı DB'ye karşılık gelmiyor
2. **Variables tablosunda `tenant_id` yok** - Tenant filtreleme doğrudan yapılamaz
3. **Workflows tablosu IoT ile ilgisiz** - İş emri/work request yönetimi için kullanılıyor
4. **device_model code benzersizliği** - Aynı code birden fazla provider tarafından kullanılabilir
5. **Realtimes tablosu `cancelled_controller_id` FK'sı var** - İptal edilmiş controller takibi mevcut
6. **Provider'lar `site_id` ve `unit_id` ile lokasyona bağlanır** - Site bazlı filtreleme mümkün
