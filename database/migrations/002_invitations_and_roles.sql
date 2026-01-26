-- ============================================
-- Migration: 002_invitations_and_roles.sql
-- Kullanıcı davet sistemi ve rol/yetki yönetimi
-- ============================================

-- ============================================
-- 1. TENANT INVITATIONS (Davetler)
-- ============================================

CREATE TABLE IF NOT EXISTS public.tenant_invitations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Davet bilgileri
    email varchar(255) NOT NULL,
    tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    role varchar(50) NOT NULL DEFAULT 'member'
        CHECK (role IN ('owner', 'admin', 'manager', 'member', 'viewer')),

    -- Durum
    status varchar(20) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'accepted', 'rejected', 'expired', 'cancelled')),

    -- Token (benzersiz, URL'de kullanılır)
    token varchar(64) NOT NULL UNIQUE,

    -- Opsiyonel mesaj
    message text,

    -- Davet eden
    invited_by uuid NOT NULL REFERENCES auth.users(id),

    -- Tarihler
    created_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL,
    responded_at timestamptz,

    -- Kabul eden kullanıcı (varsa)
    accepted_user_id uuid REFERENCES auth.users(id),

    -- Metadata
    metadata jsonb,

    -- İndeksler için
    UNIQUE(email, tenant_id, status) -- Aynı email+tenant için tek pending davet
);

-- İndeksler
CREATE INDEX IF NOT EXISTS idx_tenant_invitations_email
    ON public.tenant_invitations(email);
CREATE INDEX IF NOT EXISTS idx_tenant_invitations_tenant_id
    ON public.tenant_invitations(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tenant_invitations_token
    ON public.tenant_invitations(token);
CREATE INDEX IF NOT EXISTS idx_tenant_invitations_status
    ON public.tenant_invitations(status);
CREATE INDEX IF NOT EXISTS idx_tenant_invitations_expires_at
    ON public.tenant_invitations(expires_at);

-- ============================================
-- 2. ROLES (Özel Roller)
-- ============================================

CREATE TABLE IF NOT EXISTS public.roles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Rol bilgileri
    tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    code varchar(50) NOT NULL,
    name varchar(100) NOT NULL,
    description text,

    -- Seviye (yetki hiyerarşisi)
    level integer NOT NULL DEFAULT 0 CHECK (level >= 0 AND level <= 100),

    -- Sistem rolü mü?
    is_system boolean NOT NULL DEFAULT false,

    -- Durum
    active boolean NOT NULL DEFAULT true,

    -- Audit
    created_by uuid REFERENCES auth.users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_by uuid REFERENCES auth.users(id),
    updated_at timestamptz NOT NULL DEFAULT now(),

    -- Tenant içinde benzersiz kod
    UNIQUE(tenant_id, code)
);

-- İndeksler
CREATE INDEX IF NOT EXISTS idx_roles_tenant_id ON public.roles(tenant_id);
CREATE INDEX IF NOT EXISTS idx_roles_code ON public.roles(code);
CREATE INDEX IF NOT EXISTS idx_roles_level ON public.roles(level);

-- ============================================
-- 3. ROLE PERMISSIONS (Rol İzinleri)
-- ============================================

CREATE TABLE IF NOT EXISTS public.role_permissions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    -- İlişkiler
    role_id uuid NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
    tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,

    -- İzin kodu (örn: "users.create", "sites.manage")
    permission_code varchar(100) NOT NULL,

    -- Tarihler
    created_at timestamptz NOT NULL DEFAULT now(),

    -- Aynı rol için aynı izin tekrar eklenemez
    UNIQUE(role_id, permission_code)
);

-- İndeksler
CREATE INDEX IF NOT EXISTS idx_role_permissions_role_id
    ON public.role_permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_tenant_id
    ON public.role_permissions(tenant_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_code
    ON public.role_permissions(permission_code);

-- ============================================
-- 4. RLS POLİTİKALARI
-- ============================================

-- tenant_invitations için RLS
ALTER TABLE public.tenant_invitations ENABLE ROW LEVEL SECURITY;

-- Tenant admini tüm davetleri görebilir
CREATE POLICY "tenant_invitations_select_policy" ON public.tenant_invitations
    FOR SELECT
    USING (
        -- Token ile erişim (davetli için)
        true
    );

-- Sadece admin+ davet oluşturabilir
CREATE POLICY "tenant_invitations_insert_policy" ON public.tenant_invitations
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.tenant_users tu
            WHERE tu.user_id = auth.uid()
              AND tu.tenant_id = tenant_invitations.tenant_id
              AND tu.status = 'active'
              AND tu.role IN ('owner', 'admin', 'manager')
        )
    );

