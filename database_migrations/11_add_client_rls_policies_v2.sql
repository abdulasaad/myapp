-- Add RLS policies for client users to access campaign data
-- Clients should be able to read data related to campaigns they monitor

-- 1. First check existing policies to avoid conflicts
SELECT 'Current policies for campaign_agents:' as info;
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'campaign_agents';

SELECT 'Current policies for tasks:' as info;
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'tasks';

-- 2. Add policy for clients to read campaign_agents table
DROP POLICY IF EXISTS "Clients can view campaign agents for their campaigns" ON campaign_agents;

CREATE POLICY "Clients can view campaign agents for their campaigns" ON campaign_agents
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM campaigns c
        WHERE c.id = campaign_agents.campaign_id
        AND c.client_id = auth.uid()
    )
);

-- 3. Add policy for clients to read tasks for their campaigns  
DROP POLICY IF EXISTS "Clients can view tasks for their campaigns" ON tasks;

CREATE POLICY "Clients can view tasks for their campaigns" ON tasks
FOR SELECT 
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM campaigns c
        WHERE c.id = tasks.campaign_id
        AND c.client_id = auth.uid()
    )
);

-- 4. Add policy for clients to read task assignments (if it exists)
-- First check if the table exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'task_assignments') THEN
        -- Drop existing policy if any
        DROP POLICY IF EXISTS "Clients can view task assignments for their campaigns" ON task_assignments;
        
        -- Create new policy
        CREATE POLICY "Clients can view task assignments for their campaigns" ON task_assignments
        FOR SELECT
        TO authenticated
        USING (
            EXISTS (
                SELECT 1 FROM campaigns c
                JOIN tasks t ON t.campaign_id = c.id
                WHERE t.id = task_assignments.task_id
                AND c.client_id = auth.uid()
            )
        );
    END IF;
END $$;

-- 5. Check if active_agents table exists and add policy
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'active_agents') THEN
        -- Drop existing policy if any
        DROP POLICY IF EXISTS "Clients can view active agents for their campaigns" ON active_agents;
        
        -- Create new policy
        CREATE POLICY "Clients can view active agents for their campaigns" ON active_agents
        FOR SELECT
        TO authenticated
        USING (
            EXISTS (
                SELECT 1 FROM campaigns c
                JOIN campaign_agents ca ON ca.campaign_id = c.id
                WHERE ca.agent_id = active_agents.user_id
                AND c.client_id = auth.uid()
            )
        );
    END IF;
END $$;

-- 6. Verify the policies were created
SELECT 'Policies created successfully:' as result;

SELECT 
    tablename,
    policyname,
    cmd
FROM pg_policies 
WHERE tablename IN ('campaign_agents', 'tasks', 'task_assignments', 'active_agents')
AND policyname LIKE '%client%'
ORDER BY tablename, policyname;

-- 7. Also check what location-related tables exist
SELECT 'Location-related tables in database:' as info;
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND (table_name LIKE '%location%' OR table_name LIKE '%heartbeat%' OR table_name LIKE '%active%')
ORDER BY table_name;