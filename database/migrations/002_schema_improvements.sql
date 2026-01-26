-- =====================================================
-- Schema Improvements for Protoolbag Database
-- =====================================================
-- Version: 1.0.0
-- Date: 2024-01-26
-- Description: Adds missing fields, indexes, and constraints
-- =====================================================

-- =====================================================
-- STEP 1: Tenant Status Field
-- =====================================================

-- Add status field to tenants table
ALTER TABLE tenants
ADD COLUMN IF NOT EXISTS status varchar(20) DEFAULT 'active'
CHECK (status IN ('active', 'suspended', 'pending', 'trial', 'cancelled', 'deleted'));

ALTER TABLE tenants
ADD COLUMN IF NOT EXISTS suspended_at timestamp with time zone,
ADD COLUMN IF NOT EXISTS suspended_reason text,
ADD COLUMN IF NOT EXISTS deleted_at timestamp with time zone;

COMMENT ON COLUMN tenants.status IS 'Tenant status: active, suspended, pending, trial, cancelled, deleted';
COMMENT ON COLUMN tenants.suspended_at IS 'Timestamp when tenant was suspended';
COMMENT ON COLUMN tenants.suspended_reason IS 'Reason for tenant suspension';
COMMENT ON COLUMN tenants.deleted_at IS 'Soft delete timestamp';

-- =====================================================
-- STEP 2: Variable-Controller Direct Relationship
-- =====================================================

-- Add controller_id to variables table for direct relationship
ALTER TABLE variables
ADD COLUMN IF NOT EXISTS controller_id uuid REFERENCES controllers(id);

-- Create index for the new relationship
CREATE INDEX IF NOT EXISTS idx_variables_controller_id ON variables(controller_id);

-- Migrate existing data from realtimes
UPDATE variables v
SET controller_id = r.controller_id
FROM realtimes r
WHERE r.variable_id = v.id
AND v.controller_id IS NULL;

COMMENT ON COLUMN variables.controller_id IS 'Direct reference to controller, populated from realtimes';

-- =====================================================
-- STEP 3: Unit Status Field
-- =====================================================

ALTER TABLE units
ADD COLUMN IF NOT EXISTS status varchar(20) DEFAULT 'operational'
CHECK (status IN ('operational', 'maintenance', 'closed', 'renovation', 'inactive'));

COMMENT ON COLUMN units.status IS 'Unit operational status';

-- =====================================================
-- STEP 4: Profile Organization Relationship
-- =====================================================

ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES organizations(id),
ADD COLUMN IF NOT EXISTS default_site_id uuid REFERENCES sites(id);

CREATE INDEX IF NOT EXISTS idx_profiles_organization_id ON profiles(organization_id);
CREATE INDEX IF NOT EXISTS idx_profiles_default_site_id ON profiles(default_site_id);

COMMENT ON COLUMN profiles.organization_id IS 'Primary organization for the user';
COMMENT ON COLUMN profiles.default_site_id IS 'Default site for the user';

-- =====================================================
-- STEP 5: Work Request Site Relationship
-- =====================================================

ALTER TABLE work_requests
ADD COLUMN IF NOT EXISTS site_id uuid REFERENCES sites(id);

CREATE INDEX IF NOT EXISTS idx_work_requests_site_id ON work_requests(site_id);

COMMENT ON COLUMN work_requests.site_id IS 'Site where the work request originated';

-- =====================================================
-- STEP 6: Performance Indexes
-- =====================================================

-- Hierarchy traversal indexes
CREATE INDEX IF NOT EXISTS idx_organizations_tenant_id ON organizations(tenant_id);
CREATE INDEX IF NOT EXISTS idx_sites_organization_id ON sites(organization_id);
CREATE INDEX IF NOT EXISTS idx_sites_tenant_id ON sites(tenant_id);
CREATE INDEX IF NOT EXISTS idx_units_site_id ON units(site_id);
CREATE INDEX IF NOT EXISTS idx_units_parent_unit_id ON units(parent_unit_id);
CREATE INDEX IF NOT EXISTS idx_units_tenant_id ON units(tenant_id);
CREATE INDEX IF NOT EXISTS idx_controllers_site_id ON controllers(site_id);
CREATE INDEX IF NOT EXISTS idx_controllers_tenant_id ON controllers(tenant_id);
CREATE INDEX IF NOT EXISTS idx_controllers_provider_id ON controllers(provider_id);

