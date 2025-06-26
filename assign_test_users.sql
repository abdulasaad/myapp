-- Assign Test Users to Groups for Isolation Testing
-- This creates a realistic scenario to test manager isolation

-- ================================
-- STEP 1: Ensure test groups exist
-- ================================

INSERT INTO public.groups (name, description) VALUES 
    ('Sales Team', 'Sales division with dedicated agents'),
    ('Support Team', 'Customer support and service agents'),
    ('Marketing Team', 'Marketing and promotion agents')
ON CONFLICT (name) DO NOTHING;

-- ================================
-- STEP 2: Assign user.manager@test.com to Sales Team
-- ================================

-- First, let's see what users we have
SELECT 'Current Users:' as info;
SELECT id, full_name, email, role 
FROM public.profiles 
ORDER BY role, full_name;

-- Assign the test manager to Sales Team
INSERT INTO public.user_groups (user_id, group_id)
SELECT p.id, g.id
FROM public.profiles p, public.groups g
WHERE p.email = 'user.manager@test.com'
  AND g.name = 'Sales Team'
ON CONFLICT DO NOTHING;

-- ================================
-- STEP 3: Create some test agents and assign them to different groups
-- ================================

-- You can create test agents using the user management system, then assign them:

-- Example: Assign any existing agents to different groups
-- (Modify the WHERE conditions based on your actual users)

-- Assign first 2 agents to Sales Team (same as manager)
INSERT INTO public.user_groups (user_id, group_id)
SELECT p.id, g.id
FROM public.profiles p, public.groups g
WHERE p.role = 'agent'
  AND g.name = 'Sales Team'
  AND p.id IN (
    SELECT id FROM public.profiles 
    WHERE role = 'agent' 
    ORDER BY created_at 
    LIMIT 2
  )
ON CONFLICT DO NOTHING;

-- Assign next 2 agents to Support Team (different from manager)
INSERT INTO public.user_groups (user_id, group_id)
SELECT p.id, g.id
FROM public.profiles p, public.groups g
WHERE p.role = 'agent'
  AND g.name = 'Support Team'
  AND p.id IN (
    SELECT id FROM public.profiles 
    WHERE role = 'agent' 
    ORDER BY created_at 
    OFFSET 2
    LIMIT 2
  )
ON CONFLICT DO NOTHING;

-- ================================
-- STEP 4: Verify assignments
-- ================================

SELECT 'Group Assignments Created:' as info;
SELECT 
    p.full_name,
    p.email,
    p.role,
    g.name as group_name
FROM public.profiles p
JOIN public.user_groups ug ON p.id = ug.user_id
JOIN public.groups g ON ug.group_id = g.id
ORDER BY g.name, p.role, p.full_name;

-- ================================
-- STEP 5: Test what manager can see
-- ================================

SELECT 'What user.manager@test.com should see:' as info;
SELECT DISTINCT
    target.full_name,
    target.email,
    target.role,
    shared_groups.group_names
FROM public.profiles manager
JOIN public.user_groups manager_ug ON manager.id = manager_ug.user_id
JOIN public.user_groups target_ug ON manager_ug.group_id = target_ug.group_id
JOIN public.profiles target ON target_ug.user_id = target.id
JOIN (
    SELECT 
        target_ug2.user_id,
        string_agg(g2.name, ', ') as group_names
    FROM public.user_groups target_ug2
    JOIN public.groups g2 ON target_ug2.group_id = g2.id
    GROUP BY target_ug2.user_id
) shared_groups ON target.id = shared_groups.user_id
WHERE manager.email = 'user.manager@test.com'
  AND target.id != manager.id  -- Exclude self
ORDER BY target.role, target.full_name;

-- ================================
-- STEP 6: Expected behavior summary
-- ================================

SELECT 'Expected Behavior:' as info;
SELECT 
    'user.manager@test.com should only see users in Sales Team' as expected_isolation,
    'Agents in Support Team should be invisible to this manager' as additional_info,
    'Admin users can see all users regardless of groups' as admin_behavior;

SELECT 'Test setup completed! Now test the user management system in the app.' as result;