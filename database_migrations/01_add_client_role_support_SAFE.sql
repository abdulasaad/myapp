-- SAFE Migration: Add client role support
-- Based on actual database analysis from user

-- 1. UPDATE the existing role constraint to include 'client'
-- Current: role_check: ((role = ANY (ARRAY['admin'::text, 'manager'::text, 'agent'::text])))
-- This replaces the existing constraint safely

ALTER TABLE profiles 
DROP CONSTRAINT IF EXISTS role_check;

ALTER TABLE profiles 
ADD CONSTRAINT role_check 
CHECK (role = ANY (ARRAY['admin'::text, 'manager'::text, 'agent'::text, 'client'::text]));

-- 2. Add client_id column to campaigns table
-- Following the same pattern as assigned_manager_id
ALTER TABLE campaigns 
ADD COLUMN client_id UUID REFERENCES profiles(id) ON DELETE SET NULL;

-- 3. Create index for performance (same pattern as other foreign keys)
CREATE INDEX IF NOT EXISTS idx_campaigns_client_id ON campaigns(client_id);

-- 4. Add helpful comment
COMMENT ON COLUMN campaigns.client_id IS 'Client who can monitor this campaign (read-only access)';

-- 5. Verify the changes
SELECT 'Role constraint updated' as status, 
       tc.constraint_name, 
       cc.check_clause 
FROM information_schema.table_constraints tc
JOIN information_schema.check_constraints cc ON tc.constraint_name = cc.constraint_name
WHERE tc.table_name = 'profiles' 
AND tc.constraint_type = 'CHECK'
AND cc.check_clause ILIKE '%role%';

SELECT 'Client ID column added' as status,
       column_name,
       data_type,
       is_nullable
FROM information_schema.columns 
WHERE table_name = 'campaigns' 
AND column_name = 'client_id';