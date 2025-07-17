# Database Setup for Live Map Geofences

## Overview
This document contains the SQL commands needed to set up the database function for displaying geofences (both campaign and touring task geofences) in the live map.

## Required Database Function

### Function: `get_all_geofences_wkt()`

This function returns all active geofences in WKT format for the live map display, including both campaign geofences and touring task geofences.

## SQL Commands to Execute

Copy and paste the following SQL commands into your Supabase SQL Editor:

```sql
-- First, drop the existing function if it exists
DROP FUNCTION IF EXISTS get_all_geofences_wkt();

-- Create function to get all geofences in WKT format for live map
-- This includes both campaign geofences and touring task geofences

CREATE OR REPLACE FUNCTION get_all_geofences_wkt()
RETURNS TABLE(
    geofence_id UUID,
    geofence_name TEXT,
    geofence_area_wkt TEXT,
    geofence_type TEXT,
    geofence_color TEXT,
    campaign_id UUID,
    campaign_name TEXT,
    touring_task_id UUID,
    touring_task_title TEXT,
    max_agents INTEGER,
    is_active BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    -- Campaign geofences (regular geofences)
    SELECT 
        cg.id as geofence_id,
        cg.name as geofence_name,
        cg.area_text as geofence_area_wkt,
        'campaign'::TEXT as geofence_type,
        COALESCE(cg.color, 'FFA500') as geofence_color, -- Default to orange if no color
        cg.campaign_id,
        c.name as campaign_name,
        NULL::UUID as touring_task_id,
        NULL::TEXT as touring_task_title,
        cg.max_agents,
        cg.is_active
    FROM campaign_geofences cg
    JOIN campaigns c ON cg.campaign_id = c.id
    WHERE cg.is_active = true
    
    UNION ALL
    
    -- Touring task geofences (geofences that have touring tasks)
    SELECT 
        cg.id as geofence_id,
        CONCAT('Touring: ', tt.title) as geofence_name,
        cg.area_text as geofence_area_wkt,
        'touring_task'::TEXT as geofence_type,
        COALESCE(cg.color, '9C27B0') as geofence_color, -- Default to purple for touring tasks
        cg.campaign_id,
        c.name as campaign_name,
        tt.id as touring_task_id,
        tt.title as touring_task_title,
        cg.max_agents,
        cg.is_active AND tt.status = 'active' as is_active
    FROM touring_tasks tt
    JOIN campaign_geofences cg ON tt.geofence_id = cg.id
    JOIN campaigns c ON cg.campaign_id = c.id
    WHERE tt.status = 'active' AND cg.is_active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_all_geofences_wkt() TO authenticated;

-- Add comment explaining the function
COMMENT ON FUNCTION get_all_geofences_wkt() IS 'Returns all active geofences in WKT format for live map display, including both campaign geofences and touring task geofences';
```

## How to Apply These Commands

### Step 1: Access Supabase Dashboard
1. Go to https://supabase.com/dashboard
2. Select your project
3. Navigate to the **SQL Editor** tab

### Step 2: Execute the SQL
1. Copy the entire SQL code block above
2. Paste it into the SQL Editor
3. Click the **"Run"** button to execute

### Step 3: Verify the Function
You can test the function by running:
```sql
SELECT * FROM get_all_geofences_wkt();
```

### Step 4: Restart Your App
After creating the function:
1. Restart your Flutter application
2. Navigate to the live map screen
3. Open the geofences panel to see all geofences

## What This Function Returns

The function returns the following data for each geofence:

| Column | Description |
|--------|-------------|
| `geofence_id` | Unique identifier for the geofence |
| `geofence_name` | Display name (regular name for campaign geofences, "Touring: [title]" for touring tasks) |
| `geofence_area_wkt` | WKT polygon data for map rendering |
| `geofence_type` | Either 'campaign' or 'touring_task' |
| `geofence_color` | Hex color code (default: orange for campaign, purple for touring) |
| `campaign_id` | ID of the associated campaign |
| `campaign_name` | Name of the associated campaign |
| `touring_task_id` | ID of the touring task (null for campaign geofences) |
| `touring_task_title` | Title of the touring task (null for campaign geofences) |
| `max_agents` | Maximum number of agents allowed in this geofence |
| `is_active` | Whether the geofence is currently active |

## Expected Results

After applying these commands, your live map will display:

### Campaign Geofences
- **Icon**: Layer outline icon
- **Color**: Orange (default) or custom color from database
- **Name**: Original geofence name
- **Subtitle**: Campaign name

### Touring Task Geofences
- **Icon**: Tour icon
- **Color**: Purple (default) or custom color from database
- **Name**: "Touring: [task title]"
- **Subtitle**: Campaign name
- **Stroke**: Thicker line (3px vs 2px)

## Troubleshooting

### If you get permission errors:
Make sure you're logged in as a database admin or have the necessary permissions.

### If the function already exists:
The `CREATE OR REPLACE FUNCTION` command will update the existing function safely.

### If you get table/column errors:
Ensure your database schema matches the expected structure with tables: `campaign_geofences`, `campaigns`, `touring_tasks`.

### If no geofences appear:
Check that you have:
1. Created campaigns with geofences
2. Created touring tasks linked to geofences
3. Set geofences and touring tasks as active (`is_active = true`, `status = 'active'`)

## Support

If you encounter any issues:
1. Check the Supabase logs for error details
2. Verify your database schema matches the expected structure
3. Ensure you have proper permissions to execute functions
4. Test the function directly in SQL Editor before using in the app