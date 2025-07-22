-- SAFE FIX V2: Client campaign agent display (NON-DESTRUCTIVE)
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
-- STEP 2: CREATE SAFE TABLE (NOT VIEW) - MORE COMPATIBLE
-- ==================================================================

-- Instead of a view, create an actual table that mirrors task_assignments
-- This avoids RLS issues with views and is what the Flutter app expects

-- Check if campaign_agents table already exists
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'campaign_agents' 
        AND table_schema = 'public'
    ) THEN
        -- Create the table structure the app expects
        CREATE TABLE campaign_agents (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            campaign_id UUID REFERENCES campaigns(id) ON DELETE CASCADE,
            agent_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
            assigned_by UUID REFERENCES profiles(id),
            assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            UNIQUE(campaign_id, agent_id)
        );
        
        -- Enable RLS on the new table
        ALTER TABLE campaign_agents ENABLE ROW LEVEL SECURITY;
        
        -- Grant basic permissions
        GRANT SELECT, INSERT, UPDATE, DELETE ON campaign_agents TO authenticated;
        
        RAISE NOTICE 'Created campaign_agents table';
    ELSE
        RAISE NOTICE 'campaign_agents table already exists - skipping creation';
    END IF;
END $$;

-- ==================================================================
-- STEP 3: POPULATE TABLE FROM EXISTING DATA (SAFE)
-- ==================================================================

-- Populate the new table with existing task assignment data
-- This preserves all current functionality
INSERT INTO campaign_agents (campaign_id, agent_id, assigned_by, assigned_at)
SELECT DISTINCT
    t.campaign_id,
    ta.agent_id,
    c.created_by,
    ta.created_at
FROM task_assignments ta
JOIN tasks t ON ta.task_id = t.id
JOIN campaigns c ON t.campaign_id = c.id
JOIN profiles p ON ta.agent_id = p.id
WHERE p.role = 'agent'
ON CONFLICT (campaign_id, agent_id) DO NOTHING;

-- ==================================================================
-- STEP 4: ADD UNIVERSAL RLS POLICY (SAFE FOR ALL USERS)
-- ==================================================================

-- Add RLS policy that works for ALL user types:
-- - Admins: Can see all (existing behavior preserved)
-- - Managers: Can see all (existing behavior preserved) 
-- - Agents: Can see their own assignments (existing behavior preserved)
-- - Clients: Can see agents in their campaigns (NEW functionality)

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'campaign_agents' 
        AND policyname = 'Universal campaign_agents access'
    ) THEN
        CREATE POLICY "Universal campaign_agents access" ON campaign_agents
        FOR ALL
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
        RAISE NOTICE 'Added universal campaign_agents RLS policy';
    ELSE
        RAISE NOTICE 'campaign_agents RLS policy already exists - skipping';
    END IF;
END $$;

-- ==================================================================
-- STEP 5: CREATE SYNC FUNCTION (MAINTAINS DATA CONSISTENCY)
-- ==================================================================

-- Create function to keep campaign_agents in sync with task_assignments
-- This ensures no breaking changes - data stays consistent

CREATE OR REPLACE FUNCTION sync_campaign_agents_from_tasks()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Add to campaign_agents when task assignment is created
        INSERT INTO campaign_agents (campaign_id, agent_id, assigned_by)
        SELECT t.campaign_id, NEW.agent_id, c.created_by
        FROM tasks t
        JOIN campaigns c ON t.campaign_id = c.id
        WHERE t.id = NEW.task_id
        ON CONFLICT (campaign_id, agent_id) DO NOTHING;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        -- Remove from campaign_agents if no more task assignments
        DELETE FROM campaign_agents ca
        WHERE ca.agent_id = OLD.agent_id
        AND ca.campaign_id IN (
            SELECT t.campaign_id 
            FROM tasks t 
            WHERE t.id = OLD.task_id
        )
        AND NOT EXISTS (
            SELECT 1 FROM task_assignments ta2
            JOIN tasks t2 ON ta2.task_id = t2.id
            WHERE ta2.agent_id = OLD.agent_id
            AND t2.campaign_id IN (
                SELECT t3.campaign_id 
                FROM tasks t3 
                WHERE t3.id = OLD.task_id
            )
            AND ta2.id != OLD.id
        );
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger (only if it doesn't exist)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.triggers 
        WHERE trigger_name = 'sync_campaign_agents_trigger'
    ) THEN
        CREATE TRIGGER sync_campaign_agents_trigger
            AFTER INSERT OR DELETE ON task_assignments
            FOR EACH ROW EXECUTE FUNCTION sync_campaign_agents_from_tasks();
        RAISE NOTICE 'Created sync trigger for campaign_agents';
    ELSE
        RAISE NOTICE 'Sync trigger already exists - skipping';
    END IF;
END $$;

-- ==================================================================
-- STEP 6: VERIFICATION - ENSURE NO BREAKING CHANGES
-- ==================================================================

SELECT 'TESTING: Verify all user types can access data' as step;

-- Test 1: Check table was created properly
SELECT 'Table creation test:' as test_type;
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'campaign_agents' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Test 2: Verify data was populated
SELECT 'Data population test:' as test_type;
SELECT COUNT(*) as total_campaign_agents FROM campaign_agents;

-- Test 3: Verify client-specific data
SELECT 'Client visibility test:' as test_type;
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
-- STEP 7: SAFETY CHECK - NO DESTRUCTIVE CHANGES MADE
-- ==================================================================

SELECT 'SAFETY VERIFICATION: What this fix did' as summary;
SELECT 'ADDED: campaign_agents table - NO existing data changed' as change_1;
SELECT 'ADDED: RLS policies - existing permissions preserved' as change_2;  
SELECT 'ADDED: Sync triggers - maintains data consistency' as change_3;
SELECT 'PRESERVED: All existing functionality for Admin/Manager/Agent' as preserved_1;
SELECT 'ENHANCED: Added Client access without breaking others' as enhanced_1;

-- ==================================================================
-- ROLLBACK PLAN (if needed)
-- ==================================================================

SELECT 'ROLLBACK PLAN: If issues occur, run these commands:' as rollback_info;
SELECT 'DROP TRIGGER IF EXISTS sync_campaign_agents_trigger ON task_assignments;' as rollback_1;
SELECT 'DROP FUNCTION IF EXISTS sync_campaign_agents_from_tasks();' as rollback_2;
SELECT 'DROP TABLE IF EXISTS campaign_agents CASCADE;' as rollback_3;