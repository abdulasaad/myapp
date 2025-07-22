-- Fix for client authentication context
-- This helps when auth.uid() returns null

-- 1. First, let's create a function to safely get the current user ID
CREATE OR REPLACE FUNCTION get_current_user_id()
RETURNS UUID AS $$
BEGIN
    -- Return the authenticated user ID, or null if not authenticated
    RETURN auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Create an improved client campaign policy that handles edge cases
DROP POLICY IF EXISTS "Clients can view assigned campaigns" ON campaigns;

CREATE POLICY "Clients can view their campaigns" ON campaigns
FOR SELECT
TO authenticated
USING (
    -- Check if user is authenticated and is a client
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role = 'client'
        AND campaigns.client_id = profiles.id
    )
);

-- 3. Also ensure campaign_agents policy works for clients
DROP POLICY IF EXISTS "Clients can view campaign agents" ON campaign_agents;

CREATE POLICY "Clients view campaign agents" ON campaign_agents
FOR SELECT  
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM campaigns c
        JOIN profiles p ON p.id = auth.uid()
        WHERE c.id = campaign_agents.campaign_id
        AND c.client_id = p.id
        AND p.role = 'client'
    )
);

-- 4. Ensure active_agents policy works for clients
DROP POLICY IF EXISTS "Clients can view active agents" ON active_agents;

CREATE POLICY "Clients view their agents" ON active_agents
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 
        FROM campaign_agents ca
        JOIN campaigns c ON c.id = ca.campaign_id
        JOIN profiles p ON p.id = auth.uid()
        WHERE ca.agent_id = active_agents.user_id
        AND c.client_id = p.id
        AND p.role = 'client'
    )
);

-- 5. Verify the new policies
SELECT 'New RLS policies:' as info;
SELECT 
    tablename,
    policyname,
    cmd
FROM pg_policies 
WHERE tablename IN ('campaigns', 'campaign_agents', 'active_agents')
AND policyname LIKE '%lient%'
ORDER BY tablename, policyname;