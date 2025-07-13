-- Debug why some agents don't have location data

-- 1. Check all agents that appear in the live map function vs active_agents table
WITH live_map_agents AS (
  SELECT id, full_name, last_location, last_seen 
  FROM get_agents_with_last_location()
),
active_agents_data AS (
  SELECT 
    user_id,
    last_location[0] as longitude,
    last_location[1] as latitude,
    last_seen,
    updated_at
  FROM active_agents
)
SELECT 
  lma.id,
  lma.full_name,
  lma.last_location as formatted_location,
  lma.last_seen,
  CASE 
    WHEN aad.user_id IS NULL THEN 'NO ENTRY IN active_agents'
    WHEN aad.longitude IS NULL THEN 'NULL LOCATION DATA'
    ELSE 'HAS LOCATION DATA'
  END as location_status
FROM live_map_agents lma
LEFT JOIN active_agents_data aad ON lma.id = aad.user_id
ORDER BY location_status, lma.full_name;

-- 2. Check which users have active status but no location entries
SELECT 
  p.id,
  p.full_name,
  p.status,
  p.connection_status,
  p.last_heartbeat,
  CASE 
    WHEN aa.user_id IS NULL THEN 'NO active_agents ENTRY'
    ELSE 'HAS active_agents ENTRY'
  END as active_agents_status
FROM profiles p
LEFT JOIN active_agents aa ON p.id = aa.user_id
WHERE p.status = 'active' AND p.role IN ('agent', 'manager')
ORDER BY active_agents_status, p.full_name;

-- 3. Find جعفر طارق صبيح specifically
SELECT 
  p.id,
  p.full_name,
  p.username,
  p.status,
  p.connection_status,
  p.last_heartbeat,
  aa.last_location,
  aa.last_seen,
  aa.updated_at
FROM profiles p
LEFT JOIN active_agents aa ON p.id = aa.user_id
WHERE p.full_name LIKE '%جعفر%' OR p.full_name LIKE '%طارق%';