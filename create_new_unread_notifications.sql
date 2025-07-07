-- Create NEW unread notifications for user.agent2@test.com

-- 1. First check current state
SELECT 
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE read_at IS NULL) as unread
FROM notifications
WHERE recipient_id = (SELECT id FROM auth.users WHERE email = 'user.agent2@test.com');

-- 2. Create fresh unread notifications
WITH agent_user AS (
    SELECT id FROM auth.users WHERE email = 'user.agent2@test.com'
)
INSERT INTO notifications (recipient_id, type, title, message, data)
SELECT 
    id,
    'campaign_assignment',
    'New Campaign: Winter Collection',
    'You have been assigned to campaign "Winter Collection 2024"',
    '{"campaign_id": "camp789", "campaign_name": "Winter Collection 2024"}'::JSONB
FROM agent_user;

-- 3. Create another one
WITH agent_user AS (
    SELECT id FROM auth.users WHERE email = 'user.agent2@test.com'
)
INSERT INTO notifications (recipient_id, type, title, message, data)
SELECT 
    id,
    'task_assignment',
    'Urgent Task',
    'New urgent task: Store inspection required today',
    '{"task_id": "task999", "priority": "high"}'::JSONB
FROM agent_user;

-- 4. Verify new unread notifications
SELECT 
    id,
    type,
    title,
    message,
    read_at,
    created_at
FROM notifications
WHERE recipient_id = (SELECT id FROM auth.users WHERE email = 'user.agent2@test.com')
AND read_at IS NULL
ORDER BY created_at DESC;

-- 5. Check total unread count
SELECT get_unread_notification_count(
    (SELECT id FROM auth.users WHERE email = 'user.agent2@test.com')
) as unread_count;