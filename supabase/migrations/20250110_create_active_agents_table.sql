-- Create active_agents table if it doesn't exist
CREATE TABLE IF NOT EXISTS active_agents (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  last_location POINT,
  last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  accuracy DOUBLE PRECISION,
  speed DOUBLE PRECISION,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Ensure one record per user
  UNIQUE(user_id)
);

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_active_agents_user_id ON active_agents(user_id);
CREATE INDEX IF NOT EXISTS idx_active_agents_last_seen ON active_agents(last_seen);

-- Enable RLS
ALTER TABLE active_agents ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can view active agents" ON active_agents
  FOR SELECT
  USING (true); -- Allow all authenticated users to read location data

CREATE POLICY "Users can update own location" ON active_agents
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Grant permissions
GRANT ALL ON active_agents TO authenticated;
GRANT ALL ON active_agents TO service_role;

-- Create function to insert/update location data
CREATE OR REPLACE FUNCTION insert_location_update(
  p_user_id UUID,
  p_location TEXT,
  p_accuracy DOUBLE PRECISION DEFAULT NULL,
  p_speed DOUBLE PRECISION DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO active_agents (user_id, last_location, last_seen, accuracy, speed)
  VALUES (p_user_id, p_location::POINT, NOW(), p_accuracy, p_speed)
  ON CONFLICT (user_id)
  DO UPDATE SET
    last_location = EXCLUDED.last_location,
    last_seen = EXCLUDED.last_seen,
    accuracy = EXCLUDED.accuracy,
    speed = EXCLUDED.speed,
    updated_at = NOW();
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION insert_location_update TO authenticated;

-- Comment on table
COMMENT ON TABLE active_agents IS 'Stores real-time location data for active agents';