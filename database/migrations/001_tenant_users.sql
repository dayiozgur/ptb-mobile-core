-- ============================================
-- TENANT_USERS Migration
-- Geriye uyumlu çoklu tenant üyelik sistemi
-- ============================================

-- ============================================
-- 1. TENANT_USERS TABLOSU
-- ============================================

CREATE TABLE IF NOT EXISTS public.tenant_users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    -- İlişkiler
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,

    -- Rol ve Durum
    role varchar(50) NOT NULL DEFAULT 'member'
        CHECK (role IN ('owner', 'admin', 'manager', 'member', 'viewer')),
    status varchar(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'inactive', 'suspended', 'pending')),

    -- Varsayılan tenant işareti
    is_default boolean NOT NULL DEFAULT false,

    -- Davet bilgileri
    invited_by uuid REFERENCES auth.users(id),
    invited_at timestamptz,
    invitation_token uuid,
    invitation_expires_at timestamptz,

    -- Zaman damgaları
    joined_at timestamptz DEFAULT now(),
    last_accessed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    -- Unique constraint: Bir kullanıcı bir tenant'a sadece bir kez üye olabilir
    UNIQUE(user_id, tenant_id)
);

-- İndeksler
CREATE INDEX IF NOT EXISTS idx_tenant_users_user_id ON public.tenant_users(user_id);
CREATE INDEX IF NOT EXISTS idx_tenant_users_tenant_id ON public.tenant_users(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tenant_users_user_default ON public.tenant_users(user_id, is_default) WHERE is_default = true;
CREATE INDEX IF NOT EXISTS idx_tenant_users_invitation_token ON public.tenant_users(invitation_token) WHERE invitation_token IS NOT NULL;

-- ============================================
-- 2. UPDATED_AT TRİGGER
-- ============================================

CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_tenant_users_updated_at ON public.tenant_users;
CREATE TRIGGER set_tenant_users_updated_at
    BEFORE UPDATE ON public.tenant_users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- ============================================
-- 3. TEK DEFAULT TENANT KONTROLÜ
-- Bir kullanıcının sadece bir default tenant'ı olabilir
-- ============================================

CREATE OR REPLACE FUNCTION public.ensure_single_default_tenant()
RETURNS TRIGGER AS $$
BEGIN
    -- Eğer yeni kayıt default olarak işaretlendiyse
    IF NEW.is_default = true THEN
        -- Diğer tenant'ları default olmaktan çıkar
        UPDATE public.tenant_users
        SET is_default = false
        WHERE user_id = NEW.user_id
          AND id != NEW.id
          AND is_default = true;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS ensure_single_default_tenant ON public.tenant_users;
CREATE TRIGGER ensure_single_default_tenant
    BEFORE INSERT OR UPDATE ON public.tenant_users
    FOR EACH ROW
    WHEN (NEW.is_default = true)
    EXECUTE FUNCTION public.ensure_single_default_tenant();

-- ============================================
-- 4. PROFILES.TENANT_ID SYNC (Geriye Uyumluluk)
-- tenant_users değiştiğinde profiles.tenant_id'yi güncelle
-- ============================================

CREATE OR REPLACE FUNCTION public.sync_profile_tenant_id()
RETURNS TRIGGER AS $$
BEGIN
    -- Eğer bu default tenant ise, profiles.tenant_id'yi güncelle
    IF NEW.is_default = true AND NEW.status = 'active' THEN
        UPDATE public.profiles
        SET tenant_id = NEW.tenant_id,
            updated_at = now()
        WHERE id = NEW.user_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS sync_profile_tenant_id ON public.tenant_users;
CREATE TRIGGER sync_profile_tenant_id
    AFTER INSERT OR UPDATE ON public.tenant_users
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_profile_tenant_id();

-- ============================================
-- 5. İLK TENANT ÜYELİĞİNDE DEFAULT YAP
-- Kullanıcının ilk tenant'ı otomatik default olsun
-- ============================================

CREATE OR REPLACE FUNCTION public.set_first_tenant_as_default()
RETURNS TRIGGER AS $$
BEGIN
    -- Eğer kullanıcının başka tenant'ı yoksa, bunu default yap
    IF NOT EXISTS (
        SELECT 1 FROM public.tenant_users
        WHERE user_id = NEW.user_id AND id != NEW.id
    ) THEN
        NEW.is_default = true;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_first_tenant_as_default ON public.tenant_users;
CREATE TRIGGER set_first_tenant_as_default
    BEFORE INSERT ON public.tenant_users
    FOR EACH ROW
    EXECUTE FUNCTION public.set_first_tenant_as_default();

-- ============================================
-- 6. MEVCUT VERİLERİ MİGRASYON (Geriye Uyumluluk)
-- profiles.tenant_id olan kullanıcıları tenant_users'a aktar
-- ============================================

-- Bu fonksiyon manuel çalıştırılmalı (bir kerelik migrasyon)
-- NOT: Sadece auth.users tablosunda mevcut olan profilleri migrate eder
CREATE OR REPLACE FUNCTION public.migrate_existing_profile_tenants()
RETURNS void AS $$
DECLARE
    v_migrated_count integer := 0;
    v_skipped_count integer := 0;
BEGIN
    -- Sadece auth.users'da mevcut olan profilleri migrate et
    INSERT INTO public.tenant_users (user_id, tenant_id, role, status, is_default, joined_at)
    SELECT
        p.id as user_id,
        p.tenant_id,
        COALESCE(
            CASE
                WHEN p.role = 'ROLE_ADMIN' THEN 'admin'
                WHEN p.role = 'ROLE_MANAGER' THEN 'manager'
                ELSE 'member'
            END,
            'member'
        ) as role,
        'active' as status,
        true as is_default,
        COALESCE(p.created_at, now()) as joined_at
    FROM public.profiles p
    WHERE p.tenant_id IS NOT NULL
      -- KRITIK: Sadece auth.users'da mevcut olan kullanıcıları al
      AND EXISTS (
          SELECT 1 FROM auth.users au
          WHERE au.id = p.id
      )
      -- Zaten tenant_users'da yoksa
      AND NOT EXISTS (
          SELECT 1 FROM public.tenant_users tu
          WHERE tu.user_id = p.id AND tu.tenant_id = p.tenant_id
      );

    GET DIAGNOSTICS v_migrated_count = ROW_COUNT;

    -- Migrate edilemeyen (auth.users'da olmayan) profil sayısını bul
    SELECT COUNT(*) INTO v_skipped_count
    FROM public.profiles p
    WHERE p.tenant_id IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM auth.users au
          WHERE au.id = p.id
      );

    RAISE NOTICE 'Migration completed. Migrated: %, Skipped (no auth user): %',
        v_migrated_count, v_skipped_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 7. ROW LEVEL SECURITY (RLS)
-- ============================================

ALTER TABLE public.tenant_users ENABLE ROW LEVEL SECURITY;

-- Kullanıcı kendi üyeliklerini görebilir
CREATE POLICY "Users can view own memberships"
    ON public.tenant_users
    FOR SELECT
    USING (auth.uid() = user_id);

-- Tenant admin'leri tüm üyeleri görebilir
CREATE POLICY "Tenant admins can view all members"
    ON public.tenant_users
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.tenant_users tu
            WHERE tu.tenant_id = tenant_users.tenant_id
              AND tu.user_id = auth.uid()
              AND tu.role IN ('owner', 'admin')
              AND tu.status = 'active'
        )
    );