-- Time-based indexes
CREATE INDEX IF NOT EXISTS idx_alarm_histories_start_time ON alarm_histories(start_time);
CREATE INDEX IF NOT EXISTS idx_alarm_histories_tenant_site ON alarm_histories(tenant_id, site_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at);
CREATE INDEX IF NOT EXISTS idx_notifications_profile_read ON notifications(profile_id, read);
CREATE INDEX IF NOT EXISTS idx_activities_created_at ON activities(created_at);
CREATE INDEX IF NOT EXISTS idx_activities_tenant_created ON activities(tenant_id, created_at);

-- Composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_controllers_site_active ON controllers(site_id, active) WHERE active = true;
CREATE INDEX IF NOT EXISTS idx_units_site_active ON units(site_id, active) WHERE active = true;
CREATE INDEX IF NOT EXISTS idx_organizations_tenant_active ON organizations(tenant_id, active) WHERE active = true;

-- =====================================================
-- STEP 7: Audit Fields Standardization
-- =====================================================

-- Add missing audit fields to key tables

-- Organizations
ALTER TABLE organizations
ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES profiles(id),
ADD COLUMN IF NOT EXISTS updated_by uuid REFERENCES profiles(id);

-- Sites
ALTER TABLE sites
ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES profiles(id),
ADD COLUMN IF NOT EXISTS updated_by uuid REFERENCES profiles(id);

-- Units
ALTER TABLE units
ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES profiles(id),
ADD COLUMN IF NOT EXISTS updated_by uuid REFERENCES profiles(id);

-- =====================================================
-- STEP 8: Audit Trigger Function
-- =====================================================

