-- Test a real campaign assignment scenario

-- 1. Check user roles
SELECT 
    u.id,
    u.email,
    p.role,
    p.full_name
FROM auth.users u
LEFT JOIN profiles p ON p.id = u.id
WHERE u.email IN ('aboodealtikrity1@gmail.com', '112233@agent.local', '1234@agent.local')
ORDER BY u.email;

-- 2. Get a real campaign to test with
SELECT 
    id,
    name,
    status
FROM campaigns
WHERE status = 'active'
LIMIT 5;

-- 3. Create a notification for an agent user (let's use 112233@agent.local)
-- First get their user ID
SELECT id, email FROM auth.users WHERE email = '112233@agent.local';

-- 4. If you have a campaign ID from step 2, you can test creating a real campaign assignment notification
-- Replace CAMPAIGN_ID and AGENT_USER_ID with actual values:

-- Example (uncomment and fill in):
-- SELECT create_notification(
--     'AGENT_USER_ID'::UUID,              -- recipient_id (agent)
--     'campaign_assignment',              -- type  
--     'Campaign Assignment',              -- title
--     'You have been assigned to campaign "CAMPAIGN_NAME"',  -- message
--     'MANAGER_USER_ID'::UUID,           -- sender_id (manager who assigned)
--     '{"campaign_id": "CAMPAIGN_ID", "campaign_name": "CAMPAIGN_NAME"}'::JSONB  -- data
-- );