# IoT SQL Sorgu Referansı

Bu doküman, DB analizi sırasında kullanılan tüm SQL sorgularını ve amaçlarını içerir.
Sorgular `scripts/` klasöründe de mevcuttur.

---

## 1. Şema Keşif Sorguları

**Script:** `scripts/discover_schema.sql`

### 1.1 Tablo Kolon Yapısını Öğrenme

```sql
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'providers'
ORDER BY ordinal_position;
```

**Amaç:** Gerçek DB kolon adlarını keşfetmek. Dart model'lerindeki kolon adları DB ile uyuşmuyordu (örn: `type` → `protocol_type_id`, `host` → `ip`).

### 1.2 Tablo Kayıt Sayıları

```sql
SELECT
    (SELECT COUNT(*) FROM providers) as providers,
    (SELECT COUNT(*) FROM controllers) as controllers,
    (SELECT COUNT(*) FROM variables) as variables,
    (SELECT COUNT(*) FROM workflows) as workflows,
    (SELECT COUNT(*) FROM sites) as sites,
    (SELECT COUNT(*) FROM units) as units;
```

**Sonuç:** providers=18, controllers=219, variables=7838, workflows=0, sites=13, units=149

---

## 2. İlişki Keşif Sorguları

**Script:** `scripts/discover_relationships.sql`

### 2.1 Junction/Bridge Tabloları Bulma

```sql
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND (
    table_name LIKE '%\_%\_%'
    OR table_name LIKE '%_variables'
    OR table_name LIKE '%_controllers'
)
ORDER BY table_name;
```

**Amaç:** Variables-Controller arasındaki bağlantı tablosunu bulmak.

### 2.2 Foreign Key İlişkileri

```sql
-- Variables FK'ları
SELECT
    tc.constraint_name,
    kcu.column_name,
    ccu.table_name AS references_table,
    ccu.column_name AS references_column
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
AND tc.table_name = 'variables';
```

**Bulgu:** Variables tablosunda `controller_id` FK'sı yok. `device_model_id` ve `priority_id` FK'ları mevcut.

### 2.3 Realtime Tablo Yapısı

```sql
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name LIKE '%realtime%'
ORDER BY table_name, ordinal_position;
```

**Bulgu:** `realtimes` tablosu hem `controller_id` hem `variable_id` içeriyor → Junction tablo.

---

## 3. Device Model İlişki Sorguları

**Script:** `scripts/analyze_device_model_relationship.sql`

### 3.1 Device Model Kapsam Analizi

```sql
-- Controller'ların device_model coverage'ı
SELECT
    COUNT(*) as total_controllers,
    COUNT(device_model_id) as with_device_model,
    COUNT(*) - COUNT(device_model_id) as without_device_model,
    ROUND(COUNT(device_model_id)::numeric / COUNT(*)::numeric * 100, 2) as coverage_percent
FROM controllers;
```

**Sonuç:** 219 controller'dan 172'si (%78.54) device_model_id'ye sahip.

### 3.2 Eşleşme İstatistikleri

```sql
SELECT
    (SELECT COUNT(*) FROM controllers WHERE device_model_id IS NOT NULL) as controllers_with_model,
    (SELECT COUNT(*) FROM variables WHERE device_model_id IS NOT NULL) as variables_with_model,
    (SELECT COUNT(DISTINCT c.id)
     FROM controllers c
     JOIN variables v ON v.device_model_id = c.device_model_id) as controllers_with_variables,
    (SELECT COUNT(DISTINCT v.id)
     FROM variables v
     JOIN controllers c ON c.device_model_id = v.device_model_id) as variables_matched_to_controllers;
```

### 3.3 Orphan Kontrolü

```sql
-- Controller'sız variable'lar
SELECT COUNT(*) as orphan_variable_count
FROM variables v
WHERE NOT EXISTS (
    SELECT 1 FROM controllers c WHERE c.device_model_id = v.device_model_id
);

-- Variable'sız controller'lar
SELECT c.id, c.name, c.device_model_id, dm.name as device_model_name
FROM controllers c
LEFT JOIN device_models dm ON dm.id = c.device_model_id
WHERE NOT EXISTS (
    SELECT 1 FROM variables v WHERE v.device_model_id = c.device_model_id
)
LIMIT 10;
```

---

## 4. Provider İzolasyon Sorguları

**Script:** `scripts/analyze_provider_isolation.sql`

### 4.1 Paylaşımlı Device Model Tespiti

