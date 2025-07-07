-- Test notification badge functionality
-- Run this to verify the notification system is working

-- 1. Check if we have unread notifications for the test user
SELECT 
    COUNT(*) as total_notifications,
    COUNT(*) FILTER (WHERE read_at IS NULL) as unread_notifications
FROM notifications
WHERE recipient_id = (SELECT id FROM auth.users WHERE email = 'user.agent2@test.com');

-- 2. Test the get_unread_notification_count function directly
SELECT get_unread_notification_count(
    (SELECT id FROM auth.users WHERE email = 'user.agent2@test.com')
) as function_result;

-- 3. Show recent notifications for the test user
SELECT 
    id,
    type,
    title,
    message,
    read_at,
    created_at
FROM notifications
WHERE recipient_id = (SELECT id FROM auth.users WHERE email = 'user.agent2@test.com')
ORDER BY created_at DESC
LIMIT 5;