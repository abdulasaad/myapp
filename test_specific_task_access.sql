-- Test specific task access scenario
-- Replace the task_id and agent_id with actual values from your app

-- First, get the current user and a task they're trying to access
-- You'll need to replace these with actual IDs from your app
SET @current_user_id = (SELECT id FROM profiles WHERE role = 'agent' LIMIT 1);
SET @test_task_id = (SELECT id FROM tasks LIMIT 1);

-- Show the current user info
SELECT 
    id,
    full_name,
    role,
    'Current test user' as note
FROM profiles 
WHERE id = @current_user_id;

-- Show the task info
SELECT 
    id,
    title,
    campaign_id,
    created_by,
    'Test task' as note
FROM tasks 
WHERE id = @test_task_id;

-- Check if there's a campaign assignment
SELECT 
    ca.campaign_id,
    ca.agent_id,
    c.title as campaign_title,
    'Campaign assignment check' as note
FROM campaign_agents ca
LEFT JOIN campaigns c ON ca.campaign_id = c.id
WHERE ca.agent_id = @current_user_id
  AND ca.campaign_id = (SELECT campaign_id FROM tasks WHERE id = @test_task_id);

-- Check if there's a direct task assignment
SELECT 
    ta.id,
    ta.task_id,
    ta.agent_id,
    ta.status,
    ta.created_at,
    'Direct task assignment check' as note
FROM task_assignments ta
WHERE ta.task_id = @test_task_id
  AND ta.agent_id = @current_user_id;

-- Alternative version without variables (for databases that don't support them)
-- Just run this and replace the IDs manually:

-- Get available agents
SELECT 
    id,
    full_name,
    role,
    'Available agents' as note
FROM profiles 
WHERE role = 'agent'
ORDER BY created_at DESC
LIMIT 5;

-- Get available tasks  
SELECT 
    id,
    title,
    campaign_id,
    'Available tasks' as note
FROM tasks 
ORDER BY created_at DESC
LIMIT 5;

-- Check what happens when we simulate the Flutter app's query
-- Replace 'your-task-id' and 'your-agent-id' with actual values
/*
-- Campaign check simulation:
SELECT campaign_id FROM tasks WHERE id = 'your-task-id';

-- Campaign assignment check:
SELECT campaign_id 
FROM campaign_agents 
WHERE campaign_id = 'campaign-id-from-above' 
  AND agent_id = 'your-agent-id';

-- Task assignment check:
SELECT status 
FROM task_assignments 
WHERE task_id = 'your-task-id' 
  AND agent_id = 'your-agent-id';
*/