```sql
SELECT
    dm.code as device_model_code,
    dm.name as device_model_name,
    COUNT(DISTINCT c.provider_id) as provider_count,
    COUNT(DISTINCT c.id) as controller_count,
    STRING_AGG(DISTINCT p.name, ', ') as providers
FROM device_models dm
JOIN controllers c ON c.device_model_id = dm.id
LEFT JOIN providers p ON p.id = c.provider_id
GROUP BY dm.code, dm.name
HAVING COUNT(DISTINCT c.provider_id) > 1
ORDER BY provider_count DESC;
```

**Bulgu:** Örneğin code `208` (mcella_v1) birden fazla provider tarafından kullanılıyor.

### 4.2 Realtimes İzolasyon Kontrolü

```sql
SELECT
    p.name as provider_name,
    c.name as controller_name,
    dm.name as device_model,
    COUNT(r.id) as realtime_count,
    COUNT(DISTINCT r.variable_id) as unique_variables
FROM realtimes r
JOIN controllers c ON c.id = r.controller_id
LEFT JOIN providers p ON p.id = c.provider_id
LEFT JOIN device_models dm ON dm.id = c.device_model_id
GROUP BY p.name, c.name, dm.name
ORDER BY p.name, c.name
LIMIT 20;
```

**Sonuç:** Realtimes tablosu controller_id bazında izolasyon sağlıyor.

### 4.3 Provider Özet

```sql
SELECT
    p.name as provider_name,
    COUNT(DISTINCT c.id) as controller_count,
    COUNT(DISTINCT c.device_model_id) as unique_device_models,
    COUNT(DISTINCT c.site_id) as site_count,
    (SELECT COUNT(*)
     FROM realtimes r
     WHERE r.controller_id IN (SELECT id FROM controllers WHERE provider_id = p.id)
    ) as total_realtimes
FROM providers p
LEFT JOIN controllers c ON c.provider_id = p.id
GROUP BY p.id, p.name
ORDER BY controller_count DESC;
```

---

## 5. Hiyerarşik Görünüm Sorguları

**Script:** `scripts/analyze_iot_simple.sql`

### 5.1 Tam Hiyerarşi

```sql
SELECT
    t.id as tenant_id,
    t.name as tenant_name,
    s.id as site_id,
    s.name as site_name,
    p.id as provider_id,
    p.name as provider_name,
    c.id as controller_id,
    c.name as controller_name,
    (SELECT COUNT(*) FROM realtimes r WHERE r.controller_id = c.id) as variable_count
FROM tenants t
LEFT JOIN sites s ON s.tenant_id = t.id
LEFT JOIN controllers c ON c.site_id = s.id
LEFT JOIN providers p ON p.id = c.provider_id
WHERE c.id IS NOT NULL
ORDER BY t.name, s.name, p.name, c.name;
```

---

## 6. Mobil Uygulama İçin Kullanılacak Sorgular

### 6.1 Site'a Ait Controller Listesi

```sql
SELECT c.*, p.name as provider_name, dm.name as device_model_name
FROM controllers c
LEFT JOIN providers p ON p.id = c.provider_id
LEFT JOIN device_models dm ON dm.id = c.device_model_id
WHERE c.site_id = :site_id
ORDER BY c.name;
```

### 6.2 Controller'ın Variable'ları (Realtimes Üzerinden)

```sql
SELECT
    r.id as realtime_id,
    r.active as realtime_active,
    v.*
FROM realtimes r
JOIN variables v ON v.id = r.variable_id
WHERE r.controller_id = :controller_id
ORDER BY v.name;
```

### 6.3 Site'ın Tüm Verileri (Tek Sorgu)

```sql
SELECT
    c.id as controller_id,
    c.name as controller_name,
    p.name as provider_name,
    dm.name as device_model_name,
    r.id as realtime_id,
    v.id as variable_id,
    v.name as variable_name,
    v.data_type,
    v.unit,
    v.value,
    v.minimum,
    v.maximum
FROM controllers c
JOIN realtimes r ON r.controller_id = c.id
JOIN variables v ON v.id = r.variable_id
LEFT JOIN providers p ON p.id = c.provider_id
LEFT JOIN device_models dm ON dm.id = c.device_model_id
WHERE c.site_id = :site_id
ORDER BY c.name, v.name;
```

### 6.4 Provider Listesi (Site Bazlı)

```sql
SELECT DISTINCT p.*
FROM providers p
JOIN controllers c ON c.provider_id = p.id
WHERE c.site_id = :site_id
ORDER BY p.name;
```
