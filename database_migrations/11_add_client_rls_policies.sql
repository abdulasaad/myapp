-- Add RLS policies for client users to access task assignments and location data
-- Clients should be able to read data related to campaigns they monitor

-- 1. First check existing policies to avoid conflicts
SELECT 'Current policies for task_assignments:' as info;
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'task_assignments';

SELECT 'Current policies for location_heartbeats:' as info;
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'location_heartbeats';

-- 2. Add policy for clients to read task assignments for their campaigns
DROP POLICY IF EXISTS "Clients can view task assignments for their campaigns" ON task_assignments;

CREATE POLICY "Clients can view task assignments for their campaigns" ON task_assignments
FOR SELECT
TO authenticated
USING (
    auth.jwt() ->> 'role' = 'authenticated' AND
    EXISTS (
        SELECT 1 FROM campaigns c
        JOIN tasks t ON t.campaign_id = c.id
        WHERE t.id = task_assignments.task_id
        AND c.client_id = auth.uid()
    )
);

-- 3. Add policy for clients to read tasks for their campaigns  
DROP POLICY IF EXISTS "Clients can view tasks for their campaigns" ON tasks;

CREATE POLICY "Clients can view tasks for their campaigns" ON tasks
FOR SELECT 
TO authenticated
USING (
    auth.jwt() ->> 'role' = 'authenticated' AND
    EXISTS (
        SELECT 1 FROM campaigns c
        WHERE c.id = tasks.campaign_id
        AND c.client_id = auth.uid()
    )
);

-- 4. Add policy for clients to read location heartbeats for agents assigned to their campaigns
DROP POLICY IF EXISTS "Clients can view location heartbeats for their campaign agents" ON location_heartbeats;

CREATE POLICY "Clients can view location heartbeats for their campaign agents" ON location_heartbeats
FOR SELECT
TO authenticated  
USING (
    auth.jwt() ->> 'role' = 'authenticated' AND
    EXISTS (
        SELECT 1 FROM campaigns c
        JOIN tasks t ON t.campaign_id = c.id
        JOIN task_assignments ta ON ta.task_id = t.id
        WHERE ta.agent_id = location_heartbeats.agent_id
        AND c.client_id = auth.uid()
    )
);

-- 5. Add policy for clients to read campaign_agents table
DROP POLICY IF EXISTS "Clients can view campaign agents for their campaigns" ON campaign_agents;

CREATE POLICY "Clients can view campaign agents for their campaigns" ON campaign_agents
FOR SELECT
TO authenticated
USING (
    auth.jwt() ->> 'role' = 'authenticated' AND
    EXISTS (
        SELECT 1 FROM campaigns c
        WHERE c.id = campaign_agents.campaign_id
        AND c.client_id = auth.uid()
    )
);

-- 6. Verify the policies were created
SELECT 'Policies created successfully:' as result;

SELECT 
    tablename,
    policyname,
    cmd
FROM pg_policies 
WHERE tablename IN ('task_assignments', 'tasks', 'location_heartbeats', 'campaign_agents')
AND policyname LIKE '%client%'
ORDER BY tablename, policyname;