-- Davet durumu güncellenebilir
CREATE POLICY "tenant_invitations_update_policy" ON public.tenant_invitations
    FOR UPDATE
    USING (
        -- Davetli (token ile) veya admin güncelleyebilir
        true
    );

-- Sadece admin iptal edebilir
CREATE POLICY "tenant_invitations_delete_policy" ON public.tenant_invitations
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.tenant_users tu
            WHERE tu.user_id = auth.uid()
              AND tu.tenant_id = tenant_invitations.tenant_id
              AND tu.status = 'active'
              AND tu.role IN ('owner', 'admin')
        )
    );

-- roles için RLS
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;

-- Tenant üyeleri rolleri görebilir
CREATE POLICY "roles_select_policy" ON public.roles
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.tenant_users tu
            WHERE tu.user_id = auth.uid()
              AND tu.tenant_id = roles.tenant_id
              AND tu.status = 'active'
        )
    );

-- Sadece admin+ rol oluşturabilir
CREATE POLICY "roles_insert_policy" ON public.roles
    FOR INSERT
    WITH CHECK (
        NOT is_system AND
        EXISTS (
            SELECT 1 FROM public.tenant_users tu
            WHERE tu.user_id = auth.uid()
              AND tu.tenant_id = roles.tenant_id
              AND tu.status = 'active'
              AND tu.role IN ('owner', 'admin')
        )
    );

-- Sadece admin+ rol güncelleyebilir (sistem rolleri hariç)
CREATE POLICY "roles_update_policy" ON public.roles
    FOR UPDATE
    USING (
        NOT is_system AND
        EXISTS (
            SELECT 1 FROM public.tenant_users tu
            WHERE tu.user_id = auth.uid()
              AND tu.tenant_id = roles.tenant_id
              AND tu.status = 'active'
              AND tu.role IN ('owner', 'admin')
        )
    );

-- Sadece admin+ rol silebilir (sistem rolleri hariç)
CREATE POLICY "roles_delete_policy" ON public.roles
    FOR DELETE
    USING (
        NOT is_system AND
        EXISTS (
            SELECT 1 FROM public.tenant_users tu
            WHERE tu.user_id = auth.uid()
              AND tu.tenant_id = roles.tenant_id
              AND tu.status = 'active'
              AND tu.role IN ('owner', 'admin')
        )
    );

-- role_permissions için RLS
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;

-- Tenant üyeleri izinleri görebilir
CREATE POLICY "role_permissions_select_policy" ON public.role_permissions
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.tenant_users tu
            WHERE tu.user_id = auth.uid()
              AND tu.tenant_id = role_permissions.tenant_id
              AND tu.status = 'active'
        )
    );

-- Sadece admin+ izin ekleyebilir
CREATE POLICY "role_permissions_insert_policy" ON public.role_permissions
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.tenant_users tu
            WHERE tu.user_id = auth.uid()
              AND tu.tenant_id = role_permissions.tenant_id
              AND tu.status = 'active'
              AND tu.role IN ('owner', 'admin')
        )
    );

-- Sadece admin+ izin silebilir
CREATE POLICY "role_permissions_delete_policy" ON public.role_permissions
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.tenant_users tu
            WHERE tu.user_id = auth.uid()
              AND tu.tenant_id = role_permissions.tenant_id
              AND tu.status = 'active'
              AND tu.role IN ('owner', 'admin')
        )
    );

-- ============================================
-- 5. TRIGGER'LAR
-- ============================================

-- updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER roles_updated_at
    BEFORE UPDATE ON public.roles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Süresi dolmuş davetleri otomatik expire et
CREATE OR REPLACE FUNCTION expire_old_invitations()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.tenant_invitations
    SET status = 'expired'
    WHERE status = 'pending'
      AND expires_at < now();
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Her invitation işleminde expire kontrolü (opsiyonel, cron job tercih edilebilir)
-- CREATE TRIGGER check_expired_invitations
--     AFTER INSERT OR UPDATE ON public.tenant_invitations
--     FOR EACH STATEMENT
--     EXECUTE FUNCTION expire_old_invitations();

-- ============================================
-- 6. YARDIMCI FONKSİYONLAR
-- ============================================

