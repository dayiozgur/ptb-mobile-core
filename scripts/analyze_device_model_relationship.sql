-- ============================================
-- DEVICE_MODEL_ID İLİŞKİ ANALİZİ
-- Controller → device_model → Variables akışını doğrula
-- ============================================

-- 1. Her controller'ın device_model_id'si var mı?
SELECT '=== CONTROLLER DEVICE_MODEL COVERAGE ===' as section;
SELECT
    COUNT(*) as total_controllers,
    COUNT(device_model_id) as with_device_model,
    COUNT(*) - COUNT(device_model_id) as without_device_model,
    ROUND(COUNT(device_model_id)::numeric / COUNT(*)::numeric * 100, 2) as coverage_percent
FROM controllers;

-- 2. Her variable'ın device_model_id'si var mı?
SELECT '=== VARIABLE DEVICE_MODEL COVERAGE ===' as section;
SELECT
    COUNT(*) as total_variables,
    COUNT(device_model_id) as with_device_model,
    COUNT(*) - COUNT(device_model_id) as without_device_model,
    ROUND(COUNT(device_model_id)::numeric / COUNT(*)::numeric * 100, 2) as coverage_percent
FROM variables;

-- 3. Device model başına controller ve variable sayısı
SELECT '=== DEVICE MODEL DISTRIBUTION ===' as section;
SELECT
    dm.id as device_model_id,
    dm.name as device_model_name,
    dm.protocol,
    COUNT(DISTINCT c.id) as controller_count,
    COUNT(DISTINCT v.id) as variable_count
FROM device_models dm
LEFT JOIN controllers c ON c.device_model_id = dm.id
LEFT JOIN variables v ON v.device_model_id = dm.id
GROUP BY dm.id, dm.name, dm.protocol
ORDER BY controller_count DESC, variable_count DESC
LIMIT 20;

-- 4. Ortak device_model_id üzerinden eşleşen controller-variable sayısı
SELECT '=== CONTROLLER-VARIABLE MATCH VIA DEVICE_MODEL ===' as section;
SELECT
    c.id as controller_id,
    c.name as controller_name,
    c.device_model_id,
    dm.name as device_model_name,
    c.site_id,
    s.name as site_name,
    COUNT(v.id) as matched_variable_count
FROM controllers c
JOIN device_models dm ON dm.id = c.device_model_id
JOIN variables v ON v.device_model_id = c.device_model_id
LEFT JOIN sites s ON s.id = c.site_id
GROUP BY c.id, c.name, c.device_model_id, dm.name, c.site_id, s.name
ORDER BY matched_variable_count DESC
LIMIT 15;

-- 5. Toplam eşleşme istatistikleri
SELECT '=== TOTAL MATCH STATISTICS ===' as section;
SELECT
    (SELECT COUNT(*) FROM controllers WHERE device_model_id IS NOT NULL) as controllers_with_model,
    (SELECT COUNT(*) FROM variables WHERE device_model_id IS NOT NULL) as variables_with_model,
    (SELECT COUNT(DISTINCT c.id)
     FROM controllers c
     JOIN variables v ON v.device_model_id = c.device_model_id) as controllers_with_variables,
    (SELECT COUNT(DISTINCT v.id)
     FROM variables v
     JOIN controllers c ON c.device_model_id = v.device_model_id) as variables_matched_to_controllers;

-- 6. Realtimes vs device_model karşılaştırması
SELECT '=== REALTIMES VS DEVICE_MODEL COMPARISON ===' as section;
SELECT
    'realtimes' as method,
    COUNT(DISTINCT controller_id) as unique_controllers,
    COUNT(DISTINCT variable_id) as unique_variables,
    COUNT(*) as total_bindings
FROM realtimes
WHERE controller_id IS NOT NULL AND variable_id IS NOT NULL
UNION ALL
SELECT
    'device_model' as method,
    COUNT(DISTINCT c.id) as unique_controllers,
    COUNT(DISTINCT v.id) as unique_variables,
    SUM(variable_count) as total_bindings
FROM (
    SELECT c.id, COUNT(v.id) as variable_count
    FROM controllers c
    JOIN variables v ON v.device_model_id = c.device_model_id
    GROUP BY c.id
) sub
CROSS JOIN controllers c2 WHERE c2.id = sub.id;

-- 7. Bir site için tam hiyerarşi örneği
SELECT '=== SAMPLE SITE HIERARCHY ===' as section;
SELECT
    s.id as site_id,
    s.name as site_name,
    p.id as provider_id,
    p.name as provider_name,
    c.id as controller_id,
    c.name as controller_name,
    dm.name as device_model,
    COUNT(v.id) as variable_count
FROM sites s
JOIN controllers c ON c.site_id = s.id
LEFT JOIN providers p ON p.id = c.provider_id
LEFT JOIN device_models dm ON dm.id = c.device_model_id
LEFT JOIN variables v ON v.device_model_id = c.device_model_id
GROUP BY s.id, s.name, p.id, p.name, c.id, c.name, dm.name
ORDER BY s.name, p.name, c.name
LIMIT 30;

-- 8. Controller'sız variable'lar var mı? (orphan check)
SELECT '=== ORPHAN VARIABLES (no matching controller) ===' as section;
SELECT
    COUNT(*) as orphan_variable_count,
    COUNT(DISTINCT device_model_id) as orphan_device_models
FROM variables v
WHERE NOT EXISTS (
    SELECT 1 FROM controllers c WHERE c.device_model_id = v.device_model_id
);

-- 9. Variable'sız controller'lar var mı?
SELECT '=== CONTROLLERS WITHOUT VARIABLES ===' as section;
SELECT
    c.id,
    c.name,
    c.device_model_id,
    dm.name as device_model_name
FROM controllers c
LEFT JOIN device_models dm ON dm.id = c.device_model_id
WHERE NOT EXISTS (
    SELECT 1 FROM variables v WHERE v.device_model_id = c.device_model_id
)
LIMIT 10;

-- 10. Provider → Controller → Variables tam zincir
SELECT '=== FULL CHAIN: PROVIDER → CONTROLLER → VARIABLES ===' as section;
SELECT
    p.name as provider,
    c.name as controller,
    dm.name as device_model,
    c.site_id IS NOT NULL as has_site,
    COUNT(v.id) as variable_count
FROM providers p
JOIN controllers c ON c.provider_id = p.id
LEFT JOIN device_models dm ON dm.id = c.device_model_id
LEFT JOIN variables v ON v.device_model_id = c.device_model_id
GROUP BY p.name, c.name, dm.name, c.site_id
ORDER BY p.name, c.name
LIMIT 30;
