-- Complete fix for earnings system
-- Run this in your Supabase SQL Editor

-- 1. Create function to auto-add agents to campaign_agents when they complete tasks
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

-- 2. Create trigger to auto-add agents to campaigns
DROP TRIGGER IF EXISTS ensure_agent_in_campaign_trigger ON task_assignments;
CREATE TRIGGER ensure_agent_in_campaign_trigger
    AFTER UPDATE ON task_assignments
    FOR EACH ROW
    EXECUTE FUNCTION ensure_agent_in_campaign();

-- 3. Backfill missing campaign agents for completed tasks
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

-- 4. Also handle touring tasks
CREATE OR REPLACE FUNCTION ensure_agent_in_campaign_touring()
RETURNS TRIGGER AS $$
BEGIN
    -- Only process completed tasks
    IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
        -- Get campaign ID from the touring task
        DECLARE
            task_campaign_id UUID;
        BEGIN
            SELECT tt.campaign_id INTO task_campaign_id
            FROM touring_tasks tt
            WHERE tt.id = NEW.touring_task_id;
            
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

-- 5. Create trigger for touring tasks
DROP TRIGGER IF EXISTS ensure_agent_in_campaign_touring_trigger ON touring_task_assignments;
CREATE TRIGGER ensure_agent_in_campaign_touring_trigger
    AFTER UPDATE ON touring_task_assignments
    FOR EACH ROW
    EXECUTE FUNCTION ensure_agent_in_campaign_touring();

-- 6. Backfill missing campaign agents for completed touring tasks
INSERT INTO campaign_agents (campaign_id, agent_id, assigned_at)
SELECT DISTINCT tt.campaign_id, tta.agent_id, tta.completed_at
FROM touring_task_assignments tta
JOIN touring_tasks tt ON tta.touring_task_id = tt.id
WHERE tta.status = 'completed'
AND tt.campaign_id IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM campaign_agents ca
    WHERE ca.campaign_id = tt.campaign_id
    AND ca.agent_id = tta.agent_id
)
ON CONFLICT (campaign_id, agent_id) DO NOTHING;

-- 7. Grant permissions
GRANT EXECUTE ON FUNCTION ensure_agent_in_campaign TO authenticated;
GRANT EXECUTE ON FUNCTION ensure_agent_in_campaign_touring TO authenticated;

-- 8. Test query to verify the fix worked
-- Replace 'test2' with your actual task name
SELECT 
    t.title as task_name,
    ta.agent_id,
    p.full_name as agent_name,
    t.campaign_id,
    c.name as campaign_name,
    ca.agent_id as in_campaign_agents
FROM task_assignments ta
JOIN tasks t ON ta.task_id = t.id
JOIN profiles p ON ta.agent_id = p.id
JOIN campaigns c ON t.campaign_id = c.id
LEFT JOIN campaign_agents ca ON (ca.campaign_id = t.campaign_id AND ca.agent_id = ta.agent_id)
WHERE ta.status = 'completed'
AND t.title = 'test2';