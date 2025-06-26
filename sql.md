# SQL Scripts

## Check Submitted Form Data

Run these queries to see where the agent's submitted form data is stored:

```sql
-- 1. Check the task's custom_fields column (main storage)
SELECT 
    t.id,
    t.title,
    t.custom_fields,
    ta.status,
    ta.completed_at
FROM tasks t
JOIN task_assignments ta ON t.id = ta.task_id
WHERE t.id = 'c30b3693-9c3c-4493-a8b3-73170165b1fb';

-- 2. Check evidence table (backup/audit storage)
SELECT 
    e.id,
    e.title,
    e.file_url,
    e.mime_type,
    e.status,
    e.created_at
FROM evidence e
JOIN task_assignments ta ON e.task_assignment_id = ta.id
WHERE ta.task_id = 'c30b3693-9c3c-4493-a8b3-73170165b1fb'
ORDER BY e.created_at DESC;

-- 3. Check task assignment status
SELECT 
    ta.status,
    ta.completed_at,
    p.email as agent_email
FROM task_assignments ta
JOIN profiles p ON ta.agent_id = p.id
WHERE ta.task_id = 'c30b3693-9c3c-4493-a8b3-73170165b1fb';
```