-- Debug: Test the exact query that UserManagementService is running

-- 1. This is what the service should be running:
SELECT 'Direct client query' as test_type,
       id,
       full_name,
       username,
       email,
       role,
       status,
       agent_creation_limit,
       default_group_id,
       created_by,
       created_at,
       updated_at
FROM profiles
WHERE role = 'client'
  AND status = 'active'
ORDER BY created_at DESC;

-- 2. Check if there are any RLS policies blocking this query
-- (Run this as the manager user if possible)
SELECT 'RLS test for manager user' as test_type,
       COUNT(*) as visible_clients
FROM profiles 
WHERE role = 'client'
  AND status = 'active';

-- 3. Check what the manager user can see in profiles table
SELECT 'What manager can see' as test_type,
       role,
       status,
       COUNT(*) as count
FROM profiles
GROUP BY role, status
ORDER BY role, status;