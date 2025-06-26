-- Manually confirm email for testing
-- Run this in your Supabase SQL editor

-- Find the user with email 'user.manager@test.com'
SELECT id, email, email_confirmed_at, created_at 
FROM auth.users 
WHERE email = 'user.manager@test.com';

-- Manually confirm the email for this user
UPDATE auth.users 
SET 
    email_confirmed_at = now(),
    updated_at = now()
WHERE email = 'user.manager@test.com';

-- Verify the confirmation
SELECT 
    id, 
    email, 
    email_confirmed_at,
    created_at,
    CASE 
        WHEN email_confirmed_at IS NOT NULL THEN 'CONFIRMED'
        ELSE 'NOT CONFIRMED'
    END as confirmation_status
FROM auth.users 
WHERE email = 'user.manager@test.com';

-- Also check the corresponding profile
SELECT p.id, p.full_name, p.email, p.role, p.status
FROM public.profiles p
JOIN auth.users u ON p.id = u.id
WHERE u.email = 'user.manager@test.com';

SELECT 'Email confirmation completed for user.manager@test.com' as result;