-- Test notification retrieval as the user would see it

-- 1. Check notifications for the test user (aboodealtikrity1@gmail.com)
SELECT 
    id,
    type,
    title,
    message,
    read_at,
    created_at
FROM notifications
WHERE recipient_id = '80cb4bac-1ad2-4c35-8e09-c01ef275114e'
ORDER BY created_at DESC;

-- 2. Test the get_unread_notification_count function
SELECT get_unread_notification_count('80cb4bac-1ad2-4c35-8e09-c01ef275114e'::UUID) as unread_count;

-- 3. Check if RLS is blocking access (run as superuser to bypass RLS)
-- This will show all notifications regardless of RLS
SELECT COUNT(*) as total_visible_with_rls
FROM notifications
WHERE recipient_id = '80cb4bac-1ad2-4c35-8e09-c01ef275114e';

-- 4. Get user emails for all notifications to verify recipient
SELECT 
    n.id,
    n.type,
    n.title,
    u.email as recipient_email,
    n.created_at
FROM notifications n
LEFT JOIN auth.users u ON u.id = n.recipient_id
ORDER BY n.created_at DESC;