# Fix Earnings System - SQL Commands

The issue is likely that agents are not being properly added to the `campaign_agents` table when they complete tasks. Run these SQL commands to fix the earnings system:

## 1. Check Current State
```sql
-- Check if agent is in campaign_agents table
SELECT ca.*, p.full_name as agent_name, c.name as campaign_name
FROM campaign_agents ca
JOIN profiles p ON ca.agent_id = p.id
JOIN campaigns c ON ca.campaign_id = c.id;

-- Check completed tasks that might not be counted
SELECT ta.*, p.full_name as agent_name, t.title, t.points, c.name as campaign_name
FROM task_assignments ta
JOIN profiles p ON ta.agent_id = p.id
JOIN tasks t ON ta.task_id = t.id
LEFT JOIN campaigns c ON t.campaign_id = c.id
WHERE ta.status = 'completed'
AND t.campaign_id IS NOT NULL;
```

## 2. Create Function to Auto-Add Agents to Campaign
```sql
-- Function to ensure agent is added to campaign_agents when completing campaign tasks
CREATE OR REPLACE FUNCTION ensure_agent_in_campaign()
RETURNS TRIGGER AS $$
BEGIN
    -- Only process completed tasks
    IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
        -- Get campaign ID from the task
        DECLARE
            task_campaign_id UUID;
        BEGIN
            SELECT t.campaign_id INTO task_campaign_id
            FROM tasks t
            WHERE t.id = NEW.task_id;
            
            -- If this is a campaign task, ensure agent is in campaign_agents
            IF task_campaign_id IS NOT NULL THEN
                INSERT INTO campaign_agents (campaign_id, agent_id, assigned_at)
                VALUES (task_campaign_id, NEW.agent_id, NEW.completed_at)
                ON CONFLICT (campaign_id, agent_id) DO NOTHING;
            END IF;
        END;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to auto-add agents to campaigns
DROP TRIGGER IF EXISTS ensure_agent_in_campaign_trigger ON task_assignments;
CREATE TRIGGER ensure_agent_in_campaign_trigger
    AFTER UPDATE ON task_assignments
    FOR EACH ROW
    EXECUTE FUNCTION ensure_agent_in_campaign();
```

## 3. Backfill Missing Campaign Agents
```sql
-- Add all agents who have completed campaign tasks to campaign_agents
INSERT INTO campaign_agents (campaign_id, agent_id, assigned_at)
SELECT DISTINCT t.campaign_id, ta.agent_id, ta.completed_at
FROM task_assignments ta
JOIN tasks t ON ta.task_id = t.id
WHERE ta.status = 'completed'
AND t.campaign_id IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM campaign_agents ca
    WHERE ca.campaign_id = t.campaign_id
    AND ca.agent_id = ta.agent_id
)
ON CONFLICT (campaign_id, agent_id) DO NOTHING;
```

## 4. Update Existing Triggers to Work with New Structure
```sql
-- Update the daily participation trigger to handle the new flow
CREATE OR REPLACE FUNCTION auto_update_daily_participation()
RETURNS TRIGGER AS $$
DECLARE
    task_campaign_id UUID;
    completion_date DATE;
BEGIN
    -- Only process completed tasks
    IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
        -- Get campaign ID and completion date
        IF TG_TABLE_NAME = 'task_assignments' THEN
            SELECT t.campaign_id INTO task_campaign_id
            FROM tasks t
            WHERE t.id = NEW.task_id;
            
            completion_date := NEW.completed_at::DATE;
        ELSIF TG_TABLE_NAME = 'touring_task_assignments' THEN
            SELECT tt.campaign_id INTO task_campaign_id
            FROM touring_tasks tt
            WHERE tt.id = NEW.touring_task_id;
            
            completion_date := NEW.completed_at::DATE;
        END IF;
        
        -- Update daily participation if this is a campaign task
        IF task_campaign_id IS NOT NULL THEN
            -- Get current participation data
            DECLARE
                current_tasks INTEGER := 0;
                current_touring_tasks INTEGER := 0;
            BEGIN
                SELECT 
                    COALESCE(tasks_completed, 0),
                    COALESCE(touring_tasks_completed, 0)
                INTO current_tasks, current_touring_tasks
                FROM campaign_daily_participation
                WHERE campaign_id = task_campaign_id
                AND agent_id = NEW.agent_id
                AND participation_date = completion_date;
                
                -- Increment the appropriate counter
                IF TG_TABLE_NAME = 'task_assignments' THEN
                    current_tasks := current_tasks + 1;
                ELSIF TG_TABLE_NAME = 'touring_task_assignments' THEN
                    current_touring_tasks := current_touring_tasks + 1;
                END IF;
                
                -- Update daily participation
                PERFORM update_daily_participation(
                    task_campaign_id,
                    NEW.agent_id,
                    completion_date,
                    0, -- hours_worked (can be updated separately)
                    current_tasks,
                    current_touring_tasks
                );
            END;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the triggers
DROP TRIGGER IF EXISTS auto_update_daily_participation_task_assignments ON task_assignments;
CREATE TRIGGER auto_update_daily_participation_task_assignments
    AFTER UPDATE ON task_assignments
    FOR EACH ROW
    EXECUTE FUNCTION auto_update_daily_participation();

DROP TRIGGER IF EXISTS auto_update_daily_participation_touring_task_assignments ON touring_task_assignments;
CREATE TRIGGER auto_update_daily_participation_touring_task_assignments
    AFTER UPDATE ON touring_task_assignments
    FOR EACH ROW
    EXECUTE FUNCTION auto_update_daily_participation();
```

## 5. Test the Fix
```sql
-- Test earnings calculation after running the above
SELECT * FROM get_agent_overall_earnings('AGENT_ID_HERE');

-- Check if agent is now in campaign_agents
SELECT ca.*, p.full_name as agent_name, c.name as campaign_name
FROM campaign_agents ca
JOIN profiles p ON ca.agent_id = p.id
JOIN campaigns c ON ca.campaign_id = c.id;

-- Check daily participation
SELECT cdp.*, p.full_name as agent_name, c.name as campaign_name
FROM campaign_daily_participation cdp
JOIN profiles p ON cdp.agent_id = p.id
JOIN campaigns c ON cdp.campaign_id = c.id
ORDER BY cdp.participation_date DESC;
```

## 6. Grant Permissions
```sql
GRANT EXECUTE ON FUNCTION ensure_agent_in_campaign TO authenticated;
```

Run these commands in order, and the earnings system should start working properly for completed tasks!