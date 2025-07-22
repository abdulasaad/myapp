-- Add missing policy for agents to see campaigns they're assigned to

-- 1. Add SELECT policy for agents
CREATE POLICY "Agents can view assigned campaigns" ON campaigns
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM campaign_agents ca
        WHERE ca.campaign_id = campaigns.id
        AND ca.agent_id = auth.uid()
    )
    AND EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role = 'agent'
    )
);

-- 2. Verify all campaigns policies now
SELECT 'All campaigns policies after adding agent policy:' as info;
SELECT 
    policyname,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'campaigns'
ORDER BY policyname;

-- 3. Test query that agent should now be able to run
-- (Run this as the agent user after the policy is added)
SELECT 'Agent campaign access test:' as info;
SELECT 
    c.id,
    c.name,
    c.description,
    c.start_date,
    c.end_date
FROM campaigns c
JOIN campaign_agents ca ON ca.campaign_id = c.id
WHERE ca.agent_id = auth.uid();