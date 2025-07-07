-- Debug notification access for user.agent2@test.com

-- 1. Get the exact user ID
SELECT id, email FROM auth.users WHERE email = 'user.agent2@test.com';

-- 2. Test direct query (what the app does)
SELECT 
    id,
    recipient_id,
    sender_id,
    type,
    title,
    message,
    data,
    read_at,
    created_at,
    updated_at
FROM notifications
WHERE recipient_id = (SELECT id FROM auth.users WHERE email = 'user.agent2@test.com')
ORDER BY created_at DESC
LIMIT 50;

-- 3. Check if RLS might be blocking
SELECT current_setting('role') as current_role;

-- 4. Test the exact query the Flutter app uses
SELECT *
FROM notifications
WHERE recipient_id = (SELECT id FROM auth.users WHERE email = 'user.agent2@test.com')
ORDER BY created_at DESC
LIMIT 50
OFFSET 0;