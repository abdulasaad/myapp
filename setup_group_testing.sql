-- Setup Group Isolation Testing
-- Now that recursion is fixed, let's create a proper test scenario

-- ================================
-- STEP 1: Create meaningful groups
-- ================================

-- Clean up the test group and create proper ones
DELETE FROM public.user_groups WHERE group_id = 'c8e7add4-aad5-4fdc-9360-f7a69422722e';
DELETE FROM public.groups WHERE name = '1';

-- Create proper test groups
INSERT INTO public.groups (name, description) VALUES 
    ('Sales Team', 'Sales and marketing agents'),
    ('Support Team', 'Customer support agents'),
    ('Operations Team', 'Field operations agents')
ON CONFLICT (name) DO NOTHING;

-- ================================
-- STEP 2: Assign manager to a specific group
-- ================================

-- Assign manager 'a' to Sales Team
INSERT INTO public.user_groups (user_id, group_id)
SELECT '272afd47-5e8d-4411-8369-81b03abaf9c5', g.id
FROM public.groups g
WHERE g.name = 'Sales Team'
ON CONFLICT DO NOTHING;

-- ================================
-- STEP 3: Assign agents to different groups
-- ================================

-- Assign agent 'c' to Sales Team (same as manager)
INSERT INTO public.user_groups (user_id, group_id)
SELECT 'f33e02d4-4e3a-48f3-8788-49b9a079c721', g.id
FROM public.groups g
WHERE g.name = 'Sales Team'
ON CONFLICT DO NOTHING;

-- Assign agent '1' to Support Team (different from manager)
INSERT INTO public.user_groups (user_id, group_id)
SELECT '49560fc3-8413-4e35-90b2-8fc313b9bf87', g.id
FROM public.groups g
WHERE g.name = 'Support Team'
ON CONFLICT DO NOTHING;

-- ================================
-- STEP 4: Set up admin access
-- ================================

-- Add manager 'a' as admin for testing
INSERT INTO public.admin_users (user_id)
VALUES ('272afd47-5e8d-4411-8369-81b03abaf9c5')
ON CONFLICT DO NOTHING;

-- Update their role
UPDATE public.profiles 
SET role = 'admin'
WHERE id = '272afd47-5e8d-4411-8369-81b03abaf9c5';

-- ================================
-- STEP 5: Create a second manager for isolation testing
-- ================================

-- Create a test manager for Support Team (you can do this via the app UI instead)
-- This is just the SQL structure - create the actual user via your user management system

-- ================================
-- STEP 6: Verify the setup
-- ================================

SELECT 'Group assignments created:' as info;
SELECT 
    p.full_name,
    p.role,
    g.name as group_name,
    CASE 
        WHEN au.user_id IS NOT NULL THEN 'YES'
        ELSE 'NO'
    END as is_admin
FROM public.profiles p
LEFT JOIN public.user_groups ug ON p.id = ug.user_id
LEFT JOIN public.groups g ON ug.group_id = g.id
LEFT JOIN public.admin_users au ON p.id = au.user_id
ORDER BY p.role, p.full_name;

SELECT 'Expected behavior:' as info;
SELECT 
    'Manager "a" should see agent "c" (both in Sales Team)' as expectation_1,
    'Manager "a" should NOT see agent "1" (in Support Team)' as expectation_2,
    'Admin "a" should see ALL users regardless of groups' as expectation_3;

-- ================================
-- STEP 7: Test what manager can see with app-level filtering
-- ================================

SELECT 'Manager groups (for app-level filtering):' as info;
SELECT 
    p.full_name as manager_name,
    string_agg(g.name, ', ') as manager_groups
FROM public.profiles p
JOIN public.user_groups ug ON p.id = ug.user_id
JOIN public.groups g ON ug.group_id = g.id
WHERE p.id = '272afd47-5e8d-4411-8369-81b03abaf9c5'
GROUP BY p.id, p.full_name;

SELECT 'Users in same groups as manager:' as info;
SELECT DISTINCT
    target.full_name as visible_user,
    target.role,
    shared_group.name as shared_group_name
FROM public.profiles manager
JOIN public.user_groups manager_ug ON manager.id = manager_ug.user_id
JOIN public.groups shared_group ON manager_ug.group_id = shared_group.id
JOIN public.user_groups target_ug ON shared_group.id = target_ug.group_id
JOIN public.profiles target ON target_ug.user_id = target.id
WHERE manager.id = '272afd47-5e8d-4411-8369-81b03abaf9c5'
  AND target.id != manager.id
ORDER BY target.full_name;

SELECT 'Group isolation test setup completed!' as result;