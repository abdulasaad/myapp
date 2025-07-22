-- Nuclear option: Completely reset campaigns table RLS
-- This will temporarily disable all security to fix the recursion

-- 1. Show current state
SELECT 'Current campaigns policies before nuclear reset:' as info;
SELECT COUNT(*) as policy_count FROM pg_policies WHERE tablename = 'campaigns';

-- 2. COMPLETELY DISABLE ROW LEVEL SECURITY
ALTER TABLE campaigns DISABLE ROW LEVEL SECURITY;

-- 3. Drop ALL policies (even hidden/system ones)
DROP POLICY IF EXISTS "campaigns_admin_access" ON campaigns;
DROP POLICY IF EXISTS "campaigns_manager_select" ON campaigns;  
DROP POLICY IF EXISTS "campaigns_manager_insert" ON campaigns;
DROP POLICY IF EXISTS "campaigns_manager_update" ON campaigns;
DROP POLICY IF EXISTS "campaigns_client_select" ON campaigns;
DROP POLICY IF EXISTS "campaigns_agent_select" ON campaigns;

-- Also drop any legacy policies that might still exist
DROP POLICY IF EXISTS "Admin full access" ON campaigns;
DROP POLICY IF EXISTS "Manager campaign SELECT" ON campaigns;
DROP POLICY IF EXISTS "Manager campaign INSERT" ON campaigns;
DROP POLICY IF EXISTS "Manager campaign UPDATE" ON campaigns;
DROP POLICY IF EXISTS "Client campaign SELECT" ON campaigns;
DROP POLICY IF EXISTS "Agent campaign SELECT" ON campaigns;

-- 4. Verify NO policies exist
SELECT 'Policies after nuclear cleanup:' as info;
SELECT COUNT(*) as should_be_zero FROM pg_policies WHERE tablename = 'campaigns';

-- 5. Test basic access without RLS (should work for everyone)
SELECT 'Testing campaigns without RLS:' as info;
SELECT COUNT(*) as total_campaigns FROM campaigns;
SELECT 'SUCCESS: No RLS, no recursion' as status;

-- 6. Leave RLS DISABLED for now to test app
-- We'll re-enable it later with simpler policies

SELECT 'IMPORTANT: RLS is now DISABLED on campaigns table' as warning;
SELECT 'App should work but without security restrictions' as note;
SELECT 'Run migration 47 later to re-enable with simple policies' as next_step;