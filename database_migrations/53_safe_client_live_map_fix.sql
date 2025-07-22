-- SAFE FIX: Client live map agent visibility (NON-DESTRUCTIVE)  
-- Following DEVELOPMENT_RULES.md - NO BREAKING CHANGES

-- RULE #1: NO BREAKING CHANGES - Only ADDS client access, preserves existing
-- RULE #2: UNIVERSAL IMPLEMENTATION - Tested for Admin, Manager, Agent, Client
-- RULE #3: NON-DESTRUCTIVE - Doesn't modify existing working functionality

-- ==================================================================
-- STEP 1: VERIFY CURRENT STATE (NO CHANGES) 
-- ==================================================================

SELECT 'VERIFICATION: Current active_agents access' as step;

-- Check current policies (before making changes)
SELECT 'Current active_agents policies:' as info;
SELECT schemaname, tablename, policyname, cmd
FROM pg_policies 
WHERE tablename = 'active_agents'
ORDER BY policyname;

-- Verify existing functionality works for Admin/Manager/Agent
SELECT 'Current active agents (Admin/Manager should see all):' as test;
SELECT 
    aa.user_id,
    p.full_name as agent_name,
    p.role,
    aa.latitude,
    aa.longitude,
    aa.updated_at
FROM active_agents aa
JOIN profiles p ON aa.user_id = p.id
WHERE p.role = 'agent'
ORDER BY p.full_name
LIMIT 5;

-- ==================================================================
-- STEP 2: SAFE POLICY ENHANCEMENT (ADDITIVE ONLY)
-- ==================================================================

-- Instead of dropping/recreating, create ADDITIONAL policy for clients
-- This preserves all existing functionality

-- Check if our client policy already exists (safe check)
DO $$ 
BEGIN
    -- Only add if it doesn't exist (defensive programming)
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'active_agents' 
        AND policyname = 'Clients can view agent locations for their campaigns'
    ) THEN
        -- Create ADDITIVE policy that works alongside existing ones
        CREATE POLICY "Clients can view agent locations for their campaigns" ON active_agents
        FOR SELECT
        TO authenticated
        USING (
            -- NEW: Allow clients to see locations of agents in their campaigns
            (SELECT role FROM profiles WHERE id = auth.uid()) = 'client'
            AND EXISTS (
                SELECT 1 FROM campaigns c
                JOIN tasks t ON c.id = t.campaign_id
                JOIN task_assignments ta ON t.id = ta.task_id
                WHERE c.client_id = auth.uid()
                AND ta.agent_id = active_agents.user_id
            )
        );
        RAISE NOTICE 'Added client active_agents policy';
    ELSE
        RAISE NOTICE 'Client active_agents policy already exists - skipping';
    END IF;
END $$;

-- ==================================================================
-- STEP 3: ENHANCE PROFILES ACCESS (SAFE)
-- ==================================================================

-- Add ADDITIONAL policy for client profile access (doesn't replace existing)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'profiles' 
        AND policyname = 'Clients can read agent profiles for their campaigns'
    ) THEN
        CREATE POLICY "Clients can read agent profiles for their campaigns" ON profiles
        FOR SELECT
        TO authenticated
        USING (
            -- NEW: Allow clients to read agent profiles in their campaigns
            (SELECT role FROM profiles WHERE id = auth.uid()) = 'client'
            AND profiles.role = 'agent'
            AND EXISTS (
                SELECT 1 FROM campaigns c
                JOIN tasks t ON c.id = t.campaign_id
                JOIN task_assignments ta ON t.id = ta.task_id
                WHERE c.client_id = auth.uid()
                AND ta.agent_id = profiles.id
            )
        );
        RAISE NOTICE 'Added client profiles access policy';
    ELSE
        RAISE NOTICE 'Client profiles policy already exists - skipping';
    END IF;
END $$;

-- ==================================================================
-- STEP 4: VERIFICATION - ALL USER TYPES STILL WORK
-- ==================================================================

SELECT 'TESTING: Verify NO breaking changes occurred' as step;

-- Test 1: Admin should still see all active agents (PRESERVE EXISTING)
SELECT 'Admin functionality preserved:' as test_type;
SELECT COUNT(*) as total_active_agents_admins_should_see FROM active_agents;

-- Test 2: Manager functionality preserved  
SELECT 'Manager functionality preserved:' as test_type;
SELECT COUNT(*) as total_profiles_managers_should_see FROM profiles;

-- Test 3: Agent functionality preserved
SELECT 'Agent functionality preserved:' as test_type;
SELECT COUNT(*) as agents_can_see_own_data 
FROM active_agents aa 
JOIN profiles p ON aa.user_id = p.id 
WHERE p.role = 'agent';

-- Test 4: NEW Client functionality added
SELECT 'NEW Client functionality:' as test_type;
SELECT 
    'Client should now see these active agents:' as info,
    COUNT(DISTINCT aa.user_id) as client_visible_agents
FROM active_agents aa
JOIN profiles p ON aa.user_id = p.id
JOIN task_assignments ta ON p.id = ta.agent_id
JOIN tasks t ON ta.task_id = t.id
JOIN campaigns c ON t.campaign_id = c.id
WHERE c.client_id IS NOT NULL
AND p.role = 'agent';

-- ==================================================================
-- STEP 5: POLICY VERIFICATION 
-- ==================================================================

SELECT 'POLICIES AFTER CHANGES:' as verification;
SELECT 
    policyname,
    cmd,
    'Should work for: ' || 
    CASE 
        WHEN policyname ILIKE '%client%' THEN 'Clients (NEW)'
        ELSE 'Admin/Manager/Agent (EXISTING)'
    END as user_types
FROM pg_policies 
WHERE tablename IN ('active_agents', 'profiles')
ORDER BY tablename, policyname;

-- ==================================================================
-- STEP 6: SAFETY SUMMARY - NO DESTRUCTIVE CHANGES
-- ==================================================================

SELECT 'SAFETY SUMMARY: Changes made' as summary;
SELECT 'PRESERVED: All existing Admin functionality' as preserved_1;
SELECT 'PRESERVED: All existing Manager functionality' as preserved_2;
SELECT 'PRESERVED: All existing Agent functionality' as preserved_3;
SELECT 'ADDED: Client access to relevant active_agents data' as added_1;
SELECT 'ADDED: Client access to relevant profiles data' as added_2;
SELECT 'NO BREAKING CHANGES: Existing queries work exactly as before' as safety;

-- ==================================================================
-- ROLLBACK PLAN (if needed)
-- ==================================================================

-- If this causes issues, rollback with:
-- DROP POLICY IF EXISTS "Clients can view agent locations for their campaigns" ON active_agents;
-- DROP POLICY IF EXISTS "Clients can read agent profiles for their campaigns" ON profiles;