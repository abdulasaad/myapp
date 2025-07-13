-- Check the current logged-in agent's information
SELECT 
    au.id as auth_user_id,
    au.email,
    p.id as profile_id,
    p.full_name,
    p.role
FROM auth.users au
LEFT JOIN profiles p ON au.id = p.id
WHERE au.email = 'user.agent2@test.com';

-- Check what touring task assignments exist for this agent
SELECT 
    tta.id,
    tta.agent_id,
    tta.status,
    tt.title as task_title,
    au.email as agent_email
FROM touring_task_assignments tta
JOIN touring_tasks tt ON tta.touring_task_id = tt.id
JOIN auth.users au ON tta.agent_id = au.id
WHERE au.email = 'user.agent2@test.com';