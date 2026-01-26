-- Migration: 003_notifications
-- Description: Create notifications table for in-app notifications
-- Author: Claude
-- Date: 2026-01-26

-- =====================================================
-- NOTIFICATIONS TABLE
-- =====================================================

-- Drop existing policy if exists
DROP POLICY IF EXISTS "Users can view their own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can delete their own notifications" ON notifications;
DROP POLICY IF EXISTS "System can create notifications" ON notifications;

-- Create notifications table if not exists
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Recipient
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Content
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,

    -- Type and priority
    type VARCHAR(50) NOT NULL DEFAULT 'INFO',
    priority VARCHAR(20) NOT NULL DEFAULT 'NORMAL',

    -- Entity reference (optional)
    entity_type VARCHAR(50),
    entity_id UUID,
    action_url VARCHAR(500),

    -- Additional data
    data JSONB,

    -- Sender (optional)
    sender_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,

    -- Tenant (optional, for multi-tenant notifications)
    tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,

    -- Read status
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    read_at TIMESTAMPTZ,

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

-- =====================================================
-- INDEXES
-- =====================================================

-- Index for user lookups
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);

-- Index for unread notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications(user_id, is_read) WHERE is_read = FALSE;

-- Index for tenant notifications
CREATE INDEX IF NOT EXISTS idx_notifications_tenant_id ON notifications(tenant_id);

-- Index for entity reference
CREATE INDEX IF NOT EXISTS idx_notifications_entity ON notifications(entity_type, entity_id);

-- Index for created_at (for sorting)
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);

-- Composite index for common queries
CREATE INDEX IF NOT EXISTS idx_notifications_user_created ON notifications(user_id, created_at DESC);

-- =====================================================
-- ROW LEVEL SECURITY
-- =====================================================

-- Enable RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own notifications
CREATE POLICY "Users can view their own notifications"
    ON notifications
    FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

-- Policy: Users can update their own notifications (mark as read, etc.)
CREATE POLICY "Users can update their own notifications"
    ON notifications
    FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Policy: Users can delete their own notifications
CREATE POLICY "Users can delete their own notifications"
    ON notifications
    FOR DELETE
    TO authenticated
    USING (user_id = auth.uid());

-- Policy: Authenticated users can create notifications
-- (In production, you might want to restrict this to specific roles or use a service role)
CREATE POLICY "System can create notifications"
    ON notifications
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- =====================================================
-- TRIGGER: Update updated_at timestamp
-- =====================================================

-- Create function if not exists
CREATE OR REPLACE FUNCTION update_notifications_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_notifications_updated_at ON notifications;
CREATE TRIGGER trigger_notifications_updated_at
    BEFORE UPDATE ON notifications
    FOR EACH ROW
    EXECUTE FUNCTION update_notifications_updated_at();

-- =====================================================
-- NOTIFICATION TYPES REFERENCE
-- =====================================================
-- SYSTEM: System notifications
-- INFO: Informational notifications
-- WARNING: Warning notifications
-- ERROR: Error notifications
-- SUCCESS: Success notifications
-- TASK: Task-related notifications
-- ACTIVITY: Activity notifications
-- INVITATION: Invitation notifications
-- COMMENT: Comment notifications
-- MENTION: Mention notifications

-- =====================================================
-- PRIORITY LEVELS REFERENCE
-- =====================================================
-- LOW: Low priority
-- NORMAL: Normal priority (default)
-- HIGH: High priority
-- URGENT: Urgent notifications

-- =====================================================
-- REALTIME SUBSCRIPTION
-- =====================================================

-- Enable realtime for notifications
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;

COMMENT ON TABLE notifications IS 'In-app notifications for users';