-- Kullanıcının belirli bir izne sahip olup olmadığını kontrol et
CREATE OR REPLACE FUNCTION check_permission(
    p_user_id uuid,
    p_tenant_id uuid,
    p_permission varchar
)
RETURNS boolean AS $$
DECLARE
    v_role varchar;
    v_has_permission boolean := false;
BEGIN
    -- Kullanıcının rolünü al
    SELECT role INTO v_role
    FROM public.tenant_users
    WHERE user_id = p_user_id
      AND tenant_id = p_tenant_id
      AND status = 'active';

    IF v_role IS NULL THEN
        RETURN false;
    END IF;

    -- Sistem rolleri için hızlı kontrol
    IF v_role = 'owner' THEN
        RETURN true; -- Owner her şeyi yapabilir
    END IF;

    -- Admin için faturalama hariç
    IF v_role = 'admin' AND NOT p_permission LIKE 'billing.%' THEN
        RETURN true;
    END IF;

    -- Özel rol için izin tablosundan kontrol et
    SELECT EXISTS (
        SELECT 1
        FROM public.role_permissions rp
        JOIN public.roles r ON r.id = rp.role_id
        WHERE r.code = v_role
          AND r.tenant_id = p_tenant_id
          AND r.active = true
          AND (
              rp.permission_code = p_permission
              OR rp.permission_code = '*'
              OR rp.permission_code = split_part(p_permission, '.', 1) || '.*'
          )
    ) INTO v_has_permission;

    RETURN v_has_permission;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Daveti kabul et (transaction içinde)
CREATE OR REPLACE FUNCTION accept_invitation(
    p_token varchar,
    p_user_id uuid
)
RETURNS json AS $$
DECLARE
    v_invitation record;
    v_result json;
BEGIN
    -- Daveti getir ve kilitle
    SELECT * INTO v_invitation
    FROM public.tenant_invitations
    WHERE token = p_token
    FOR UPDATE;

    IF v_invitation IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Davet bulunamadı');
    END IF;

    IF v_invitation.status != 'pending' THEN
        RETURN json_build_object('success', false, 'error', 'Davet artık geçerli değil');
    END IF;

    IF v_invitation.expires_at < now() THEN
        -- Durumu güncelle
        UPDATE public.tenant_invitations
        SET status = 'expired'
        WHERE id = v_invitation.id;

        RETURN json_build_object('success', false, 'error', 'Davet süresi dolmuş');
    END IF;

    -- Kullanıcıyı tenant'a ekle
    INSERT INTO public.tenant_users (
        user_id, tenant_id, role, status, is_default,
        invited_by, invited_at, joined_at, created_at
    ) VALUES (
        p_user_id, v_invitation.tenant_id, v_invitation.role, 'active', false,
        v_invitation.invited_by, v_invitation.created_at, now(), now()
    )
    ON CONFLICT (user_id, tenant_id) DO NOTHING;

    -- Daveti güncelle
    UPDATE public.tenant_invitations
    SET status = 'accepted',
        responded_at = now(),
        accepted_user_id = p_user_id
    WHERE id = v_invitation.id;

    RETURN json_build_object(
        'success', true,
        'tenant_id', v_invitation.tenant_id,
        'role', v_invitation.role
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 7. VARSAYILAN VERİLER (Opsiyonel)
-- ============================================

-- Eğer sistem rolleri veritabanında tutulacaksa:
-- INSERT INTO public.roles (id, tenant_id, code, name, description, level, is_system)
-- VALUES
--     ('system-owner', NULL, 'owner', 'Sahip', 'Tenant sahibi, tüm yetkilere sahip', 100, true),
--     ('system-admin', NULL, 'admin', 'Yönetici', 'Yönetici, faturalama hariç tüm yetkilere sahip', 80, true),
--     ('system-manager', NULL, 'manager', 'Müdür', 'Operasyonel yönetim yetkileri', 60, true),
--     ('system-member', NULL, 'member', 'Üye', 'Temel kullanıcı yetkileri', 40, true),
--     ('system-viewer', NULL, 'viewer', 'Görüntüleyici', 'Sadece görüntüleme yetkisi', 20, true)
-- ON CONFLICT DO NOTHING;

COMMENT ON TABLE public.tenant_invitations IS 'Tenant kullanıcı davetleri';
COMMENT ON TABLE public.roles IS 'Özel tenant rolleri';
COMMENT ON TABLE public.role_permissions IS 'Rol izin eşleştirmeleri';
