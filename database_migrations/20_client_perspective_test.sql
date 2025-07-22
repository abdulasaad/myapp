-- Test from CLIENT perspective
-- Run this AS THE CLIENT USER

-- 1. Who am I?
SELECT 'My identity:' as info;
SELECT id, full_name, role FROM profiles WHERE id = auth.uid();

-- 2. Can I see ANY campaigns?
SELECT 'Campaigns I can see:' as info;
SELECT id, name, client_id, created_by FROM campaigns;

-- 3. Can I see campaigns assigned to me?
SELECT 'My assigned campaigns:' as info;
SELECT id, name, client_id FROM campaigns WHERE client_id = auth.uid();

-- 4. Can I access campaign_agents table at all?
SELECT 'Campaign agents access test:' as info;
SELECT COUNT(*) as total_visible FROM campaign_agents;

-- 5. Can I access active_agents table?
SELECT 'Active agents access test:' as info;
SELECT COUNT(*) as total_visible FROM active_agents;

-- 6. Test if I can join through the tables
SELECT 'Join test:' as info;
SELECT 
    c.name as campaign_name,
    ca.agent_id,
    p.full_name as agent_name
FROM campaigns c
LEFT JOIN campaign_agents ca ON ca.campaign_id = c.id
LEFT JOIN profiles p ON p.id = ca.agent_id
WHERE c.client_id = auth.uid();

-- 7. Test the RLS policy conditions directly
SELECT 'RLS condition tests:' as info;
SELECT 
    'Can see my campaigns' as test,
    EXISTS(SELECT 1 FROM campaigns WHERE client_id = auth.uid()) as result
UNION ALL
SELECT 
    'Campaign agents policy works',
    EXISTS(
        SELECT 1 FROM campaign_agents ca 
        WHERE ca.campaign_id IN (
            SELECT id FROM campaigns WHERE client_id = auth.uid()
        )
    )
UNION ALL
SELECT 
    'Active agents policy works',
    EXISTS(
        SELECT 1 FROM active_agents aa
        WHERE aa.user_id IN (
            SELECT ca.agent_id FROM campaign_agents ca
            JOIN campaigns c ON c.id = ca.campaign_id
            WHERE c.client_id = auth.uid()
        )
    );