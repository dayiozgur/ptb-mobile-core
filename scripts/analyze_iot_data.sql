-- ============================================
-- IOT VERİ ANALİZ SCRİPTİ
-- Bu script'i Supabase SQL Editor'da çalıştırın
-- ============================================

-- Tenant ID'nizi buraya yazın
-- Eğer bilmiyorsanız önce aşağıdaki sorguyu çalıştırın:
-- SELECT id, name FROM tenants;

-- ============================================
-- 1. TENANT BİLGİSİ
-- ============================================
SELECT '=== TENANTS ===' as section;
SELECT id, name, created_at
FROM tenants
ORDER BY name;

-- ============================================
-- 2. ORGANİZASYON HİYERARŞİSİ
-- ============================================
SELECT '=== ORGANIZATIONS ===' as section;
SELECT
    o.id as org_id,
    o.name as org_name,
    o.tenant_id,
    t.name as tenant_name
FROM organizations o
LEFT JOIN tenants t ON t.id = o.tenant_id
ORDER BY t.name, o.name;

-- ============================================
-- 3. SITE'LAR
-- ============================================
SELECT '=== SITES ===' as section;
SELECT
    s.id as site_id,
    s.name as site_name,
    s.code as site_code,
    s.tenant_id,
    s.organization_id,
    o.name as org_name
FROM sites s
LEFT JOIN organizations o ON o.id = s.organization_id
ORDER BY o.name, s.name;

-- ============================================
-- 4. UNIT'LAR
-- ============================================
SELECT '=== UNITS ===' as section;
SELECT
    u.id as unit_id,
    u.name as unit_name,
    u.code as unit_code,
    u.site_id,
    s.name as site_name
FROM units u
LEFT JOIN sites s ON s.id = u.site_id
ORDER BY s.name, u.name;

-- ============================================
-- 5. PROVIDERS (Veri Sağlayıcılar)
-- ============================================
SELECT '=== PROVIDERS ===' as section;
SELECT
    p.id as provider_id,
    p.name as provider_name,
    p.code,
    p.type,
    p.status,
    p.host,
    p.port,
    p.tenant_id,
    p.active
FROM providers p
ORDER BY p.name;

-- ============================================
-- 6. CONTROLLERS
-- ============================================
SELECT '=== CONTROLLERS ===' as section;
SELECT
    c.id as controller_id,
    c.name as controller_name,
    c.code,
    c.type,
    c.protocol,
    c.status,
    c.ip_address,
    c.port,
    c.tenant_id,
    c.site_id,
    s.name as site_name,
    c.unit_id,
    u.name as unit_name,
    c.provider_id,
    p.name as provider_name,
    c.active
FROM controllers c
LEFT JOIN sites s ON s.id = c.site_id
LEFT JOIN units u ON u.id = c.unit_id
LEFT JOIN providers p ON p.id = c.provider_id
ORDER BY s.name, c.name;

-- ============================================
-- 7. VARIABLES
-- ============================================
SELECT '=== VARIABLES ===' as section;
SELECT
    v.id as variable_id,
    v.name as variable_name,
    v.code,
    v.data_type,
    v.category,
    v.address,
    v.unit as unit_label,
    v.controller_id,
    c.name as controller_name,
    v.tenant_id,
    v.active
FROM variables v
LEFT JOIN controllers c ON c.id = v.controller_id
ORDER BY c.name, v.name;

-- ============================================
-- 8. WORKFLOWS
-- ============================================
SELECT '=== WORKFLOWS ===' as section;
SELECT
    w.id as workflow_id,
    w.name as workflow_name,
    w.type,
    w.status,
    w.tenant_id,
    w.site_id,
    s.name as site_name,
    w.active
FROM workflows w
LEFT JOIN sites s ON s.id = w.site_id
ORDER BY w.name;

-- ============================================
-- 9. ÖZET İSTATİSTİKLER
-- ============================================
SELECT '=== SUMMARY ===' as section;
SELECT
    (SELECT COUNT(*) FROM tenants) as tenant_count,
    (SELECT COUNT(*) FROM organizations) as org_count,
    (SELECT COUNT(*) FROM sites) as site_count,
    (SELECT COUNT(*) FROM units) as unit_count,
    (SELECT COUNT(*) FROM providers) as provider_count,
    (SELECT COUNT(*) FROM controllers) as controller_count,
    (SELECT COUNT(*) FROM variables) as variable_count,
    (SELECT COUNT(*) FROM workflows) as workflow_count;

-- ============================================
-- 10. CONTROLLER-VARIABLE İLİŞKİ DETAYI
-- (Her controller altında kaç variable var)
-- ============================================
SELECT '=== CONTROLLER VARIABLE COUNTS ===' as section;
SELECT
    c.id as controller_id,
    c.name as controller_name,
    c.site_id,
    s.name as site_name,
    COUNT(v.id) as variable_count
FROM controllers c
LEFT JOIN sites s ON s.id = c.site_id
LEFT JOIN variables v ON v.controller_id = c.id
GROUP BY c.id, c.name, c.site_id, s.name
ORDER BY s.name, c.name;

-- ============================================
-- 11. HİYERARŞİK GÖRÜNÜM (Tek Sorgu)
-- ============================================
SELECT '=== HIERARCHICAL VIEW ===' as section;
SELECT
    t.name as tenant,
    o.name as organization,
    s.name as site,
    p.name as provider,
    c.name as controller,
    c.type as controller_type,
    c.status as controller_status,
    COUNT(v.id) as variable_count
FROM tenants t
LEFT JOIN organizations o ON o.tenant_id = t.id
LEFT JOIN sites s ON s.organization_id = o.id
LEFT JOIN controllers c ON c.site_id = s.id
LEFT JOIN providers p ON p.id = c.provider_id
LEFT JOIN variables v ON v.controller_id = c.id
GROUP BY t.name, o.name, s.name, p.name, c.name, c.type, c.status
ORDER BY t.name, o.name, s.name, p.name, c.name;
