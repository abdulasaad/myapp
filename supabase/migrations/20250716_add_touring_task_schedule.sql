-- Add schedule fields to touring_tasks table
ALTER TABLE touring_tasks ADD COLUMN IF NOT EXISTS use_schedule BOOLEAN DEFAULT FALSE;
ALTER TABLE touring_tasks ADD COLUMN IF NOT EXISTS daily_start_time TEXT;
ALTER TABLE touring_tasks ADD COLUMN IF NOT EXISTS daily_end_time TEXT;

-- Update existing records to use default schedule behavior
UPDATE touring_tasks 
SET use_schedule = FALSE
WHERE use_schedule IS NULL;

-- Add comments for new columns
COMMENT ON COLUMN touring_tasks.use_schedule IS 'Whether this task uses a daily schedule or is available all day';
COMMENT ON COLUMN touring_tasks.daily_start_time IS 'Start time in HH:MM format when task becomes available each day';
COMMENT ON COLUMN touring_tasks.daily_end_time IS 'End time in HH:MM format when task becomes unavailable each day';

-- Update the create_touring_task RPC function to handle schedule parameters
CREATE OR REPLACE FUNCTION create_touring_task(
    p_campaign_id UUID,
    p_geofence_id UUID,
    p_title TEXT,
    p_description TEXT DEFAULT NULL,
    p_required_time_minutes INTEGER DEFAULT 30,
    p_movement_timeout_seconds INTEGER DEFAULT 60,
    p_min_movement_threshold NUMERIC DEFAULT 5.0,
    p_points INTEGER DEFAULT 10,
    p_use_schedule BOOLEAN DEFAULT FALSE,
    p_daily_start_time TEXT DEFAULT NULL,
    p_daily_end_time TEXT DEFAULT NULL
) RETURNS touring_tasks AS $$
DECLARE
    new_task touring_tasks;
BEGIN
    -- Insert the new touring task
    INSERT INTO touring_tasks (
        campaign_id,
        geofence_id,
        title,
        description,
        required_time_minutes,
        movement_timeout_seconds,
        min_movement_threshold,
        points,
        use_schedule,
        daily_start_time,
        daily_end_time,
        status,
        created_at,
        created_by
    ) VALUES (
        p_campaign_id,
        p_geofence_id,
        p_title,
        p_description,
        p_required_time_minutes,
        p_movement_timeout_seconds,
        p_min_movement_threshold,
        p_points,
        p_use_schedule,
        p_daily_start_time,
        p_daily_end_time,
        'active',
        NOW(),
        auth.uid()
    ) RETURNING * INTO new_task;
    
    RETURN new_task;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add helper function to check if touring task is available at a specific time
CREATE OR REPLACE FUNCTION is_touring_task_available_at_time(
    task_id UUID,
    check_time TIMESTAMP WITH TIME ZONE DEFAULT NOW()
) RETURNS BOOLEAN AS $$
DECLARE
    task_record touring_tasks;
    current_time_of_day TIME;
    start_time TIME;
    end_time TIME;
BEGIN
    -- Get the task record
    SELECT * INTO task_record FROM touring_tasks WHERE id = task_id;
    
    -- If task doesn't exist, return false
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    -- If task doesn't use schedule, it's always available
    IF NOT task_record.use_schedule OR task_record.daily_start_time IS NULL OR task_record.daily_end_time IS NULL THEN
        RETURN TRUE;
    END IF;
    
    -- Get current time of day
    current_time_of_day := (check_time AT TIME ZONE 'UTC')::TIME;
    
    -- Parse start and end times
    start_time := task_record.daily_start_time::TIME;
    end_time := task_record.daily_end_time::TIME;
    
    -- Check if current time is within the range
    IF start_time <= end_time THEN
        -- Same day range
        RETURN current_time_of_day >= start_time AND current_time_of_day <= end_time;
    ELSE
        -- Crosses midnight
        RETURN current_time_of_day >= start_time OR current_time_of_day <= end_time;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION create_touring_task TO authenticated;
GRANT EXECUTE ON FUNCTION is_touring_task_available_at_time TO authenticated;