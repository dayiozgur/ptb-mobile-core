-- ============================================
-- REALTIME VE İLİŞKİ KEŞİF SCRİPTİ
-- Variables-Controller bağlantısını anlamak için
-- ============================================

-- 1. Realtime ile ilgili tüm tabloları bul
SELECT '=== REALTIME TABLES ===' as section;
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name LIKE '%realtime%'
ORDER BY table_name;

-- 2. Device ile ilgili tüm tabloları bul
SELECT '=== DEVICE RELATED TABLES ===' as section;
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND (table_name LIKE '%device%' OR table_name LIKE '%variable%' OR table_name LIKE '%controller%')
ORDER BY table_name;

-- 3. Tüm junction/bridge tabloları bul (iki FK içeren tablolar)
SELECT '=== POTENTIAL JUNCTION TABLES ===' as section;
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND (
    table_name LIKE '%\_%\_%' -- iki underscore içeren (genellikle junction)
    OR table_name LIKE '%_variables'
    OR table_name LIKE '%_controllers'
)
ORDER BY table_name;

-- 4. Variables tablosundaki tüm FK ilişkileri
SELECT '=== VARIABLES FOREIGN KEYS ===' as section;
SELECT
    tc.constraint_name,
    kcu.column_name,
    ccu.table_name AS references_table,
    ccu.column_name AS references_column
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
AND tc.table_name = 'variables';

-- 5. Controllers tablosundaki tüm FK ilişkileri
SELECT '=== CONTROLLERS FOREIGN KEYS ===' as section;
SELECT
    tc.constraint_name,
    kcu.column_name,
    ccu.table_name AS references_table,
    ccu.column_name AS references_column
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
AND tc.table_name = 'controllers';

-- 6. device_model_id üzerinden ilişki var mı?
SELECT '=== DEVICE MODEL RELATIONSHIP ===' as section;
SELECT
    'controllers' as source_table,
    COUNT(DISTINCT device_model_id) as unique_device_models
FROM controllers
WHERE device_model_id IS NOT NULL
UNION ALL
SELECT
    'variables' as source_table,
    COUNT(DISTINCT device_model_id) as unique_device_models
FROM variables
WHERE device_model_id IS NOT NULL;

-- 7. device_models tablosu var mı ve yapısı nedir?
SELECT '=== DEVICE_MODELS TABLE COLUMNS ===' as section;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'device_models'
ORDER BY ordinal_position;

-- 8. Realtime tablolarının yapısı (eğer varsa)
SELECT '=== REALTIME TABLE COLUMNS (if exists) ===' as section;
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name LIKE '%realtime%'
ORDER BY table_name, ordinal_position;

-- 9. Örnek bir controller'ın device_model_id'si ile eşleşen variables
SELECT '=== SAMPLE: CONTROLLER-VARIABLE VIA DEVICE_MODEL ===' as section;
SELECT
    c.id as controller_id,
    c.name as controller_name,
    c.device_model_id,
    COUNT(v.id) as variable_count
FROM controllers c
LEFT JOIN variables v ON v.device_model_id = c.device_model_id
WHERE c.device_model_id IS NOT NULL
GROUP BY c.id, c.name, c.device_model_id
ORDER BY variable_count DESC
LIMIT 10;

-- 10. Public şemadaki tüm tabloları listele
SELECT '=== ALL PUBLIC TABLES ===' as section;
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_type = 'BASE TABLE'
ORDER BY table_name;
