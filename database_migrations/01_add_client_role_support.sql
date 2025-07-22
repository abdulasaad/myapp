-- Migration: Add client role support and campaign ownership
-- This file contains SQL commands to add client role support to the database

-- 1. Update profiles table to support client role
-- Add constraint to include 'client' as a valid role
ALTER TABLE profiles 
DROP CONSTRAINT IF EXISTS profiles_role_check;

ALTER TABLE profiles 
ADD CONSTRAINT profiles_role_check 
CHECK (role IN ('admin', 'manager', 'agent', 'client'));

-- 2. Add client_id column to campaigns table
-- This links campaigns to their client owners
ALTER TABLE campaigns 
ADD COLUMN client_id UUID REFERENCES profiles(id) ON DELETE SET NULL;

-- 3. Create index for better performance on client_id lookups
CREATE INDEX IF NOT EXISTS idx_campaigns_client_id ON campaigns(client_id);

-- 4. Add comment to document the new column
COMMENT ON COLUMN campaigns.client_id IS 'Client who owns this campaign - can monitor but not modify';

-- 5. Update any existing campaigns to have NULL client_id (will be set manually for existing campaigns)