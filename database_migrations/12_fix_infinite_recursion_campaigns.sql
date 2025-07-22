-- Fix infinite recursion in campaigns table policies

-- 1. First, let's see all current policies on campaigns table
SELECT 'Current campaigns policies:' as info;
SELECT policyname, cmd, qual 
FROM pg_policies 
WHERE tablename = 'campaigns' 
ORDER BY policyname;

-- 2. Drop ALL client-related policies that might be causing recursion
DROP POLICY IF EXISTS "Clients can view tasks for their campaigns" ON tasks;
DROP POLICY IF EXISTS "Clients can view campaign agents for their campaigns" ON campaign_agents;
DROP POLICY IF EXISTS "Clients can view task assignments for their campaigns" ON task_assignments;
DROP POLICY IF EXISTS "Clients can view active agents for their campaigns" ON active_agents;

-- 3. Check if there's a problematic policy on campaigns itself
DROP POLICY IF EXISTS "Clients can view their assigned campaigns" ON campaigns;

-- 4. Create a simple, non-recursive policy for clients to view their campaigns
CREATE POLICY "Clients can view their assigned campaigns" ON campaigns
FOR SELECT
TO authenticated
USING (
    client_id = auth.uid()
);

-- 5. Create simple policies for related tables without recursive checks
-- For campaign_agents
CREATE POLICY "Clients can view campaign agents" ON campaign_agents
FOR SELECT
TO authenticated
USING (
    campaign_id IN (
        SELECT id FROM campaigns WHERE client_id = auth.uid()
    )
);

-- 6. For tasks
CREATE POLICY "Clients can view campaign tasks" ON tasks
FOR SELECT
TO authenticated
USING (
    campaign_id IN (
        SELECT id FROM campaigns WHERE client_id = auth.uid()
    )
);

-- 7. For active_agents (if it exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'active_agents') THEN
        CREATE POLICY "Clients can view active agents" ON active_agents
        FOR SELECT
        TO authenticated
        USING (
            user_id IN (
                SELECT agent_id 
                FROM campaign_agents 
                WHERE campaign_id IN (
                    SELECT id FROM campaigns WHERE client_id = auth.uid()
                )
            )
        );
    END IF;
END $$;

-- 8. Verify the new policies
SELECT 'New policies created:' as info;
SELECT 
    tablename,
    policyname,
    cmd
FROM pg_policies 
WHERE tablename IN ('campaigns', 'campaign_agents', 'tasks', 'active_agents')
AND policyname LIKE '%lient%'
ORDER BY tablename, policyname;