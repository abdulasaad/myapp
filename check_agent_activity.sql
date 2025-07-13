-- Check which agents are actually active vs just marked as active

SELECT 
  p.id,
  p.full_name,
  p.username,
  p.status as profile_status,
  p.connection_status,
  CASE 
    WHEN p.last_heartbeat IS NULL THEN 'NEVER LOGGED IN'
    WHEN NOW() - p.last_heartbeat < INTERVAL '1 minute' THEN 'CURRENTLY ACTIVE'
    WHEN NOW() - p.last_heartbeat < INTERVAL '15 minutes' THEN 'RECENTLY ACTIVE'
    ELSE 'INACTIVE'
  END as actual_status,
  p.last_heartbeat,
  EXTRACT(EPOCH FROM (NOW() - p.last_heartbeat)) / 60 as minutes_since_heartbeat,
  CASE 
    WHEN aa.user_id IS NULL THEN 'NO LOCATION DATA'
    WHEN aa.last_location IS NULL THEN 'NULL LOCATION'
    ELSE 'HAS LOCATION'
  END as location_status,
  aa.last_seen as last_location_update
FROM profiles p
LEFT JOIN active_agents aa ON p.id = aa.user_id
WHERE p.status = 'active' AND p.role IN ('agent', 'manager')
ORDER BY 
  CASE 
    WHEN p.last_heartbeat IS NULL THEN 3
    WHEN NOW() - p.last_heartbeat < INTERVAL '1 minute' THEN 0
    WHEN NOW() - p.last_heartbeat < INTERVAL '15 minutes' THEN 1
    ELSE 2
  END,
  p.last_heartbeat DESC NULLS LAST;