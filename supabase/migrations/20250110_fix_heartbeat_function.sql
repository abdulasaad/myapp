-- Fix the update_user_heartbeat function - resolve column ambiguity
DROP FUNCTION IF EXISTS update_user_heartbeat(UUID, TEXT);

CREATE OR REPLACE FUNCTION update_user_heartbeat(
  p_user_id UUID,
  p_status TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE profiles
  SET 
    last_heartbeat = NOW(),
    connection_status = p_status,
    updated_at = NOW()
  WHERE id = p_user_id;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION update_user_heartbeat TO authenticated;