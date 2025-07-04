-- Add timezone support for dynamic timezone based on manager location
-- This will allow each manager to set their country/timezone and all users under them will use the same timezone

-- Add timezone column to profiles table
ALTER TABLE profiles 
ADD COLUMN timezone TEXT DEFAULT 'Asia/Kuwait';

-- Add constraint to ensure valid timezone values
-- Common Middle East/GCC timezones
ALTER TABLE profiles 
ADD CONSTRAINT valid_timezone CHECK (
    timezone IN (
        'Asia/Kuwait',      -- Kuwait (UTC+3)
        'Asia/Riyadh',      -- Saudi Arabia (UTC+3)  
        'Asia/Qatar',       -- Qatar (UTC+3)
        'Asia/Dubai',       -- UAE (UTC+4)
        'Asia/Bahrain',     -- Bahrain (UTC+3)
        'Asia/Muscat',      -- Oman (UTC+4)
        'Europe/London',    -- UK (UTC+0/+1)
        'America/New_York', -- US East (UTC-5/-4)
        'Asia/Dhaka',       -- Bangladesh (UTC+6)
        'Asia/Karachi',     -- Pakistan (UTC+5)
        'Africa/Cairo',     -- Egypt (UTC+2/+3)
        'Asia/Baghdad'      -- Iraq (UTC+3)
    )
);

-- Set default timezone for existing manager/admin accounts
UPDATE profiles 
SET timezone = 'Asia/Kuwait' 
WHERE role IN ('manager', 'admin');

-- Create function to get manager timezone for agents
CREATE OR REPLACE FUNCTION get_manager_timezone(agent_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    manager_tz TEXT;
BEGIN
    -- Get the timezone of the manager who manages this agent
    SELECT p_manager.timezone INTO manager_tz
    FROM profiles p_agent
    JOIN user_groups ug ON ug.user_id = p_agent.id
    JOIN groups g ON g.id = ug.group_id
    JOIN profiles p_manager ON p_manager.id = g.manager_id
    WHERE p_agent.id = agent_id
    AND p_agent.role = 'agent'
    LIMIT 1;
    
    -- If no manager found, return default Kuwait timezone
    RETURN COALESCE(manager_tz, 'Asia/Kuwait');
END;
$$;

-- Create function to get user's effective timezone
CREATE OR REPLACE FUNCTION get_user_timezone(user_id UUID)
RETURNS TEXT  
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_role TEXT;
    user_tz TEXT;
BEGIN
    -- Get user role and timezone
    SELECT role, timezone INTO user_role, user_tz
    FROM profiles 
    WHERE id = user_id;
    
    -- If manager/admin, return their own timezone
    IF user_role IN ('manager', 'admin') THEN
        RETURN COALESCE(user_tz, 'Asia/Kuwait');
    END IF;
    
    -- If agent, return manager's timezone
    IF user_role = 'agent' THEN
        RETURN get_manager_timezone(user_id);
    END IF;
    
    -- Default fallback
    RETURN 'Asia/Kuwait';
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_manager_timezone(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_timezone(UUID) TO authenticated;