-- Force clean duplicate campaigns policies

-- 1. Drop ALL old policies manually by exact name
DROP POLICY IF EXISTS "Agents can view assigned campaigns" ON campaigns;
DROP POLICY IF EXISTS "Clients can view their campaigns" ON campaigns;
DROP POLICY IF EXISTS "Manager campaign access" ON campaigns;
DROP POLICY IF EXISTS "Managers can create campaigns" ON campaigns;
DROP POLICY IF EXISTS "Managers can update campaigns" ON campaigns;

-- 2. Verify only the new clean policies remain
SELECT 'Final campaigns policies after cleanup:' as info;
SELECT 
    policyname,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'campaigns'
ORDER BY policyname;

-- 3. Test agent access (run as agent)
SELECT 'Agent campaign access test:' as info;
SELECT c.id, c.name 
FROM campaigns c
WHERE c.id IN (
    SELECT ca.campaign_id 
    FROM campaign_agents ca 
    WHERE ca.agent_id = auth.uid()
)
LIMIT 5;