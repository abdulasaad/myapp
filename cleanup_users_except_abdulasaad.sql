-- Delete all user accounts except abdulasaad95@gmail.com
-- This will clean up test accounts for fresh testing

-- ================================
-- STEP 1: Identify the user to keep
-- ================================

SELECT 'User to keep:' as info;
SELECT u.id, u.email, p.full_name, p.role
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id
WHERE u.email = 'abdulasaad95@gmail.com';

-- ================================
-- STEP 2: Show all users that will be deleted
-- ================================

SELECT 'Users that will be deleted:' as info;
SELECT u.id, u.email, p.full_name, p.role
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id
WHERE u.email != 'abdulasaad95@gmail.com'
ORDER BY u.email;

-- ================================
-- STEP 3: Delete user group assignments (except for abdulasaad95@gmail.com)
-- ================================

DELETE FROM public.user_groups 
WHERE user_id IN (
    SELECT u.id 
    FROM auth.users u 
    WHERE u.email != 'abdulasaad95@gmail.com'
);

-- ================================
-- STEP 4: Delete from admin_users table (except for abdulasaad95@gmail.com)
-- ================================

DELETE FROM public.admin_users 
WHERE user_id IN (
    SELECT u.id 
    FROM auth.users u 
    WHERE u.email != 'abdulasaad95@gmail.com'
);

-- ================================
-- STEP 5: Delete profiles (except for abdulasaad95@gmail.com)
-- ================================

DELETE FROM public.profiles 
WHERE id IN (
    SELECT u.id 
    FROM auth.users u 
    WHERE u.email != 'abdulasaad95@gmail.com'
);

-- ================================
-- STEP 6: Delete from auth.users (except for abdulasaad95@gmail.com)
-- ================================

DELETE FROM auth.users 
WHERE email != 'abdulasaad95@gmail.com';

-- ================================
-- STEP 7: Ensure abdulasaad95@gmail.com has admin access
-- ================================

-- Add to admin_users if not already there
INSERT INTO public.admin_users (user_id)
SELECT u.id FROM auth.users u WHERE u.email = 'abdulasaad95@gmail.com'
ON CONFLICT (user_id) DO NOTHING;

-- Update role to admin
UPDATE public.profiles 
SET role = 'admin'
WHERE id IN (SELECT id FROM auth.users WHERE email = 'abdulasaad95@gmail.com');

-- ================================
-- STEP 8: Clean up empty groups if needed
-- ================================

-- Remove groups that have no users assigned
DELETE FROM public.groups 
WHERE id NOT IN (SELECT DISTINCT group_id FROM public.user_groups);

-- ================================
-- STEP 9: Verification
-- ================================

SELECT 'Cleanup completed!' as result;

SELECT 'Remaining users:' as info;
SELECT u.id, u.email, p.full_name, p.role,
       CASE WHEN au.user_id IS NOT NULL THEN 'YES' ELSE 'NO' END as is_admin
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id
LEFT JOIN public.admin_users au ON u.id = au.user_id
ORDER BY u.email;

SELECT 'Remaining groups:' as info;
SELECT g.id, g.name, g.description,
       COUNT(ug.user_id) as user_count
FROM public.groups g
LEFT JOIN public.user_groups ug ON g.id = ug.group_id
GROUP BY g.id, g.name, g.description
ORDER BY g.name;