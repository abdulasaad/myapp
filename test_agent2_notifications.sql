-- Test notifications for user.agent2@test.com

-- 1. Get the user ID for user.agent2@test.com
SELECT id, email FROM auth.users WHERE email = 'user.agent2@test.com';

-- 2. Check their profile and role
SELECT 
    u.id,
    u.email,
    p.role,
    p.full_name
FROM auth.users u
LEFT JOIN profiles p ON p.id = u.id
WHERE u.email = 'user.agent2@test.com';

-- 3. Check if they have any existing notifications
SELECT 
    id,
    type,
    title,
    message,
    read_at,
    created_at
FROM notifications
WHERE recipient_id = (SELECT id FROM auth.users WHERE email = 'user.agent2@test.com')
ORDER BY created_at DESC;

-- 4. Create test notifications for user.agent2@test.com
-- First, let's create them manually to ensure they work
WITH agent_user AS (
    SELECT id FROM auth.users WHERE email = 'user.agent2@test.com'
)
INSERT INTO notifications (recipient_id, type, title, message, data)
SELECT 
    id,
    type_val,
    title_val,
    message_val,
    data_val
FROM agent_user,
LATERAL (VALUES 
    ('campaign_assignment', 'New Campaign Assignment', 'You have been assigned to campaign "Summer Sales 2024"', '{"campaign_id": "camp123", "campaign_name": "Summer Sales 2024"}'::JSONB),
    ('task_assignment', 'New Task Assigned', 'You have a new task: Visit Store Location A', '{"task_id": "task456", "task_name": "Visit Store Location A"}'::JSONB),
    ('system', 'Welcome!', 'Welcome to the notification system', '{}'::JSONB)
) AS t(type_val, title_val, message_val, data_val);

-- 5. Verify the notifications were created
SELECT 
    id,
    type,
    title,
    message,
    read_at,
    created_at
FROM notifications
WHERE recipient_id = (SELECT id FROM auth.users WHERE email = 'user.agent2@test.com')
ORDER BY created_at DESC;

-- 6. Test the unread count function
SELECT get_unread_notification_count(
    (SELECT id FROM auth.users WHERE email = 'user.agent2@test.com')
) as unread_count;

-- 7. Test using the create_notification function
SELECT create_notification(
    (SELECT id FROM auth.users WHERE email = 'user.agent2@test.com'),  -- recipient
    'route_assignment',                                                 -- type
    'Route Assignment',                                                 -- title
    'You have been assigned to route "Downtown Circuit"',              -- message
    NULL,                                                              -- sender_id
    '{"route_id": "route789", "route_name": "Downtown Circuit"}'::JSONB  -- data
);