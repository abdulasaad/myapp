-- Add missing columns to active_agents table for Flutter compatibility
-- These will make the table compatible with the Flutter app expectations

-- 1. Add the new columns
ALTER TABLE active_agents 
ADD COLUMN IF NOT EXISTS latitude double precision,
ADD COLUMN IF NOT EXISTS longitude double precision,
ADD COLUMN IF NOT EXISTS last_heartbeat timestamp with time zone,
ADD COLUMN IF NOT EXISTS battery_level integer,
ADD COLUMN IF NOT EXISTS connection_status text;

-- 2. Update existing rows to populate lat/lng from point and set defaults
UPDATE active_agents 
SET 
    latitude = (last_location)[1],
    longitude = (last_location)[0],
    last_heartbeat = COALESCE(last_heartbeat, last_seen),
    connection_status = CASE 
        WHEN last_seen > (NOW() - INTERVAL '5 minutes') THEN 'active'
        WHEN last_seen > (NOW() - INTERVAL '30 minutes') THEN 'away'
        ELSE 'offline'
    END
WHERE last_location IS NOT NULL;

-- 3. Create a trigger to keep lat/lng and other fields in sync
CREATE OR REPLACE FUNCTION sync_active_agents_fields()
RETURNS TRIGGER AS $$
BEGIN
    -- Sync lat/lng from point
    IF NEW.last_location IS NOT NULL THEN
        NEW.latitude := (NEW.last_location)[1];
        NEW.longitude := (NEW.last_location)[0];
    ELSE
        NEW.latitude := NULL;
        NEW.longitude := NULL;
    END IF;
    
    -- Update last_heartbeat if not set
    IF NEW.last_heartbeat IS NULL THEN
        NEW.last_heartbeat := NEW.last_seen;
    END IF;
    
    -- Update connection status based on last_seen
    IF NEW.last_seen IS NOT NULL THEN
        IF NEW.last_seen > (NOW() - INTERVAL '5 minutes') THEN
            NEW.connection_status := 'active';
        ELSIF NEW.last_seen > (NOW() - INTERVAL '30 minutes') THEN
            NEW.connection_status := 'away';
        ELSE
            NEW.connection_status := 'offline';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Drop trigger if exists and create new one
DROP TRIGGER IF EXISTS sync_lat_lng_trigger ON active_agents;
DROP TRIGGER IF EXISTS sync_active_agents_trigger ON active_agents;
CREATE TRIGGER sync_active_agents_trigger
BEFORE INSERT OR UPDATE ON active_agents
FOR EACH ROW
EXECUTE FUNCTION sync_active_agents_fields();

-- 5. Test the result
SELECT 'Updated active_agents schema:' as info;
SELECT 
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'active_agents'
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 6. Verify data
SELECT 'Sample data with new columns:' as info;
SELECT 
    user_id,
    last_location,
    latitude,
    longitude,
    last_seen,
    last_heartbeat,
    connection_status,
    battery_level
FROM active_agents
LIMIT 5;