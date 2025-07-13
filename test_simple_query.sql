SELECT 
    tta.id,
    tta.touring_task_id,
    tta.agent_id,
    tta.status,
    tta.assigned_at
FROM touring_task_assignments tta
WHERE tta.agent_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'
AND tta.status = 'assigned';

SELECT constraint_name, constraint_type
FROM information_schema.table_constraints
WHERE table_name = 'touring_task_assignments'
AND constraint_type = 'FOREIGN KEY';