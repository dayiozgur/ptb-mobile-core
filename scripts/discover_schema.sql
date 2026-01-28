-- ============================================
-- DB ŞEMA KEŞİF SCRİPTİ
-- Önce bu script'i çalıştırarak gerçek kolon adlarını öğrenelim
-- ============================================

-- 1. PROVIDERS tablosu kolonları
SELECT 'PROVIDERS COLUMNS' as table_info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'providers'
ORDER BY ordinal_position;

-- 2. CONTROLLERS tablosu kolonları
SELECT 'CONTROLLERS COLUMNS' as table_info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'controllers'
ORDER BY ordinal_position;

-- 3. VARIABLES tablosu kolonları
SELECT 'VARIABLES COLUMNS' as table_info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'variables'
ORDER BY ordinal_position;

-- 4. WORKFLOWS tablosu kolonları
SELECT 'WORKFLOWS COLUMNS' as table_info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'workflows'
ORDER BY ordinal_position;

-- 5. SITES tablosu kolonları
SELECT 'SITES COLUMNS' as table_info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'sites'
ORDER BY ordinal_position;

-- 6. UNITS tablosu kolonları
SELECT 'UNITS COLUMNS' as table_info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'units'
ORDER BY ordinal_position;

-- 7. Basit veri sayımı (kolon adı gerektirmez)
SELECT 'DATA COUNTS' as summary;
SELECT
    (SELECT COUNT(*) FROM providers) as providers,
    (SELECT COUNT(*) FROM controllers) as controllers,
    (SELECT COUNT(*) FROM variables) as variables,
    (SELECT COUNT(*) FROM workflows) as workflows,
    (SELECT COUNT(*) FROM sites) as sites,
    (SELECT COUNT(*) FROM units) as units;

-- 8. Providers tablosundan sadece id ve name (kesin var olan kolonlar)
SELECT 'PROVIDERS DATA' as table_data;
SELECT id, name FROM providers LIMIT 10;

-- 9. Controllers tablosundan sadece id ve name
SELECT 'CONTROLLERS DATA' as table_data;
SELECT id, name FROM controllers LIMIT 10;

-- 10. Variables tablosundan sadece id ve name
SELECT 'VARIABLES DATA' as table_data;
SELECT id, name FROM variables LIMIT 10;
