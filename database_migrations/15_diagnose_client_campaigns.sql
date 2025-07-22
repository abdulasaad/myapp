-- Diagnose why client can't see campaigns

-- 1. Check current user
SELECT 'Current user info:' as info;
SELECT auth.uid() as current_user_id, 
       p.role as current_user_role,
       p.full_name as current_user_name
FROM profiles p
WHERE p.id = auth.uid();

-- 2. List ALL campaigns with their client assignments
SELECT 'All campaigns with client info:' as info;
SELECT 
    c.id,
    c.name,
    c.client_id,
    p.full_name as client_name,
    p.role as client_role
FROM campaigns c
LEFT JOIN profiles p ON p.id = c.client_id
ORDER BY c.created_at DESC;

-- 3. Check if there are any campaigns assigned to current user as client
SELECT 'Campaigns for current user as client:' as info;
SELECT 
    c.id,
    c.name,
    c.client_id,
    c.client_id = auth.uid() as is_my_campaign
FROM campaigns c
WHERE c.client_id IS NOT NULL;

-- 4. Test direct query without RLS
SELECT 'Direct query test (admin only):' as info;
SELECT COUNT(*) as total_campaigns_with_clients
FROM campaigns 
WHERE client_id IS NOT NULL;

-- 5. Check if RLS is enabled
SELECT 'RLS status:' as info;
SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables
WHERE tablename = 'campaigns';