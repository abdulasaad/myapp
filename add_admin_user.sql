-- Add Admin User to admin_users Table
-- Run this after the simple_fix_no_recursion.sql to grant admin access

-- ================================
-- STEP 1: Find admin user IDs
-- ================================

-- Check current users and their emails to identify admins
SELECT 'Current users with roles:' as info;
SELECT 
    u.id,
    u.email,
    p.full_name,
    p.role
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id
ORDER BY p.role, u.email;

-- ================================
-- STEP 2: Add admin users to admin_users table
-- ================================

-- Add user.manager@test.com as admin for testing (replace with actual admin)
INSERT INTO public.admin_users (user_id)
SELECT u.id
FROM auth.users u
WHERE u.email = 'user.manager@test.com'  -- Replace with actual admin email
ON CONFLICT (user_id) DO NOTHING;

-- Add any other admin users here:
-- INSERT INTO public.admin_users (user_id)
-- SELECT u.id FROM auth.users u WHERE u.email = 'another.admin@example.com'
-- ON CONFLICT (user_id) DO NOTHING;

-- ================================
-- STEP 3: Verify admin access
-- ================================

SELECT 'Admin users configured:' as info;
SELECT 
    au.user_id,
    u.email,
    p.full_name,
    p.role,
    au.created_at
FROM public.admin_users au
JOIN auth.users u ON au.user_id = u.id
LEFT JOIN public.profiles p ON u.id = p.id
ORDER BY au.created_at;

-- ================================
-- STEP 4: Grant admin role in profiles table (optional)
-- ================================

-- Update the role in profiles table for consistency
UPDATE public.profiles 
SET role = 'admin'
WHERE id IN (SELECT user_id FROM public.admin_users)
  AND role != 'admin';

SELECT 'Admin users added successfully!' as result;
SELECT 'These users now have full system access via admin_users table' as info;