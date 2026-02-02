-- =====================================================
-- Multi-Tenant & Organization Isolation Migration
-- =====================================================
-- Version: 1.0.0
-- Date: 2025-02-02
-- Description: Adds isolation columns to alarms and logs tables
--              for consistent tenant and organization filtering
-- =====================================================

-- =====================================================
-- STEP 1: Add Isolation Columns to ALARMS Table
-- =====================================================
-- Problem: alarms tablosunda tenant_id, organization_id, site_id, provider_id yok
-- Bu durum aktif alarmların tenant bazında filtrelenmesini imkansız kılıyor

ALTER TABLE alarms
ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES tenants(id),
ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES organizations(id),
ADD COLUMN IF NOT EXISTS site_id uuid REFERENCES sites(id),
ADD COLUMN IF NOT EXISTS provider_id uuid REFERENCES providers(id);

-- Indexes for isolation columns
CREATE INDEX IF NOT EXISTS idx_alarms_tenant_id ON alarms(tenant_id);
CREATE INDEX IF NOT EXISTS idx_alarms_organization_id ON alarms(organization_id);
CREATE INDEX IF NOT EXISTS idx_alarms_site_id ON alarms(site_id);
CREATE INDEX IF NOT EXISTS idx_alarms_provider_id ON alarms(provider_id);

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_alarms_tenant_org ON alarms(tenant_id, organization_id);
CREATE INDEX IF NOT EXISTS idx_alarms_tenant_site ON alarms(tenant_id, site_id);
CREATE INDEX IF NOT EXISTS idx_alarms_org_site ON alarms(organization_id, site_id);

COMMENT ON COLUMN alarms.tenant_id IS 'Tenant isolation - must be set for all alarms';
COMMENT ON COLUMN alarms.organization_id IS 'Organization isolation - derived from controller hierarchy';
COMMENT ON COLUMN alarms.site_id IS 'Site isolation - derived from controller hierarchy';
COMMENT ON COLUMN alarms.provider_id IS 'Provider reference - derived from controller hierarchy';

-- =====================================================
-- STEP 2: Add Isolation Columns to LOGS Table
-- =====================================================
-- Problem: logs tablosunda organization_id ve site_id yok
-- Sadece tenant_id ve provider_id var

ALTER TABLE logs
ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES organizations(id),
ADD COLUMN IF NOT EXISTS site_id uuid REFERENCES sites(id);

-- Indexes for new isolation columns
CREATE INDEX IF NOT EXISTS idx_logs_organization_id ON logs(organization_id);
CREATE INDEX IF NOT EXISTS idx_logs_site_id ON logs(site_id);

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_logs_tenant_org ON logs(tenant_id, organization_id);
CREATE INDEX IF NOT EXISTS idx_logs_tenant_site ON logs(tenant_id, site_id);
CREATE INDEX IF NOT EXISTS idx_logs_org_site ON logs(organization_id, site_id);

COMMENT ON COLUMN logs.organization_id IS 'Organization isolation - derived from controller hierarchy';
COMMENT ON COLUMN logs.site_id IS 'Site isolation - derived from controller hierarchy';

-- =====================================================
-- STEP 3: Backfill Isolation Data for ALARMS
-- =====================================================
-- Populate isolation columns from controller hierarchy
-- Controller -> Site -> Organization -> Tenant

UPDATE alarms a
SET
  site_id = c.site_id,
  tenant_id = c.tenant_id,
  provider_id = c.provider_id,
  organization_id = s.organization_id
FROM controllers c
LEFT JOIN sites s ON s.id = c.site_id
WHERE a.controller_id = c.id
AND (a.tenant_id IS NULL OR a.organization_id IS NULL OR a.site_id IS NULL);

-- =====================================================
-- STEP 4: Backfill Isolation Data for LOGS
-- =====================================================
-- Populate organization_id and site_id from controller hierarchy

UPDATE logs l
SET
  site_id = c.site_id,
  organization_id = s.organization_id
