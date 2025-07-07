-- SQL Commands to Check Current Notification System Setup
-- Run these queries in your Supabase SQL editor to check the current state

-- 1. Check if notifications table exists and its structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'notifications'
ORDER BY ordinal_position;

-- 2. Check if the table has any data
SELECT COUNT(*) as total_notifications FROM public.notifications;

-- 3. Check recent notifications (if any)
SELECT 
    id,
    recipient_id,
    sender_id,
    type,
    title,
    message,
    read_at,
    created_at
FROM public.notifications
ORDER BY created_at DESC
LIMIT 5;

-- 4. Check if RLS is enabled
SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables
WHERE schemaname = 'public' 
AND tablename = 'notifications';

-- 5. Check existing RLS policies
SELECT 
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE schemaname = 'public' 
AND tablename = 'notifications';

-- 6. Check if notification functions exist
SELECT 
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN (
    'get_unread_notification_count',
    'create_notification',
    'mark_notification_read',
    'mark_all_notifications_read'
);

-- 7. Check function parameters for create_notification
SELECT 
    ordinal_position,
    parameter_name,
    data_type,
    parameter_default
FROM information_schema.parameters
WHERE specific_schema = 'public'
AND specific_name = 'create_notification'
ORDER BY ordinal_position;

-- 8. Check indexes on notifications table
SELECT 
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public' 
AND tablename = 'notifications';

-- 9. Test current user ID (to verify auth is working)
SELECT auth.uid() as current_user_id;

-- 10. Check if there are any notifications for the current user
SELECT 
    COUNT(*) as my_notifications,
    COUNT(*) FILTER (WHERE read_at IS NULL) as unread_notifications
FROM public.notifications
WHERE recipient_id = auth.uid();