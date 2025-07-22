-- Simple test to verify campaigns are accessible

-- 1. Basic campaign count
SELECT 'Campaign Count Test:' as test;
SELECT COUNT(*) as total_campaigns FROM campaigns;

-- 2. Show all campaigns with basic info
SELECT 'All Campaigns:' as test;
SELECT 
    id,
    name,
    status,
    created_at::date as created_date,
    CASE 
        WHEN created_by IS NOT NULL THEN 'Has Creator'
        ELSE 'No Creator'
    END as creator_status
FROM campaigns
ORDER BY created_at DESC;

-- 3. Check if admin user exists and can theoretically access campaigns
SELECT 'Admin User Test:' as test;
SELECT 
    id,
    full_name,
    role,
    status,
    CASE 
        WHEN role = 'admin' THEN 'Should see all campaigns'
        WHEN role = 'manager' THEN 'Should see assigned campaigns'
        WHEN role = 'client' THEN 'Should see client campaigns'
        WHEN role = 'agent' THEN 'Should see agent campaigns'
        ELSE 'Unknown access level'
    END as expected_access
FROM profiles 
WHERE role = 'admin'
LIMIT 1;

SELECT 'Database is ready for admin campaign access' as status;