-- Check current campaign policies and RLS status

-- 1. Check if RLS is enabled on campaigns table
SELECT 'RLS Status on campaigns table:' as info;
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE tablename = 'campaigns';

-- 2. Check current policies on campaigns table
SELECT 'Current campaigns policies:' as info;
SELECT 
    policyname,
    cmd,
    roles,
    substring(qual, 1, 100) as using_clause,
    substring(with_check, 1, 100) as with_check_clause
FROM pg_policies 
WHERE tablename = 'campaigns'
ORDER BY policyname;

-- 3. Count total campaigns (should work regardless of policies)
SELECT 'Total campaigns in database:' as info;
SELECT COUNT(*) as total_campaigns FROM campaigns;

-- 4. Test admin access specifically
SELECT 'Testing admin role access:' as info;
SELECT 'Admin should see all campaigns when authenticated' as note;

-- 5. Check if there are any campaigns with proper creator info
SELECT 'Sample campaigns data:' as info;
SELECT 
    id,
    name,
    created_by,
    assigned_manager_id,
    client_id,
    status
FROM campaigns 
LIMIT 3;

-- 6. Check profiles table for admin users
SELECT 'Admin users in profiles:' as info;
SELECT 
    id,
    full_name,
    email,
    role,
    status
FROM profiles 
WHERE role = 'admin'
LIMIT 3;