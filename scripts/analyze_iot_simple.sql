-- ============================================
-- KISA IOT VERİ ANALİZİ
-- Supabase SQL Editor'da çalıştırın
-- ============================================

-- Hiyerarşik görünüm (tek sorgu ile tüm ilişkiler)
SELECT
    t.id as tenant_id,
    t.name as tenant_name,
    s.id as site_id,
    s.name as site_name,
    p.id as provider_id,
    p.name as provider_name,
    p.type as provider_type,
    c.id as controller_id,
    c.name as controller_name,
    c.type as controller_type,
    c.status as controller_status,
    (SELECT COUNT(*) FROM variables WHERE controller_id = c.id) as variable_count
FROM tenants t
LEFT JOIN sites s ON s.tenant_id = t.id
LEFT JOIN controllers c ON c.site_id = s.id OR (c.tenant_id = t.id AND c.site_id IS NULL)
LEFT JOIN providers p ON p.id = c.provider_id
WHERE c.id IS NOT NULL
ORDER BY t.name, s.name, p.name, c.name;
