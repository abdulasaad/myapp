-- Verify the notification system setup

-- 1. Check table structure
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'notifications'
ORDER BY ordinal_position;

-- 2. Check RLS is enabled
SELECT 
    tablename,
    rowsecurity
FROM pg_tables
WHERE schemaname = 'public' 
AND tablename = 'notifications';

-- 3. Check policies
SELECT 
    policyname,
    cmd
FROM pg_policies
WHERE schemaname = 'public' 
AND tablename = 'notifications';

-- 4. Check if any notifications exist
SELECT COUNT(*) as total_notifications FROM notifications;

-- 5. Create a test notification with a specific user ID
-- Replace 'YOUR_USER_ID_HERE' with an actual user ID from your auth.users table
-- You can get a user ID by running: SELECT id, email FROM auth.users LIMIT 5;

-- Example (uncomment and replace with actual user ID):
-- INSERT INTO notifications (
--     recipient_id,
--     type,
--     title,
--     message,
--     data
-- ) VALUES (
--     'REPLACE_WITH_ACTUAL_USER_ID'::UUID,
--     'test',
--     'Test Notification',
--     'This is a test notification',
--     '{}'::JSONB
-- );