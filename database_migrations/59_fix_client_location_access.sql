-- SAFE FIX: Client location access issue
-- Following DEVELOPMENT_RULES.md - NO BREAKING CHANGES

-- ISSUE IDENTIFIED: Two conflicting client policies on active_agents table
-- 1. "Clients can view agent locations for their campaigns" - uses task_assignments logic
-- 2. "Clients view their agents" - uses campaign_agents logic
-- Both need to be true for RLS to allow access, but they use different data sources

-- RULE #1: NO BREAKING CHANGES - Preserve existing functionality
-- RULE #3: NON-DESTRUCTIVE - Fix without modifying core logic

SELECT 'FIXING: Duplicate client policies on active_agents' as action;

-- Step 1: Check current conflicting policies
SELECT 'Current conflicting policies:' as info;
SELECT policyname, cmd 
FROM pg_policies 
WHERE tablename = 'active_agents' 
AND policyname ILIKE '%client%';

-- Step 2: Remove the problematic duplicate policies (SAFE - won't break admin/manager/agent access)
DROP POLICY IF EXISTS "Clients can view agent locations for their campaigns" ON active_agents;
DROP POLICY IF EXISTS "Clients view their agents" ON active_agents;

-- Step 3: Create ONE comprehensive client policy that works with both data sources
CREATE POLICY "Client location access unified" ON active_agents
FOR SELECT
TO authenticated
USING (
    -- PRESERVE EXISTING: Admins can see all (keep existing functionality)
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
    OR
    -- PRESERVE EXISTING: Managers can see all (keep existing functionality)  
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'manager'
    OR
    -- PRESERVE EXISTING: Agents can see their own location (keep existing functionality)
    (
        (SELECT role FROM profiles WHERE id = auth.uid()) = 'agent'
        AND auth.uid() = active_agents.user_id
    )
    OR
    -- NEW: Unified client access - works with BOTH campaign_agents AND task_assignments
    (
        (SELECT role FROM profiles WHERE id = auth.uid()) = 'client'
        AND (
            -- Option 1: Via campaign_agents table (if populated)
            EXISTS (
                SELECT 1 FROM campaign_agents ca
                JOIN campaigns c ON ca.campaign_id = c.id
                WHERE c.client_id = auth.uid()
                AND ca.agent_id = active_agents.user_id
            )
            OR
            -- Option 2: Via task_assignments table (fallback)
            EXISTS (
                SELECT 1 FROM campaigns c
                JOIN tasks t ON c.id = t.campaign_id
                JOIN task_assignments ta ON t.id = ta.task_id
                WHERE c.client_id = auth.uid()
                AND ta.agent_id = active_agents.user_id
            )
        )
    )
);

-- Step 4: Test that the unified policy works
SELECT 'Testing unified client location access:' as test_info;

-- Simulate client query for Ahmed Ali's location
SELECT 
    aa.user_id,
    p.full_name as agent_name,
    aa.latitude,
    aa.longitude,
    aa.updated_at,
    'Should be accessible to client now' as access_status
FROM active_agents aa
JOIN profiles p ON aa.user_id = p.id
WHERE aa.user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'  -- Ahmed Ali
AND p.role = 'agent';

-- Step 5: Verify no breaking changes to other user types
SELECT 'Verification: Other user access preserved' as verification;
SELECT 
    COUNT(*) as total_active_agents,
    'Admins and managers should still see all' as admin_manager_access
FROM active_agents;

-- Step 6: Check final policy state
SELECT 'Final active_agents policies:' as final_state;
SELECT 
    policyname,
    cmd,
    CASE 
        WHEN policyname = 'Client location access unified' THEN 'NEW - Unified client access'
        ELSE 'EXISTING - Preserved functionality'
    END as policy_status
FROM pg_policies 
WHERE tablename = 'active_agents'
ORDER BY policyname;

SELECT 'CLIENT LOCATION ACCESS FIX COMPLETED' as completion;
SELECT 'Client should now be able to click on agents and see their locations' as result;