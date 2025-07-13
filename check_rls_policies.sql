-- Check Row Level Security policies that might be blocking access

-- 1. Check if RLS is enabled on key tables
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled,
    'RLS Status' as check_type
FROM pg_tables 
WHERE tablename IN ('tasks', 'task_assignments', 'campaign_agents', 'campaigns')
ORDER BY tablename;

-- 2. Check all RLS policies on task-related tables
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd as command_type,
    qual as policy_condition,
    'RLS Policies' as check_type
FROM pg_policies 
WHERE tablename IN ('tasks', 'task_assignments', 'campaign_agents', 'campaigns')
ORDER BY tablename, policyname;

-- 3. Check for any constraints on task_assignments that might enforce pending status
SELECT 
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type,
    cc.check_clause,
    'Table Constraints' as check_type
FROM information_schema.table_constraints tc
LEFT JOIN information_schema.check_constraints cc ON tc.constraint_name = cc.constraint_name
WHERE tc.table_name = 'task_assignments'
ORDER BY tc.constraint_type;

-- 4. Check for enum types that might restrict status values
SELECT 
    t.typname as enum_name,
    e.enumlabel as enum_value,
    'Enum Values' as check_type
FROM pg_type t 
JOIN pg_enum e ON t.oid = e.enumtypid 
WHERE t.typname LIKE '%status%' 
   OR t.typname LIKE '%assignment%'
ORDER BY t.typname, e.enumsortorder;

-- 5. Check the actual status values currently in use
SELECT 
    status,
    COUNT(*) as count,
    'Current Status Distribution' as check_type
FROM task_assignments 
GROUP BY status
ORDER BY count DESC;

-- 6. Find any functions that might be called by policies or triggers
SELECT 
    routine_name,
    routine_type,
    'Security Functions' as check_type
FROM information_schema.routines 
WHERE (routine_definition ILIKE '%task_assignment%' 
   OR routine_definition ILIKE '%auth.uid()%'
   OR routine_definition ILIKE '%current_user%')
   AND routine_type = 'FUNCTION'
ORDER BY routine_name;