-- Kullanıcı kendi üyeliğini güncelleyebilir (sadece belirli alanlar)
CREATE POLICY "Users can update own membership"
    ON public.tenant_users
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Tenant owner/admin yeni üye ekleyebilir
CREATE POLICY "Tenant admins can insert members"
    ON public.tenant_users
    FOR INSERT
    WITH CHECK (
        -- Kendini ekleyebilir (ilk tenant oluşturma)
        auth.uid() = user_id
        OR
        -- Veya admin ise
        EXISTS (
            SELECT 1 FROM public.tenant_users tu
            WHERE tu.tenant_id = tenant_id
              AND tu.user_id = auth.uid()
              AND tu.role IN ('owner', 'admin')
              AND tu.status = 'active'
        )
    );

-- Tenant owner üyeleri silebilir
CREATE POLICY "Tenant owners can delete members"
    ON public.tenant_users
    FOR DELETE
    USING (
        -- Kendini silebilir
        auth.uid() = user_id
        OR
        -- Veya owner ise
        EXISTS (
            SELECT 1 FROM public.tenant_users tu
            WHERE tu.tenant_id = tenant_users.tenant_id
              AND tu.user_id = auth.uid()
              AND tu.role = 'owner'
              AND tu.status = 'active'
        )
    );

-- ============================================
-- 8. YARDIMCI FONKSİYONLAR
-- ============================================

