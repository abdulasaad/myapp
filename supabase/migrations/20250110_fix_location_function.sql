-- Fix the insert_location_update function - handle POINT data type correctly
DROP FUNCTION IF EXISTS insert_location_update(UUID, TEXT, DOUBLE PRECISION, DOUBLE PRECISION);

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
DECLARE
  location_point POINT;
BEGIN
  -- Parse the POINT string correctly
  -- Expected format: "POINT(longitude latitude)"
  BEGIN
    location_point := p_location::POINT;
  EXCEPTION
    WHEN OTHERS THEN
      -- If parsing fails, log and return
      RAISE WARNING 'Failed to parse location point: %', p_location;
      RETURN;
  END;

  INSERT INTO active_agents (user_id, last_location, last_seen, accuracy, speed)
  VALUES (p_user_id, location_point, NOW(), p_accuracy, p_speed)
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

-- Alternative function that takes coordinates directly
CREATE OR REPLACE FUNCTION insert_location_coordinates(
  p_user_id UUID,
  p_longitude DOUBLE PRECISION,
  p_latitude DOUBLE PRECISION,
  p_accuracy DOUBLE PRECISION DEFAULT NULL,
  p_speed DOUBLE PRECISION DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO active_agents (user_id, last_location, last_seen, accuracy, speed)
  VALUES (p_user_id, POINT(p_longitude, p_latitude), NOW(), p_accuracy, p_speed)
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
GRANT EXECUTE ON FUNCTION insert_location_coordinates TO authenticated;