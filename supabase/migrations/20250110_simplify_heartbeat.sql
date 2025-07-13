-- Simplify the heartbeat function to just update the timestamp
-- The status will be determined dynamically based on the timestamp

DROP FUNCTION IF EXISTS update_user_heartbeat(UUID, TEXT);

CREATE OR REPLACE FUNCTION update_user_heartbeat(
  p_user_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE profiles
  SET 
    last_heartbeat = NOW(),
    updated_at = NOW()
  WHERE id = p_user_id;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION update_user_heartbeat TO authenticated;