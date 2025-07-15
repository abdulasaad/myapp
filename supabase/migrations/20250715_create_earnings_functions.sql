-- Create earnings calculation RPC functions
-- Migration: 20250715_create_earnings_functions.sql

-- Function to get agent earnings for a specific campaign
CREATE OR REPLACE FUNCTION get_agent_earnings_for_campaign(
    p_agent_id UUID,
    p_campaign_id UUID
) RETURNS JSON AS $$
DECLARE
    total_earned INTEGER := 0;
    total_paid INTEGER := 0;
    outstanding_balance INTEGER := 0;
    task_points INTEGER := 0;
    touring_task_points INTEGER := 0;
    daily_participation_points INTEGER := 0;
BEGIN
    -- Calculate total earnings from regular campaign tasks
    SELECT COALESCE(SUM(t.points), 0) INTO task_points
    FROM task_assignments ta
    JOIN tasks t ON ta.task_id = t.id
    WHERE ta.agent_id = p_agent_id
    AND t.campaign_id = p_campaign_id
    AND ta.status = 'completed';
    
    -- Calculate total earnings from touring tasks
    SELECT COALESCE(SUM(tt.points), 0) INTO touring_task_points
    FROM touring_task_assignments tta
    JOIN touring_tasks tt ON tta.touring_task_id = tt.id
    WHERE tta.agent_id = p_agent_id
    AND tt.campaign_id = p_campaign_id
    AND tta.status = 'completed';
    
    -- Calculate total earnings from daily participation
    SELECT COALESCE(SUM(daily_points_earned), 0) INTO daily_participation_points
    FROM campaign_daily_participation
    WHERE agent_id = p_agent_id
    AND campaign_id = p_campaign_id;
    
    -- Total earned is sum of all sources
    total_earned := task_points + touring_task_points + daily_participation_points;
    
    -- Calculate total paid for this campaign
    SELECT COALESCE(SUM(amount), 0) INTO total_paid
    FROM payments
    WHERE agent_id = p_agent_id
    AND campaign_id = p_campaign_id;
    
    outstanding_balance := total_earned - total_paid;
    
    RETURN json_build_object(
        'total_earned', total_earned,
        'total_paid', total_paid,
        'outstanding_balance', outstanding_balance,
        'task_points', task_points,
        'touring_task_points', touring_task_points,
        'daily_participation_points', daily_participation_points
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get overall agent earnings across all campaigns
CREATE OR REPLACE FUNCTION get_agent_overall_earnings(
    p_agent_id UUID
) RETURNS JSON AS $$
DECLARE
    total_earned INTEGER := 0;
    total_paid INTEGER := 0;
    outstanding_balance INTEGER := 0;
    campaign_task_points INTEGER := 0;
    standalone_task_points INTEGER := 0;
    touring_task_points INTEGER := 0;
    daily_participation_points INTEGER := 0;
BEGIN
    -- Calculate earnings from campaign tasks
    SELECT COALESCE(SUM(t.points), 0) INTO campaign_task_points
    FROM task_assignments ta
    JOIN tasks t ON ta.task_id = t.id
    WHERE ta.agent_id = p_agent_id
    AND t.campaign_id IS NOT NULL
    AND ta.status = 'completed';
    
    -- Calculate earnings from standalone tasks
    SELECT COALESCE(SUM(t.points), 0) INTO standalone_task_points
    FROM task_assignments ta
    JOIN tasks t ON ta.task_id = t.id
    WHERE ta.agent_id = p_agent_id
    AND t.campaign_id IS NULL
    AND ta.status = 'completed';
    
    -- Calculate earnings from touring tasks
    SELECT COALESCE(SUM(tt.points), 0) INTO touring_task_points
    FROM touring_task_assignments tta
    JOIN touring_tasks tt ON tta.touring_task_id = tt.id
    WHERE tta.agent_id = p_agent_id
    AND tta.status = 'completed';
    
    -- Calculate earnings from daily participation
    SELECT COALESCE(SUM(daily_points_earned), 0) INTO daily_participation_points
    FROM campaign_daily_participation
    WHERE agent_id = p_agent_id;
    
    -- Total earned is sum of all sources
    total_earned := campaign_task_points + standalone_task_points + touring_task_points + daily_participation_points;
    
    -- Calculate total paid across all campaigns
    SELECT COALESCE(SUM(amount), 0) INTO total_paid
    FROM payments
    WHERE agent_id = p_agent_id;
    
    outstanding_balance := total_earned - total_paid;
    
    RETURN json_build_object(
        'total_earned', total_earned,
        'total_paid', total_paid,
        'outstanding_balance', outstanding_balance,
        'campaign_task_points', campaign_task_points,
        'standalone_task_points', standalone_task_points,
        'touring_task_points', touring_task_points,
        'daily_participation_points', daily_participation_points
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update daily participation and calculate points
CREATE OR REPLACE FUNCTION update_daily_participation(
    p_campaign_id UUID,
    p_agent_id UUID,
    p_participation_date DATE,
    p_hours_worked DECIMAL DEFAULT 0,
    p_tasks_completed INTEGER DEFAULT 0,
    p_touring_tasks_completed INTEGER DEFAULT 0
) RETURNS JSON AS $$
DECLARE
    daily_points INTEGER := 0;
    campaign_daily_rate INTEGER := 0;
    result JSON;
BEGIN
    -- Get campaign daily rate (you can add this field to campaigns table)
    -- For now, let's assume 10 points per hour worked + 5 points per task
    daily_points := (p_hours_worked * 10)::INTEGER + (p_tasks_completed * 5) + (p_touring_tasks_completed * 10);
    
    -- Insert or update daily participation
    INSERT INTO campaign_daily_participation (
        campaign_id,
        agent_id,
        participation_date,
        hours_worked,
        tasks_completed,
        touring_tasks_completed,
        daily_points_earned
    ) VALUES (
        p_campaign_id,
        p_agent_id,
        p_participation_date,
        p_hours_worked,
        p_tasks_completed,
        p_touring_tasks_completed,
        daily_points
    )
    ON CONFLICT (campaign_id, agent_id, participation_date)
    DO UPDATE SET
        hours_worked = EXCLUDED.hours_worked,
        tasks_completed = EXCLUDED.tasks_completed,
        touring_tasks_completed = EXCLUDED.touring_tasks_completed,
        daily_points_earned = EXCLUDED.daily_points_earned,
        updated_at = NOW();
    
    -- Return the result
    SELECT json_build_object(
        'campaign_id', campaign_id,
        'agent_id', agent_id,
        'participation_date', participation_date,
        'hours_worked', hours_worked,
        'tasks_completed', tasks_completed,
        'touring_tasks_completed', touring_tasks_completed,
        'daily_points_earned', daily_points_earned
    ) INTO result
    FROM campaign_daily_participation
    WHERE campaign_id = p_campaign_id
    AND agent_id = p_agent_id
    AND participation_date = p_participation_date;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to automatically update daily participation based on task completions
CREATE OR REPLACE FUNCTION auto_update_daily_participation()
RETURNS TRIGGER AS $$
DECLARE
    task_campaign_id UUID;
    completion_date DATE;
BEGIN
    -- Only process completed tasks
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
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

-- Create triggers to automatically update daily participation
CREATE TRIGGER auto_update_daily_participation_task_assignments
    AFTER UPDATE ON task_assignments
    FOR EACH ROW
    EXECUTE FUNCTION auto_update_daily_participation();

CREATE TRIGGER auto_update_daily_participation_touring_task_assignments
    AFTER UPDATE ON touring_task_assignments
    FOR EACH ROW
    EXECUTE FUNCTION auto_update_daily_participation();

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION get_agent_earnings_for_campaign TO authenticated;
GRANT EXECUTE ON FUNCTION get_agent_overall_earnings TO authenticated;
GRANT EXECUTE ON FUNCTION update_daily_participation TO authenticated;