FROM controllers c
LEFT JOIN sites s ON s.id = c.site_id
WHERE l.controller_id = c.id
AND (l.organization_id IS NULL OR l.site_id IS NULL);

-- =====================================================
-- STEP 5: Sync Trigger for ALARMS
-- =====================================================
-- Automatically populate isolation columns when alarms are inserted/updated

CREATE OR REPLACE FUNCTION sync_alarm_isolation()
RETURNS TRIGGER AS $$
BEGIN
  -- Only sync if controller_id is provided
  IF NEW.controller_id IS NOT NULL THEN
    SELECT
      c.tenant_id,
      c.provider_id,
      c.site_id,
      s.organization_id
    INTO
      NEW.tenant_id,
      NEW.provider_id,
      NEW.site_id,
      NEW.organization_id
    FROM controllers c
    LEFT JOIN sites s ON s.id = c.site_id
    WHERE c.id = NEW.controller_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_alarms_sync_isolation ON alarms;
CREATE TRIGGER trg_alarms_sync_isolation
  BEFORE INSERT OR UPDATE ON alarms
  FOR EACH ROW
  WHEN (NEW.controller_id IS NOT NULL)
  EXECUTE FUNCTION sync_alarm_isolation();

COMMENT ON FUNCTION sync_alarm_isolation() IS 'Automatically syncs isolation columns for alarms based on controller hierarchy';

-- =====================================================
-- STEP 6: Sync Trigger for LOGS
-- =====================================================
-- Automatically populate isolation columns when logs are inserted/updated

CREATE OR REPLACE FUNCTION sync_log_isolation()
RETURNS TRIGGER AS $$
BEGIN
  -- Only sync if controller_id is provided
  IF NEW.controller_id IS NOT NULL THEN
    SELECT
      c.site_id,
      s.organization_id
    INTO
      NEW.site_id,
      NEW.organization_id
    FROM controllers c
    LEFT JOIN sites s ON s.id = c.site_id
    WHERE c.id = NEW.controller_id;

    -- Also sync tenant_id if not already set
    IF NEW.tenant_id IS NULL THEN
      SELECT c.tenant_id INTO NEW.tenant_id
      FROM controllers c
      WHERE c.id = NEW.controller_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_logs_sync_isolation ON logs;
CREATE TRIGGER trg_logs_sync_isolation
  BEFORE INSERT OR UPDATE ON logs
  FOR EACH ROW
  WHEN (NEW.controller_id IS NOT NULL)
  EXECUTE FUNCTION sync_log_isolation();

COMMENT ON FUNCTION sync_log_isolation() IS 'Automatically syncs isolation columns for logs based on controller hierarchy';

-- =====================================================
-- STEP 7: Row Level Security (RLS) Policies
-- =====================================================
-- Enable RLS on alarms and logs tables for additional security

-- Enable RLS on alarms
ALTER TABLE alarms ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see alarms from their tenant
CREATE POLICY tenant_isolation_alarms ON alarms
  FOR ALL
  USING (
    tenant_id = COALESCE(
      current_setting('app.current_tenant_id', true)::uuid,
      (SELECT tenant_id FROM profiles WHERE id = auth.uid())
    )
  );

-- Enable RLS on logs
ALTER TABLE logs ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see logs from their tenant
CREATE POLICY tenant_isolation_logs ON logs
  FOR ALL
  USING (
    tenant_id = COALESCE(
      current_setting('app.current_tenant_id', true)::uuid,
      (SELECT tenant_id FROM profiles WHERE id = auth.uid())
    )
  );

-- =====================================================
-- STEP 8: Bypass RLS for Service Accounts
-- =====================================================
-- Service accounts need to access all data for backend operations

-- Grant bypass to service_role (Supabase service key)
ALTER TABLE alarms FORCE ROW LEVEL SECURITY;
ALTER TABLE logs FORCE ROW LEVEL SECURITY;

-- Create policy for service role bypass
CREATE POLICY service_bypass_alarms ON alarms
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY service_bypass_logs ON logs
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- =====================================================
-- STEP 9: Alarm History Consistency Check
-- =====================================================
-- Ensure alarm_histories also has proper indexes