CREATE OR REPLACE FUNCTION update_audit_fields()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := CURRENT_TIMESTAMP;
  NEW.updated_by := COALESCE(
    current_setting('app.current_user_id', true)::uuid,
    auth.uid()
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply audit triggers to main tables
DROP TRIGGER IF EXISTS trg_organizations_audit ON organizations;
CREATE TRIGGER trg_organizations_audit
  BEFORE UPDATE ON organizations
  FOR EACH ROW EXECUTE FUNCTION update_audit_fields();

DROP TRIGGER IF EXISTS trg_sites_audit ON sites;
CREATE TRIGGER trg_sites_audit
  BEFORE UPDATE ON sites
  FOR EACH ROW EXECUTE FUNCTION update_audit_fields();

DROP TRIGGER IF EXISTS trg_units_audit ON units;
CREATE TRIGGER trg_units_audit
  BEFORE UPDATE ON units
  FOR EACH ROW EXECUTE FUNCTION update_audit_fields();

-- =====================================================
-- STEP 9: Tenant ID Sync Trigger
-- =====================================================

CREATE OR REPLACE FUNCTION sync_tenant_id()
RETURNS TRIGGER AS $$
BEGIN
  -- For sites: inherit tenant_id from organization
  IF TG_TABLE_NAME = 'sites' THEN
    NEW.tenant_id := (SELECT tenant_id FROM organizations WHERE id = NEW.organization_id);
  END IF;

  -- For units: inherit tenant_id from site->organization
  IF TG_TABLE_NAME = 'units' THEN
    NEW.tenant_id := (
      SELECT o.tenant_id
      FROM sites s
      JOIN organizations o ON o.id = s.organization_id
      WHERE s.id = NEW.site_id
    );
  END IF;

  -- For controllers: inherit tenant_id from site->organization
  IF TG_TABLE_NAME = 'controllers' THEN
    NEW.tenant_id := (
      SELECT o.tenant_id
      FROM sites s
      JOIN organizations o ON o.id = s.organization_id
      WHERE s.id = NEW.site_id
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply sync triggers
DROP TRIGGER IF EXISTS trg_sites_sync_tenant ON sites;
CREATE TRIGGER trg_sites_sync_tenant
  BEFORE INSERT OR UPDATE ON sites
  FOR EACH ROW EXECUTE FUNCTION sync_tenant_id();

DROP TRIGGER IF EXISTS trg_units_sync_tenant ON units;
CREATE TRIGGER trg_units_sync_tenant
  BEFORE INSERT OR UPDATE ON units
  FOR EACH ROW EXECUTE FUNCTION sync_tenant_id();

DROP TRIGGER IF EXISTS trg_controllers_sync_tenant ON controllers;
CREATE TRIGGER trg_controllers_sync_tenant
  BEFORE INSERT OR UPDATE ON controllers
  FOR EACH ROW EXECUTE FUNCTION sync_tenant_id();

-- =====================================================
-- STEP 10: Hierarchy Validation Trigger
-- =====================================================

CREATE OR REPLACE FUNCTION validate_hierarchy()
RETURNS TRIGGER AS $$
BEGIN
  -- For units: validate that site belongs to the same tenant
  IF TG_TABLE_NAME = 'units' AND NEW.organization_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM sites s
      JOIN organizations o ON o.id = s.organization_id
      WHERE s.id = NEW.site_id
      AND o.id = NEW.organization_id
    ) THEN
      RAISE EXCEPTION 'Site does not belong to specified organization';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_units_validate_hierarchy ON units;
CREATE TRIGGER trg_units_validate_hierarchy
  BEFORE INSERT OR UPDATE ON units
  FOR EACH ROW EXECUTE FUNCTION validate_hierarchy();

-- =====================================================
-- STEP 11: Hierarchy View
-- =====================================================

CREATE OR REPLACE VIEW tenant_hierarchy AS
WITH RECURSIVE unit_tree AS (
  SELECT
    id,
    name,
    site_id,
    parent_unit_id,
    1 as level,
    ARRAY[id] as path
  FROM units
  WHERE parent_unit_id IS NULL

  UNION ALL

  SELECT
    u.id,
    u.name,
    u.site_id,
    u.parent_unit_id,
    ut.level + 1,
    ut.path || u.id
  FROM units u
  JOIN unit_tree ut ON u.parent_unit_id = ut.id
)
SELECT
  t.id as tenant_id,
  t.name as tenant_name,
  o.id as organization_id,
  o.name as organization_name,
  s.id as site_id,
  s.name as site_name,
  ut.id as unit_id,
  ut.name as unit_name,
  ut.level as unit_level,
  ut.path as unit_path
FROM tenants t
JOIN organizations o ON o.tenant_id = t.id
JOIN sites s ON s.organization_id = o.id
LEFT JOIN unit_tree ut ON ut.site_id = s.id
WHERE t.status = 'active'
  AND o.active = true
  AND s.active = true;

COMMENT ON VIEW tenant_hierarchy IS 'Complete hierarchy from tenant to units';

-- =====================================================
-- STEP 12: User Hierarchy View
-- =====================================================

CREATE OR REPLACE VIEW user_hierarchy AS
SELECT
  p.id as profile_id,
  p.username,
  p.email,
  p.role,
  p.tenant_id,
  t.name as tenant_name,
  p.organization_id,
  o.name as organization_name,
  p.default_site_id,
  s.name as default_site_name,
  p.active,
  p.created_at
FROM profiles p
LEFT JOIN tenants t ON t.id = p.tenant_id
LEFT JOIN organizations o ON o.id = p.organization_id
LEFT JOIN sites s ON s.id = p.default_site_id
WHERE p.active = true;

COMMENT ON VIEW user_hierarchy IS 'User profiles with their hierarchy context';

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON FUNCTION update_audit_fields() IS 'Automatically updates audit fields on record modification';
COMMENT ON FUNCTION sync_tenant_id() IS 'Automatically syncs tenant_id based on hierarchy';
COMMENT ON FUNCTION validate_hierarchy() IS 'Validates that child entities belong to correct parents';
