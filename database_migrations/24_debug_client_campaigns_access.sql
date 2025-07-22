-- Debug why client can't see their campaigns
-- Run AS CLIENT USER

-- 1. Basic test - can I see ANY campaigns?
SELECT 'Can I see any campaigns?' as info;
SELECT COUNT(*) as total_campaigns FROM campaigns;

-- 2. Test the specific condition
SELECT 'Campaigns where I am the client:' as info;
SELECT id, name, client_id 
FROM campaigns 
WHERE client_id = auth.uid();

-- 3. What is my user ID?
SELECT 'My user ID:' as info;
SELECT auth.uid() as my_id;

-- 4. Direct test bypassing RLS (this will fail if RLS is working)
SELECT 'Direct campaign query:' as info;
SELECT id, name, client_id, 
       client_id = auth.uid() as is_mine
FROM campaigns
LIMIT 5;

-- 5. Check if the campaign-client assignment exists
SELECT 'Campaign assignments in database:' as info;
SELECT 
    c.id as campaign_id,
    c.name as campaign_name,
    c.client_id,
    p.full_name as client_name,
    p.role as client_role
FROM campaigns c
LEFT JOIN profiles p ON p.id = c.client_id
WHERE c.client_id IS NOT NULL;