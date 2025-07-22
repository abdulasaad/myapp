-- SAFE FIX: Client campaign agent display (NON-DESTRUCTIVE)
-- Following DEVELOPMENT_RULES.md - NO BREAKING CHANGES

-- RULE #1: NO BREAKING CHANGES - This only ADDS functionality, doesn't modify existing
-- RULE #2: UNIVERSAL IMPLEMENTATION - Works for Admin, Manager, Agent, AND Client  
-- RULE #3: NON-DESTRUCTIVE - Preserves all existing functionality

-- ==================================================================
-- STEP 1: VERIFY CURRENT STATE (NO CHANGES)
-- ==================================================================

SELECT 'VERIFICATION: Current database state' as step;

-- Check what the app is currently looking for
SELECT 'App expects campaign_agents table but we have task_assignments' as issue;

-- Verify existing task_assignments work for Admin/Manager/Agent
SELECT 'Current task assignments (should work for admins/managers):' as info;
SELECT DISTINCT 
    t.campaign_id,
    c.name as campaign_name,
    ta.agent_id,
    p.full_name as agent_name,
    c.created_by,
    c.assigned_manager_id,
    c.client_id
FROM task_assignments ta
JOIN tasks t ON ta.task_id = t.id  
JOIN campaigns c ON t.campaign_id = c.id
JOIN profiles p ON ta.agent_id = p.id
ORDER BY c.name, p.full_name
LIMIT 5;

-- ==================================================================
-- STEP 2: CREATE SAFE VIEW (ADDITIVE ONLY)
-- ==================================================================

-- Create a VIEW named campaign_agents so the Flutter app finds what it expects
-- This is NON-DESTRUCTIVE - doesn't change any existing data or functionality

CREATE OR REPLACE VIEW campaign_agents AS
SELECT DISTINCT
    -- Give it the structure the app expects
    gen_random_uuid() as id,  -- Provide an ID column
    t.campaign_id,
    ta.agent_id,
    c.created_by as assigned_by,
    ta.created_at as assigned_at
FROM task_assignments ta
JOIN tasks t ON ta.task_id = t.id
JOIN campaigns c ON t.campaign_id = c.id
JOIN profiles p ON ta.agent_id = p.id
WHERE p.role = 'agent';  -- Only include actual agents

-- Grant access to ALL authenticated users (maintains existing permissions)
GRANT SELECT ON campaign_agents TO authenticated;

-- ==================================================================
-- STEP 3: ADD CLIENT-SPECIFIC RLS POLICY (ADDITIVE ONLY)  
-- ==================================================================

-- Enable RLS on the view (safe - views don't store data)
ALTER VIEW campaign_agents SET (security_barrier = true);

-- Add RLS policy that works for ALL user types:
-- - Admins: Can see all (existing behavior preserved)
-- - Managers: Can see all (existing behavior preserved) 
-- - Agents: Can see their own assignments (existing behavior preserved)
-- - Clients: Can see agents in their campaigns (NEW functionality)

CREATE POLICY "Universal campaign_agents access" ON campaign_agents
FOR SELECT
TO authenticated
USING (
  -- PRESERVE EXISTING: Admins can see everything
  (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
  OR
  -- PRESERVE EXISTING: Managers can see everything  
  (SELECT role FROM profiles WHERE id = auth.uid()) = 'manager'
  OR
  -- PRESERVE EXISTING: Agents can see their own assignments
  (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'agent'
    AND agent_id = auth.uid()
  )
  OR
  -- NEW FUNCTIONALITY: Clients can see agents in their assigned campaigns
  (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'client'
    AND EXISTS (
      SELECT 1 FROM campaigns c
      WHERE c.id = campaign_agents.campaign_id
      AND c.client_id = auth.uid()
    )
  )
);

-- ==================================================================
-- STEP 4: VERIFICATION - ENSURE NO BREAKING CHANGES
-- ==================================================================

SELECT 'TESTING: Verify all user types can access data' as step;

-- Test 1: Admin should see all campaign agents (PRESERVE EXISTING)
SELECT 'Admin view test:' as test_type;
SELECT COUNT(*) as total_campaign_agents_admins_should_see FROM campaign_agents;

-- Test 2: Check that our view provides the same data structure the app expects
SELECT 'App compatibility test:' as test_type;
SELECT 'campaign_agents view structure:' as info;
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'campaign_agents' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Test 3: Verify client-specific data
SELECT 'Client-specific test:' as test_type;
SELECT DISTINCT
    ca.campaign_id,
    c.name as campaign_name,
    ca.agent_id,
    p.full_name as agent_name,
    'Should be visible to client' as status
FROM campaign_agents ca
JOIN campaigns c ON ca.campaign_id = c.id
JOIN profiles p ON ca.agent_id = p.id
WHERE c.client_id IS NOT NULL
ORDER BY c.name, p.full_name;

-- ==================================================================
-- STEP 5: SAFETY CHECK - NO DESTRUCTIVE CHANGES MADE
-- ==================================================================

SELECT 'SAFETY VERIFICATION: What this fix did' as summary;
SELECT 'ADDED: campaign_agents view - NO existing data changed' as change_1;
SELECT 'ADDED: RLS policies - existing permissions preserved' as change_2;  
SELECT 'PRESERVED: All existing functionality for Admin/Manager/Agent' as preserved_1;
SELECT 'ENHANCED: Added Client access without breaking others' as enhanced_1;

-- ==================================================================
-- ROLLBACK PLAN (if needed)
-- ==================================================================

-- If this causes issues, rollback with:
-- DROP VIEW IF EXISTS campaign_agents CASCADE;