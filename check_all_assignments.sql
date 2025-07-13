-- Check ALL touring task assignments for this agent
SELECT 
    tta.id,
    tta.touring_task_id,
    tta.agent_id,
    tta.status,
    tta.assigned_at,
    tt.title,
    au.email
FROM touring_task_assignments tta
JOIN touring_tasks tt ON tta.touring_task_id = tt.id
JOIN auth.users au ON tta.agent_id = au.id
WHERE au.email = 'user.agent2@test.com'
ORDER BY tta.assigned_at DESC;

-- Update ALL pending assignments to assigned
UPDATE touring_task_assignments 
SET status = 'assigned'
WHERE agent_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'
AND status = 'pending';

-- Also check if there are any with other statuses
SELECT DISTINCT status FROM touring_task_assignments 
WHERE agent_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1';