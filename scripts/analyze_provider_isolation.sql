-- ============================================
-- PROVIDER İZOLASYONU ANALİZİ
-- Aynı device_model'i kullanan farklı provider'lar arasındaki veri izolasyonu
-- ============================================

-- 1. Aynı device_model code'unu kullanan farklı provider'lar var mı?
SELECT '=== SHARED DEVICE_MODEL CODES ACROSS PROVIDERS ===' as section;
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

-- 2. Aynı device_model_id'yi paylaşan controller'lar (farklı provider'lardan)
SELECT '=== CONTROLLERS SHARING SAME DEVICE_MODEL FROM DIFFERENT PROVIDERS ===' as section;
SELECT
    dm.id as device_model_id,
    dm.code as model_code,
    dm.name as model_name,
    c.id as controller_id,
    c.name as controller_name,
    p.id as provider_id,
    p.name as provider_name,
    s.name as site_name
FROM device_models dm
JOIN controllers c ON c.device_model_id = dm.id
LEFT JOIN providers p ON p.id = c.provider_id
LEFT JOIN sites s ON s.id = c.site_id
WHERE dm.id IN (
    SELECT device_model_id
    FROM controllers
    WHERE device_model_id IS NOT NULL
    GROUP BY device_model_id
    HAVING COUNT(DISTINCT provider_id) > 1
)
ORDER BY dm.code, p.name;

-- 3. Variables tablosunda provider_id var mı?
SELECT '=== VARIABLES TABLE - PROVIDER ISOLATION CHECK ===' as section;
SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'variables'
AND column_name IN ('provider_id', 'controller_id', 'tenant_id', 'site_id');

-- 4. Realtimes tablosu üzerinden izolasyon analizi
SELECT '=== REALTIMES ISOLATION ANALYSIS ===' as section;
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

-- 5. Realtimes vs Variables karşılaştırması (controller bazında)
SELECT '=== REALTIMES VS DEVICE_MODEL VARIABLES PER CONTROLLER ===' as section;
SELECT
    c.id as controller_id,
    c.name as controller_name,
    p.name as provider_name,
    dm.name as device_model,
    (SELECT COUNT(*) FROM variables v WHERE v.device_model_id = c.device_model_id) as model_variable_count,
    (SELECT COUNT(*) FROM realtimes r WHERE r.controller_id = c.id) as realtime_count,
    CASE
        WHEN (SELECT COUNT(*) FROM realtimes r WHERE r.controller_id = c.id) > 0
        THEN 'Has Realtimes'
        ELSE 'No Realtimes'
    END as isolation_status
FROM controllers c
LEFT JOIN providers p ON p.id = c.provider_id
LEFT JOIN device_models dm ON dm.id = c.device_model_id
WHERE c.device_model_id IS NOT NULL
ORDER BY p.name, c.name
LIMIT 20;

-- 6. Provider bazında toplam özet
SELECT '=== PROVIDER SUMMARY ===' as section;
SELECT
    p.id as provider_id,
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

-- 7. Device model code tekrarı kontrolü
SELECT '=== DEVICE MODEL CODE UNIQUENESS ===' as section;
SELECT
    code,
    COUNT(*) as count,
    STRING_AGG(name, ', ') as names
FROM device_models
WHERE code IS NOT NULL
GROUP BY code
HAVING COUNT(*) > 1
ORDER BY count DESC;
