-- Fix: Client campaign agent display issue
-- The campaign detail screen looks for 'campaign_agents' table but agents are in 'task_assignments'

-- 1. First, let's check what tables actually exist for agent assignments
SELECT 'Current agent assignment tables:' as info;
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name LIKE '%agent%' OR table_name LIKE '%assignment%'
ORDER BY table_name;

-- 2. Check the structure of task_assignments table
SELECT 'Task assignments table structure:' as info;
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'task_assignments' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 3. Create a view or function to get campaign agents from task_assignments
-- This gives us all agents assigned to any task in a campaign

CREATE OR REPLACE VIEW campaign_agents_view AS
SELECT DISTINCT 
    t.campaign_id,
    ta.agent_id,
    p.full_name as agent_name,
    p.role as agent_role,
    p.status as agent_status
FROM task_assignments ta
JOIN tasks t ON ta.task_id = t.id
JOIN profiles p ON ta.agent_id = p.id
WHERE p.role = 'agent';

-- 4. Grant access to this view
GRANT SELECT ON campaign_agents_view TO authenticated;

-- 5. Test the view with client campaigns
SELECT 'Testing campaign agents view for client campaigns:' as info;
SELECT 
    cav.campaign_id,
    c.name as campaign_name,
    cav.agent_id,
    cav.agent_name,
    cav.agent_role,
    cav.agent_status
FROM campaign_agents_view cav
JOIN campaigns c ON cav.campaign_id = c.id
WHERE c.client_id IS NOT NULL
ORDER BY c.name, cav.agent_name;

-- 6. Alternative: Create a proper campaign_agents table if the app expects it
-- This table will be populated from task_assignments automatically

CREATE TABLE IF NOT EXISTS campaign_agents (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    campaign_id UUID REFERENCES campaigns(id) ON DELETE CASCADE,
    agent_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    assigned_by UUID REFERENCES profiles(id),
    UNIQUE(campaign_id, agent_id)
);

-- Enable RLS on campaign_agents
ALTER TABLE campaign_agents ENABLE ROW LEVEL SECURITY;

-- RLS policy for campaign_agents (clients can see agents in their campaigns)
CREATE POLICY "Clients can view agents in their campaigns" ON campaign_agents
FOR SELECT
TO authenticated
USING (
  -- Allow admins/managers to see all
  (SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin', 'manager')
  OR
  -- Allow clients to see agents in their assigned campaigns
  (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'client'
    AND
    EXISTS (
      SELECT 1 FROM campaigns c
      WHERE c.id = campaign_agents.campaign_id
      AND c.client_id = auth.uid()
    )
  )
);

-- Grant access
GRANT SELECT ON campaign_agents TO authenticated;
GRANT INSERT, UPDATE, DELETE ON campaign_agents TO authenticated;

-- 7. Populate campaign_agents from existing task_assignments
INSERT INTO campaign_agents (campaign_id, agent_id, assigned_by)
SELECT DISTINCT 
    t.campaign_id,
    ta.agent_id,
    c.created_by
FROM task_assignments ta
JOIN tasks t ON ta.task_id = t.id
JOIN campaigns c ON t.campaign_id = c.id
ON CONFLICT (campaign_id, agent_id) DO NOTHING;

-- 8. Create a function to automatically maintain campaign_agents when task_assignments change
CREATE OR REPLACE FUNCTION sync_campaign_agents()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Add agent to campaign_agents when assigned to a task
        INSERT INTO campaign_agents (campaign_id, agent_id, assigned_by)
        SELECT t.campaign_id, NEW.agent_id, c.created_by
        FROM tasks t
        JOIN campaigns c ON t.campaign_id = c.id
        WHERE t.id = NEW.task_id
        ON CONFLICT (campaign_id, agent_id) DO NOTHING;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        -- Remove agent from campaign_agents if no longer assigned to any tasks in that campaign
        DELETE FROM campaign_agents ca
        WHERE ca.agent_id = OLD.agent_id
        AND ca.campaign_id IN (
            SELECT t.campaign_id 
            FROM tasks t 
            WHERE t.id = OLD.task_id
        )
        AND NOT EXISTS (
            -- Agent still has other task assignments in this campaign
            SELECT 1 FROM task_assignments ta2
            JOIN tasks t2 ON ta2.task_id = t2.id
            WHERE ta2.agent_id = OLD.agent_id
            AND t2.campaign_id IN (
                SELECT t3.campaign_id 
                FROM tasks t3 
                WHERE t3.id = OLD.task_id
            )
            AND ta2.id != OLD.id  -- Exclude the assignment being deleted
        );
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 9. Create triggers to maintain campaign_agents
DROP TRIGGER IF EXISTS sync_campaign_agents_trigger ON task_assignments;
CREATE TRIGGER sync_campaign_agents_trigger
    AFTER INSERT OR DELETE ON task_assignments
    FOR EACH ROW EXECUTE FUNCTION sync_campaign_agents();

-- 10. Verification: Show final results
SELECT 'Final verification - Campaign agents for client campaigns:' as info;
SELECT 
    c.name as campaign_name,
    c.client_id,
    p_client.full_name as client_name,
    ca.agent_id,
    p_agent.full_name as agent_name,
    ca.assigned_at
FROM campaigns c
JOIN campaign_agents ca ON c.id = ca.campaign_id
JOIN profiles p_client ON c.client_id = p_client.id
JOIN profiles p_agent ON ca.agent_id = p_agent.id
WHERE c.client_id IS NOT NULL
ORDER BY c.name, p_agent.full_name;