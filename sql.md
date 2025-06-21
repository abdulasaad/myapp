# Geography Error Investigation Commands

Run these SQL commands in your Supabase SQL editor to investigate the PostGIS geography type error:

## 10. Check if there's actual data in the geofences table
```sql
SELECT 
    id,
    campaign_id,
    name,
    ST_AsText(area) as area_wkt,
    ST_GeometryType(area::geometry) as geometry_type
FROM geofences 
WHERE campaign_id = '9ef0ab40-b091-48ce-942c-db39ef56b016'::uuid;
```

## 11. Check if there's location data for the user
```sql
SELECT 
    user_id,
    ST_AsText(location) as location_wkt,
    recorded_at
FROM location_history 
WHERE user_id = (SELECT auth.uid())
ORDER BY recorded_at DESC 
LIMIT 5;
```

## 12. Test the geography functions directly
```sql
-- Test if ST_Intersects works with your geography data
SELECT 
    g.name as geofence_name,
    ST_AsText(g.area) as geofence_wkt,
    ST_GeometryType(g.area::geometry) as geofence_type,
    ST_IsValid(g.area::geometry) as is_valid
FROM geofences g 
WHERE campaign_id = '9ef0ab40-b091-48ce-942c-db39ef56b016'::uuid;
```

## 13. Check for NULL or invalid geography data
```sql
-- Check for problematic geography data
SELECT 
    'geofences' as table_name,
    id,
    area IS NULL as is_null,
    ST_IsValid(area::geometry) as is_valid_geometry
FROM geofences
WHERE campaign_id = '9ef0ab40-b091-48ce-942c-db39ef56b016'::uuid

UNION ALL

SELECT 
    'location_history' as table_name,
    id::text,
    location IS NULL as is_null,
    ST_IsValid(location::geometry) as is_valid_geometry
FROM location_history
WHERE user_id = (SELECT auth.uid())
ORDER BY table_name;
```

---

## Root Cause Found: Missing Data

The issue is NOT with PostGIS geography types - it's missing data:
- No geofence exists for campaign `9ef0ab40-b091-48ce-942c-db39ef56b016`
- No location history for the current user
- The function fails when trying to process NULL geography data

## Fix: Update the Function to Handle Missing Data

Replace the existing `check_agent_in_campaign_geofence` function with this improved version:

```sql
CREATE OR REPLACE FUNCTION check_agent_in_campaign_geofence(
    p_agent_id uuid,
    p_campaign_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    latest_location GEOGRAPHY(POINT);
    geofence_area GEOGRAPHY(POLYGON);
    v_intersects_result BOOLEAN := FALSE;
BEGIN
    -- Early return if no data exists to avoid geography type errors
    IF NOT EXISTS (SELECT 1 FROM location_history WHERE user_id = p_agent_id) THEN
        RETURN FALSE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM geofences WHERE campaign_id = p_campaign_id) THEN
        RETURN FALSE;
    END IF;

    -- Get the agent's most recent location
    SELECT location INTO latest_location
    FROM location_history
    WHERE user_id = p_agent_id
    ORDER BY recorded_at DESC
    LIMIT 1;

    -- Get the geofence for the campaign
    SELECT area INTO geofence_area
    FROM geofences
    WHERE campaign_id = p_campaign_id
    LIMIT 1;

    -- Double-check for NULL values
    IF latest_location IS NULL OR geofence_area IS NULL THEN
        RETURN FALSE;
    END IF;

    -- Use ST_DWithin for better geography handling
    v_intersects_result := ST_DWithin(latest_location, geofence_area, 0);

    RETURN v_intersects_result;
    
EXCEPTION WHEN OTHERS THEN
    -- Log the error and return false instead of failing
    RAISE LOG 'Error in check_agent_in_campaign_geofence: %', SQLERRM;
    RETURN FALSE;
END;
$$;
```

## Test the fix
After running the above function, test it:
```sql
SELECT check_agent_in_campaign_geofence(
    '00000000-0000-0000-0000-000000000000'::uuid,
    '9ef0ab40-b091-48ce-942c-db39ef56b016'::uuid
);
```