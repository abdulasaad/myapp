-- Add user status tracking fields to profiles table
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS last_heartbeat TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS connection_status TEXT DEFAULT 'offline' CHECK (connection_status IN ('active', 'away', 'offline'));

-- Create index for efficient status queries
CREATE INDEX IF NOT EXISTS idx_profiles_connection_status ON profiles(connection_status);
CREATE INDEX IF NOT EXISTS idx_profiles_last_heartbeat ON profiles(last_heartbeat);

-- Create function to update user heartbeat
CREATE OR REPLACE FUNCTION update_user_heartbeat(
  user_id UUID,
  status TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE profiles
  SET 
    last_heartbeat = NOW(),
    connection_status = status,
    updated_at = NOW()
  WHERE id = user_id;
END;
$$;

-- Create function to get users by status (with fallback if active_agents doesn't exist)
CREATE OR REPLACE FUNCTION get_users_by_status(
  status_filter TEXT DEFAULT NULL,
  group_id_filter UUID DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  username TEXT,
  role TEXT,
  connection_status TEXT,
  last_heartbeat TIMESTAMP WITH TIME ZONE,
  last_location TEXT,
  last_seen TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check if active_agents table exists
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'active_agents') THEN
    RETURN QUERY
    SELECT 
      p.id,
      p.full_name,
      p.username,
      p.role,
      p.connection_status,
      p.last_heartbeat,
      aa.last_location::TEXT,
      aa.last_seen
    FROM profiles p
    LEFT JOIN active_agents aa ON aa.user_id = p.id
    LEFT JOIN user_groups ug ON ug.user_id = p.id
    WHERE 
      (status_filter IS NULL OR p.connection_status = status_filter)
      AND (group_id_filter IS NULL OR ug.group_id = group_id_filter)
      AND p.status = 'active'
    ORDER BY 
      CASE p.connection_status 
        WHEN 'active' THEN 1
        WHEN 'away' THEN 2
        WHEN 'offline' THEN 3
        ELSE 4
      END,
      p.last_heartbeat DESC NULLS LAST;
  ELSE
    -- Fallback when active_agents table doesn't exist
    RETURN QUERY
    SELECT 
      p.id,
      p.full_name,
      p.username,
      p.role,
      p.connection_status,
      p.last_heartbeat,
      NULL::TEXT as last_location,
      NULL::TIMESTAMP WITH TIME ZONE as last_seen
    FROM profiles p
    LEFT JOIN user_groups ug ON ug.user_id = p.id
    WHERE 
      (status_filter IS NULL OR p.connection_status = status_filter)
      AND (group_id_filter IS NULL OR ug.group_id = group_id_filter)
      AND p.status = 'active'
    ORDER BY 
      CASE p.connection_status 
        WHEN 'active' THEN 1
        WHEN 'away' THEN 2
        WHEN 'offline' THEN 3
        ELSE 4
      END,
      p.last_heartbeat DESC NULLS LAST;
  END IF;
END;
$$;

-- Create a view for easy status monitoring (with fallback)
CREATE OR REPLACE VIEW user_status_view AS
SELECT 
  p.id,
  p.full_name,
  p.username,
  p.role,
  p.connection_status,
  p.last_heartbeat,
  CASE 
    WHEN p.connection_status = 'active' THEN 'Online'
    WHEN p.connection_status = 'away' THEN 'Away'
    ELSE 'Offline'
  END as status_display,
  CASE 
    WHEN p.last_heartbeat IS NULL THEN NULL
    WHEN NOW() - p.last_heartbeat < INTERVAL '1 minute' THEN 'Just now'
    WHEN NOW() - p.last_heartbeat < INTERVAL '1 hour' THEN 
      CONCAT(EXTRACT(MINUTE FROM NOW() - p.last_heartbeat)::INT, ' minutes ago')
    WHEN NOW() - p.last_heartbeat < INTERVAL '24 hours' THEN 
      CONCAT(EXTRACT(HOUR FROM NOW() - p.last_heartbeat)::INT, ' hours ago')
    ELSE 
      CONCAT(EXTRACT(DAY FROM NOW() - p.last_heartbeat)::INT, ' days ago')
  END as last_seen_text,
  CASE 
    WHEN EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'active_agents') 
    THEN aa.last_location
    ELSE NULL
  END as last_location,
  CASE 
    WHEN EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'active_agents') 
    THEN aa.last_seen
    ELSE NULL
  END as location_last_seen
FROM profiles p
LEFT JOIN (
  SELECT * FROM active_agents 
  WHERE EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'active_agents')
) aa ON aa.user_id = p.id
WHERE p.status = 'active';

-- Grant appropriate permissions
GRANT EXECUTE ON FUNCTION update_user_heartbeat TO authenticated;
GRANT EXECUTE ON FUNCTION get_users_by_status TO authenticated;
GRANT SELECT ON user_status_view TO authenticated;

-- Add RLS policies for the new columns
-- Users can update their own heartbeat
CREATE POLICY "Users can update own heartbeat" ON profiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Comment on new columns
COMMENT ON COLUMN profiles.last_heartbeat IS 'Last time the user sent a heartbeat signal';
COMMENT ON COLUMN profiles.connection_status IS 'Current connection status: active, away, or offline';