-- Fix timestamp constraint and check background tracking issues

-- 1. Drop the overly strict constraint
ALTER TABLE location_history DROP CONSTRAINT IF EXISTS check_recorded_at_not_future;

-- 2. Add a more lenient constraint (allow up to 1 hour in future for clock sync issues)
ALTER TABLE location_history 
ADD CONSTRAINT check_recorded_at_reasonable 
CHECK (recorded_at >= NOW() - INTERVAL '24 hours' AND recorded_at <= NOW() + INTERVAL '1 hour');

-- 3. Test inserting a location update manually
INSERT INTO location_history (user_id, location, accuracy, speed, recorded_at)
VALUES (
    '263e832c-f73c-48f3-bfd2-1b567cbff0b1', -- Replace with actual agent ID
    ST_GeomFromText('POINT(44.3868346 33.3166855)', 4326),
    10.0,
    0.0,
    NOW()
);

-- 4. Check if the insert worked
SELECT 
    recorded_at,
    ST_AsText(location::geometry) as location_text,
    accuracy
FROM location_history
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'
ORDER BY recorded_at DESC
LIMIT 3;