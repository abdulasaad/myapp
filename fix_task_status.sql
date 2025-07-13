-- Update the touring task assignment status from 'pending' to 'assigned'
UPDATE touring_task_assignments 
SET status = 'assigned'
WHERE agent_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'
AND status = 'pending';

-- Verify the update
SELECT 
    tta.id,
    tta.status,
    tt.title,
    au.email
FROM touring_task_assignments tta
JOIN touring_tasks tt ON tta.touring_task_id = tt.id
JOIN auth.users au ON tta.agent_id = au.id
WHERE au.email = 'user.agent2@test.com';