UPDATE touring_task_assignments 
SET agent_id = (
    SELECT auth.users.id 
    FROM auth.users 
    WHERE auth.users.email = 'user.agent2@test.com'
)
WHERE agent_id = (
    SELECT profiles.id 
    FROM profiles 
    WHERE profiles.email = 'user.agent2@test.com'
);

SELECT 
    tta.id as assignment_id,
    tta.agent_id,
    au.email as auth_email,
    p.email as profile_email,
    tt.title,
    tt.campaign_id
FROM touring_task_assignments tta
JOIN touring_tasks tt ON tta.touring_task_id = tt.id
LEFT JOIN auth.users au ON au.id = tta.agent_id
LEFT JOIN profiles p ON p.id = tta.agent_id
WHERE tta.id = (SELECT id FROM touring_task_assignments ORDER BY assigned_at DESC LIMIT 1);