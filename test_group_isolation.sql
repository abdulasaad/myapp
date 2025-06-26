-- Test Group-Based Isolation
-- Use this to verify that managers only see users in their groups

-- ================================
-- SETUP: Create test scenario
-- ================================

-- 1. Create test groups if they don't exist
INSERT INTO public.groups (name, description) VALUES 
    ('Sales Team', 'Sales division agents and managers'),
    ('Support Team', 'Customer support division'),
    ('Field Ops', 'Field operations team')
ON CONFLICT (name) DO NOTHING;

-- 2. Show all groups
SELECT 'Current Groups:' as info;
SELECT id, name, description FROM public.groups ORDER BY name;

-- ================================
-- VERIFICATION QUERIES
-- ================================

-- 3. Show all users and their group memberships
SELECT 'All Users and Their Groups:' as info;
SELECT 
    p.full_name,
    p.role,
    p.email,
    COALESCE(string_agg(g.name, ', '), 'No groups') as groups
FROM public.profiles p
LEFT JOIN public.user_groups ug ON p.id = ug.user_id
LEFT JOIN public.groups g ON ug.group_id = g.id
GROUP BY p.id, p.full_name, p.role, p.email
ORDER BY p.role, p.full_name;

-- ================================
-- MANAGER ISOLATION TEST
-- ================================

-- 4. For each manager, show what users they can see based on group isolation
SELECT 'Manager Isolation Test:' as info;

WITH manager_visibility AS (
  SELECT DISTINCT
    manager.full_name as manager_name,
    manager.email as manager_email,
    visible_user.full_name as visible_user_name,
    visible_user.role as visible_user_role,
    shared_group.name as shared_group_name
  FROM public.profiles manager
  JOIN public.user_groups manager_ug ON manager.id = manager_ug.user_id
  JOIN public.groups shared_group ON manager_ug.group_id = shared_group.id
  JOIN public.user_groups user_ug ON shared_group.id = user_ug.group_id
  JOIN public.profiles visible_user ON user_ug.user_id = visible_user.id
  WHERE manager.role = 'manager'
    AND manager.id != visible_user.id  -- Don't show self
)
SELECT 
  manager_name,
  manager_email,
  COUNT(DISTINCT visible_user_name) as total_visible_users,
  string_agg(DISTINCT visible_user_name || ' (' || visible_user_role || ')', ', ' ORDER BY visible_user_name) as visible_users,
  string_agg(DISTINCT shared_group_name, ', ' ORDER BY shared_group_name) as shared_groups
FROM manager_visibility
GROUP BY manager_name, manager_email
ORDER BY manager_name;

-- ================================
-- GROUP ASSIGNMENT SUGGESTIONS
-- ================================

-- 5. Show users not assigned to any group (need assignment)
SELECT 'Users Without Group Assignment:' as info;
SELECT p.full_name, p.role, p.email
FROM public.profiles p
LEFT JOIN public.user_groups ug ON p.id = ug.user_id
WHERE ug.user_id IS NULL
ORDER BY p.role, p.full_name;

-- ================================
-- SAMPLE ASSIGNMENT COMMANDS
-- ================================

-- 6. Example commands to assign users to groups (uncomment and modify as needed)
/*
-- Assign manager to Sales Team
INSERT INTO public.user_groups (user_id, group_id)
SELECT p.id, g.id
FROM public.profiles p, public.groups g
WHERE p.email = 'user.manager@test.com'  -- Replace with actual manager email
  AND g.name = 'Sales Team'
ON CONFLICT DO NOTHING;

-- Assign an agent to Sales Team
INSERT INTO public.user_groups (user_id, group_id)
SELECT p.id, g.id
FROM public.profiles p, public.groups g
WHERE p.email = 'agent@example.com'  -- Replace with actual agent email
  AND g.name = 'Sales Team'
ON CONFLICT DO NOTHING;
*/

-- ================================
-- FINAL VERIFICATION
-- ================================

SELECT 'Group isolation setup complete!' as result;
SELECT 'Run this script again after assigning users to groups to verify isolation.' as next_step;