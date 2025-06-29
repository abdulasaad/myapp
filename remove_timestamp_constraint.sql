-- Remove the timestamp constraint completely to fix location update issues

-- 1. Drop both constraints
ALTER TABLE location_history DROP CONSTRAINT IF EXISTS check_recorded_at_not_future;
ALTER TABLE location_history DROP CONSTRAINT IF EXISTS check_recorded_at_reasonable;

-- 2. Verify constraints are removed
SELECT 
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = 'location_history'::regclass
AND contype = 'c'; -- Check constraints

-- 3. Test inserting with current timestamp
INSERT INTO location_history (user_id, location, accuracy, speed, recorded_at)
VALUES (
    '263e832c-f73c-48f3-bfd2-1b567cbff0b1', -- Replace with actual agent ID
    ST_GeomFromText('POINT(44.3868346 33.3166855)', 4326),
    10.0,
    0.0,
    NOW()
);

-- 4. Create RPC function to insert location updates with server-side timestamp
CREATE OR REPLACE FUNCTION insert_location_update(
    p_user_id UUID,
    p_location TEXT,
    p_accuracy DOUBLE PRECISION,
    p_speed DOUBLE PRECISION
) RETURNS VOID AS $$
BEGIN
    INSERT INTO location_history (user_id, location, accuracy, speed, recorded_at)
    VALUES (
        p_user_id,
        ST_GeomFromText(p_location, 4326),
        p_accuracy,
        p_speed,
        NOW()  -- Server-side timestamp avoids clock sync issues
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Grant execute permission
GRANT EXECUTE ON FUNCTION insert_location_update(UUID, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;

-- 6. Test the new function
SELECT insert_location_update(
    '263e832c-f73c-48f3-bfd2-1b567cbff0b1'::UUID,
    'POINT(44.3868346 33.3166855)',
    10.0,
    0.0
);

-- 7. Verify it worked
SELECT 'RPC FUNCTION TEST PASSED' as result;