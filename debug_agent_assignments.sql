SELECT 
    tta.*,
    tt.title,
    tt.campaign_id
FROM touring_task_assignments tta
JOIN touring_tasks tt ON tta.touring_task_id = tt.id
WHERE tta.agent_id = (SELECT id FROM profiles WHERE email = 'user.agent2@test.com');

SELECT 
    p.id as agent_id,
    p.email,
    auth.users.id as auth_user_id
FROM profiles p
LEFT JOIN auth.users ON auth.users.email = p.email
WHERE p.email = 'user.agent2@test.com';