CREATE INDEX IF NOT EXISTS idx_alarm_histories_organization_id ON alarm_histories(organization_id);
CREATE INDEX IF NOT EXISTS idx_alarm_histories_tenant_org ON alarm_histories(tenant_id, organization_id);

-- =====================================================
-- STEP 10: Validation Function
-- =====================================================
-- Function to validate isolation data integrity

CREATE OR REPLACE FUNCTION validate_isolation_integrity()
RETURNS TABLE (
  table_name text,
  total_records bigint,
  missing_tenant bigint,
  missing_organization bigint,
  missing_site bigint,
  integrity_score numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    'alarms'::text,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE a.tenant_id IS NULL)::bigint,
    COUNT(*) FILTER (WHERE a.organization_id IS NULL)::bigint,
    COUNT(*) FILTER (WHERE a.site_id IS NULL)::bigint,
    ROUND(
      (COUNT(*) FILTER (WHERE a.tenant_id IS NOT NULL AND a.organization_id IS NOT NULL AND a.site_id IS NOT NULL)::numeric /
       NULLIF(COUNT(*), 0)::numeric) * 100, 2
    )
  FROM alarms a

  UNION ALL

  SELECT
    'logs'::text,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE l.tenant_id IS NULL)::bigint,
    COUNT(*) FILTER (WHERE l.organization_id IS NULL)::bigint,
    COUNT(*) FILTER (WHERE l.site_id IS NULL)::bigint,
    ROUND(
      (COUNT(*) FILTER (WHERE l.tenant_id IS NOT NULL AND l.organization_id IS NOT NULL AND l.site_id IS NOT NULL)::numeric /
       NULLIF(COUNT(*), 0)::numeric) * 100, 2
    )
  FROM logs l

  UNION ALL

  SELECT
    'alarm_histories'::text,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE ah.tenant_id IS NULL)::bigint,
    COUNT(*) FILTER (WHERE ah.organization_id IS NULL)::bigint,
    COUNT(*) FILTER (WHERE ah.site_id IS NULL)::bigint,
    ROUND(
      (COUNT(*) FILTER (WHERE ah.tenant_id IS NOT NULL AND ah.organization_id IS NOT NULL AND ah.site_id IS NOT NULL)::numeric /
       NULLIF(COUNT(*), 0)::numeric) * 100, 2
    )
  FROM alarm_histories ah;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION validate_isolation_integrity() IS 'Validates that all isolation columns are properly populated';

-- =====================================================
-- USAGE EXAMPLE
-- =====================================================
-- SELECT * FROM validate_isolation_integrity();
-- Expected output shows integrity score for each table

-- =====================================================
-- ROLLBACK SCRIPT (if needed)
-- =====================================================
-- To rollback this migration:
--
-- DROP POLICY IF EXISTS service_bypass_logs ON logs;
-- DROP POLICY IF EXISTS service_bypass_alarms ON alarms;
-- DROP POLICY IF EXISTS tenant_isolation_logs ON logs;
-- DROP POLICY IF EXISTS tenant_isolation_alarms ON alarms;
-- ALTER TABLE logs DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE alarms DISABLE ROW LEVEL SECURITY;
-- DROP TRIGGER IF EXISTS trg_logs_sync_isolation ON logs;
-- DROP TRIGGER IF EXISTS trg_alarms_sync_isolation ON alarms;
-- DROP FUNCTION IF EXISTS sync_log_isolation();
-- DROP FUNCTION IF EXISTS sync_alarm_isolation();
-- DROP FUNCTION IF EXISTS validate_isolation_integrity();
-- ALTER TABLE logs DROP COLUMN IF EXISTS organization_id, DROP COLUMN IF EXISTS site_id;
-- ALTER TABLE alarms DROP COLUMN IF EXISTS tenant_id, DROP COLUMN IF EXISTS organization_id,
--   DROP COLUMN IF EXISTS site_id, DROP COLUMN IF EXISTS provider_id;
