-- Fix Assignment Pending Workflow - Remove pending status requirement
-- Run these commands in sequence in your Supabase SQL editor

-- 1. Update all existing pending assignments to assigned status
UPDATE task_assignments 
SET status = 'assigned',
    started_at = COALESCE(started_at, NOW())
WHERE status = 'pending';

-- 2. Change the default status from 'pending' to 'assigned' for new assignments
ALTER TABLE task_assignments 
ALTER COLUMN status SET DEFAULT 'assigned';

-- 3. Update the auto-assignment triggers to create assignments with 'assigned' status

-- First, update the auto_assign_new_task_to_agents function
CREATE OR REPLACE FUNCTION auto_assign_new_task_to_agents()
RETURNS TRIGGER AS $$
BEGIN
  -- Insert a new task_assignment for every agent who is
  -- already assigned to the new task's parent campaign.
  -- Status is now 'assigned' by default, not 'pending'
  INSERT INTO public.task_assignments (task_id, agent_id, status, started_at)
  SELECT
    NEW.id, -- The ID of the task that was just created
    ca.agent_id,
    'assigned', -- Explicitly set to assigned instead of pending
    NOW() -- Set started_at to current time
  FROM
    public.campaign_agents ca
  WHERE
    ca.campaign_id = NEW.campaign_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Update the auto_assign_tasks_to_new_agent function
CREATE OR REPLACE FUNCTION auto_assign_tasks_to_new_agent()
RETURNS TRIGGER AS $$
BEGIN
  -- This is the core logic:
  -- Insert into the task_assignments table for the new agent (NEW.agent_id)
  -- by selecting all task IDs from the campaign (NEW.campaign_id)
  -- that do NOT already have an assignment for this agent.
  -- Status is now 'assigned' by default, not 'pending'
  INSERT INTO public.task_assignments (task_id, agent_id, status, started_at)
  SELECT
    t.id,          -- The ID of the task
    NEW.agent_id,  -- The ID of the agent who was just assigned to the campaign
    'assigned',    -- Explicitly set to assigned instead of pending
    NOW()          -- Set started_at to current time
  FROM
    public.tasks t
  WHERE
    t.campaign_id = NEW.campaign_id
  ON CONFLICT (task_id, agent_id) DO NOTHING; -- If an assignment already exists, do nothing.

  -- The function must return the new row for an AFTER trigger.
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Verify the changes
SELECT 'Updated assignments' as operation, COUNT(*) as count
FROM task_assignments 
WHERE status = 'assigned';

SELECT 'Remaining pending assignments' as operation, COUNT(*) as count
FROM task_assignments 
WHERE status = 'pending';

-- 6. Check the new default value
SELECT column_name, column_default
FROM information_schema.columns 
WHERE table_name = 'task_assignments' 
AND column_name = 'status';

-- 7. Test creating a new assignment to verify it gets 'assigned' status
-- (This is just a test query - replace with actual task_id and agent_id if needed)
/*
INSERT INTO task_assignments (task_id, agent_id) 
VALUES ('your-test-task-id', 'your-test-agent-id');

SELECT status, started_at 
FROM task_assignments 
WHERE task_id = 'your-test-task-id' AND agent_id = 'your-test-agent-id';
*/