-- Kullanıcının tenant'larını getir
CREATE OR REPLACE FUNCTION public.get_user_tenants(p_user_id uuid DEFAULT auth.uid())
RETURNS TABLE (
    tenant_id uuid,
    tenant_name varchar,
    role varchar,
    is_default boolean,
    joined_at timestamptz
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.id as tenant_id,
        t.name::varchar as tenant_name,
        tu.role::varchar,
        tu.is_default,
        tu.joined_at
    FROM public.tenant_users tu
    JOIN public.tenants t ON t.id = tu.tenant_id
    WHERE tu.user_id = p_user_id
      AND tu.status = 'active'
      AND (t.active IS NULL OR t.active = true)
    ORDER BY tu.is_default DESC, tu.joined_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Kullanıcının varsayılan tenant'ını getir
CREATE OR REPLACE FUNCTION public.get_user_default_tenant(p_user_id uuid DEFAULT auth.uid())
RETURNS uuid AS $$
DECLARE
    v_tenant_id uuid;
BEGIN
    SELECT tenant_id INTO v_tenant_id
    FROM public.tenant_users
    WHERE user_id = p_user_id
      AND is_default = true
      AND status = 'active'
    LIMIT 1;

    -- Default yoksa ilk aktif tenant'ı döndür
    IF v_tenant_id IS NULL THEN
        SELECT tenant_id INTO v_tenant_id
        FROM public.tenant_users
        WHERE user_id = p_user_id
          AND status = 'active'
        ORDER BY joined_at ASC
        LIMIT 1;
    END IF;

    RETURN v_tenant_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Varsayılan tenant'ı değiştir
CREATE OR REPLACE FUNCTION public.set_default_tenant(p_tenant_id uuid)
RETURNS boolean AS $$
BEGIN
    -- Üyelik kontrolü
    IF NOT EXISTS (
        SELECT 1 FROM public.tenant_users
        WHERE user_id = auth.uid()
          AND tenant_id = p_tenant_id
          AND status = 'active'
    ) THEN
        RETURN false;
    END IF;

    -- Tüm tenant'ları default olmaktan çıkar
    UPDATE public.tenant_users
    SET is_default = false
    WHERE user_id = auth.uid()
      AND is_default = true;

    -- Seçilen tenant'ı default yap
    UPDATE public.tenant_users
    SET is_default = true,
        last_accessed_at = now()
    WHERE user_id = auth.uid()
      AND tenant_id = p_tenant_id;

    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 9. KULLANIM ÖRNEKLERİ
-- ============================================

/*
-- Kullanıcının tenant'larını getir:
SELECT * FROM get_user_tenants();

-- Varsayılan tenant'ı getir:
SELECT get_user_default_tenant();

-- Varsayılan tenant'ı değiştir:
SELECT set_default_tenant('tenant-uuid-here');

-- Mevcut verileri migrate et (BİR KERELİK):
SELECT migrate_existing_profile_tenants();

-- Yeni tenant oluşturup kullanıcıyı owner olarak ekle:
WITH new_tenant AS (
    INSERT INTO tenants (name, code)
    VALUES ('Yeni Şirket', 'yeni-sirket')
    RETURNING id
)
INSERT INTO tenant_users (user_id, tenant_id, role, is_default)
SELECT auth.uid(), id, 'owner', true
FROM new_tenant;
*/

-- ============================================
-- 10. GRANT PERMISSIONS
-- ============================================

GRANT SELECT ON public.tenant_users TO authenticated;
GRANT INSERT ON public.tenant_users TO authenticated;
GRANT UPDATE ON public.tenant_users TO authenticated;
GRANT DELETE ON public.tenant_users TO authenticated;

GRANT EXECUTE ON FUNCTION public.get_user_tenants TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_default_tenant TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_default_tenant TO authenticated;
