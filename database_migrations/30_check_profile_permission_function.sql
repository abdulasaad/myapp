-- Check the profile permission function that might be blocking access

-- 1. Check if the function exists and what it does
SELECT 'Profile permission function:' as info;
SELECT 
    proname as function_name,
    prosrc as function_body
FROM pg_proc 
WHERE proname = 'check_profile_select_permission';

-- 2. Test the function directly as a manager
SELECT 'Testing manager access to client profile:' as info;
SELECT 
    p.id,
    p.full_name,
    p.role,
    check_profile_select_permission(p.id) as can_select
FROM profiles p
WHERE p.role = 'client';

-- 3. Check what role the current user has
SELECT 'Current user info:' as info;
SELECT 
    id,
    role,
    full_name
FROM profiles
WHERE id = auth.uid();