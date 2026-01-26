-- =====================================================
-- RLS (Row Level Security) Policies for Protoolbag
-- =====================================================
-- Version: 1.0.0
-- Date: 2024-01-26
-- Description: Implements tenant isolation and access control
-- =====================================================

-- =====================================================
-- STEP 1: Enable RLS on all tables
-- =====================================================

ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE units ENABLE ROW LEVEL SECURITY;
ALTER TABLE controllers ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE invitations ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- STEP 2: Helper Functions
-- =====================================================

-- Function to get current user's tenant ID from JWT
CREATE OR REPLACE FUNCTION get_current_tenant_id()
RETURNS uuid AS $$
BEGIN
  RETURN COALESCE(
    current_setting('app.current_tenant_id', true)::uuid,
    (auth.jwt() -> 'app_metadata' ->> 'tenant_id')::uuid
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get current user's profile ID
CREATE OR REPLACE FUNCTION get_current_profile_id()
RETURNS uuid AS $$
BEGIN
  RETURN auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user has access to a tenant
CREATE OR REPLACE FUNCTION user_has_tenant_access(tenant_uuid uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND tenant_id = tenant_uuid
    AND active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user has access to an organization
CREATE OR REPLACE FUNCTION user_has_organization_access(org_uuid uuid)
RETURNS boolean AS $$
DECLARE
  org_tenant_id uuid;
BEGIN
  SELECT tenant_id INTO org_tenant_id FROM organizations WHERE id = org_uuid;
  RETURN user_has_tenant_access(org_tenant_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- STEP 3: Tenant Policies
-- =====================================================

-- Tenants: Users can only see their own tenant
DROP POLICY IF EXISTS tenant_isolation ON tenants;
CREATE POLICY tenant_isolation ON tenants
  FOR ALL
  USING (
    id = get_current_tenant_id()
    OR id IN (SELECT tenant_id FROM profiles WHERE id = auth.uid())
  );

-- =====================================================
-- STEP 4: Organization Policies
-- =====================================================

-- Organizations: Users can see organizations in their tenant
DROP POLICY IF EXISTS organization_tenant_isolation ON organizations;
CREATE POLICY organization_tenant_isolation ON organizations
  FOR SELECT
  USING (tenant_id = get_current_tenant_id() OR user_has_tenant_access(tenant_id));

DROP POLICY IF EXISTS organization_insert ON organizations;
CREATE POLICY organization_insert ON organizations
  FOR INSERT
  WITH CHECK (tenant_id = get_current_tenant_id());

DROP POLICY IF EXISTS organization_update ON organizations;
CREATE POLICY organization_update ON organizations
  FOR UPDATE
  USING (tenant_id = get_current_tenant_id())
  WITH CHECK (tenant_id = get_current_tenant_id());

DROP POLICY IF EXISTS organization_delete ON organizations;
CREATE POLICY organization_delete ON organizations
  FOR DELETE
  USING (tenant_id = get_current_tenant_id());

-- =====================================================
-- STEP 5: Site Policies
-- =====================================================

-- Sites: Users can see sites in organizations they have access to
DROP POLICY IF EXISTS site_tenant_isolation ON sites;
CREATE POLICY site_tenant_isolation ON sites
  FOR SELECT
  USING (
    tenant_id = get_current_tenant_id()
    OR user_has_organization_access(organization_id)
  );

DROP POLICY IF EXISTS site_insert ON sites;
CREATE POLICY site_insert ON sites
  FOR INSERT
  WITH CHECK (
    tenant_id = get_current_tenant_id()
    AND user_has_organization_access(organization_id)
  );

DROP POLICY IF EXISTS site_update ON sites;
CREATE POLICY site_update ON sites
  FOR UPDATE
  USING (tenant_id = get_current_tenant_id())
  WITH CHECK (tenant_id = get_current_tenant_id());

DROP POLICY IF EXISTS site_delete ON sites;
CREATE POLICY site_delete ON sites
  FOR DELETE
  USING (tenant_id = get_current_tenant_id());

-- =====================================================
-- STEP 6: Unit Policies
-- =====================================================

-- Units: Users can see units in sites they have access to
DROP POLICY IF EXISTS unit_tenant_isolation ON units;
CREATE POLICY unit_tenant_isolation ON units
  FOR SELECT
  USING (
    tenant_id = get_current_tenant_id()
    OR site_id IN (
      SELECT id FROM sites WHERE user_has_organization_access(organization_id)
    )
  );

DROP POLICY IF EXISTS unit_insert ON units;
CREATE POLICY unit_insert ON units
  FOR INSERT
  WITH CHECK (tenant_id = get_current_tenant_id());

DROP POLICY IF EXISTS unit_update ON units;
CREATE POLICY unit_update ON units
  FOR UPDATE
  USING (tenant_id = get_current_tenant_id())
  WITH CHECK (tenant_id = get_current_tenant_id());

DROP POLICY IF EXISTS unit_delete ON units;
CREATE POLICY unit_delete ON units
  FOR DELETE
  USING (tenant_id = get_current_tenant_id());

-- =====================================================
-- STEP 7: Controller Policies
-- =====================================================

DROP POLICY IF EXISTS controller_tenant_isolation ON controllers;
CREATE POLICY controller_tenant_isolation ON controllers
  FOR SELECT
  USING (
    tenant_id = get_current_tenant_id()
    OR site_id IN (
      SELECT id FROM sites WHERE user_has_organization_access(organization_id)
    )
  );

DROP POLICY IF EXISTS controller_insert ON controllers;
CREATE POLICY controller_insert ON controllers
  FOR INSERT
  WITH CHECK (tenant_id = get_current_tenant_id());

DROP POLICY IF EXISTS controller_update ON controllers;
CREATE POLICY controller_update ON controllers
  FOR UPDATE
  USING (tenant_id = get_current_tenant_id())
  WITH CHECK (tenant_id = get_current_tenant_id());

DROP POLICY IF EXISTS controller_delete ON controllers;
CREATE POLICY controller_delete ON controllers
  FOR DELETE
  USING (tenant_id = get_current_tenant_id());

-- =====================================================
-- STEP 8: Profile Policies
-- =====================================================

-- Profiles: Users can see their own profile and profiles in their tenant
DROP POLICY IF EXISTS profile_self_access ON profiles;
CREATE POLICY profile_self_access ON profiles
  FOR SELECT
  USING (
    id = auth.uid()
    OR tenant_id = get_current_tenant_id()
  );

DROP POLICY IF EXISTS profile_update_self ON profiles;
CREATE POLICY profile_update_self ON profiles
  FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- =====================================================
-- STEP 9: Notification Policies
-- =====================================================

-- Notifications: Users can only see their own notifications
DROP POLICY IF EXISTS notification_owner_access ON notifications;
CREATE POLICY notification_owner_access ON notifications
  FOR SELECT
  USING (profile_id = auth.uid());

DROP POLICY IF EXISTS notification_update_own ON notifications;
CREATE POLICY notification_update_own ON notifications
  FOR UPDATE
  USING (profile_id = auth.uid())
  WITH CHECK (profile_id = auth.uid());

DROP POLICY IF EXISTS notification_delete_own ON notifications;
CREATE POLICY notification_delete_own ON notifications
  FOR DELETE
  USING (profile_id = auth.uid());

-- =====================================================
-- STEP 10: Activity Policies
-- =====================================================

DROP POLICY IF EXISTS activity_tenant_isolation ON activities;
CREATE POLICY activity_tenant_isolation ON activities
  FOR SELECT
  USING (
    tenant_id = get_current_tenant_id()
    OR created_by = auth.uid()
  );

DROP POLICY IF EXISTS activity_insert ON activities;
CREATE POLICY activity_insert ON activities
  FOR INSERT
  WITH CHECK (tenant_id = get_current_tenant_id());

DROP POLICY IF EXISTS activity_update ON activities;
CREATE POLICY activity_update ON activities
  FOR UPDATE
  USING (
    tenant_id = get_current_tenant_id()
    OR created_by = auth.uid()
  );

-- =====================================================
-- STEP 11: Invitation Policies
-- =====================================================

DROP POLICY IF EXISTS invitation_tenant_isolation ON invitations;
CREATE POLICY invitation_tenant_isolation ON invitations
  FOR SELECT
  USING (
    tenant_id = get_current_tenant_id()
    OR email = (SELECT email FROM profiles WHERE id = auth.uid())
  );

DROP POLICY IF EXISTS invitation_insert ON invitations;
CREATE POLICY invitation_insert ON invitations
  FOR INSERT
  WITH CHECK (tenant_id = get_current_tenant_id());

DROP POLICY IF EXISTS invitation_update ON invitations;
CREATE POLICY invitation_update ON invitations
  FOR UPDATE
  USING (
    tenant_id = get_current_tenant_id()
    OR email = (SELECT email FROM profiles WHERE id = auth.uid())
  );

-- =====================================================
-- STEP 12: Service Role Bypass
-- =====================================================

-- Allow service role to bypass RLS for administrative tasks
ALTER TABLE tenants FORCE ROW LEVEL SECURITY;
ALTER TABLE organizations FORCE ROW LEVEL SECURITY;
ALTER TABLE sites FORCE ROW LEVEL SECURITY;
ALTER TABLE units FORCE ROW LEVEL SECURITY;
ALTER TABLE controllers FORCE ROW LEVEL SECURITY;
ALTER TABLE profiles FORCE ROW LEVEL SECURITY;
ALTER TABLE notifications FORCE ROW LEVEL SECURITY;
ALTER TABLE activities FORCE ROW LEVEL SECURITY;
ALTER TABLE invitations FORCE ROW LEVEL SECURITY;

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON FUNCTION get_current_tenant_id() IS 'Returns the current tenant ID from session or JWT';
COMMENT ON FUNCTION get_current_profile_id() IS 'Returns the current user profile ID';
COMMENT ON FUNCTION user_has_tenant_access(uuid) IS 'Checks if current user has access to the specified tenant';
COMMENT ON FUNCTION user_has_organization_access(uuid) IS 'Checks if current user has access to the specified organization';
