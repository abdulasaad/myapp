-- Check campaign INSERT policies that might be blocking manager

-- 1. Check all policies on campaigns table
SELECT 'All campaigns policies:' as info;
SELECT 
    policyname,
    cmd,
    permissive,
    roles,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'campaigns'
ORDER BY cmd, policyname;

-- 2. Check if there are any INSERT policies
SELECT 'INSERT policies only:' as info;
SELECT 
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'campaigns'
AND cmd = 'INSERT'
ORDER BY policyname;

-- 3. Test if manager can insert into campaigns
-- (Run this as manager user)
SELECT 'Testing INSERT permission:' as info;
INSERT INTO campaigns (
    name,
    description,
    start_date,
    end_date,
    created_by
) VALUES (
    'Test Campaign INSERT',
    'Testing if manager can insert',
    NOW(),
    NOW() + INTERVAL '1 day',
    auth.uid()
) RETURNING id, name;