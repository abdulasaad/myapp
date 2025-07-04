-- Cleanup stale location data from logged-out agents
-- This will remove old location history entries that are causing the issue

-- First, let's check what we have
SELECT 
    lh.user_id,
    p.full_name,
    COUNT(*) as location_count,
    MAX(lh.recorded_at) as last_location,
    MIN(lh.recorded_at) as first_location
FROM location_history lh
JOIN profiles p ON p.id = lh.user_id
WHERE lh.recorded_at < NOW() - INTERVAL '1 hour'
GROUP BY lh.user_id, p.full_name
ORDER BY last_location DESC;

-- Delete old location history (older than 1 hour)
-- This will clean up the stale locations from AgentC and Abood
DELETE FROM location_history 
WHERE recorded_at < NOW() - INTERVAL '1 hour';

-- Optional: More aggressive cleanup - delete all locations older than 30 minutes
-- DELETE FROM location_history 
-- WHERE recorded_at < NOW() - INTERVAL '30 minutes';

-- Optional: Delete ALL location history for specific agents who logged out
-- Replace the IDs with actual user IDs if needed
-- DELETE FROM location_history 
-- WHERE user_id IN (
--     SELECT id FROM profiles 
--     WHERE full_name IN ('AgentC', 'Abood')
-- );

-- Verify cleanup
SELECT 
    lh.user_id,
    p.full_name,
    COUNT(*) as location_count,
    MAX(lh.recorded_at) as last_location
FROM location_history lh
JOIN profiles p ON p.id = lh.user_id
GROUP BY lh.user_id, p.full_name
ORDER BY last_location DESC;